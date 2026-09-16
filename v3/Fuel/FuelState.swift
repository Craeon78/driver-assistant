import Foundation

public enum FuelResidualState: Codable, Sendable, Equatable {
    case clear
    case diesel(productID: CanonicalID)
    case petrolVapour(productID: CanonicalID)
}

/// Fuel-only projection layered over generic Cargo compartment truth.
/// Cargo remains authoritative for liquid identity/quantity; Fuel adds chemical history.
public struct FuelCompartmentProjection: Codable, Sendable, Equatable {
    public let compartmentID: CanonicalID
    public let liquid: CargoQuantity?
    public let residual: FuelResidualState

    public init(compartmentID: CanonicalID, liquid: CargoQuantity?, residual: FuelResidualState) {
        self.compartmentID = compartmentID
        self.liquid = liquid
        self.residual = residual
    }
}

public enum FuelStateEventKind: String, Codable, Sendable {
    case productEntered
    case degas
}

/// Fuel-specific state transition. It supplements rather than replaces CargoTransaction.
public struct FuelStateEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let kind: FuelStateEventKind
    public let compartmentID: CanonicalID
    public let productID: CanonicalID?
    public let family: FuelFamily?
    public let occurredAt: Date
    public let recordedAt: Date
    public let provenance: EventProvenance

    public init(
        id: CanonicalID = .fresh(),
        kind: FuelStateEventKind,
        compartmentID: CanonicalID,
        productID: CanonicalID? = nil,
        family: FuelFamily? = nil,
        occurredAt: Date,
        recordedAt: Date = Date(),
        provenance: EventProvenance = .driverEntered
    ) {
        self.id = id
        self.kind = kind
        self.compartmentID = compartmentID
        self.productID = productID
        self.family = family
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.provenance = provenance
    }
}

public enum FuelProjectionError: Error, Equatable {
    case unknownCompartment
    case invalidProductEntry
    case invalidDegas
}

public enum FuelProjector {
    public static func project(
        cargoLedger: CargoLedger,
        fuelEvents: [FuelStateEvent]
    ) throws -> [FuelCompartmentProjection] {
        let cargoStates = try cargoLedger.allStates()
        let known = Set(cargoStates.map(\.compartmentID))
        var residuals = Dictionary(uniqueKeysWithValues: known.map { ($0, FuelResidualState.clear) })

        let ordered = fuelEvents.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }
            return $0.id.raw.uuidString < $1.id.raw.uuidString
        }

        for event in ordered {
            guard known.contains(event.compartmentID) else { throw FuelProjectionError.unknownCompartment }
            switch event.kind {
            case .productEntered:
                guard let productID = event.productID, let family = event.family else {
                    throw FuelProjectionError.invalidProductEntry
                }
                switch family {
                case .diesel:
                    residuals[event.compartmentID] = .diesel(productID: productID)
                case .petrol:
                    residuals[event.compartmentID] = .petrolVapour(productID: productID)
                }
            case .degas:
                guard event.productID == nil, event.family == nil else { throw FuelProjectionError.invalidDegas }
                residuals[event.compartmentID] = .clear
            }
        }

        return cargoStates.map {
            FuelCompartmentProjection(
                compartmentID: $0.compartmentID,
                liquid: $0.quantity,
                residual: residuals[$0.compartmentID] ?? .clear
            )
        }
    }
}
