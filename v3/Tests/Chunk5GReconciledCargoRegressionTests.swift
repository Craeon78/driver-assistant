import Foundation

public enum Chunk5GReconciledCargoRegressionTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5G Reconciled Cargo Regression ==="]
        func check(_ label: String, _ value: @autoclosure () throws -> Bool) {
            do { results.append("\(label): \(try value() ? "PASS" : "FAIL")") }
            catch { results.append("\(label): FAIL — \(error)") }
        }
        do {
            let c1=CanonicalID.fresh(), c2=CanonicalID.fresh(), c3=CanonicalID.fresh()
            let limits=[CargoCompartmentLimit(compartmentID:c1,capacityUnits:5360),CargoCompartmentLimit(compartmentID:c2,capacityUnits:4900),CargoCompartmentLimit(compartmentID:c3,capacityUnits:7240)]
            let cargo=CargoKind(name:"Diesel",kind:"fuel.diesel",unitName:"L")
            let t0=Date(timeIntervalSince1970:1_700_000_000)
            var ledger=try CargoLedger(limits:limits)
            var rec=try CargoReconciliationLog()
            try rec.append(CargoReconciliationEvent(compartmentID:c1,cargo:cargo,calculatedUnitsBefore:0,confirmedPhysicalUnitsAfter:3917,occurredAt:t0,recordedAt:t0,provenance:.driverEntered,note:"chunk5g.opening.baseline"))
            try rec.append(CargoReconciliationEvent(compartmentID:c2,cargo:cargo,calculatedUnitsBefore:0,confirmedPhysicalUnitsAfter:4271,occurredAt:t0,recordedAt:t0,provenance:.driverEntered,note:"chunk5g.opening.baseline"))
            check("Distinctive opening baseline", try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:rec,compartmentID:c1).quantity?.units == 3917)
            let op1="chunk5g.delivery.op.1"
            try ledger.append(CargoTransaction(kind:.unload,cargo:cargo,units:3000,sourceCompartmentID:c1,occurredAt:t0.addingTimeInterval(10),note:op1),reconciliationLog:rec)
            try ledger.append(CargoTransaction(kind:.unload,cargo:cargo,units:1123,sourceCompartmentID:c2,occurredAt:t0.addingTimeInterval(10),note:op1),reconciliationLog:rec)
            check("Multi-compartment 4123 L delivery", try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:rec,compartmentID:c1).quantity?.units == 917 && CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:rec,compartmentID:c2).quantity?.units == 3148)
            try ledger.append(CargoTransaction(kind:.transfer,cargo:cargo,units:317,sourceCompartmentID:c2,destinationCompartmentID:c3,occurredAt:t0.addingTimeInterval(20),note:"chunk5g.transfer.op.2"),reconciliationLog:rec)
            check("Odd transfer", try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:rec,compartmentID:c3).quantity?.units == 317)
            let before=try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:rec,compartmentID:c1).quantity?.units ?? -1
            try rec.append(CargoReconciliationEvent(compartmentID:c1,cargo:cargo,calculatedUnitsBefore:before,confirmedPhysicalUnitsAfter:900,occurredAt:t0.addingTimeInterval(30),recordedAt:t0.addingTimeInterval(30),provenance:.driverEntered,note:"physical observation"))
            try ledger.append(CargoTransaction(kind:.unload,cargo:cargo,units:123,sourceCompartmentID:c1,occurredAt:t0.addingTimeInterval(40),note:"chunk5g.delivery.op.3"),reconciliationLog:rec)
            check("Transaction after physical reconciliation", try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:rec,compartmentID:c1).quantity?.units == 777)
            try rec.append(CargoReconciliationEvent(compartmentID:c1,cargo:cargo,calculatedUnitsBefore:777,confirmedPhysicalUnitsAfter:877,occurredAt:t0.addingTimeInterval(50),recordedAt:t0.addingTimeInterval(50),provenance:.driverEntered,note:"CORRECTION: +100"))
            check("Partial +100 correction", try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:rec,compartmentID:c1).quantity?.units == 877)
            let replayLedger=try JSONDecoder().decode(CargoLedger.self,from:JSONEncoder().encode(ledger))
            let replayRec=try JSONDecoder().decode(CargoReconciliationLog.self,from:JSONEncoder().encode(rec))
            let original=try limits.map { try CargoStateReconciler.currentState(ledger:ledger,reconciliationLog:rec,compartmentID:$0.compartmentID).quantity?.units ?? 0 }
            let replay=try limits.map { try CargoStateReconciler.currentState(ledger:replayLedger,reconciliationLog:replayRec,compartmentID:$0.compartmentID).quantity?.units ?? 0 }
            check("Encode/decode replay identical", original == replay)
            check("Operation identity groups compartment rows", Set(ledger.transactions.filter{$0.kind == .unload && ($0.note?.hasPrefix("chunk5g.delivery.op.") ?? false)}.compactMap(\.note)).count == 2)
        } catch { results.append("Unexpected error: FAIL — \(error)") }
        results.append("---"); results.append(results.contains(where:{$0.contains(": FAIL")}) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
