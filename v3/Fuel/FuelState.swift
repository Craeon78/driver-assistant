import Foundation

public enum FuelResidualState: Codable, Sendable, Equatable {
    case clear
    case diesel(productID: CanonicalID)
    case petrolVapour(productID: CanonicalID)
}

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
    case incident
}

/// Fuel-specific state/history fact supplementing the generic Cargo transaction.
/// Incidents preserve what physically happened; they are never Cargo corrections.
public struct FuelStateEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let kind: FuelStateEventKind
    public let compartmentID: CanonicalID
    public let productID: CanonicalID?
    public let family: FuelFamily?
    public let occurredAt: Date
    public let recordedAt: Date
    public let provenance: EventProvenance
    public let note: String?

    public init(
        id: CanonicalID = .fresh(),
        kind: FuelStateEventKind,
        compartmentID: CanonicalID,
        productID: CanonicalID? = nil,
        family: FuelFamily? = nil,
        occurredAt: Date,
        recordedAt: Date = Date(),
        provenance: EventProvenance = .driverEntered,
        note: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.compartmentID = compartmentID
        self.productID = productID
        self.family = family
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.provenance = provenance
        self.note = note
    }
}

public enum FuelProposalDecision: Equatable {
    case allowed
    case prevented(reason: String)
}

/// Prevention is prospective only. It returns a decision and creates no Cargo or Fuel event.
public enum FuelProposalGuard {
    public static func evaluateLoad(
        product: FuelProduct,
        litres: Double,
        compartmentLimitLitres: Double
    ) -> FuelProposalDecision {
        guard litres > 0 else { return .prevented(reason: "Fuel quantity must be positive") }
        guard litres <= compartmentLimitLitres else { return .prevented(reason: "Proposed fuel quantity exceeds compartment limit") }
        return .allowed
    }
}

public enum FuelProjectionError: Error, Equatable {
    case unknownCompartment
    case invalidProductEntry
    case invalidDegas
    case invalidIncident
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
                guard let productID = event.productID, let family = event.family else { throw FuelProjectionError.invalidProductEntry }
                switch family {
                case .diesel: residuals[event.compartmentID] = .diesel(productID: productID)
                case .petrol: residuals[event.compartmentID] = .petrolVapour(productID: productID)
                }
            case .degas:
                guard event.productID == nil, event.family == nil else { throw FuelProjectionError.invalidDegas }
                residuals[event.compartmentID] = .clear
            case .incident:
                guard event.note?.isEmpty == false else { throw FuelProjectionError.invalidIncident }
                // Incident is history/provenance. It does not silently rewrite physical projection.
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
