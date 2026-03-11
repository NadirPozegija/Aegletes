//
// AegletesViewModel.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 14
// Edited on 3/11/26 - Track low-light warning from autoAdjust
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

    // EV offset used for manual preview simulation
    @Published var previewEVOffset: Double = 0.0

    // True when no combination of exposure settings can reach evDelta ≥ 0.
    @Published var lowLightWarning: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        exposure = ExposureSettings(
            isoIndex: isoValues.firstIndex(of: 100)!,
            apertureIndex: apertureValues.firstIndex(of: 8)!,
            shutterIndex: shutterValues.firstIndex(where: { abs($0 - 1/250) < 1e-6 }) ?? 4
        )

        // When scene EV changes, run auto-adjust (in light meter mode)
        // and recompute preview offset (in manual mode)
        camera.$sceneEV100
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateForNewSceneEV()
                self?.updatePreviewEVOffsetIfNeeded()
            }
            .store(in: &cancellables)
    }

    var sceneEV100Value: Double {
        camera.sceneEV100
    }

    var settingsEV100Value: Double {
        settingsEV100(exposure)
    }

    var evDeltaValue: Double {
        evDelta(evScene100: sceneEV100Value, evSettings100: settingsEV100Value)
    }

    // Light-meter mode: auto adjust unlocked settings toward the scene EV
    func updateForNewSceneEV() {
        guard !manualMode else { return }
        var e = exposure
        let ok = autoAdjust(settings: &e,
                            locks: locks,
                            targetEV: camera.sceneEV100)
        exposure = e
        lowLightWarning = !ok   // show warning only when no evDelta ≥ 0 is possible
    }

    // Manual mode: simulate exposure via preview only (no hardware changes)
    func updatePreviewEVOffsetIfNeeded() {
        guard manualMode else {
            previewEVOffset = 0.0
            camera.previewEVOffset = 0.0
            return
        }
        let evTarget = settingsEV100Value
        let evCamera = sceneEV100Value
        // Positive offset should brighten the image, so use camera - target.
        // If target EV is higher (darker settings), this becomes negative → darker preview.
        let delta = evCamera - evTarget
        previewEVOffset = delta
        camera.previewEVOffset = delta
    }

    func setManualMode(_ manual: Bool) {
        manualMode = manual
        if manual {
            // In manual mode, low-light warning is not relevant
            lowLightWarning = false
        } else {
            // Re-run auto-adjust and warning when returning to meter mode
            updateForNewSceneEV()
        }
        updatePreviewEVOffsetIfNeeded()
    }
}
