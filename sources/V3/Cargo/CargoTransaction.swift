import Foundation

/// Generic cargo transaction truth required by the V3 architecture.
/// Cargo modules provide their own payload interpretation; Core/Operations do not
/// acquire Fuel-specific fields such as litres, products or compartments.
struct CargoQuantity: Codable, Hashable {
    let amount: Double
    let unitCode: String
}

enum CargoTransactionKind: String, Codable {
    case load
    case unload
    case transfer
}

struct CargoTransaction: Identifiable, Codable, Hashable {
    let id: UUID
    let occurredAt: Date
    let recordedAt: Date
    let kind: CargoTransactionKind
    let cargoModuleID: String
    let cargoUnitID: String?
    let quantity: CargoQuantity
    let sourceTransactionID: UUID?
    let supersedesTransactionID: UUID?

    init(
        id: UUID = UUID(),
        occurredAt: Date,
        recordedAt: Date,
        kind: CargoTransactionKind,
        cargoModuleID: String,
        cargoUnitID: String? = nil,
        quantity: CargoQuantity,
        sourceTransactionID: UUID? = nil,
        supersedesTransactionID: UUID? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.kind = kind
        self.cargoModuleID = cargoModuleID
        self.cargoUnitID = cargoUnitID
        self.quantity = quantity
        self.sourceTransactionID = sourceTransactionID
        self.supersedesTransactionID = supersedesTransactionID
    }
}
