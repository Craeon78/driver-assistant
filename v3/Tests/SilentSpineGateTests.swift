//======================================
// MARK: - SilentSpineGateTests (V3)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Gate tests for Chunk 1.
// These must pass before Chunk 2 is opened.
// Designed to be callable from Playgrounds without XCTest.
//
// Phase: Chunk 1 — Silent spine
//======================================

import Foundation

/// Minimal test harness that can run without XCTest (Playgrounds-friendly).
public enum SilentSpineGateTests {

    public static func runAll(store: EventStore) -> [String] {
        var failures: [String] = []

        do {
            try testClosedShiftRoundTrip(store: store)
        } catch {
            failures.append("Closed shift round-trip failed: \(error)")
        }

        do {
            try testOpenShiftCrashRelaunch(store: store)
        } catch {
            failures.append("Open-shift crash/relaunch failed: \(error)")
        }

        return failures
    }

    // MARK: - Gate 1: closed shift save + replay

    private static func testClosedShiftRoundTrip(store: EventStore) throws {
        try store.clear()
        let fabricated = ShiftFabricator.closedShift()
        try store.append(fabricated.events)

        let loaded = try store.allEvents()
        guard loaded.count == fabricated.events.count else {
            throw TestError.countMismatch(expected: fabricated.events.count, actual: loaded.count)
        }

        for (original, replayed) in zip(fabricated.events, loaded) {
            guard original.kind == replayed.kind,
                  abs(original.occurredAt.timeIntervalSince(replayed.occurredAt)) < 1.0 else {
                throw TestError.eventMismatch(kind: original.kind)
            }
        }
    }

    // MARK: - Gate 2: open shift + simulated crash/relaunch

    private static func testOpenShiftCrashRelaunch(store: EventStore) throws {
        try store.clear()
        let fabricated = ShiftFabricator.openShift()
        try store.append(fabricated.events)

        // Simulate crash: if the store supports reload, use it; otherwise re-read.
        if let fileStore = store as? FileEventStore {
            try fileStore.reloadFromDisk()
        }

        let reloaded = try store.allEvents()
        guard reloaded.count == fabricated.events.count else {
            throw TestError.countMismatch(expected: fabricated.events.count, actual: reloaded.count)
        }
        guard reloaded.contains(where: { $0.kind == "shift.started" }) else {
            throw TestError.missingShiftStart
        }
        // Open shift must still be open (no shift.ended).
        guard !reloaded.contains(where: { $0.kind == "shift.ended" }) else {
            throw TestError.unexpectedShiftEnd
        }
    }

    // MARK: - Errors

    private enum TestError: Error, CustomStringConvertible {
        case countMismatch(expected: Int, actual: Int)
        case eventMismatch(kind: String)
        case missingShiftStart
        case unexpectedShiftEnd

        var description: String {
            switch self {
            case .countMismatch(let e, let a): return "Event count mismatch (expected \(e), got \(a))"
            case .eventMismatch(let k): return "Event mismatch for kind \(k)"
            case .missingShiftStart: return "Reloaded events missing shift.started"
            case .unexpectedShiftEnd: return "Open shift unexpectedly contained shift.ended"
            }
        }
    }
}
