//
// ExposureModel.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 2
//

import Foundation

enum ExposureLock {
    case none, iso, aperture, shutter
}

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

// ISO: 25 → 6400
let isoValues: [Double] = [
    25, 50, 100, 200, 400, 800, 1600, 3200, 6400
]

// Aperture stops
let apertureValues: [Double] = [1.4, 2, 2.8, 4, 5.6, 8, 11, 16]

// Shutter: 1/4000 → 4s
let shutterValues: [Double] = [
    1/4000, 1/2000, 1/1000, 1/500, 1/250,
    1/125, 1/60, 1/30, 1/15, 1/8,
    1/4, 1/2, 1, 2, 4
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

// Auto adjust: priority shutter → aperture → ISO, respecting lock
func autoAdjust(settings: inout ExposureSettings,
                locks: ExposureLockState,
                targetEV: Double,
                maxIterations: Int = 16) {

    var currentEV = settingsEV100(settings)

    func attemptAdjust(for keyPath: WritableKeyPath<ExposureSettings, Int>,
                       values: [Double]) -> Bool {
        let oldIndex = settings[keyPath: keyPath]
        var bestIndex = oldIndex
        var bestEV = currentEV

        let down = max(oldIndex - 1, 0)
        let up = min(oldIndex + 1, values.count - 1)
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
        let delta = targetEV - currentEV
        if abs(delta) < 0.1 { break }

        var changed = false

        // 1) Shutter
        if !locks.shutter {
            changed = attemptAdjust(for: \.shutterIndex, values: shutterValues)
        }

        // 2) Aperture
        if !changed && !locks.aperture {
            changed = attemptAdjust(for: \.apertureIndex, values: apertureValues)
        }

        // 3) ISO
        if !changed && !locks.iso {
            changed = attemptAdjust(for: \.isoIndex, values: isoValues)
        }

        if !changed { break }
    }
}
