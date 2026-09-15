import Foundation

struct HazchemCode: Codable {
    var prefixDot: Bool
    var digit: Int
    var letter: String
    var hasE: Bool
}

/// Fuel-specific draft cargo position. Litres and Product deliberately live in
/// the Fuel module rather than generic Cargo/Core.
struct FuelCompartmentDraft: Identifiable, Codable {
    var id = UUID()
    let name: String
    let capacityLitres: Int
    var selectedProduct: Product?
    var litresText: String = ""
    var isDegassed: Bool = false
}

struct ConfirmedFuelCompartment: Identifiable, Codable {
    var id = UUID()
    let name: String
    let sfl: Int
    let productShort: String
    let sg: Double?
    let litres: Double
    let massKg: Double
}

enum FuelTransactionMode: String, Codable {
    case loadConfirmed = "LOAD"
    case unloadSnapshot = "UNLOAD"

    var displayName: String {
        switch self {
        case .loadConfirmed: return "Load"
        case .unloadSnapshot: return "Unload"
        }
    }
}

struct ConfirmedFuelTransaction: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let mode: FuelTransactionMode
    let terminalName: String
    let loadCode: String
    let vehicleId: String
    let driverName: String
    let compartments: [ConfirmedFuelCompartment]
    let totalLitres: Int
    let totalMassKg: Double
    let steerKg: Double
    let driveKg: Double
    let gvmKg: Double
}

struct FuelDeliveryLine: Identifiable, Codable {
    var id = UUID()
    let cargoPositionName: String
    let productShort: String
    let litresDelivered: Int
}

struct FuelDeliveryRecord: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let customerName: String?
    let lines: [FuelDeliveryLine]
    let note: String?
}

/// Compatibility aliases allow behavioural extraction to proceed without a
/// simultaneous app-wide public-type rename. Remove only after callers migrate.
typealias CompartmentModel = FuelCompartmentDraft
typealias ConfirmedCompartment = ConfirmedFuelCompartment
typealias ConfirmedLoadMode = FuelTransactionMode
typealias ConfirmedLoad = ConfirmedFuelTransaction
typealias DeliveryLine = FuelDeliveryLine
typealias DeliveryRecord = FuelDeliveryRecord
