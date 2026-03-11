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

/// Auto adjust exposure settings to match the target EV.
///
/// Behavior:
/// - Priority of *what is allowed to change*:
///   1. Try to solve using **shutter + aperture only** (ISO fixed).
///   2. Only if that fails, allow **ISO** to change as well.
/// - Among all candidates with `evDelta >= 0` (sceneEV - settingsEV), choose the one
///   with the **smallest positive evDelta** (as close to 0 as possible).
///   Ties (or near-ties) are broken by preferring:
///     - shutter changes first (no penalty),
///     - then aperture changes (small penalty),
///     - then ISO changes (large penalty).
/// - If *no* candidate can achieve `evDelta >= 0`, choose the closest overall
///   (min |evDelta|) and return `false` (low-light warning case).
///
/// Returns:
/// - `true`  if a combination with `evDelta >= 0` was found
/// - `false` otherwise.
func autoAdjust(settings: inout ExposureSettings,
                locks: ExposureLockState,
                targetEV: Double) -> Bool {

    let current = settings

    // Preference penalty: how "undesirable" it is to move away from the current settings.
    //  - Shutter changes carry no penalty (free to move).
    //  - Aperture changes are mildly penalized.
    //  - ISO changes are strongly penalized (last resort).
    func preferencePenalty(for candidate: ExposureSettings,
                           from base: ExposureSettings) -> Double {
        let apertureDist = abs(candidate.apertureIndex - base.apertureIndex)
        let isoTicks = abs(candidate.isoIndex - base.isoIndex)
        let isoStops = Double(isoTicks) / 3.0

        // We ignore shutterDist in the penalty (0 weight), penalize aperture a bit,
        // and ISO quite a bit more.
        let apertureWeight = 0.04
        let isoWeight = 0.15

        return apertureWeight * Double(apertureDist)
             + isoWeight * isoStops
    }

    // Search helper over a given set of ISO indices (respects locks on other axes).
    func search(isoIndices: [Int]) -> (bestPositive: (ExposureSettings, Double /*delta*/, Double /*penalty*/)?,
                                       bestAny: (ExposureSettings, Double /*absDelta*/)) {

        // Baseline: current settings
        var bestAnySettings = current
        var bestAnyAbsDelta = abs(targetEV - settingsEV100(current))

        var bestPositiveSettings: ExposureSettings?
        var bestPositiveDelta: Double = .greatestFiniteMagnitude
        var bestPositivePenalty: Double = .greatestFiniteMagnitude

        let apertureRange: [Int] = locks.aperture
            ? [current.apertureIndex]
            : Array(apertureValues.indices)

        let shutterRange: [Int] = locks.shutter
            ? [current.shutterIndex]
            : Array(shutterValues.indices)

        let eps: Double = 1e-4

        for isoIdx in isoIndices {
            for apertureIdx in apertureRange {
                for shutterIdx in shutterRange {
                    var candidate = current

                    // Respect ISO lock
                    candidate.isoIndex = locks.iso ? current.isoIndex : isoIdx
                    candidate.apertureIndex = apertureIdx
                    candidate.shutterIndex = shutterIdx

                    let ev = settingsEV100(candidate)
                    let delta = targetEV - ev
                    let absDelta = abs(delta)

                    // Track closest overall (min |delta|)
                    if absDelta < bestAnyAbsDelta {
                        bestAnyAbsDelta = absDelta
                        bestAnySettings = candidate
                    }

                    // Only consider candidates on the "bright enough" side
                    if delta >= 0 {
                        let penalty = preferencePenalty(for: candidate, from: current)

                        if bestPositiveSettings == nil {
                            bestPositiveSettings = candidate
                            bestPositiveDelta = delta
                            bestPositivePenalty = penalty
                        } else {
                            // Primary key: smaller positive delta
                            if delta < bestPositiveDelta - eps {
                                bestPositiveSettings = candidate
                                bestPositiveDelta = delta
                                bestPositivePenalty = penalty
                            }
                            // Secondary key: for near-equal delta, smaller penalty
                            else if abs(delta - bestPositiveDelta) <= eps,
                                    penalty < bestPositivePenalty {
                                bestPositiveSettings = candidate
                                bestPositiveDelta = delta
                                bestPositivePenalty = penalty
                            }
                        }
                    }
                }
            }
        }

        if let pos = bestPositiveSettings {
            return ((pos, bestPositiveDelta, bestPositivePenalty),
                    (bestAnySettings, bestAnyAbsDelta))
        } else {
            return (nil, (bestAnySettings, bestAnyAbsDelta))
        }
    }

    // Case 1: ISO is *not* locked → try to solve without touching ISO first.
    if !locks.iso {
        // 1A. Try shutter + aperture only (ISO fixed)
        let resultNoISO = search(isoIndices: [current.isoIndex])

        if let bestPos = resultNoISO.bestPositive {
            settings = bestPos.0
            return true
        }

        // 1B. Allow ISO to change as well
        let resultFull = search(isoIndices: Array(isoValues.indices))

        if let bestPos = resultFull.bestPositive {
            settings = bestPos.0
            return true
        } else {
            // No candidate with evDelta >= 0 exists at all
            settings = resultFull.bestAny.0
            return false
        }
    } else {
        // Case 2: ISO locked → single-pass search with fixed ISO
        let result = search(isoIndices: [current.isoIndex])

        if let bestPos = result.bestPositive {
            settings = bestPos.0
            return true
        } else {
            settings = result.bestAny.0
            return false
        }
    }
}
