import Foundation

/// Deliberately non-fuel Cargo implementation used only to prove that the
/// generic Cargo contract is not secretly a Fuel contract.
public struct TestBulkCargo: CargoDescriptor {
    public let id: CanonicalID
    public let name: String
    public let kilogramsPerUnit: Double?

    public init(id: CanonicalID = .fresh(), name: String = "Test bulk cargo", kilogramsPerUnit: Double? = 2.0) {
        self.id = id
        self.name = name
        self.kilogramsPerUnit = kilogramsPerUnit
    }

    public var erased: CargoKind {
        CargoKind(id: id, name: name, kind: "test.bulk", unitName: "units", kilogramsPerUnit: kilogramsPerUnit)
    }
}
