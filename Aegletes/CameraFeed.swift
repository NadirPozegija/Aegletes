//
// CameraFeed.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 4
//

import AVFoundation
import UIKit
import Foundation
import Combine
import ImageIO

enum ExposureControlMode {
    case auto
    case manual
}

final class CameraFeed: NSObject,
                        ObservableObject,
                        AVCaptureVideoDataOutputSampleBufferDelegate,
                        AVCapturePhotoCaptureDelegate {

    @Published var sceneEV100: Double = 0.0
    @Published var meteringMode: MeteringMode = .centerWeighted  // label-only for now
    @Published var exifBrightnessValue: Double? = nil            // from EXIF

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "CameraFeedQueue")
    private var device: AVCaptureDevice?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

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

        // Video output for live EV metering
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Photo output for EXIF metadata (BrightnessValue)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
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
                    // For manual, we will drive exposure via setExposureModeCustom.
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

    // Apply manual ISO and shutter time (seconds) from the pickers
    func applyManualExposure(iso: Double, shutter: Double) {
        queue.async {
            guard let device = self.device else { return }

            do {
                try device.lockForConfiguration()

                // Clamp ISO to device range
                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let targetISO = Float(iso)
                let clampedISO = max(minISO, min(targetISO, maxISO))

                // Clamp shutter to device range
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
                // Ignore configuration errors for now
            }
        }
    }

    // MARK: - Live metering from exposure settings (no pixels)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let device = self.device else { return }

        // Read the camera's current exposure settings (AE or manual)
        let duration = device.exposureDuration   // CMTime
        let iso = device.iso                     // Float
        let aperture = device.lensAperture       // Float (fixed per lens)
        let t = max(duration.seconds, 1e-6)      // shutter time in seconds as Double

        // Base EV100 from exposure settings
        let evScene = ev100FromSettings(
            aperture: Double(aperture),
            shutter: t,
            iso: Double(iso)
        )

        DispatchQueue.main.async {
            self.sceneEV100 = evScene
        }
    }

    // MARK: - EXIF BrightnessValue sampling

    func captureExifBrightnessSample() {
        let settings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *) {
            // Use a modest size since we only need metadata; adjust as needed
            settings.maxPhotoDimensions = .init(width: 1920, height: 1080)
        } else {
            // Fallback for older OSes where maxPhotoDimensions isn't available
            settings.isHighResolutionPhotoEnabled = false
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        guard error == nil else { return }

        let metadata = photo.metadata

        if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let bv = exif[kCGImagePropertyExifBrightnessValue as String] as? Double {
            DispatchQueue.main.async {
                self.exifBrightnessValue = bv
            }
        }
    }
}

