import Foundation

/// Generic transported mass located in a vehicle compartment. Vehicle deliberately
/// receives kilograms, not product/density semantics; Fuel/Cargo own that evidence.
public struct TransportedCompartmentMass: Codable, Sendable, Equatable {
    public let compartmentID: CanonicalID
    public let massKg: Double

    public init(compartmentID: CanonicalID, massKg: Double) {
        self.compartmentID = compartmentID
        self.massKg = massKg
    }
}

/// Longitudinal physical evidence relative to a caller-defined datum.
/// The same datum must be used for axle-group and compartment positions.
public struct VehicleLongitudinalGeometry: Codable, Sendable, Equatable {
    public let frontGroupPositionMetres: Double
    public let rearGroupPositionMetres: Double
    public let compartmentPositionsMetres: [CanonicalID: Double]

    public init(frontGroupPositionMetres: Double, rearGroupPositionMetres: Double, compartmentPositionsMetres: [CanonicalID: Double]) {
        self.frontGroupPositionMetres = frontGroupPositionMetres
        self.rearGroupPositionMetres = rearGroupPositionMetres
        self.compartmentPositionsMetres = compartmentPositionsMetres
    }
}

/// Tare axle evidence is configuration-specific. It is never mutated by cargo projection.
public struct VehicleAxleTareEvidence: Codable, Sendable, Equatable {
    public let configurationFingerprint: String
    public let frontGroupMassKg: Double
    public let rearGroupMassKg: Double

    public init(configurationFingerprint: String, frontGroupMassKg: Double, rearGroupMassKg: Double) {
        self.configurationFingerprint = configurationFingerprint
        self.frontGroupMassKg = frontGroupMassKg
        self.rearGroupMassKg = rearGroupMassKg
    }
}

public enum VehicleAxleProjectionUnavailableReason: Codable, Sendable, Equatable {
    case missingGeometry
    case missingCompartmentPosition(CanonicalID)
    case invalidGeometry
    case missingAxleTareEvidence
    case tareConfigurationMismatch
}

public struct VehicleAxleMassProjection: Codable, Sendable, Equatable {
    public let frontGroupMassKg: Double
    public let rearGroupMassKg: Double
}

public enum VehicleAxleProjection: Codable, Sendable, Equatable {
    case available(VehicleAxleMassProjection)
    case unavailable(VehicleAxleProjectionUnavailableReason)
}

public struct VehicleMassProjection: Codable, Sendable, Equatable {
    public let tareKg: Double?
    public let transportedMassKg: Double
    public let grossMassKg: Double?
    public let axleProjection: VehicleAxleProjection
}

/// Pure derived projection. No ledger and no mutation: authoritative Cargo/Fuel/Vehicle
/// evidence remains owned by those domains.
public enum VehicleMassProjector {
    public static func project(
        vehicle: VehicleCombinationSnapshot,
        transportedMass: [TransportedCompartmentMass],
        geometry: VehicleLongitudinalGeometry? = nil,
        axleTare: VehicleAxleTareEvidence? = nil
    ) -> VehicleMassProjection {
        let cargoKg = transportedMass.reduce(0) { $0 + $1.massKg }
        let tareKg = vehicle.authoritativeTareKg
        let grossKg = tareKg.map { $0 + cargoKg }

        let axle = projectAxles(
            configurationFingerprint: vehicle.configurationFingerprint,
            transportedMass: transportedMass,
            geometry: geometry,
            axleTare: axleTare
        )

        return VehicleMassProjection(tareKg: tareKg, transportedMassKg: cargoKg, grossMassKg: grossKg, axleProjection: axle)
    }

    private static func projectAxles(
        configurationFingerprint: String,
        transportedMass: [TransportedCompartmentMass],
        geometry: VehicleLongitudinalGeometry?,
        axleTare: VehicleAxleTareEvidence?
    ) -> VehicleAxleProjection {
        guard let geometry else { return .unavailable(.missingGeometry) }
        let span = geometry.rearGroupPositionMetres - geometry.frontGroupPositionMetres
        guard span > 0 else { return .unavailable(.invalidGeometry) }
        guard let axleTare else { return .unavailable(.missingAxleTareEvidence) }
        guard axleTare.configurationFingerprint == configurationFingerprint else {
            return .unavailable(.tareConfigurationMismatch)
        }

        var frontCargoKg = 0.0
        var rearCargoKg = 0.0
        for item in transportedMass {
            guard let position = geometry.compartmentPositionsMetres[item.compartmentID] else {
                return .unavailable(.missingCompartmentPosition(item.compartmentID))
            }
            let rearFraction = (position - geometry.frontGroupPositionMetres) / span
            frontCargoKg += item.massKg * (1 - rearFraction)
            rearCargoKg += item.massKg * rearFraction
        }

        return .available(VehicleAxleMassProjection(
            frontGroupMassKg: axleTare.frontGroupMassKg + frontCargoKg,
            rearGroupMassKg: axleTare.rearGroupMassKg + rearCargoKg
        ))
    }
}