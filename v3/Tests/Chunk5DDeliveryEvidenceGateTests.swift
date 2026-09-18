import Foundation

public enum Chunk5DDeliveryEvidenceGateTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5D.3 Delivery Evidence Gate ==="]
        func check(_ label: String, _ value: @autoclosure () -> Bool) { results.append("\(label): \(value() ? "PASS" : "FAIL")") }

        let t0 = Date(timeIntervalSince1970: 1_758_200_000)
        let product = CanonicalID.fresh()
        var aat = FuelDeliveryCard(serviceJobID: CanonicalID.fresh(), productID: product, expectedDeliveryLitres: 8001, expectedPumpFinish: t0.addingTimeInterval(14 * 60))

        check("Expected delivery begins as suggestion only", aat.expectedDeliveryLitres.confirmedValue == nil)
        aat.confirmExpectedDelivery(8001, at: t0)
        check("Driver confirmation establishes expected quantity", aat.expectedDeliveryLitres.confirmedValue == 8001)

        aat.recordOpeningLevel(OperationalQuantityEvidence(value: 4000, unitName: "L", status: .observed, occurredAt: t0, resolution: 500, sourceDescription: "dipstick"))
        aat.recordClosingLevel(OperationalQuantityEvidence(value: 12190, unitName: "L", status: .observed, occurredAt: t0.addingTimeInterval(14 * 60), resolution: 500, sourceDescription: "driver interpretation from coarse dip"))
        aat.recordClosingLevel(OperationalQuantityEvidence(value: 12200, unitName: "L", status: .administrative, occurredAt: t0.addingTimeInterval(17 * 60), sourceDescription: "FC close"))
        check("Coarse physical and administrative close coexist", aat.closingLevelEvidence.count == 2 && aat.closingLevelEvidence[0].resolution == 500 && aat.closingLevelEvidence[1].status == .administrative)

        check("Pump starts independently of planned finish", aat.startPump(at: t0))
        check("Pump finish cannot precede start", !aat.finishPump(at: t0.addingTimeInterval(-1)))
        check("Pump finish records actual execution", aat.finishPump(at: t0.addingTimeInterval(14 * 60)) && aat.pumpDuration == 14 * 60)

        aat.recordDeliveredLitres(OperationalQuantityEvidence(value: 8001, unitName: "L", status: .confirmed, occurredAt: t0.addingTimeInterval(14 * 60)))
        check("Confirmed physical delivery is actual", aat.actualDeliveredLitres == 8001)

        var moongalba = FuelDeliveryCard(serviceJobID: CanonicalID.fresh(), productID: product, expectedDeliveryLitres: 5501)
        moongalba.confirmExpectedDelivery(5580, at: t0)
        check("Replacement preserves 5501 suggestion and 5580 truth", moongalba.expectedDeliveryLitres.suggestedValue == 5501 && moongalba.expectedDeliveryLitres.confirmedValue == 5580)

        results.append("---")
        results.append(results.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
