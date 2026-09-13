//======================================
// MARK: - ShiftFabricator (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Produces a minimal fabricated shift for the Chunk 1 gate.
// Not a real domain model; exists only to prove save + replay + crash recovery.
//
// Phase: Chunk 1 — Silent spine
//======================================

import Foundation

public struct FabricatedShift {
    public let shiftID: CanonicalID
    public let startedAt: Date
    public let endedAt: Date?
    public let events: [Event]

    public init(shiftID: CanonicalID = .fresh(), startedAt: Date, endedAt: Date? = nil, events: [Event]) {
        self.shiftID = shiftID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.events = events
    }
}

public enum ShiftFabricator {
    /// Builds a simple closed shift with a couple of notes.
    public static func closedShift(
        start: Date = Date().addingTimeInterval(-8 * 3600),
        durationHours: Double = 8
    ) -> FabricatedShift {
        let end = start.addingTimeInterval(durationHours * 3600)
        let shiftID = CanonicalID.fresh()

        let events: [Event] = [
            .shiftStarted(at: start),
            .note("Fabricated pre-start check", at: start.addingTimeInterval(60)),
            .note("Fabricated mid-shift observation", at: start.addingTimeInterval(4 * 3600)),
            .shiftEnded(at: end)
        ]

        return FabricatedShift(shiftID: shiftID, startedAt: start, endedAt: end, events: events)
    }

    /// Builds an open (overnight) shift for the crash/relaunch skeleton test.
    public static func openShift(start: Date = Date().addingTimeInterval(-14 * 3600)) -> FabricatedShift {
        let shiftID = CanonicalID.fresh()
        let events: [Event] = [
            .shiftStarted(at: start),
            .note("Still on duty — fabricated overnight open shift", at: start.addingTimeInterval(6 * 3600))
        ]
        return FabricatedShift(shiftID: shiftID, startedAt: start, endedAt: nil, events: events)
    }
}
