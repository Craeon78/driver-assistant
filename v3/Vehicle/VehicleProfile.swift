import Foundation

public struct VehicleDimensions: Codable, Sendable, Equatable {
    public var lengthMetres: Double
    public var widthMetres: Double
    public var heightMetres: Double
    public init(lengthMetres: Double, widthMetres: Double, heightMetres: Double) { self.lengthMetres = lengthMetres; self.widthMetres = widthMetres; self.heightMetres = heightMetres }
}

public enum AxleGroupKind: String, Codable, Sendable, CaseIterable { case steer, single, tandem, tri, quad, other }

/// Physical axle-group truth only. Regulatory interpretation remains Policy truth.
public struct VehicleAxleGroup: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var kind: AxleGroupKind
    public var axleCount: Int
    public var manufacturerRatingKg: Double?
    public var spacingToPreviousMetres: Double?
    public init(id: CanonicalID = .fresh(), name: String, kind: AxleGroupKind, axleCount: Int, manufacturerRatingKg: Double? = nil, spacingToPreviousMetres: Double? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.axleCount = axleCount; self.manufacturerRatingKg = manufacturerRatingKg; self.spacingToPreviousMetres = spacingToPreviousMetres
    }
}

public struct VehicleCompartment: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var capacityLitres: Double
    public init(id: CanonicalID = .fresh(), name: String, capacityLitres: Double) { self.id = id; self.name = name; self.capacityLitres = capacityLitres }
}

public struct VehicleChassis: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var registration: String?
    public var vin: String?
    public var dimensions: VehicleDimensions?
    public var baseEmptyMassKg: Double?
    public var grossVehicleMassLimitKg: Double?
    public var axleGroups: [VehicleAxleGroup]
    public init(id: CanonicalID = .fresh(), name: String, registration: String? = nil, vin: String? = nil, dimensions: VehicleDimensions? = nil, baseEmptyMassKg: Double? = nil, grossVehicleMassLimitKg: Double? = nil, axleGroups: [VehicleAxleGroup] = []) {
        self.id = id; self.name = name; self.registration = registration; self.vin = vin; self.dimensions = dimensions; self.baseEmptyMassKg = baseEmptyMassKg; self.grossVehicleMassLimitKg = grossVehicleMassLimitKg; self.axleGroups = axleGroups
    }
}

public enum VehicleBodyKind: String, Codable, Sendable, CaseIterable { case tank, tray, tipper, agitator, van, other }
public struct VehicleBodyModule: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID; public var name: String; public var kind: VehicleBodyKind; public var serialNumber: String?; public var emptyMassKg: Double?; public var dimensions: VehicleDimensions?; public var compartments: [VehicleCompartment]
    public init(id: CanonicalID = .fresh(), name: String, kind: VehicleBodyKind, serialNumber: String? = nil, emptyMassKg: Double? = nil, dimensions: VehicleDimensions? = nil, compartments: [VehicleCompartment] = []) { self.id = id; self.name = name; self.kind = kind; self.serialNumber = serialNumber; self.emptyMassKg = emptyMassKg; self.dimensions = dimensions; self.compartments = compartments }
}

public enum TowedAssetKind: String, Codable, Sendable, CaseIterable { case dog, pig, semiTrailer, aTrailer, bTrailer, skeletal, other }
public struct TowedAsset: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID; public var name: String; public var kind: TowedAssetKind; public var registration: String?; public var serialNumber: String?; public var emptyMassKg: Double?; public var dimensions: VehicleDimensions?; public var compartments: [VehicleCompartment]; public var axleGroups: [VehicleAxleGroup]
    public init(id: CanonicalID = .fresh(), name: String, kind: TowedAssetKind, registration: String? = nil, serialNumber: String? = nil, emptyMassKg: Double? = nil, dimensions: VehicleDimensions? = nil, compartments: [VehicleCompartment] = [], axleGroups: [VehicleAxleGroup] = []) { self.id = id; self.name = name; self.kind = kind; self.registration = registration; self.serialNumber = serialNumber; self.emptyMassKg = emptyMassKg; self.dimensions = dimensions; self.compartments = compartments; self.axleGroups = axleGroups }
}

public enum VehicleEquipmentKind: String, Codable, Sendable, CaseIterable { case crane, forkliftMount, forklift, toolbox, pump, other }
public struct VehicleEquipment: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID; public var name: String; public var kind: VehicleEquipmentKind; public var serialNumber: String?; public var massKg: Double?
    public init(id: CanonicalID = .fresh(), name: String, kind: VehicleEquipmentKind, serialNumber: String? = nil, massKg: Double? = nil) { self.id = id; self.name = name; self.kind = kind; self.serialNumber = serialNumber; self.massKg = massKg }
}

