//
//  CameraFeed.swift
//  Aegletes
//
//  Created by Nadir Pozegija on 3/3/26.
//

import AVFoundation
import UIKit
import Foundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import os.log

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

    // Session health
    @Published var sessionErrorMessage: String?
    @Published var sessionInterrupted: Bool = false

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

    // Logger
    private let logger = Logger(subsystem: "com.aegletes.app", category: "CameraFeed")

    override init() {
        super.init()
        configureSession()
        setupSessionObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Session control (off main thread)

    func start() {
        queue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.logger.debug("Starting capture session")
            self.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.logger.debug("Stopping capture session")
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
                                                 position: .back)
        else {
            logger.error("Unable to get default wide angle camera")
            session.commitConfiguration()
            return
        }

        guard
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            logger.error("Unable to create or add AVCaptureDeviceInput")
            session.commitConfiguration()
            return
        }

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
            logger.debug("Camera configured for continuous auto exposure")
        } catch {
            logger.error("Failed to configure camera exposure: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                self.sessionErrorMessage = "Unable to configure camera exposure."
            }
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
        } else {
            logger.error("Unable to add video output to capture session")
        }

        session.commitConfiguration()
    }

    // MARK: - Session observers

    private func setupSessionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRuntimeError(_:)),
            name: AVCaptureSession.runtimeErrorNotification,
            object: session
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVCaptureSession.wasInterruptedNotification,
            object: session
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruptionEnded(_:)),
            name: AVCaptureSession.interruptionEndedNotification,
            object: session
        )
    }

    @objc private func handleRuntimeError(_ notification: Notification) {
        let nsError = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
        let message = nsError?.localizedDescription ?? "Camera failed with an unknown error."

        logger.error("AVCaptureSession runtime error: \(message, privacy: .public)")

        DispatchQueue.main.async {
            self.sessionErrorMessage = message
            self.sessionInterrupted = false
        }

        stop()
    }

    @objc private func handleInterruption(_ notification: Notification) {
        logger.debug("AVCaptureSession was interrupted")
        DispatchQueue.main.async {
            self.sessionInterrupted = true
            self.sessionErrorMessage = nil
        }
    }

    @objc private func handleInterruptionEnded(_ notification: Notification) {
        logger.debug("AVCaptureSession interruption ended")
        DispatchQueue.main.async {
            self.sessionInterrupted = false
        }
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
                self.logger.error("Failed to set zoom: \(error.localizedDescription, privacy: .public)")
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
                    self.logger.debug("Switched to auto exposure mode")
                } else {
                    if device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                    }
                    self.mode = .manual
                    self.logger.debug("Switched to manual exposure mode")
                }
                device.unlockForConfiguration()
            } catch {
                self.logger.error("Failed to change exposure mode: \(error.localizedDescription, privacy: .public)")
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
                self.logger.debug("Applied manual exposure: ISO \(iso, privacy: .public), shutter \(shutter, privacy: .public)")
                device.unlockForConfiguration()
            } catch {
                self.logger.error("Failed to apply manual exposure: \(error.localizedDescription, privacy: .public)")
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
