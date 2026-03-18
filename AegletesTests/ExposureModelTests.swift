import XCTest
@testable import Aegletes   // ensure this matches your app module name

final class ExposureModelTests: XCTestCase {

    // Helper: a stable starting point (ISO 100, f/8, 1/125s)
    private func makeBaseSettings() -> ExposureSettings {
        // These lookups rely on the arrays in ExposureModel.swift
        let isoIndex = isoValues.firstIndex(of: 100)!          // ISO 100
        let apertureIndex = apertureValues.firstIndex(of: 8)!  // f/8
        let shutterIndex = shutterValues.firstIndex(where: { abs($0 - (1.0/125.0)) < 1e-6 })!
        return ExposureSettings(isoIndex: isoIndex,
                                apertureIndex: apertureIndex,
                                shutterIndex: shutterIndex)
    }

    func testNoAdjustmentWhenExactlyOnTarget() {
        var settings = makeBaseSettings()
        let baseEV = settingsEV100(settings)

        let locks = ExposureLockState(iso: false, aperture: false, shutter: false)
        let ok = autoAdjust(settings: &settings,
                            locks: locks,
                            targetEV: baseEV)

        XCTAssertTrue(ok)
        let original = makeBaseSettings()
        XCTAssertEqual(settings.isoIndex, original.isoIndex)
        XCTAssertEqual(settings.apertureIndex, original.apertureIndex)
        XCTAssertEqual(settings.shutterIndex, original.shutterIndex)
    }

    func testSlightUnderexposureWithinToleranceDoesNotChangeSettings() {
        var settings = makeBaseSettings()
        let baseEV = settingsEV100(settings)

        // delta = targetEV - baseEV = -0.05 (within the -0.1 tolerance band)
        let targetEV = baseEV - 0.05

        let original = settings
        let locks = ExposureLockState(iso: false, aperture: false, shutter: false)
        let ok = autoAdjust(settings: &settings,
                            locks: locks,
                            targetEV: targetEV)

        XCTAssertTrue(ok, "Should still be considered acceptable (no low-light warning).")
        XCTAssertEqual(settings.isoIndex, original.isoIndex)
        XCTAssertEqual(settings.apertureIndex, original.apertureIndex)
        XCTAssertEqual(settings.shutterIndex, original.shutterIndex)
    }

    func testUnderexposedBeyondToleranceBrightens() {
        var settings = makeBaseSettings()
        let baseEV = settingsEV100(settings)

        // Strong underexposure: delta = -1 stop
        let targetEV = baseEV - 1.0

        let original = settings
        let locks = ExposureLockState(iso: false, aperture: false, shutter: false)
        let ok = autoAdjust(settings: &settings,
                            locks: locks,
                            targetEV: targetEV)

        XCTAssertTrue(ok)
        let newEV = settingsEV100(settings)

        let originalDelta = targetEV - baseEV
        let newDelta = targetEV - newEV

        XCTAssertGreaterThanOrEqual(newDelta, -0.1, "Should no longer be beyond tolerance.")
        XCTAssertLessThan(abs(newDelta), abs(originalDelta), "Should move closer to target EV.")
        XCTAssert(
            settings.isoIndex != original.isoIndex ||
            settings.apertureIndex != original.apertureIndex ||
            settings.shutterIndex != original.shutterIndex
        )
    }

    func testOverexposedDarkens() {
        var settings = makeBaseSettings()
        let baseEV = settingsEV100(settings)

        // Overexposed by 1 stop: delta = +1
        let targetEV = baseEV + 1.0

        let original = settings
        let locks = ExposureLockState(iso: false, aperture: false, shutter: false)
        let ok = autoAdjust(settings: &settings,
                            locks: locks,
                            targetEV: targetEV)

        XCTAssertTrue(ok)
        let newEV = settingsEV100(settings)

        let originalDelta = targetEV - baseEV
        let newDelta = targetEV - newEV

        XCTAssertGreaterThanOrEqual(newDelta, -0.1)
        XCTAssertLessThan(abs(newDelta), abs(originalDelta))
        XCTAssert(
            settings.isoIndex != original.isoIndex ||
            settings.apertureIndex != original.apertureIndex ||
            settings.shutterIndex != original.shutterIndex
        )
    }

    func testLowLightWarningWhenCannotBrightenEnough() {
        // Lock everything and set an impossible target
        var settings = makeBaseSettings()
        let baseEV = settingsEV100(settings)

        // Ask for +5 stops brighter with everything locked: cannot reach it
        let targetEV = baseEV - 5.0
        let locks = ExposureLockState(iso: true, aperture: true, shutter: true)
        let ok = autoAdjust(settings: &settings,
                            locks: locks,
                            targetEV: targetEV)

        XCTAssertFalse(ok, "Should signal low-light warning when unfixable.")
    }
}
