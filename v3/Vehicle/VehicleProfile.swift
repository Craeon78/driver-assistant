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

public struct VehicleCompartment: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var capacityLitres: Double

    public init(id: CanonicalID = .fresh(), name: String, capacityLitres: Double) {
        self.id = id
        self.name = name
        self.capacityLitres = capacityLitres
    }
}

/// The powered road-going asset. A body may change without changing this identity.
public struct VehicleChassis: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var registration: String?
    public var vin: String?
    public var dimensions: VehicleDimensions?
    public var baseEmptyMassKg: Double?
    public var grossVehicleMassLimitKg: Double?

    public init(id: CanonicalID = .fresh(), name: String, registration: String? = nil, vin: String? = nil, dimensions: VehicleDimensions? = nil, baseEmptyMassKg: Double? = nil, grossVehicleMassLimitKg: Double? = nil) {
        self.id = id
        self.name = name
        self.registration = registration
        self.vin = vin
        self.dimensions = dimensions
        self.baseEmptyMassKg = baseEmptyMassKg
        self.grossVehicleMassLimitKg = grossVehicleMassLimitKg
    }
}

public enum VehicleBodyKind: String, Codable, Sendable, CaseIterable { case tank, tray, tipper, agitator, van, other }

/// Independently persistent body/container fitted to a powered vehicle.
public struct VehicleBodyModule: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var kind: VehicleBodyKind
    public var serialNumber: String?
    public var emptyMassKg: Double?
    public var dimensions: VehicleDimensions?
    public var compartments: [VehicleCompartment]

    public init(id: CanonicalID = .fresh(), name: String, kind: VehicleBodyKind, serialNumber: String? = nil, emptyMassKg: Double? = nil, dimensions: VehicleDimensions? = nil, compartments: [VehicleCompartment] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.serialNumber = serialNumber
        self.emptyMassKg = emptyMassKg
        self.dimensions = dimensions
        self.compartments = compartments
    }
}

public enum TowedAssetKind: String, Codable, Sendable, CaseIterable { case dog, pig, semiTrailer, aTrailer, bTrailer, skeletal, other }

/// A complete non-powered road-going asset. It is not artificially split into chassis/body.
public struct TowedAsset: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var kind: TowedAssetKind
    public var registration: String?
    public var serialNumber: String?
    public var emptyMassKg: Double?
    public var dimensions: VehicleDimensions?
    public var compartments: [VehicleCompartment]

    public init(id: CanonicalID = .fresh(), name: String, kind: TowedAssetKind, registration: String? = nil, serialNumber: String? = nil, emptyMassKg: Double? = nil, dimensions: VehicleDimensions? = nil, compartments: [VehicleCompartment] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.registration = registration
        self.serialNumber = serialNumber
        self.emptyMassKg = emptyMassKg
        self.dimensions = dimensions
        self.compartments = compartments
    }
}

public enum VehicleEquipmentKind: String, Codable, Sendable, CaseIterable { case crane, forkliftMount, forklift, toolbox, pump, other }

public struct VehicleEquipment: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var kind: VehicleEquipmentKind
    public var serialNumber: String?
    public var massKg: Double?

    public init(id: CanonicalID = .fresh(), name: String, kind: VehicleEquipmentKind, serialNumber: String? = nil, massKg: Double? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.serialNumber = serialNumber
        self.massKg = massKg
    }
}

public enum AssetReference: Codable, Sendable, Equatable {
    case poweredVehicle(CanonicalID)
    case body(CanonicalID)
    case towedAsset(CanonicalID)
    case equipment(CanonicalID)
}

public enum ConfigurationRelationshipKind: String, Codable, Sendable, CaseIterable { case fittedTo, coupledTo, mountedTo, carriedBy }

/// Typed relationship between independently persistent physical assets.
public struct ConfigurationRelationship: Codable, Sendable, Equatable {
    public let subject: AssetReference
    public let kind: ConfigurationRelationshipKind
    public let target: AssetReference

    public init(subject: AssetReference, kind: ConfigurationRelationshipKind, target: AssetReference) {
        self.subject = subject
        self.kind = kind
        self.target = target
    }
}

/// Evidence applies only to the exact configuration fingerprint measured.
public struct MeasuredTareEvidence: Codable, Sendable, Equatable {
    public let measuredAt: Date
    public let massKg: Double
    public let configurationFingerprint: String
    public var note: String?

    public init(measuredAt: Date, massKg: Double, configurationFingerprint: String, note: String? = nil) {
        self.measuredAt = measuredAt
        self.massKg = massKg
        self.configurationFingerprint = configurationFingerprint
        self.note = note
    }
}

/// Immutable historical snapshot. Vehicle truth records physical topology; regulatory
/// consequences such as licence class remain Policy truth.
public struct VehicleCombinationSnapshot: Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let capturedAt: Date
    public let chassis: VehicleChassis
    public let body: VehicleBodyModule?
    public let towedAssets: [TowedAsset]
    public let equipment: [VehicleEquipment]
    public let relationships: [ConfigurationRelationship]
    public let measuredTare: MeasuredTareEvidence?

    public init(id: CanonicalID = .fresh(), capturedAt: Date = Date(), chassis: VehicleChassis, body: VehicleBodyModule? = nil, towedAssets: [TowedAsset] = [], equipment: [VehicleEquipment] = [], relationships: [ConfigurationRelationship] = [], measuredTare: MeasuredTareEvidence? = nil) {
        self.id = id
        self.capturedAt = capturedAt
        self.chassis = chassis
        self.body = body
        self.towedAssets = towedAssets
        self.equipment = equipment
        self.relationships = relationships
        self.measuredTare = measuredTare
    }

    /// Stable within a snapshot and changes when participating asset identities/topology change.
    public var configurationFingerprint: String {
        var parts = ["powered:\(String(describing: chassis.id))"]
        if let body { parts.append("body:\(String(describing: body.id))") }
        parts += towedAssets.map { "towed:\(String(describing: $0.id))" }
        parts += equipment.map { "equipment:\(String(describing: $0.id))" }
        parts += relationships.map { String(describing: $0) }
        return parts.joined(separator: "|")
    }

    /// Empty configured mass includes the powered asset, fitted body, towed assets and
    /// fitted/mounted equipment. Carried equipment is current load, not tare.
    public var calculatedEmptyMassKg: Double? {
        var masses = [chassis.baseEmptyMassKg, body?.emptyMassKg] + towedAssets.map(\.emptyMassKg)
        let carriedIDs = relationships.compactMap { relationship -> CanonicalID? in
            guard relationship.kind == .carriedBy, case let .equipment(id) = relationship.subject else { return nil }
            return id
        }
        masses += equipment.filter { equipment in !carriedIDs.contains(equipment.id) }.map(\.massKg)
        let known = masses.compactMap { $0 }
        guard !known.isEmpty else { return nil }
        return known.reduce(0, +)
    }

    public var authoritativeTareKg: Double? {
        guard let measuredTare else { return calculatedEmptyMassKg }
        return measuredTare.configurationFingerprint == configurationFingerprint ? measuredTare.massKg : calculatedEmptyMassKg
    }
}
