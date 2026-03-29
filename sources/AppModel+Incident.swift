//======================================
// MARK: - AppModel+Incident
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+Incident.swift
//
// Purpose:
// - Manages incident draft lifecycle, advisory recomputation, and minimal incident logging.
//
// Responsibilities:
// - Create and seed new incident drafts from best-known current context.
// - Recompute advisory guidance when incident draft values change.
// - Commit incident drafts into the timeline/event system.
// - Provide lightweight context helpers for suburb and location prefill.
//
// Notes:
// - This file owns incident draft lifecycle and advisory integration.
// - Current implementation is pre-persistence and logs incidents minimally to the timeline.
// - Location context is best-effort only for now; richer location wiring can be added later.
//
// Phase: Pre-persistence
//======================================
//
// INCIDENT FLOW CONTRACT
// - AppModel owns incident lifecycle and presentation state.
// - Views may mutate incidentDraft only while the sheet is visible.
// - Views must never clear incidentDraft directly.
// - Clearing happens after dismissal on the next runloop tick.

import Foundation
extension AppModel {
    
    func beginIncidentDraft() {
        // Pull best-known context without being creepy.
        let suburb = locationManagerSuburbGuessOrNil()
        let (lat, lon) = locationManagerLatLonOrNil()
        
        incidentDraft = IncidentReport(
            suburb: suburb,
            latitude: lat,
            longitude: lon,
            type: .accident,
            severity: .minor
        )
        recomputeIncidentAdvice()
    }
    
    func recomputeIncidentAdvice() {
        guard let draft = incidentDraft else {
            lastIncidentAdvicePlan = nil
            return
        }
        lastIncidentAdvicePlan = IncidentAdviceEngine.buildPlan(report: draft, settings: settings)
    }
    
    func commitIncidentDraft() {
        guard let draft = incidentDraft else { return }
        
        // Phase 1: minimal timeline logging.
        // Later: persistence + attachments + export bundles.
        logEvent(.other, note: "Incident – \(draft.type.rawValue.capitalized) / \(draft.severity.rawValue.capitalized)", at: draft.timestamp)
    }
    
    // MARK: - Context helpers (Phase 1 placeholders)
    
    private func locationManagerSuburbGuessOrNil() -> String? {
        // You already have suburb suggestion plumbing elsewhere.
        // If you have a “currentSuburb” string in your model, use that instead.
        // For now, use the last recorded suburb if available.
        return odoLocationRecords.last?.suburb.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func locationManagerLatLonOrNil() -> (Double?, Double?) {
        // If you have lat/lon available from LocationManager, wire it here later.
        return (nil, nil)
    }
}
