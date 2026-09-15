import Foundation

public struct VehicleDimensions: Codable, Sendable, Equatable {
    public var lengthMetres: Double
    public var widthMetres: Double
    public var heightMetres: Double

    public init(lengthMetres: Double, widthMetres: Double, heightMetres: Double) {
        self.lengthMetres = lengthMetres
        self.widthMetres = widthMetres
        self.heightMetres = heightMetres
    }
}

/// The road-going chassis/cab asset. It remains the same asset when a body is changed.
public struct VehicleChassis: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var registration: String?
    public var vin: String?
    public var dimensions: VehicleDimensions?
    public var baseEmptyMassKg: Double?
    public var grossVehicleMassLimitKg: Double?

    public init(
        id: CanonicalID = .fresh(),
        name: String,
        registration: String? = nil,
        vin: String? = nil,
        dimensions: VehicleDimensions? = nil,
        baseEmptyMassKg: Double? = nil,
        grossVehicleMassLimitKg: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.registration = registration
        self.vin = vin
        self.dimensions = dimensions
        self.baseEmptyMassKg = baseEmptyMassKg
        self.grossVehicleMassLimitKg = grossVehicleMassLimitKg
    }
}

public enum VehicleBodyKind: String, Codable, Sendable, CaseIterable {
    case tank
    case tray
    case tipper
    case agitator
    case van
    case other
}

/// A physical body/container asset with its own lifecycle, independent of the chassis.
/// `compartmentCapacitiesLitres` describes physical container structure only; current
/// product/quantity remains Cargo/Fuel truth in Chunk 5.
public struct VehicleBodyModule: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var kind: VehicleBodyKind
    public var serialNumber: String?
    public var emptyMassKg: Double?
    public var dimensions: VehicleDimensions?
    public var compartmentCapacitiesLitres: [Double]

    public init(
        id: CanonicalID = .fresh(),
        name: String,
        kind: VehicleBodyKind,
        serialNumber: String? = nil,
        emptyMassKg: Double? = nil,
        dimensions: VehicleDimensions? = nil,
        compartmentCapacitiesLitres: [Double] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.serialNumber = serialNumber
        self.emptyMassKg = emptyMassKg
        self.dimensions = dimensions
        self.compartmentCapacitiesLitres = compartmentCapacitiesLitres
    }
}

/// Evidence of an authoritative measured tare for one assembled configuration.
/// This is intentionally distinct from calculated empty mass.
public struct MeasuredTareEvidence: Codable, Sendable, Equatable {
    public let measuredAt: Date
    public let massKg: Double
    public var note: String?

    public init(measuredAt: Date, massKg: Double, note: String? = nil) {
        self.measuredAt = measuredAt
        self.massKg = massKg
        self.note = note
    }
}

/// Immutable historical snapshot of the physical configuration used for an operation.
/// Chassis and body identities are independent; changing either later cannot rewrite history.
public struct VehicleCombinationSnapshot: Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let capturedAt: Date
    public let chassis: VehicleChassis
    public let body: VehicleBodyModule?
    public let measuredTare: MeasuredTareEvidence?

    public init(
        id: CanonicalID = .fresh(),
        capturedAt: Date = Date(),
        chassis: VehicleChassis,
        body: VehicleBodyModule? = nil,
        measuredTare: MeasuredTareEvidence? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.chassis = chassis
        self.body = body
        self.measuredTare = measuredTare
    }

    public var calculatedEmptyMassKg: Double? {
        let known = [chassis.baseEmptyMassKg, body?.emptyMassKg].compactMap { $0 }
        guard !known.isEmpty else { return nil }
        return known.reduce(0, +)
    }

    public var authoritativeTareKg: Double? {
        measuredTare?.massKg ?? calculatedEmptyMassKg
    }
}
