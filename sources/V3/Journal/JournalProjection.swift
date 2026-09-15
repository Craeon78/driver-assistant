import Foundation

/// Journal is a projection over stored truth, never an owner of operational truth.
/// Existing journal implementation is still planned, so this boundary deliberately
/// contains no invented reconstruction or compliance behaviour.
struct JournalProjection {
    let events: [ShiftEvent]

    init(events: [ShiftEvent]) {
        self.events = events
    }
}
