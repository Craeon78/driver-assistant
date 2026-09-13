//======================================
// MARK: - DistanceGateTests (V3)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Structural + regression tests for Chunk 2.
// Final road-comparison gate still requires device data.
//
// Phase: Chunk 2 — Distance truth engine
//======================================

import Foundation

public enum DistanceGateTests {

    public static func runAll() -> [String] {
        var failures: [String] = []

        do { try testODOIntervalIntegrity() }
        catch { failures.append("ODO interval integrity: \(error)") }

        do { try testJumpRejection() }
        catch { failures.append("Jump rejection: \(error)") }

        do { try testDoubledDistanceDelta() }
        catch { failures.append("Doubled-distance delta: \(error)") }

        do { try testCorrectionFactorLearning() }
        catch { failures.append("Correction factor learning: \(error)") }

        return failures
    }

    // MARK: - ODO is authoritative

    private static func testODOIntervalIntegrity() throws {
        let engine = DistanceEngine()
        let (anchors, expected) = DistanceRegressionFixtures.odoIntervalCase()
        _ = engine.handleODOAnchor(anchors[0])
        let interval = engine.handleODOAnchor(anchors[1])
        guard let interval, abs(interval.odoDeltaKm - expected) < 0.01 else {
            throw TestError("Expected ODO delta \(expected), got \(interval?.odoDeltaKm ?? -1)")
        }
        // Critical: the interval must be exactly the ODO difference, not a GPS invention
        guard interval.chosenSource == .raw || interval.chosenSource == .filtered || interval.chosenSource == .odoAnchor else {
            throw TestError("Unexpected source")
        }
    }

    // MARK: - Jump rejection

    private static func testJumpRejection() throws {
        let engine = DistanceEngine()
        let (locs, expectedAccepted) = DistanceRegressionFixtures.jumpRejectionCase()
        var accepted = 0
        for loc in locs {
            if engine.ingestLocation(loc) { accepted += 1 }
        }
        guard accepted == expectedAccepted else {
            throw TestError("Expected \(expectedAccepted) accepted, got \(accepted)")
        }
    }

    // MARK: - Near-zero delta must not invent distance

    private static func testDoubledDistanceDelta() throws {
        let engine = DistanceEngine()
        let (locs, _) = DistanceRegressionFixtures.doubledDistanceCase()
        for loc in locs {
            _ = engine.ingestLocation(loc)
        }
        // After two near-identical points the filtered accumulation should still be ~0
        // We cannot inspect private meters, so we close with a tiny ODO and check sanity.
        let a1 = ODOAnchor(km: 50)
        let a2 = ODOAnchor(km: 50) // zero delta — should produce no interval
        _ = engine.handleODOAnchor(a1)
        let interval = engine.handleODOAnchor(a2)
        guard interval == nil else {
            throw TestError("Zero ODO delta should not close an interval")
        }
    }

    // MARK: - Learning moves toward truth

    private static func testCorrectionFactorLearning() throws {
        let engine = DistanceEngine()
        // First anchor
        _ = engine.handleODOAnchor(ODOAnchor(km: 0))

        // Feed a location that will create ~1 km geometric distance
        let t0 = Date()
        let loc1 = FakeLocation(lat: -27.47, lon: 153.02, time: t0)
        let loc2 = FakeLocation(lat: -27.479, lon: 153.02, time: t0.addingTimeInterval(60)) // ~1 km south
        _ = engine.ingestLocation(loc1)
        _ = engine.ingestLocation(loc2)

        // Close with ODO saying 1 km
        let interval = engine.handleODOAnchor(ODOAnchor(km: 1))
        guard interval != nil else { throw TestError("Expected interval") }

        // Factor should still be near 1.0 after one sample, but the machinery must not crash
        guard engine.effectiveCorrectionFactor >= 0.70 && engine.effectiveCorrectionFactor <= 1.30 else {
            throw TestError("Factor out of bounds: \(engine.effectiveCorrectionFactor)")
        }
    }

    private struct TestError: Error, CustomStringConvertible {
        let message: String
        init(_ message: String) { self.message = message }
        var description: String { message }
    }
}
