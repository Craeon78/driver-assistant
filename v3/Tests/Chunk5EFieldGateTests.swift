import Foundation

public enum Chunk5EFieldGateTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5E Field Model Gate ==="]
        func check(_ label: String, _ value: @autoclosure () -> Bool) {
            results.append("\(label): \(value() ? "PASS" : "FAIL")")
        }

        let tankWithDip = DeliveryContext(
            destinationKind: .storageTank,
            evidenceCapability: .init(levelObservationMethod: .dipstick, approximateResolutionLitres: 500)
        )
        let tankWithoutDip = DeliveryContext(destinationKind: .storageTank)
        let die = DeliveryContext(destinationKind: .equipment)

        check("Tank may expose dip evidence", tankWithDip.evidenceCapability.canObserveReceivingLevel)
        check("Tank without usable dip does not fabricate level evidence", !tankWithoutDip.evidenceCapability.canObserveReceivingLevel)
        check("DIE does not imply receiving-level evidence", !die.evidenceCapability.canObserveReceivingLevel)
        check("Destination identity and evidence capability remain separate",
              tankWithDip.destinationKind == tankWithoutDip.destinationKind &&
              tankWithDip.evidenceCapability != tankWithoutDip.evidenceCapability)

        do {
            let store = try FieldTestStore.fiveCompartmentFixture()
            check("Field fixture has five compartments", store.compartmentIDs.count == 5)
            check("Five compartments are fixture data, not a fixed DeliveryContext property",
                  Mirror(reflecting: tankWithDip).children.count == 2)
        } catch {
            check("Field fixture constructs", false)
        }

        results.append("---")
        results.append(results.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
