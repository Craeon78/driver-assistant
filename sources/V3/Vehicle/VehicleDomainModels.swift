import Foundation

struct AxleSplit: Codable {
    var steerFraction: Double
    var driveFraction: Double
}

struct TruckConfig: Codable {
    var name: String
    var tareSteerKg: Double
    var tareDriveKg: Double
    var runTankFullKg: Double = 0
    var lazyLiftTransferKg: Double
    var hasLazyAxle: Bool = true
    var maxSteerKg: Double
    var maxDriveKg: Double
    var maxGvmKg: Double

    /// Cargo-position mass distribution. The Vehicle domain owns axle physics;
    /// cargo modules provide mass and position identifiers.
    var axleSplitByCargoPosition: [String: AxleSplit]
}
