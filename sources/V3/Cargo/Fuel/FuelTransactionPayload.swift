import Foundation

/// Fuel-owned interpretation attached to generic cargo transaction truth.
/// This preserves V3's rule that product/compartment/density vocabulary does not
/// leak into Core, Driver, Vehicle or Operations.
struct FuelTransactionLine: Codable, Hashable {
    let compartmentName: String
    let productShortName: String
    let quantity: CargoQuantity
    let densityKgPerLitre: Double
}

struct FuelTransactionPayload: Codable, Hashable {
    let transactionID: UUID
    let lines: [FuelTransactionLine]
    let terminalName: String?
    let loadCode: String?
}
