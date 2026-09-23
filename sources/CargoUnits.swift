import Foundation

struct QuantityValue: Codable, Hashable {
    let amount: Double
    let unitCode: String
}

struct CargoUnit: Identifiable, Codable, Hashable {
    let id: String
    var capacity: QuantityValue?
    var quantity: QuantityValue?
    var massKg: Double?
    var longitudinalPositionMetres: Double?
}

struct CargoModule: Identifiable, Codable, Hashable {
    let id: String
    var units: [CargoUnit]
    var isFixed: Bool
    var isSwapCapable: Bool
    var isTransferCapable: Bool
}
