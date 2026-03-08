
import Foundation

  

//======================================

// MARK: - INCIDENT MODELS (PRE-PERSISTENCE)

//======================================

//

// Purpose:

// - Define the core data structures for incident handling.

// - Support calm, structured driver guidance during stressful events

//   (accidents, breakdowns, spills, medical, near-misses).

//

// Scope (Phase 1):

// - Model-only definitions (NO UI, NO side-effects).

// - Incidents are event-based (not activity segments).

// - Advice is computed dynamically, not hard-coded.

//

// Design principles:

// - Favour clarity over completeness.

// - Use triage-style questions (yes / no / unknown).

// - Avoid "big brother" behaviour — only use data the driver

//   explicitly provides or the app already holds.

//

// Future evolution:

// - Phase 2+: persistence to SQLite.

// - Phase 3+: richer branching logic, photo metadata, exports.

// - Phase 4+: incident history review and editing.

//

//======================================

  

  

enum IncidentType: String, Codable, CaseIterable {

    case accident

    case breakdown

    case nearMiss

    case spill

    case fire

    case medical

}

  

enum IncidentSeverity: String, Codable {

    case informationOnly   // near miss, no damage

    case minor             // damage, no danger

    case serious           // vehicle disabled, injury possible

    case emergency         // immediate danger

}

  

enum TernaryAnswer: String, Codable {

    case yes

    case no

    case unknown

}

  

struct IncidentReport: Identifiable, Codable {

    let id: UUID

    let timestamp: Date

    // Context (auto-filled)

    let suburb: String?

    let latitude: Double?

    let longitude: Double?

    // Driver input

    var type: IncidentType

    var severity: IncidentSeverity

    // Key triage answers

    var isSafeStopped: TernaryAnswer

    var injuriesPresent: TernaryAnswer

    var fireOrSpill: TernaryAnswer

    var hitAndRun: TernaryAnswer

    // Evidence

    var photosTakenCount: Int

    var shortNote: String?

    init(

        timestamp: Date = Date(),

        suburb: String? = nil,

        latitude: Double? = nil,

        longitude: Double? = nil,

        type: IncidentType,

        severity: IncidentSeverity

    ) {

        self.id = UUID()

        self.timestamp = timestamp

        self.suburb = suburb

        self.latitude = latitude

        self.longitude = longitude

        self.type = type

        self.severity = severity

        self.isSafeStopped = .unknown

        self.injuriesPresent = .unknown

        self.fireOrSpill = .unknown

        self.hitAndRun = .unknown

        self.photosTakenCount = 0

        self.shortNote = nil

    }

}

  

enum IncidentAdviceAction: Identifiable, Codable {

    case call000

    case callSpecialistAdvice(phone: String)

    case callSupervisor(phone: String)

    case callMechanic(phone: String)

    case reportToPolicelink

    case takePhotos(count: Int)

    case writeShortNote

    case hydrateAndRest

    var id: String {

        switch self {

        case .call000: return "call000"

        case .callSpecialistAdvice(let phone): return "callSpecialist-\(phone)"

        case .callSupervisor(let phone): return "callSupervisor-\(phone)"

        case .callMechanic(let phone): return "callMechanic-\(phone)"

        case .reportToPolicelink: return "policelink"

        case .takePhotos(let count): return "photos-\(count)"

        case .writeShortNote: return "note"

        case .hydrateAndRest: return "rest"

        }

    }

}

  

struct IncidentAdvicePlan: Codable {

    let headline: String

    let actions: [IncidentAdviceAction]

}
