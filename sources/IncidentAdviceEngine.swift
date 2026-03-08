
import Foundation

  

//======================================

// MARK: - INCIDENT ADVICE ENGINE (PRE-PERSISTENCE)

//======================================

//

// Purpose:

// - Convert an IncidentReport into a calm, structured action plan.

// - Uses triage answers + app settings (phones) + known context.

//

// Scope (Phase 1):

// - Pure functions only (no UI, no alerts, no side-effects).

// - Returns an IncidentAdvicePlan: headline + ordered actions.

//

// Design principles:

// - Safety first.

// - Prefer minimal, high-value actions.

// - Don’t assume — ask (TernaryAnswer).

//

//======================================

  

  

enum IncidentAdviceEngine {

    static func buildPlan(report: IncidentReport, settings: DriverSettings) -> IncidentAdvicePlan {

        var actions: [IncidentAdviceAction] = []

        // 0) Always start with “safe stop” if not confirmed

        // If unknown, we still prompt early because driver might be mid-chaos.

        if report.isSafeStopped != .yes {

            // We don’t have a dedicated “pull over safely” action yet,

            // so we front-load 000 for emergencies and evidence steps later.

            // (UI will ask this as the first triage question.)

        }

        // 1) Determine whether this is an emergency (000)

        let emergencyBySeverity = (report.severity == .emergency)

        let emergencyByFireSpill = (report.fireOrSpill == .yes)

        let emergencyByInjury = (report.injuriesPresent == .yes)

        let shouldCall000 = emergencyBySeverity || emergencyByFireSpill || emergencyByInjury

        if shouldCall000 {

            actions.append(.call000)

        }

        // 2) Specialist advice (EIP / hazchem) when relevant:

        // - Any spill/fire OR accident with unknowns OR serious/emergency.

        let hasSpecialist = !settings.specialistAdvicePhone.trimmed().isEmpty

        let shouldCallSpecialist =

        report.fireOrSpill != .no ||

        report.severity == .serious ||

        report.severity == .emergency ||

        report.type == .spill ||

        report.type == .fire

        if shouldCallSpecialist, hasSpecialist {

            actions.append(.callSpecialistAdvice(phone: settings.specialistAdvicePhone.cleanedPhone()))

        }

        // 3) Supervisor is useful for basically everything except “info-only near miss”

        let hasSupervisor = !settings.supervisorPhone.trimmed().isEmpty

        let shouldCallSupervisor =

        report.severity != .informationOnly ||

        report.type != .nearMiss

        if shouldCallSupervisor, hasSupervisor {

            actions.append(.callSupervisor(phone: settings.supervisorPhone.cleanedPhone()))

        }

        // 4) Mechanic mainly for breakdowns / non-drivable vehicle (or serious accident)

        let hasMechanic = !settings.mechanicPhone.trimmed().isEmpty

        let shouldCallMechanic =

        report.type == .breakdown ||

        report.severity == .serious ||

        report.severity == .emergency

        if shouldCallMechanic, hasMechanic {

            actions.append(.callMechanic(phone: settings.mechanicPhone.cleanedPhone()))

        }

        // 5) Hit & run / non-urgent police reporting

        // If it’s NOT an emergency call, and hit&run is yes → Policelink advice

        if !shouldCall000, report.hitAndRun == .yes {

            actions.append(.reportToPolicelink)

        }

        // 6) Evidence + note (only if safe stopped is yes OR unknown)

        // If they said "no" (not safely stopped), UI should push "stop safely" first.

        if report.isSafeStopped != .no {

            // Suggest photos if they haven't already taken enough.

            if report.photosTakenCount < 4 {

                actions.append(.takePhotos(count: 4))

            }

            if (report.shortNote?.trimmed().isEmpty ?? true) {

                actions.append(.writeShortNote)

            }

            // Camera prompt is handled in UI later; for now we nudge rest/hydration always.

            actions.append(.hydrateAndRest)

        }

        // Headline

        let headline = headlineFor(report: report, shouldCall000: shouldCall000)

        // De-dupe while preserving order (important for repeated rules)

        actions = actions.uniquedById()

        return IncidentAdvicePlan(headline: headline, actions: actions)

    }

    private static func headlineFor(report: IncidentReport, shouldCall000: Bool) -> String {

        if shouldCall000 {

            return "Emergency actions first"

        }

        switch report.type {

        case .accident:  return "Accident — stay calm, capture details"

        case .breakdown: return "Breakdown — secure the scene, get help moving"

        case .nearMiss:  return "Near miss — quick record while it’s fresh"

        case .spill:     return "Spill — treat as hazchem until confirmed safe"

        case .fire:      return "Fire — treat as emergency risk"

        case .medical:   return "Medical — safety and support first"

        }

    }

}

  

// MARK: - Small helpers (local to this file)

  

private extension String {

    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Keep digits and a leading + only (good enough for Phase 1)

    func cleanedPhone() -> String {

        let t = trimmed()

        guard !t.isEmpty else { return "" }

        var out = ""

        for (i, ch) in t.enumerated() {

            if ch.isNumber { out.append(ch) }

            else if ch == "+", i == 0 { out.append(ch) }

        }

        return out

    }

}

  

private extension Array where Element == IncidentAdviceAction {

    func uniquedById() -> [IncidentAdviceAction] {

        var seen = Set<String>()

        var out: [IncidentAdviceAction] = []

        for a in self {

            if seen.contains(a.id) { continue }

            seen.insert(a.id)

            out.append(a)

        }

        return out

    }

}
