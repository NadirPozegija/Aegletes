//
// CameraFeed.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/10/26 - Moved AVCaptureSession off of main thread to avoid UI hang ups
//

import AVFoundation
import UIKit
import Foundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

enum ExposureControlMode {
    case auto
    case manual
}

final class CameraFeed: NSObject,
                        ObservableObject,
                        AVCaptureVideoDataOutputSampleBufferDelegate {

    // Scene EV100 derived from hardware exposure settings
    @Published var sceneEV100: Double = 0.0

    // Processed frame for preview (after Core Image exposure adjust)
    @Published var previewFrame: CGImage?

    // Brightness histogram bins (0..1 fractions, 256 bins, dark → bright)
    @Published var histogramBins: [CGFloat] = Array(repeating: 0, count: 256)

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "CameraFeedQueue")
    private var device: AVCaptureDevice?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext(options: nil)

    // Metal-based histogram computer
    private let metalHistogram = MetalHistogram(minUpdateInterval: 0.1)

    // Virtual EV offset to apply in manual mode (set by ViewModel)
    var previewEVOffset: Double = 0.0

    // Track whether we're using the iPhone's AE as a light meter or full manual control
    private(set) var mode: ExposureControlMode = .auto

    override init() {
        super.init()
        configureSession()
    }

    // MARK: - Session control (moved off main thread)

    func start() {
        queue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Session configuration

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }

        self.device = device
        session.addInput(input)

        // Center-weighted auto-exposure using the system’s own meter
        do {
            try device.lockForConfiguration()
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5) // center
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
            mode = .auto
        } catch {
            // If configuration fails, just leave defaults
        }

        // Request BGRA so we can easily build both CIImage and Metal textures
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        // Video output for live EV metering + Core Image preview + Metal histogram
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
    }

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    // MARK: - Zoom

    func setZoom(factor: CGFloat) {
        queue.async {
            guard let device = self.device else { return }
            let minZoom: CGFloat = 1.0
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 8.0)
            let clamped = max(minZoom, min(factor, maxZoom))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                // Ignore zoom errors
            }
        }
    }

    // MARK: - Exposure control mode

    func setAutoExposureEnabled(_ enabled: Bool) {
        queue.async {
            guard let device = self.device else { return }
            do {
                try device.lockForConfiguration()
                if enabled {
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    self.mode = .auto
                } else {
                    if device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                    }
                    self.mode = .manual
                }
                device.unlockForConfiguration()
            } catch {
                // Ignore configuration errors for now
            }
        }
    }

    // Optional: apply manual ISO/shutter to hardware (not used by preview simulation)
    func applyManualExposure(iso: Double, shutter: Double) {
        queue.async {
            guard let device = self.device else { return }
            do {
                try device.lockForConfiguration()

                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let targetISO = Float(iso)
                let clampedISO = max(minISO, min(targetISO, maxISO))

                let desiredDuration = CMTimeMakeWithSeconds(
                    shutter,
                    preferredTimescale: 1_000_000_000
                )
                let minDuration = device.activeFormat.minExposureDuration
                let maxDuration = device.activeFormat.maxExposureDuration
                var duration = desiredDuration
                if CMTimeCompare(duration, minDuration) < 0 { duration = minDuration }
                if CMTimeCompare(duration, maxDuration) > 0 { duration = maxDuration }

                device.setExposureModeCustom(duration: duration,
                                             iso: clampedISO,
                                             completionHandler: nil)
                self.mode = .manual
                device.unlockForConfiguration()
            } catch {
                // Ignore manual exposure errors
            }
        }
    }

    // MARK: - Live metering + Core Image exposure simulation + Metal histogram

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard
            let device = self.device,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        // 1) Compute EV100 from hardware exposure
        let duration = device.exposureDuration
        let iso = device.iso
        let aperture = device.lensAperture
        let t = max(duration.seconds, 1e-6)

        let evScene = ev100FromSettings(
            aperture: Double(aperture),
            shutter: t,
            iso: Double(iso)
        )

        // 2) Build CIImage from pixel buffer and orient to portrait
        var image = CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(.right)

        // 3) Compute brightness histogram via Metal (throttled)
        if let metalHistogram = metalHistogram,
           let bins = metalHistogram.updateHistogramIfNeeded(from: pixelBuffer) {
            DispatchQueue.main.async {
                self.histogramBins = bins
            }
        }

        // 4) Apply EV offset (set by ViewModel in manual mode) for preview
        let offset = previewEVOffset
        if abs(offset) > 1e-6 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = Float(offset)
            if let out = filter.outputImage {
                image = out
            }
        }

        // 5) Render to CGImage for preview
        let extent = image.extent
        guard let cg = ciContext.createCGImage(image, from: extent) else {
            DispatchQueue.main.async {
                self.sceneEV100 = evScene
            }
            return
        }

        DispatchQueue.main.async {
            self.sceneEV100 = evScene
            self.previewFrame = cg
        }
    }
}
