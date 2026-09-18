import Foundation

public enum Chunk5DVarianceGateTests {
    public static func run() -> [String] {
        var results=["=== V3 Chunk 5D.1 Reconciliation / Variance Gate ==="]
        func check(_ label:String,_ condition:@autoclosure()->Bool){results.append("\(label): \(condition() ? "PASS":"FAIL")")}
        func succeeds(_ block:()throws->Bool)->Bool{(try? block())==true}
        let compartment=CanonicalID.fresh()
        let cargo=TestBulkCargo(name:"XLS fixture",kilogramsPerUnit:0.84).erased
        let t0=Date(timeIntervalSince1970:1_758_200_000)
        let limits=[CargoCompartmentLimit(compartmentID:compartment,capacityUnits:8000)]

        check("Physical remainder bucketed to slops is movement, not variance", succeeds {
            var ledger=try CargoLedger(limits:limits)
            try ledger.append(CargoTransaction(kind:.load,cargo:cargo,units:5580,destinationCompartmentID:compartment,occurredAt:t0))
            try ledger.append(CargoTransaction(kind:.unload,cargo:cargo,units:5501,sourceCompartmentID:compartment,occurredAt:t0.addingTimeInterval(1),note:"customer"))
            try ledger.append(CargoTransaction(kind:.unload,cargo:cargo,units:79,sourceCompartmentID:compartment,occurredAt:t0.addingTimeInterval(2),note:"terminal slops"))
            return try ledger.state(compartmentID:compartment).quantity == nil
        })

        check("Calculated 40 remains but confirmed empty => -40 reconciliation, no fake unload", succeeds {
            var ledger=try CargoLedger(limits:limits)
            try ledger.append(CargoTransaction(kind:.load,cargo:cargo,units:5501,destinationCompartmentID:compartment,occurredAt:t0))
            try ledger.append(CargoTransaction(kind:.unload,cargo:cargo,units:5461,sourceCompartmentID:compartment,occurredAt:t0.addingTimeInterval(1)))
            let unloads=ledger.transactions.filter{$0.kind == .unload}.count
            var log=try CargoReconciliationLog()
            try log.append(CargoReconciliationEvent(compartmentID:compartment,cargo:cargo,calculatedUnitsBefore:40,confirmedPhysicalUnitsAfter:0,occurredAt:t0.addingTimeInterval(2)))
            let state=try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:log,compartmentID:compartment)
            return state.quantity == nil && log.netVariance(cargoID:cargo.id) == -40 && ledger.transactions.filter{$0.kind == .unload}.count == unloads
        })

        check("Moongalba observed 5580 vs explainable 5501, confirmed empty => +79 evidence, zero inventory", succeeds {
            var ledger=try CargoLedger(limits:limits)
            try ledger.append(CargoTransaction(kind:.load,cargo:cargo,units:5501,destinationCompartmentID:compartment,occurredAt:t0))
            let explainable=CargoTransaction(kind:.unload,cargo:cargo,units:5501,sourceCompartmentID:compartment,occurredAt:t0.addingTimeInterval(1),note:"meter observed 5580; ledger explains 5501")
            try ledger.append(explainable)
            var log=try CargoReconciliationLog()
            try log.append(CargoReconciliationEvent(compartmentID:compartment,cargo:cargo,calculatedUnitsBefore:0,confirmedPhysicalUnitsAfter:0,observedMovementVariance:79,occurredAt:t0.addingTimeInterval(2),relatedCargoTransactionID:explainable.id))
            let state=try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:log,compartmentID:compartment)
            return state.quantity == nil && log.netVariance(cargoID:cargo.id) == 79
        })

        check("Positive variance cannot be dipped into for delivery", succeeds {
            var ledger=try CargoLedger(limits:limits)
            var log=try CargoReconciliationLog()
            try log.append(CargoReconciliationEvent(compartmentID:compartment,cargo:cargo,calculatedUnitsBefore:0,confirmedPhysicalUnitsAfter:0,observedMovementVariance:79,occurredAt:t0))
            do { try ledger.append(CargoTransaction(kind:.unload,cargo:cargo,units:79,sourceCompartmentID:compartment,occurredAt:t0.addingTimeInterval(1))); return false }
            catch CargoLedgerError.insufficientQuantity { return log.netVariance(cargoID:cargo.id)==79 }
        })

        check("Reconciliation evidence survives validated Codable replay", succeeds {
            var log=try CargoReconciliationLog()
            try log.append(CargoReconciliationEvent(compartmentID:compartment,cargo:cargo,calculatedUnitsBefore:100,confirmedPhysicalUnitsAfter:0,occurredAt:t0))
            let replay=try JSONDecoder().decode(CargoReconciliationLog.self,from:JSONEncoder().encode(log))
            return replay.events.count==1 && replay.netVariance(cargoID:cargo.id)==(-100)
        })

        results.append("---"); results.append(results.contains(where:{$0.hasSuffix("FAIL")}) ? "GATE FAIL":"GATE PASS"); return results
    }
}
