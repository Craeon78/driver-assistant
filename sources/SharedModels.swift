
import SwiftUI

import MapKit

  

//======================================

// MARK: - SharedModels

//======================================

//

//======================================

// MARK: - SETTINGS / DRIVER PROFILE

//======================================

  

/// Simple settings bag for driver + base info.

/// This will grow later (e.g. SG presets, favourite terminals, fatigue mode selection, etc.).

  

  

  

struct DriverSettings: Codable {

    var driverName: String = "Cory"

    var truckIdentifier: String = "Truck 92"

    // NHVR/base-radius features (Phase 3+)

    // Placeholder only: NOT enforcing NHVR rules yet.

    var nhvrBaseName: String = ""      // e.g. "BP 6750 depot"

    var nhvrBaseAddress: String = ""   // free-text for now

    var nhvrRadiusKm: Double = 100.0 // placeholder for base-radius/geofence logic

    // Emergency / specialist contacts

    var specialistAdvicePhone: String = ""   // e.g. EIP / Hazchem advice

    var supervisorPhone: String = ""

    var mechanicPhone: String = ""

    // Non-urgent police (AU wide)

    var policelinkPhone: String = "131 444"

    // Optional: does the vehicle have a dashcam / inward cam?

    var hasVehicleCamera: Bool = false

}

  

//======================================

// MARK: - OTHER ACTIVITIES / ODO CAPTURE

//======================================

  

/// User-defined activity shortcuts (Phase 1: used to log events quickly).

struct OtherActivity: Identifiable, Codable, Hashable {

    let id: UUID

    var name: String       // e.g. "Training"

    var isWork: Bool       // true = counts as work, false = rest

}

  

/// Why the odo/suburb prompt is being shown.

enum OdoPromptContext: String, Codable {

    case shiftStart

    case legalBreakEnd

    case shiftEnd

    case odoUpdate

}

  

/// Logbook-style capture of odometer + a simple location label.

/// Pre-persistence: suburb is stored as free-text.

struct OdoLocationRecord: Identifiable, Codable {

    let id: UUID

    let timestamp: Date

    let context: OdoPromptContext

    let odoText: String

    let suburb: String

    let segmentID: UUID?    

}

  

//======================================

// MARK: - LOCATION / MAP MODELS

//======================================

  

enum LocationCategory: String, CaseIterable, Identifiable, Codable {

    case terminal = "Terminal"

    case customer = "Customer"

    case breakSpot = "Break Spot"

    case other = "Other"

    var id: String { rawValue }

    /// UI-only color hint (no business logic).

    var color: Color {

        switch self {

        case .terminal:  return .red

        case .customer:  return .blue

        case .breakSpot: return .green

        case .other:     return .gray

        }

    }

}

  

/// Map pin stored in a Codable-friendly way (lat/long instead of CLLocationCoordinate2D).

/// Persistence-friendly as-is.

struct LocationPin: Identifiable, Codable {

    var id: UUID

    var name: String

    var latitude: Double

    var longitude: Double

    var category: LocationCategory

    // Alias so you can use pin.title OR pin.name

    var title: String {

        get { name }

        set { name = newValue }

    }

    var coordinate: CLLocationCoordinate2D {

        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

    }

    // Full init (your original intent)

    init(id: UUID = UUID(),

         name: String,

         coordinate: CLLocationCoordinate2D,

         category: LocationCategory) {

        self.id = id

        self.name = name

        self.latitude = coordinate.latitude

        self.longitude = coordinate.longitude

        self.category = category

    }

    // Convenience init: allows you to omit name (defaults to category label)

    init(id: UUID = UUID(),

         coordinate: CLLocationCoordinate2D,

         category: LocationCategory) {

        self.id = id

        self.name = category.rawValue

        self.latitude = coordinate.latitude

        self.longitude = coordinate.longitude

        self.category = category

    }

}

  

//======================================

// MARK: - LOAD / TRUCK MODELS

//======================================

  

/// Fuel/product definition used for load planning, mass simulation and (later) DG rules.

/// Note: `id` is currently a random UUID (runtime identity).

/// Persistence will eventually require a STABLE ID (e.g. based on shortName or a fixed UUID).

  

/// Placeholder for future Hazchem parsing/display logic.

/// Safe to keep even if unused until Hazchem UI exists.

struct HazchemCode: Codable {

    var prefixDot: Bool

    var digit: Int

    var letter: String

    var hasE: Bool

}

  

/// Live compartment state for Load/Unload views (draft state, not authoritative).

struct CompartmentModel: Identifiable, Codable {

    var id = UUID()

    let name: String

    let capacityLitres: Int

    var selectedProduct: Product?

    var litresText: String = ""

    var isDegassed: Bool = false

}

  

struct AxleSplit: Codable {

    var steerFraction: Double  // can exceed 0...1 in edge cases (e.g. rear overhang)

    var driveFraction: Double

}

  

struct TruckConfig: Codable {

    var name: String

    // Tare weights (empty truck) — NOTE: your tare currently includes FULL fuel tank.

    var tareSteerKg: Double

    var tareDriveKg: Double

    // Full tank fuel mass that is INCLUDED in the tare above.

    // Used for “fuel slider” to reduce tare as tank empties.

    var runTankFullKg: Double = 0

    var lazyLiftTransferKg: Double 

    var hasLazyAxle: Bool = true   // or false by default, set per truck

    // Configured limits (UI warnings use these; not legal advice)

    var maxSteerKg: Double

    var maxDriveKg: Double

    var maxGvmKg: Double

    // How each compartment's mass is shared between axles

    // keyed by compartment name, e.g. "C1", "C2"...

    var axleSplitByCompartment: [String: AxleSplit]

}

  

/// A confirmed snapshot line for a compartment.