public enum AssetReference: Codable, Sendable, Equatable { case poweredVehicle(CanonicalID), body(CanonicalID), towedAsset(CanonicalID), equipment(CanonicalID) }
public enum ConfigurationRelationshipKind: String, Codable, Sendable, CaseIterable { case fittedTo, coupledTo, mountedTo, carriedBy }
public struct ConfigurationRelationship: Codable, Sendable, Equatable {
    public let subject: AssetReference; public let kind: ConfigurationRelationshipKind; public let target: AssetReference
    public init(subject: AssetReference, kind: ConfigurationRelationshipKind, target: AssetReference) { self.subject = subject; self.kind = kind; self.target = target }
}

public struct MeasuredTareEvidence: Codable, Sendable, Equatable {
    public let measuredAt: Date; public let massKg: Double; public let configurationFingerprint: String; public var note: String?
    public init(measuredAt: Date, massKg: Double, configurationFingerprint: String, note: String? = nil) { self.measuredAt = measuredAt; self.massKg = massKg; self.configurationFingerprint = configurationFingerprint; self.note = note }
}

public struct VehicleCombinationSnapshot: Codable, Sendable, Equatable {
    public let id: CanonicalID; public let capturedAt: Date; public let chassis: VehicleChassis; public let body: VehicleBodyModule?; public let towedAssets: [TowedAsset]; public let equipment: [VehicleEquipment]; public let relationships: [ConfigurationRelationship]; public let measuredTare: MeasuredTareEvidence?
    public init(id: CanonicalID = .fresh(), capturedAt: Date = Date(), chassis: VehicleChassis, body: VehicleBodyModule? = nil, towedAssets: [TowedAsset] = [], equipment: [VehicleEquipment] = [], relationships: [ConfigurationRelationship] = [], measuredTare: MeasuredTareEvidence? = nil) { self.id = id; self.capturedAt = capturedAt; self.chassis = chassis; self.body = body; self.towedAssets = towedAssets; self.equipment = equipment; self.relationships = relationships; self.measuredTare = measuredTare }

    private func refKey(_ ref: AssetReference) -> String {
        switch ref {
        case .poweredVehicle(let id): return "powered:\(id.raw.uuidString)"
        case .body(let id): return "body:\(id.raw.uuidString)"
        case .towedAsset(let id): return "towed:\(id.raw.uuidString)"
        case .equipment(let id): return "equipment:\(id.raw.uuidString)"
        }
    }

    /// Canonical, ordering-independent configuration identity. Human labels and snapshot time are deliberately excluded.
    public var configurationFingerprint: String {
        var parts = [refKey(.poweredVehicle(chassis.id))]
        if let body { parts.append(refKey(.body(body.id))) }
        parts += towedAssets.map { refKey(.towedAsset($0.id)) }
        parts += equipment.map { refKey(.equipment($0.id)) }
        parts += chassis.axleGroups.map { "axle:powered:\($0.id.raw.uuidString):\($0.kind.rawValue):\($0.axleCount):\($0.manufacturerRatingKg ?? -1):\($0.spacingToPreviousMetres ?? -1)" }
        for asset in towedAssets { parts += asset.axleGroups.map { "axle:towed:\(asset.id.raw.uuidString):\($0.id.raw.uuidString):\($0.kind.rawValue):\($0.axleCount):\($0.manufacturerRatingKg ?? -1):\($0.spacingToPreviousMetres ?? -1)" } }
        parts += relationships.map { "rel:\(refKey($0.subject)):\($0.kind.rawValue):\(refKey($0.target))" }
        return parts.sorted().joined(separator: "|")
    }

    /// Only explicitly fitted or mounted equipment contributes to configured empty mass.
    /// Carried or orphan/unclassified equipment does not silently alter tare.
    public var calculatedEmptyMassKg: Double? {
        var masses = [chassis.baseEmptyMassKg, body?.emptyMassKg] + towedAssets.map(\.emptyMassKg)
        let tareEquipmentIDs = Set(relationships.compactMap { relationship -> CanonicalID? in
            guard relationship.kind == .fittedTo || relationship.kind == .mountedTo, case let .equipment(id) = relationship.subject else { return nil }
            return id
        })
        masses += equipment.filter { tareEquipmentIDs.contains($0.id) }.map(\.massKg)
        let known = masses.compactMap { $0 }
        guard !known.isEmpty else { return nil }
        return known.reduce(0, +)
    }

    public var authoritativeTareKg: Double? {
        guard let measuredTare else { return calculatedEmptyMassKg }
        return measuredTare.configurationFingerprint == configurationFingerprint ? measuredTare.massKg : calculatedEmptyMassKg
    }
}
