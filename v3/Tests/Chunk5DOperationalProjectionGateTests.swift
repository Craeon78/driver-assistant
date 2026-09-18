import Foundation

public enum Chunk5DOperationalProjectionGateTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5D.5 Operational Projection / Replay Gate ==="]
        func check(_ label: String, _ value: @autoclosure () -> Bool) {
            results.append("\(label): \(value() ? "PASS" : "FAIL")")
        }

        let t0 = Date(timeIntervalSince1970: 1_758_200_000)

        var current = ServiceJob(
            identity: ServiceJobIdentity(siteID: CanonicalID.fresh()),
            plannedArrival: t0,
            plannedCompletion: t0.addingTimeInterval(20 * 60)
        )
        _ = current.confirmArrival(at: t0.addingTimeInterval(60))
        _ = current.begin(at: t0.addingTimeInterval(2 * 60))

        var card = FuelDeliveryCard(
            serviceJobID: current.id,
            productID: CanonicalID.fresh(),
            expectedDeliveryLitres: 8001,
            expectedPumpFinish: t0.addingTimeInterval(17 * 60),
            expectedDeparture: t0.addingTimeInterval(24 * 60)
        )

        let next = ServiceJob(
            identity: ServiceJobIdentity(siteID: CanonicalID.fresh()),
            plannedArrival: t0.addingTimeInterval(70 * 60)
        )

        let projection = OperationalProjectionBuilder.currentAndNext(
            currentJob: current,
            currentCard: card,
            nextJob: next,
            nextRequiredCargoUnits: 2000,
            availableCargoUnits: 4000,
            projectedNextArrival: t0.addingTimeInterval(72 * 60),
            relevantConstraintAt: t0.addingTimeInterval(90 * 60),
            generatedAt: t0
        )

        check("Current expected finish comes from operational evidence", projection.currentExpectedCompletion == t0.addingTimeInterval(17 * 60))
        check("Current expected departure is retained separately", projection.currentExpectedDeparture == t0.addingTimeInterval(24 * 60))
        check("Sufficient cargo produces zero shortfall, not invented surplus inventory", projection.projectedCargoShortfallUnits == 0)
        check("Constraint margin is consequence evidence", projection.constraintMarginSeconds == 18 * 60)

        let shortage = OperationalProjectionBuilder.currentAndNext(
            currentJob: current,
            currentCard: card,
            nextJob: next,
            nextRequiredCargoUnits: 5000,
            availableCargoUnits: 4000,
            projectedNextArrival: nil,
            relevantConstraintAt: nil,
            generatedAt: t0
        )
        check("Cargo consequence exposes shortfall without changing Cargo", shortage.projectedCargoShortfallUnits == 1000 && shortage.availableCargoUnits == 4000)

        _ = card.startPump(at: t0.addingTimeInterval(3 * 60))
        _ = card.finishPump(at: t0.addingTimeInterval(17 * 60))
        card.recordDeliveredLitres(OperationalQuantityEvidence(value: 8001, unitName: "L", status: .confirmed, occurredAt: t0.addingTimeInterval(17 * 60)))
        _ = current.complete(at: t0.addingTimeInterval(17 * 60))
        _ = current.depart(at: t0.addingTimeInterval(24 * 60))

        let replay = OperationalReplayEvidence(job: current, card: card)
        check("Replay preserves plan and actual independently", replay.plannedCompletion == t0.addingTimeInterval(20 * 60) && replay.actualCompletion == t0.addingTimeInterval(17 * 60))
        check("Replay derives completion delta without rewriting either fact", replay.completionDeltaSeconds == -3 * 60)
        check("Expected and actual delivery remain independently replayable", replay.expectedDeliveryUnits == 8001 && replay.actualDeliveryUnits == 8001 && replay.deliveryDeltaUnits == 0)

        let late = OperationalProjectionBuilder.currentAndNext(
            currentJob: current,
            currentCard: card,
            nextJob: next,
            nextRequiredCargoUnits: 2000,
            availableCargoUnits: 4000,
            projectedNextArrival: t0.addingTimeInterval(100 * 60),
            relevantConstraintAt: t0.addingTimeInterval(90 * 60),
            generatedAt: t0
        )
        check("Negative margin reports threatened constraint without deciding for driver", late.constraintMarginSeconds == -10 * 60)

        results.append("---")
        results.append(results.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
