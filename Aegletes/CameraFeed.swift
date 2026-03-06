//
// CameraFeed.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/7/26 - Y-plane brightness histogram
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

    // Brightness histogram bins (0..1 fractions, 256 bins, 0 = black, 255 = white)
    @Published var histogramBins: [CGFloat] = Array(repeating: 0, count: 256)

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "CameraFeedQueue")
    private var device: AVCaptureDevice?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext(options: nil)

    // Virtual EV offset to apply in manual mode (set by ViewModel)
    var previewEVOffset: Double = 0.0

    // Histogram configuration (Y-plane histogram)
    private let histogramBinCount = 256
    private let histogramMinInterval: CFTimeInterval = 0.1
    private var lastHistogramTime: CFTimeInterval = 0

    // Track whether we're using the iPhone's AE as a light meter or full manual control
    private(set) var mode: ExposureControlMode = .auto

    override init() {
        super.init()
        configureSession()
    }

    func start() { session.startRunning() }
    func stop() { session.stopRunning() }

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

        // Request a YUV 4:2:0 buffer so we can use the Y plane for histogram
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]

        // Video output for live EV metering + Core Image preview
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
            }
        }
    }

    // MARK: - Live metering + Core Image exposure simulation + histogram
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

        // 3) Compute brightness histogram from Y plane (throttled)
        let now = CACurrentMediaTime()
        if now - lastHistogramTime >= histogramMinInterval,
           let bins = computeLumaHistogram(from: pixelBuffer) {
            lastHistogramTime = now
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

    /// Compute a 256-bin brightness histogram from the Y plane of a 420f buffer.
    /// Bin index 0 = luma 0 (pure black), bin 255 = luma 255 (pure white).
    private func computeLumaHistogram(from pixelBuffer: CVPixelBuffer) -> [CGFloat]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        // Plane 0 is luminance (Y) for 420 bi-planar buffers
        guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
              let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        else {
            return nil
        }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        var counts = [Int](repeating: 0, count: histogramBinCount)
        var totalPixels = 0

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            let row = buffer.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                let value = Int(row[x]) // 0..255 luma
                counts[value] += 1
                totalPixels += 1
            }
        }

        guard totalPixels > 0 else { return nil }

        let totalF = Double(totalPixels)
        return counts.map { CGFloat(Double($0) / totalF) }
    }
}