/// Confirmed loads become the "authoritative" session history used by DG placarding.

struct ConfirmedCompartment: Identifiable, Codable {

    var id = UUID()

    let name: String

    let sfl: Int

    let productShort: String

    let sg: Double?       // optional for future flexibility (paper-only / unknown SG)

    let litres: Double

    let massKg: Double

}

  

enum ConfirmedLoadMode: String, Codable {

    case loadConfirmed = "LOAD"

    case unloadSnapshot = "UNLOAD"

}

  

extension ConfirmedLoadMode {

    var displayName: String {

        switch self {

        case .loadConfirmed:  return "Load"

        case .unloadSnapshot: return "Unload"

        }

    }

}

  

/// Confirmed load/unload snapshot.

/// This is the history source used for placarding + later persistence.

struct ConfirmedLoad: Identifiable, Codable {

    var id = UUID()

    let timestamp: Date

    let mode: ConfirmedLoadMode

    let terminalName: String

    let loadCode: String

    let vehicleId: String

    let driverName: String

    let compartments: [ConfirmedCompartment]

    let totalLitres: Int

    let totalMassKg: Double

    let steerKg: Double

    let driveKg: Double

    let gvmKg: Double

}

  

/// Delivery sheet model (future-ready for multiple products + multiple compartments).

struct DeliveryLine: Identifiable, Codable {

    var id = UUID()

    let compName: String        // "C1"

    let productShort: String    // "DSL", "P91", etc

    let litresDelivered: Int

}

  

struct DeliveryRecord: Identifiable, Codable {

    var id = UUID()

    let timestamp: Date

    let customerName: String?        // later: from pins

    let lines: [DeliveryLine]        // multiple compartments, multiple products

    let note: String?

}

  

// MARK: - Product Catalogue (Fuel for now; modular later)

var products: [Product] { FuelProducts.all }

  

//======================================

// MARK: - DG helpers (ConfirmedLoad → last-known family)

//======================================

  

extension ConfirmedLoad {

    /// Returns the last known DG family for a compartment based on a confirmed load record.

    /// Phase 1: heuristic mapping from productShort. Keep it simple and aligned to product naming.

    func lastFamilyForCompartmentNamed(_ compName: String) -> DGProductFamily? {

        guard let c = compartments.first(where: { $0.name == compName }) else { return nil }

        guard c.litres > 0 else { return nil }   // only trust it if it actually had product

        let s = c.productShort.lowercased()

        if s.contains("ulp") || s.contains("petrol") || s.contains("p91") || s.contains("p95") || s.contains("p98") {

            return .ulp

        }

        if s.contains("diesel") || s.contains("dsl") || s.contains("adf") {

            return .diesel

        }

        return .other

    }

}

  

//======================================

// MARK: - EVENTS / ACTIVITY / FATIGUE

//======================================

  

enum EventKind: String, Codable {

    case shiftStart = "Shift started"

    case shiftEnd   = "Shift ended"

    case driveStart = "Driving"

    case breakStart = "Break started"

    case load       = "Load event"

    case unload     = "Unload event"

    case incident   = "Incident"

    case other      = "Other"

}

  

struct ShiftEvent: Identifiable, Codable {

    var id = UUID()

    let time: Date

    let kind: EventKind

    let note: String?

}

  

/// Detailed activity types.

/// Phase 1: NHVR work/rest is derived ONLY via `isWork`.

/// Later phases can add activity-specific constraints and better categorisation.

enum ActivityType: String, Codable {

    case offDuty

    // WORK activities

    case driving

    case workGeneral

    case workLoad

    case workUnload

    // REST activities

    case restBreak

    case restBreakdown

}

  

extension ActivityType {

    /// NHVR view: is this WORK time?

    var isWork: Bool {

        switch self {

        case .driving,

                .workGeneral,

                .workLoad,

                .workUnload:

            return true

        case .offDuty,

                .restBreak,

                .restBreakdown:

            return false

        }

    }

    /// Human-friendly label (handy for UI + debugging).

    var displayName: String {

        switch self {

        case .offDuty: return "Off duty"

        case .driving: return "Driving"

        case .workGeneral: return "On Duty "

        case .workLoad: return "Loading"

        case .workUnload: return "Unloading"

        case .restBreak: return "Break"

        case .restBreakdown: return "Breakdown"

        }

    }

}

  

/// A continuous chunk of time spent in a single activity.

struct ActivitySegment: Identifiable, Codable {

    var id = UUID()

    let type: ActivityType

    let start: Date

    var end: Date?   // nil == still going

    // Future hooks (Phase 3+)

    var odoAtStart: Int?

    var locationName: String?

}

  

struct ShiftSummary: Identifiable, Codable {

    var id = UUID()

    let date: Date

    let start: Date?

    let end: Date

    let workSeconds: TimeInterval

    let restSeconds: TimeInterval

    let driveSeconds: TimeInterval

    let loadCount: Int

    let unloadCount: Int

}

  

//======================================

// MARK: - HELPERS

//======================================

  

/// Shared formatter to avoid repeated DateFormatter creation cost.

private let shortTimeFormatter: DateFormatter = {

    let df = DateFormatter()

    df.dateStyle = .none

    df.timeStyle = .short

    return df

}()

  

func formatTimeHM(_ seconds: TimeInterval) -> String {

    let clamped = max(seconds, 0)

    let totalMinutes = Int(clamped / 60)

    let hours = totalMinutes / 60

    let minutes = totalMinutes % 60

    return String(format: "%dh %02dm", hours, minutes)

}

  

func formatTimeShort(_ date: Date) -> String {

    shortTimeFormatter.string(from: date)

}

  

/// UI-friendly shape for displaying the timeline list.

struct TimelineEvent: Identifiable {

    let id: UUID

    let timeString: String

    let label: String

}
