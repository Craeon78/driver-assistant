import Foundation

/// Fuel-specific product identity and physical metadata.
/// The generic Cargo layer sees only the adapted CargoKind.
public enum FuelFamily: String, Codable, Sendable, CaseIterable {
    case diesel
    case petrol
}

public struct FuelProduct: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var code: String
    public var family: FuelFamily
    /// kg/L for the applicable load. This is physical conversion data, not cargo quantity truth.
    public var kilogramsPerLitre: Double

    public init(
        id: CanonicalID = .fresh(),
        name: String,
        code: String,
        family: FuelFamily,
        kilogramsPerLitre: Double
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.family = family
        self.kilogramsPerLitre = kilogramsPerLitre
    }

    public var cargoKind: CargoKind {
        CargoKind(
            id: id,
            name: name,
            kind: "fuel.\(code.lowercased())",
            unitName: "L",
            kilogramsPerUnit: kilogramsPerLitre
        )
    }
}

public enum FuelCatalogue {
    /// Catalogue values intentionally omit default density. Density/SG is load evidence,
    /// not a universal product constant. Callers construct the applicable FuelProduct
    /// using terminal/load evidence before committing cargo truth.
    public static let supportedNames: [(name: String, code: String, family: FuelFamily)] = [
        ("Diesel", "diesel", .diesel),
        ("Ultimate Diesel", "xls", .diesel),
        ("ULP 91", "ulp91", .petrol),
        ("PULP 95", "pulp95", .petrol),
        ("S-PULP 98", "spulp98", .petrol),
        ("E10", "e10", .petrol)
    ]
}
