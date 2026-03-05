//
// CameraFeed.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 9
//

import AVFoundation
import UIKit
import Foundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

final class CameraFeed: NSObject,
                        ObservableObject,
                        AVCaptureVideoDataOutputSampleBufferDelegate {

    // Scene EV100 derived from hardware exposure settings
    @Published var sceneEV100: Double = 0.0

    // CI-processed frame for preview
    @Published var previewFrame: CGImage?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "CameraFeedQueue")
    private var device: AVCaptureDevice?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext(options: nil)

    // Virtual EV offset to apply in manual mode (set by ViewModel)
    var previewEVOffset: Double = 0.0

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

        // Center-weighted auto-exposure
        do {
            try device.lockForConfiguration()
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            // Leave defaults if configuration fails
        }

        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
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

    // MARK: - CI-based preview + metering

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let device = self.device,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

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
            .oriented(.right)   // adjust if needed: .left or remove

        // 3) Apply EV offset from the view model (manual mode only)
        let offset = previewEVOffset
        if abs(offset) > 1e-6 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = Float(offset)
            if let out = filter.outputImage {
                image = out
            }
        }

        // 4) Render to CGImage for preview
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
