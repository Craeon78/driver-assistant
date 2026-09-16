import Foundation

/// Cross-domain seam between Chunk 2 distance truth and Chunk 4 Vehicle truth.
/// The ODOAnchor remains the authoritative driver-entered observation.
/// This type only records which powered vehicle's physical odometer was read.
public struct VehicleODOAnchor: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let anchor: ODOAnchor
    public let poweredVehicleID: CanonicalID

    public init(
        id: CanonicalID = .fresh(),
        anchor: ODOAnchor,
        poweredVehicleID: CanonicalID
    ) {
        self.id = id
        self.anchor = anchor
        self.poweredVehicleID = poweredVehicleID
    }
}

/// A closed Chunk 2 distance interval attributed to the powered vehicle that
/// generated its authoritative end ODO observation. Vehicle/Operations consume
/// this evidence; neither may rewrite it or manufacture ODO truth from GPS.
public struct VehicleDistanceEvidence: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let poweredVehicleID: CanonicalID
    public let interval: DistanceInterval

    public init(
        id: CanonicalID = .fresh(),
        poweredVehicleID: CanonicalID,
        interval: DistanceInterval
    ) {
        self.id = id
        self.poweredVehicleID = poweredVehicleID
        self.interval = interval
    }
}

public enum VehicleODOAttributionError: Error, Equatable {
    case startAnchorBelongsToDifferentVehicle
    case endAnchorBelongsToDifferentVehicle
}

/// Builds vehicle-attributed distance evidence without creating a second
/// odometer authority. Cross-vehicle ODO spans are rejected: each powered
/// vehicle must close its own distance interval.
public enum VehicleODOAttribution {
    public static func attribute(
        interval: DistanceInterval,
        start: VehicleODOAnchor?,
        end: VehicleODOAnchor
    ) throws -> VehicleDistanceEvidence {
        guard interval.endAnchor.id == end.anchor.id,
              interval.endAnchor == end.anchor else {
            throw VehicleODOAttributionError.endAnchorBelongsToDifferentVehicle
        }
        if let intervalStart = interval.startAnchor {
            guard let start,
                  intervalStart.id == start.anchor.id,
                  intervalStart == start.anchor,
                  start.poweredVehicleID == end.poweredVehicleID else {
                throw VehicleODOAttributionError.startAnchorBelongsToDifferentVehicle
            }
        }
        return VehicleDistanceEvidence(
            poweredVehicleID: end.poweredVehicleID,
            interval: interval
        )
    }
}
