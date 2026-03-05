//
// AegletesViewModel.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 8
//

import Foundation
import SwiftUI
import Combine

final class AegletesViewModel: ObservableObject {
    @Published var camera = CameraFeed()
    @Published var exposure: ExposureSettings
    @Published var locks = ExposureLockState()

    // false = light meter (auto AE), true = full manual exposure
    @Published var manualMode = false

    // Metering mode selection; forwarded to CameraFeed
    @Published var meteringMode: MeteringMode = .centerWeighted {
        didSet { camera.meteringMode = meteringMode }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        exposure = ExposureSettings(
            isoIndex: isoValues.firstIndex(of: 100)!,
            apertureIndex: apertureValues.firstIndex(of: 8)!,
            shutterIndex: shutterValues.firstIndex(where: { abs($0 - 1/250) < 1e-6 }) ?? 4
        )

        // Ensure camera starts with same metering mode
        camera.meteringMode = meteringMode

        // Whenever the meter EV changes, update auto settings (light meter mode only)
        camera.$sceneEV100
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateForNewSceneEV()
            }
            .store(in: &cancellables)
    }

    // EXIF BrightnessValue from a sampled still image (may be nil)
    var exifBrightnessLabel: String {
        if let bv = camera.exifBrightnessValue {
            return String(format: "%0.2f", bv)
        } else {
            return "--"
        }
    }

    // Scene EV at ISO 100 from live exposure settings
    var sceneEV100Value: Double {
        camera.sceneEV100
    }

    // EV100 from current wheel settings
    var settingsEV100Value: Double {
        settingsEV100(exposure)
    }

    // Difference between scene EV and settings EV
    var evDeltaValue: Double {
        evDelta(evScene100: sceneEV100Value, evSettings100: settingsEV100Value)
    }

    // Light-meter mode: auto adjust unlocked settings toward the scene EV
    func updateForNewSceneEV() {
        // NO automatic adjustments in manual mode
        guard !manualMode else { return }

        var e = exposure
        autoAdjust(settings: &e, locks: locks, targetEV: camera.sceneEV100)
        exposure = e
    }

    // Manual mode: directly apply wheel settings to the physical camera
    func applyPickersToCamera() {
        let iso = isoValues[exposure.isoIndex]
        let shutter = shutterValues[exposure.shutterIndex]
        camera.applyManualExposure(iso: iso, shutter: shutter)
    }

    // Trigger a single EXIF BrightnessValue sample
    func captureExifBrightnessSample() {
        camera.captureExifBrightnessSample()
    }

    // Switch between light-meter mode and manual exposure mode
    func setManualMode(_ manual: Bool) {
        manualMode = manual

        if manual {
            camera.setAutoExposureEnabled(false)
            applyPickersToCamera()
        } else {
            camera.setAutoExposureEnabled(true)
            updateForNewSceneEV()
        }
    }
}
