import SwiftUI

  

//======================================

// MARK: - Timeline Projection (UI View Models)

//======================================

//

// Purpose:

// - Convert raw events/segments into UI-friendly timeline rows

// - Provides stable IDs for SwiftUI List rendering

// - Formats timestamps consistently

//

// Scope:

// - Read-only transformations only

// - No business logic (that belongs in AppModel core or Logic/)

// - Pure view-model layer

//

// Pre-persistence:

// - Operates on in-memory events array

// - Lost on app restart

//

// Post-persistence:

// - Will query from SQLite instead

// - Same UI contract, different data source

//

//======================================

  

extension AppModel {

  

    /// UI-friendly projection of `events` for Timeline display.

    /// - Reuses `ShiftEvent.id` so SwiftUI diffing stays stable across refreshes.

    /// - Formats timestamps to short time strings for compact display.

    var timelineEvents: [TimelineEvent] {

        events.map { event in

            let label: String

            switch event.kind {

            case .other:

                if let note = event.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                    label = "Other – \(note)"

                } else {

                    label = event.kind.rawValue   // "Other"

                }

            case .incident:

                if let note = event.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                    label = "Incident – \(note)"

                } else {

                    label = event.kind.rawValue

                }

            default:

                // For all standard events, use the canonical EventKind string.

                // This keeps the timeline in sync if you rename EventKind labels later.

                label = event.kind.rawValue

            }

            return TimelineEvent(

                id: event.id,

                timeString: formatTimeShort(event.time),

                label: label

            )

        }

    }

}
