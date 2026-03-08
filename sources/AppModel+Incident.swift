import Foundation

//======================================

// MARK: - AppModel+Incident

//======================================

//

// INCIDENT FLOW CONTRACT

// - AppModel owns incident lifecycle and presentation state

// - Views may mutate incidentDraft *only while sheet is visible*

// - Views must never clear incidentDraft directly

// - Clearing happens after dismissal on next runloop tick

  

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
