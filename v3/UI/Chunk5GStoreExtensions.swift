import Foundation
import SwiftUI

extension Chunk5FPrototypeStore {
    /// Explicit Fixture / preview builder only. Must never be used on the live End Shift path.
    public func makeDemoGateReport() -> Chunk5GGateReport {
        Chunk5GGateReport(
            shiftStart: Date().addingTimeInterval(-8 * 3600),
            shiftEnd: Date(),
            openingODO: 482315,
            closingODO: 482512,
            events: [
                Chunk5GEvent(kind: .shiftStart, summary: "[FIXTURE] Shift started", detail: "Opening ODO 482315"),
                Chunk5GEvent(kind: .cargoBaseline, summary: "[FIXTURE] Opening cargo baseline", detail: "4000,0,4500,3200,7200"),
                Chunk5GEvent(kind: .load, summary: "[FIXTURE] Load confirmed", detail: "Terminal"),
                Chunk5GEvent(kind: .delivery, summary: "[FIXTURE] Delivery 5000 L", detail: "SEALINK Minjerrabah"),
                Chunk5GEvent(kind: .delivery, summary: "[FIXTURE] Delivery 9000 L", detail: "SEALINK Seabreeze"),
                Chunk5GEvent(kind: .transfer, summary: "[FIXTURE] Transfer 200 L", detail: "C1 → C3"),
                Chunk5GEvent(kind: .reconciliation, summary: "[FIXTURE] Reconcile C4", detail: "Physical empty"),
                Chunk5GEvent(kind: .shiftEnd, summary: "[FIXTURE] Shift ended", detail: "Closing ODO 482512")
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
