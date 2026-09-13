import Foundation

struct DriverSettings: Codable {
    var driverName: String = "Cory"
    var truckIdentifier: String = "Truck 92"
    var nhvrBaseName: String = ""
    var nhvrBaseAddress: String = ""
    var nhvrRadiusKm: Double = 100.0
    var specialistAdvicePhone: String = ""
    var supervisorPhone: String = ""
    var mechanicPhone: String = ""
    var policelinkPhone: String = "131 444"
    var hasVehicleCamera: Bool = false
}

struct OtherActivity: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isWork: Bool
}

enum ActivityType: String, Codable {
    case offDuty
    case driving
    case workGeneral
    case workLoad
    case workUnload
    case restBreak
    case restBreakdown

    var isWork: Bool {
        switch self {
        case .driving, .workGeneral, .workLoad, .workUnload: return true
        case .offDuty, .restBreak, .restBreakdown: return false
        }
    }

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

struct ActivitySegment: Identifiable, Codable {
    var id = UUID()
    let type: ActivityType
    let start: Date
    var end: Date?
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
