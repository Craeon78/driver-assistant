import Foundation

public enum VehicleBodyKind: String, Codable, Sendable, CaseIterable {
    case rigid
    case primeMover
    case trailer
    case other
}

public struct VehicleProfile: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var registration: String?
    public var bodyKind: VehicleBodyKind

    public init(id: CanonicalID = .fresh(), name: String, registration: String? = nil, bodyKind: VehicleBodyKind) {
        self.id = id
        self.name = name
        self.registration = registration
        self.bodyKind = bodyKind
    }
}

/// Immutable historical snapshot of the physical combination used for an operation.
/// Changing the driver's current vehicle later does not rewrite this snapshot.
public struct VehicleCombinationSnapshot: Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let capturedAt: Date
    public let units: [VehicleProfile]

    public init(id: CanonicalID = .fresh(), capturedAt: Date = Date(), units: [VehicleProfile]) {
        self.id = id
        self.capturedAt = capturedAt
        self.units = units
    }
}
