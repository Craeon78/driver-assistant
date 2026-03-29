//======================================
// MARK: - AppModel+TimelineProjection
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+TimelineProjection.swift
//
// Purpose:
// - Projects internal timeline events into UI-friendly display rows for timeline rendering.
//
// Responsibilities:
// - Convert ShiftEvent values into stable TimelineEvent view models.
// - Format timeline labels and timestamps for compact display.
// - Preserve stable IDs for SwiftUI diffing and list rendering.
//
// Notes:
// - This is a pure projection layer: read-only, no business logic.
// - It should reflect canonical event labels rather than inventing new timeline meaning.
// - Pre-persistence, it reads from the in-memory events array.
// - Post-persistence, the UI contract can remain the same while the data source changes.
//
// Phase: Pre-persistence
//======================================

import SwiftUI

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
                    label = event.kind.rawValue   // "Other"
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
