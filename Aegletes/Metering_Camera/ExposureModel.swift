//
// ExposureModel.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/7/26 - Revision 4 (ISO 1/3-stops, autoAdjust uses full-stop ISO steps)
//

import Foundation

struct ExposureLockState {
    var iso: Bool = false
    var aperture: Bool = false
    var shutter: Bool = false
}

struct ExposureSettings {
    var isoIndex: Int
    var apertureIndex: Int
    var shutterIndex: Int
}

// ISO: 12 → 6400, 1/3-stop increments (two ticks between each full stop)
let isoValues: [Double] = [
    12, 16, 20,
    25, 32, 40,
    50, 64, 80,
    100, 125, 160,
    200, 250, 320,
    400, 500, 640,
    800, 1000, 1250,
    1600, 2000, 2500,
    3200, 4000, 5000,
    6400
]

// Aperture stops (conceptual)
let apertureValues: [Double] = [1.4, 2, 2.8, 4, 5.6, 8, 11, 16]

// Shutter: 1/4000 → 4s
let shutterValues: [Double] = [
    1/4000, 1/2000, 1/1000, 1/500, 1/250,
    1/125,  1/60,   1/30,   1/15,  1/8,
    1/4,    1/2,    1,      2,     4
]

// EV at ISO 100 from settings
func ev100FromSettings(aperture: Double, shutter: Double, iso: Double) -> Double {
    // EV100 = log2(N^2 / t) - log2(iso / 100)
    let base = (aperture * aperture) / shutter
    return log2(base) - log2(iso / 100.0)
}

func settingsEV100(_ s: ExposureSettings) -> Double {
    ev100FromSettings(
        aperture: apertureValues[s.apertureIndex],
        shutter: shutterValues[s.shutterIndex],
        iso: isoValues[s.isoIndex]
    )
}

func evDelta(evScene100: Double, evSettings100: Double) -> Double {
    return evScene100 - evSettings100
}

// Auto adjust: priority shutter → aperture → ISO, respecting lock.
// For ISO, treat one "step" as 3 indices (~1 full stop) so it behaves like before
// even though the wheel exposes 1/3-stop ticks.
// Helper: minimal (brightest) EV we can reach given current locks.
private func minPossibleEV(for settings: ExposureSettings,
                           locks: ExposureLockState) -> Double {
    var s = settings

    // Brightest aperture: smallest f-number
    if !locks.aperture {
        s.apertureIndex = 0
    }

    // Brightest shutter: longest time
    if !locks.shutter {
        s.shutterIndex = shutterValues.indices.last!
    }

    // Brightest ISO: highest sensitivity
    if !locks.iso {
        s.isoIndex = isoValues.indices.last!
    }

    return settingsEV100(s)
}

// Auto adjust: priority shutter → aperture → ISO, respecting lock.
// NEW: guarantees evDelta >= 0 if physically possible, and reports whether that was possible.
func autoAdjust(settings: inout ExposureSettings,
                locks: ExposureLockState,
                targetEV: Double,
                maxIterations: Int = 16) -> Bool {

    // 1) Check if there exists ANY combination with evDelta >= 0.
    //    i.e., some settingsEV <= targetEV.
    let minEV = minPossibleEV(for: settings, locks: locks)
    let canReachNonNegative = (minEV <= targetEV + 1e-6)

    // 2) Original greedy behavior (unchanged).
    var currentEV = settingsEV100(settings)

    func attemptAdjust(for keyPath: WritableKeyPath<ExposureSettings, Int>,
                       values: [Double],
                       step: Int = 1) -> Bool {
        let oldIndex = settings[keyPath: keyPath]
        var bestIndex = oldIndex
        var bestEV = currentEV

        let down = max(oldIndex - step, 0)
        let up = min(oldIndex + step, values.count - 1)
        let candidates = [down, up].filter { $0 != oldIndex }

        for idx in candidates {
            var test = settings
            test[keyPath: keyPath] = idx
            let newEV = settingsEV100(test)
            if abs(targetEV - newEV) < abs(targetEV - bestEV) {
                bestEV = newEV
                bestIndex = idx
            }
        }

        if bestIndex != oldIndex {
            settings[keyPath: keyPath] = bestIndex
            currentEV = bestEV
            return true
        }
        return false
    }

    for _ in 0..<maxIterations {
        var changed = false

        if !locks.shutter {
            changed = attemptAdjust(for: \.shutterIndex,
                                    values: shutterValues,
                                    step: 1) || changed
        }
        if !locks.aperture {
            changed = attemptAdjust(for: \.apertureIndex,
                                    values: apertureValues,
                                    step: 1) || changed
        }
        if !locks.iso {
            // ISO “step” is 3 indices ≈ 1 stop
            changed = attemptAdjust(for: \.isoIndex,
                                    values: isoValues,
                                    step: 3) || changed
        }
        if !changed { break }
    }

    // 3) If some combination CAN achieve evDelta >= 0, clamp final result so evDelta >= 0.
    if canReachNonNegative {
        var delta = targetEV - currentEV       // evDelta = sceneEV - settingsEV
        var guardIterations = 0

        while delta < 0 && guardIterations < 32 {
            var brightened = false

            // Try to brighten via shutter first (longer exposure)
            if !locks.shutter {
                let old = settings.shutterIndex
                if old < shutterValues.count - 1 {
                    settings.shutterIndex = old + 1
                    currentEV = settingsEV100(settings)
                    brightened = true
                }
            }

            // If we couldn't change shutter, brighten via aperture (wider, smaller f-number)
            if !brightened && !locks.aperture {
                let old = settings.apertureIndex
                if old > 0 {
                    settings.apertureIndex = old - 1
                    currentEV = settingsEV100(settings)
                    brightened = true
                }
            }

            // If still no change, brighten via ISO (higher sensitivity)
            if !brightened && !locks.iso {
                let old = settings.isoIndex
                if old < isoValues.count - 1 {
                    let newIndex = min(old + 3, isoValues.count - 1) // ~1 stop
                    settings.isoIndex = newIndex
                    currentEV = settingsEV100(settings)
                    brightened = true
                }
            }

            if !brightened { break } // Can't get any brighter given locks/limits
            delta = targetEV - currentEV
            guardIterations += 1
        }
    }

    // Caller can use this to decide whether to show "Low Light Warning"
    return canReachNonNegative
}
