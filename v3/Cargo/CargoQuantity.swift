import Foundation

public struct CargoQuantity: Codable, Sendable, Equatable {
    public let cargo: CargoKind
    public let units: Double

    public init(cargo: CargoKind, units: Double) {
        self.cargo = cargo
        self.units = units
    }

    public var massKg: Double? {
        guard let factor = cargo.kilogramsPerUnit else { return nil }
        return units * factor
    }
}

public struct CargoCompartmentState: Codable, Sendable, Equatable {
    public let compartmentID: CanonicalID
    public let quantity: CargoQuantity?

    public init(compartmentID: CanonicalID, quantity: CargoQuantity?) {
        self.compartmentID = compartmentID
        self.quantity = quantity
    }
}
