//
// AegletesViewModel.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 6
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

    private var cancellables = Set<AnyCancellable>()

    init() {
        exposure = ExposureSettings(
            isoIndex: isoValues.firstIndex(of: 100)!,
            apertureIndex: apertureValues.firstIndex(of: 8)!,
            shutterIndex: shutterValues.firstIndex(where: { abs($0 - 1/250) < 1e-6 }) ?? 4
        )

        // Whenever the meter EV changes, update auto settings (light meter mode only)
        camera.$sceneEV100
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateForNewSceneEV()
            }
            .store(in: &cancellables)
    }

    var evDeltaValue: Double {
        let sEV = settingsEV100(exposure)
        return evDelta(evScene100: camera.sceneEV100, evSettings100: sEV)
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

    // Switch between light-meter mode and manual exposure mode
    func setManualMode(_ manual: Bool) {
        manualMode = manual

        if manual {
            // Full manual: stop using AE as a meter, drive exposure strictly from wheels
            camera.setAutoExposureEnabled(false)
            applyPickersToCamera()
        } else {
            // Light meter mode: re-enable AE and let autoAdjust align the wheels
            camera.setAutoExposureEnabled(true)
            updateForNewSceneEV()
        }
    }
}
