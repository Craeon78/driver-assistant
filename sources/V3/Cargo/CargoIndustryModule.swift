import Foundation

/// Cargo-module boundary. Industry modules own their vocabulary and
/// interpretation; the platform owns only generic identity/quantity exchange.
protocol CargoIndustryModule {
    var moduleID: String { get }
    var displayName: String { get }
    var cargoUnits: [CargoUnit] { get }

    func massContributionKg() -> Double
}

/// Registry deliberately knows protocols rather than Fuel concrete types.
struct CargoModuleRegistry {
    private(set) var modules: [any CargoIndustryModule] = []

    mutating func register(_ module: any CargoIndustryModule) {
        modules.removeAll { $0.moduleID == module.moduleID }
        modules.append(module)
    }
}
