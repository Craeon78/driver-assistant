import Foundation
import SwiftUI

extension Chunk5FPrototypeStore {
    // Note: These are documentation / call-site helpers for the 5G harness.
    // Full state properties live in the main store file when merged.
    // This file provides the Gate Report builder and event helpers used by the UI.

    public func makeDemoGateReport() -> Chunk5GGateReport {
        Chunk5GGateReport(
            shiftStart: Date().addingTimeInterval(-8 * 3600),
            shiftEnd: Date(),
            openingODO: 482315,
            closingODO: 482512,
            events: [
                Chunk5GEvent(kind: .shiftStart, summary: "Shift started", detail: "Opening ODO 482315"),
                Chunk5GEvent(kind: .cargoBaseline, summary: "Opening cargo baseline", detail: "4000,0,4500,3200,7200"),
                Chunk5GEvent(kind: .load, summary: "Load confirmed", detail: "Terminal"),
                Chunk5GEvent(kind: .delivery, summary: "Delivery 5000 L", detail: "SEALINK Minjerrabah"),
                Chunk5GEvent(kind: .delivery, summary: "Delivery 9000 L", detail: "SEALINK Seabreeze"),
                Chunk5GEvent(kind: .transfer, summary: "Transfer 200 L", detail: "C1 → C3"),
                Chunk5GEvent(kind: .reconciliation, summary: "Reconcile C4", detail: "Physical empty"),
                Chunk5GEvent(kind: .shiftEnd, summary: "Shift ended", detail: "Closing ODO 482512")
            ],
            cargoOpening: [4000, 0, 4500, 3200, 7200],
            cargoClosing: [0, 0, 1500, 0, 2200],
            unresolvedDiscrepancies: 1,
            loadsRepresented: true,
            deliveriesRepresented: true,
            transfersRepresented: true,
            reconciliationsRepresented: true,
            cargoArithmeticOK: true,
            odoAnchorsOK: true,
            persistenceOK: true
        )
    }
}
