import SwiftUI
import MapKit

// V3 compatibility surface.
// Domain-owned models have moved to V3/Driver, V3/Vehicle and V3/Cargo/Fuel.
// Keep this file limited to genuinely cross-domain/UI compatibility types while
// legacy callers are migrated. Do not add new Driver, Vehicle or Cargo truth here.

enum OdoPromptContext: String, Codable {
    case shiftStart
    case legalBreakEnd
    case shiftEnd
    case odoUpdate
}

struct OdoLocationRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let context: OdoPromptContext
    let odoText: String
    let suburb: String
    let segmentID: UUID?
}

enum LocationCategory: String, CaseIterable, Identifiable, Codable {
    case terminal = "Terminal"
    case customer = "Customer"
    case breakSpot = "Break Spot"
    case other = "Other"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .terminal: return .red
        case .customer: return .blue
        case .breakSpot: return .green
        case .other: return .gray
        }
    }
}

struct LocationPin: Identifiable, Codable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var category: LocationCategory

    var title: String {
        get { name }
        set { name = newValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: UUID = UUID(), name: String, coordinate: CLLocationCoordinate2D, category: LocationCategory) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.category = category
    }

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, category: LocationCategory) {
        self.id = id
        self.name = category.rawValue
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.category = category
    }
}

enum EventKind: String, Codable {
    case shiftStart = "Shift started"
    case shiftEnd = "Shift ended"
    case driveStart = "Driving"
    case breakStart = "Break started"
    case load = "Load event"
    case unload = "Unload event"
    case incident = "Incident"
    case other = "Other"
}

struct ShiftEvent: Identifiable, Codable {
    var id = UUID()
    let time: Date
    let kind: EventKind
    let note: String?
}

private let shortTimeFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .none
    df.timeStyle = .short
    return df
}()

func formatTimeHM(_ seconds: TimeInterval) -> String {
    let clamped = max(seconds, 0)
    let totalMinutes = Int(clamped / 60)
    return String(format: "%dh %02dm", totalMinutes / 60, totalMinutes % 60)
}

func formatTimeShort(_ date: Date) -> String {
    shortTimeFormatter.string(from: date)
}

struct TimelineEvent: Identifiable {
    let id: UUID
    let timeString: String
    let label: String
}
