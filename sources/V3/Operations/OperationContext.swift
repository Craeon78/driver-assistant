import Foundation

/// Operational activity is independent of Driver, Vehicle and Cargo truth.
enum OperationKind: String, Codable, CaseIterable {
    case drive
    case stop
    case load
    case unload
    case transfer
    case wait
    case maintenance
    case incident
}

struct OperationContext: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: OperationKind
    let startedAt: Date
    var endedAt: Date?
    var siteID: UUID?

    init(id: UUID = UUID(), kind: OperationKind, startedAt: Date, endedAt: Date? = nil, siteID: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.siteID = siteID
    }
}
