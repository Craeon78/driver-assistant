import Foundation

public enum Chunk5DServiceJobGateTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5D.2 Service Job Lifecycle Gate ==="]
        func check(_ label: String, _ value: @autoclosure () -> Bool) { results.append("\(label): \(value() ? "PASS" : "FAIL")") }

        let t0 = Date(timeIntervalSince1970: 1_758_200_000)
        let site = CanonicalID.fresh(), customer = CanonicalID.fresh(), asset = CanonicalID.fresh()

        var atlas = ServiceJob(identity: ServiceJobIdentity(siteID: site, customerID: customer, assetID: asset), plannedArrival: t0)
        check("Site customer and asset remain distinct", atlas.identity.siteID != atlas.identity.customerID && atlas.identity.customerID != atlas.identity.assetID)
        check("Plan does not fabricate arrival", atlas.state == .planned && atlas.actualArrival == nil)
        check("Driver confirms arrival", atlas.confirmArrival(at: t0.addingTimeInterval(60)))
        check("Arrival can begin service", atlas.begin(at: t0.addingTimeInterval(120)))
        check("Service completes after start", atlas.complete(at: t0.addingTimeInterval(300)))
        check("Departure is separate from completion", atlas.actualDeparture == nil && atlas.depart(at: t0.addingTimeInterval(360)))

        let suggestion = ConfirmedValue<Double>(suggestedValue: 8001)
        check("Suggested quantity is not actual truth", suggestion.confirmedValue == nil)
        let confirmed = suggestion.confirming(8001, at: t0)
        check("Unchanged suggestion requires positive confirmation", confirmed.suggestedValue == 8001 && confirmed.confirmedValue == 8001)
        let replaced = suggestion.confirming(7998, at: t0)
        check("Replacement preserves original suggestion", replaced.suggestedValue == 8001 && replaced.confirmedValue == 7998)

        var oasis = ServiceJob(identity: ServiceJobIdentity(siteID: CanonicalID.fresh(), customerID: CanonicalID.fresh()))
        check("Planned job may be explicitly deferred", oasis.deferJob() && oasis.state == .deferred && oasis.actualCompletion == nil)
        check("Deferred job cannot fabricate service start", !oasis.begin(at: t0))

        results.append("---")
        results.append(results.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
