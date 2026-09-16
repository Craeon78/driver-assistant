import Foundation

/// Fuel-specific stable product identity. Load density is evidence, not identity.
public enum FuelFamily: String, Codable, Sendable, CaseIterable {
    case diesel
    case petrol
}

public struct FuelProduct: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var name: String
    public var code: String
    public var family: FuelFamily

    public init(
        id: CanonicalID = .fresh(),
        name: String,
        code: String,
        family: FuelFamily
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.family = family
    }

    /// Stable generic Cargo identity. Density deliberately stays nil so two loads of
    /// the same fuel remain the same CargoKind even when their observed density differs.
    public var cargoKind: CargoKind {
        CargoKind(
            id: id,
            name: name,
            kind: "fuel.\(code.lowercased())",
            unitName: "L",
            kilogramsPerUnit: nil
        )
    }
}

/// Physical evidence attached to a particular load, not to enduring product identity.
public struct FuelLoadEvidence: Codable, Sendable, Equatable {
    public let kilogramsPerLitre: Double
    public let sourceDescription: String?

    public init(kilogramsPerLitre: Double, sourceDescription: String? = nil) {
        self.kilogramsPerLitre = kilogramsPerLitre
        self.sourceDescription = sourceDescription
    }

    public func massKg(forLitres litres: Double) -> Double {
        litres * kilogramsPerLitre
    }
}

public enum FuelCatalogue {
    public static let supportedNames: [(name: String, code: String, family: FuelFamily)] = [
        ("Diesel", "diesel", .diesel),
        ("Ultimate Diesel", "xls", .diesel),
        ("ULP 91", "ulp91", .petrol),
        ("PULP 95", "pulp95", .petrol),
        ("S-PULP 98", "spulp98", .petrol),
        ("E10", "e10", .petrol)
    ]
}
