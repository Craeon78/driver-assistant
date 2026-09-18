import Foundation

public enum CargoTransactionKind: String, Codable, Sendable, CaseIterable {
    case load
    case unload
    case transfer
    case correction
}

/// Immutable cargo movement/correction fact.
/// Reconciliation is not a CargoTransaction: it establishes observed physical state.
public struct CargoTransaction: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let kind: CargoTransactionKind
    public let cargo: CargoKind
    public let units: Double
    public let sourceCompartmentID: CanonicalID?
    public let destinationCompartmentID: CanonicalID?
    public let occurredAt: Date
    public let recordedAt: Date
    public let provenance: EventProvenance
    public let correctsTransactionID: CanonicalID?
    public let note: String?

    public init(id: CanonicalID = .fresh(), kind: CargoTransactionKind, cargo: CargoKind, units: Double, sourceCompartmentID: CanonicalID? = nil, destinationCompartmentID: CanonicalID? = nil, occurredAt: Date, recordedAt: Date = Date(), provenance: EventProvenance = .driverEntered, correctsTransactionID: CanonicalID? = nil, note: String? = nil) {
        self.id=id; self.kind=kind; self.cargo=cargo; self.units=units
        self.sourceCompartmentID=sourceCompartmentID; self.destinationCompartmentID=destinationCompartmentID
        self.occurredAt=occurredAt; self.recordedAt=recordedAt; self.provenance=provenance
        self.correctsTransactionID=correctsTransactionID; self.note=note
    }
}
