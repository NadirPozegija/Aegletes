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

/// evDelta = sceneEV - settingsEV
/// Positive: scene is brighter than settings → **overexposed** (too much light).
/// Negative: scene is darker than settings → **underexposed** (too little light).
func evDelta(evScene100: Double, evSettings100: Double) -> Double {
    return evScene100 - evSettings100
}

/// Auto adjust exposure settings to correct toward the target EV.
///
/// Behavior:
/// - Compute `evDelta = targetEV - settingsEV`.
/// - We consider anything with `evDelta >= evDeltaTarget` acceptable.
///   (evDeltaTarget = -0.1 → up to 0.1 stop under is allowed.)
/// - If `evDelta < evDeltaTarget` (meaningfully underexposed),
///   **brighten** by `ceil(-(delta - evDeltaTarget))` stops.
/// - If `evDelta > evDeltaTarget` (overexposed beyond tolerance),
///   **darken** by `floor(delta - evDeltaTarget)` stops
///   (never intentionally go below `evDeltaTarget`).
/// - 1 stop ≈ 1 index of shutter, 1 index of aperture, or 3 ISO indices.
/// - Stops are spent in priority order:
///   1. Shutter (if unlocked),
///   2. Aperture (if unlocked),
///   3. ISO (if unlocked).
/// - After the main adjustment, a sanity step tries nudging the highest‑priority
///   unlocked axis by ±1 index to get `evDelta` closer to 0 while keeping
///   `evDelta >= evDeltaTarget`.
///
/// Returns:
/// - `true`  if final `evDelta >= evDeltaTarget` (no meaningful underexposure),
/// - `false` if final `evDelta < evDeltaTarget` (still underexposed → low-light warning).
func autoAdjust(settings: inout ExposureSettings,
                locks: ExposureLockState,
                targetEV: Double) -> Bool {

    let evDeltaTarget: Double = -0.1   // accept up to 0.1 stop underexposed

    var s = settings
    var currentEV = settingsEV100(s)
    var delta = targetEV - currentEV

    // Quick exit if we're already within a tiny band around target
    let smallTolerance: Double = 1e-3
    if abs(delta) < smallTolerance {
        settings = s
        return delta >= evDeltaTarget
    }

    // MARK: - Spend stops in priority order: shutter → aperture → ISO

    if delta < evDeltaTarget {
        // UNDEREXPOSED beyond tolerance: need to brighten.
        // We want to move delta up to at least evDeltaTarget.
        // Required change in EV ≈ (evDeltaTarget - delta), so:
        let neededStops = evDeltaTarget - delta        // positive number of stops to add
        var remainingStops = Int(ceil(neededStops))

        // 1) Shutter: lengthen exposure time (toward the end of the array).
        if !locks.shutter && remainingStops > 0 {
            let maxIndex = shutterValues.count - 1
            let available = maxIndex - s.shutterIndex          // steps to longest
            let used = min(remainingStops, available)
            s.shutterIndex += used
            remainingStops -= used
        }

        // 2) Aperture: open up (toward f/1.4, index down).
        if !locks.aperture && remainingStops > 0 {
            let available = s.apertureIndex                    // steps to index 0
            let used = min(remainingStops, available)
            s.apertureIndex -= used
            remainingStops -= used
        }

        // 3) ISO: raise ISO (3 ticks ≈ 1 stop).
        if !locks.iso && remainingStops > 0 {
            let maxIndex = isoValues.count - 1
            let availableTicks = maxIndex - s.isoIndex
            let availableStops = availableTicks / 3
            let used = min(remainingStops, availableStops)
            s.isoIndex += used * 3
            remainingStops -= used
        }

        currentEV = settingsEV100(s)
        delta = targetEV - currentEV
    } else if delta >= evDeltaTarget {
        // OVEREXPOSED beyond tolerance: need to darken.
        // We want to move delta down toward evDeltaTarget (but not below).
        let extra = delta - evDeltaTarget                  // how many stops to remove
        var remainingStops = Int(floor(extra))

        if remainingStops > 0 {
            // 1) Shutter: shorten exposure time (toward faster speeds).
            if !locks.shutter && remainingStops > 0 {
                let available = s.shutterIndex             // steps to index 0
                let used = min(remainingStops, available)
                s.shutterIndex -= used
                remainingStops -= used
            }

            // 2) Aperture: stop down (toward higher f-numbers).
            if !locks.aperture && remainingStops > 0 {
                let maxIndex = apertureValues.count - 1
                let available = maxIndex - s.apertureIndex // steps to max f
                let used = min(remainingStops, available)
                s.apertureIndex += used
                remainingStops -= used
            }

            // 3) ISO: lower ISO (3 ticks ≈ 1 stop).
            if !locks.iso && remainingStops > 0 {
                let availableTicks = s.isoIndex
                let availableStops = availableTicks / 3
                let used = min(remainingStops, availableStops)
                s.isoIndex -= used * 3
                remainingStops -= used
            }
        }

        currentEV = settingsEV100(s)
        delta = targetEV - currentEV
    }

    // At this point, s is the main-adjusted settings.
    // If we're still underexposed beyond tolerance, we hit bounds and couldn't fix it.
    if delta < evDeltaTarget {
        settings = s
        return false
    }

    // MARK: - Sanity nudge: one index tweak on highest-priority unlocked axis

    func tryNudge(_ axis: WritableKeyPath<ExposureSettings, Int>,
                  direction: Int) {
        let oldIndex = s[keyPath: axis]
        let newIndex = oldIndex + direction

        // Bounds check
        if axis == \.shutterIndex {
            guard newIndex >= 0, newIndex < shutterValues.count else { return }
        } else if axis == \.apertureIndex {
            guard newIndex >= 0, newIndex < apertureValues.count else { return }
        } else if axis == \.isoIndex {
            guard newIndex >= 0, newIndex < isoValues.count else { return }
        }

        var candidate = s
        candidate[keyPath: axis] = newIndex
        let ev = settingsEV100(candidate)
        let newDelta = targetEV - ev

        // Only accept if we stay within the acceptable range and get closer to 0.
        if newDelta >= evDeltaTarget, abs(newDelta) < abs(delta) {
            s = candidate
            delta = newDelta
        }
    }

    // We currently have delta >= evDeltaTarget. To get closer to 0,
    // we want to "darken" a bit (reduce delta's magnitude toward 0).
    if delta > evDeltaTarget {
        // Priority: shutter → aperture → ISO (respecting locks)
        if !locks.shutter {
            // Darken shutter = shorter time = move one index toward 0.
            tryNudge(\.shutterIndex, direction: -1)
        } else if !locks.aperture {
            // Darken aperture = higher f-number = move +1.
            tryNudge(\.apertureIndex, direction: +1)
        } else if !locks.iso {
            // Darken ISO = lower ISO = move -1 (1/3-stop).
            tryNudge(\.isoIndex, direction: -1)
        }
    }

    settings = s
    return delta >= evDeltaTarget
}
