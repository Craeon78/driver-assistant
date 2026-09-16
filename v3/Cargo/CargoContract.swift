import Foundation

/// Generic transported-cargo identity. Fuel may specialise metadata later,
/// but the ledger does not know or require fuel semantics.
public protocol CargoDescriptor: Codable, Sendable, Equatable {
    var id: CanonicalID { get }
    var name: String { get }
    /// Optional physical mass conversion. Nil means mass is not derivable.
    var kilogramsPerUnit: Double? { get }
}

/// Type-erased persisted descriptor used by the generic ledger.
/// `kind` is a namespaced discriminator (for example "test.bulk" or later
/// "fuel.petrol") and is deliberately not interpreted by Core/Vehicle/Operations.
public struct CargoKind: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var kind: String
    public var unitName: String
    public var kilogramsPerUnit: Double?

    public init(id: CanonicalID = .fresh(), name: String, kind: String, unitName: String, kilogramsPerUnit: Double? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.unitName = unitName
        self.kilogramsPerUnit = kilogramsPerUnit
    }
}

public struct CargoCompartmentLimit: Codable, Sendable, Equatable {
    public let compartmentID: CanonicalID
    public let capacityUnits: Double

    public init(compartmentID: CanonicalID, capacityUnits: Double) {
        self.compartmentID = compartmentID
        self.capacityUnits = capacityUnits
    }
}
