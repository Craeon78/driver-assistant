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

    /// Select an incomplete drop at the current site without leaving Site workspace.
    @discardableResult
    public func selectFill(at fillIndex: Int) -> Bool {
        guard workspace == .site,
              visits.indices.contains(selectedVisit),
              visits[selectedVisit].fills.indices.contains(fillIndex),
              !visits[selectedVisit].fills[fillIndex].completed else { return false }
        selectedFill = fillIndex
        resetDraft()
        let f = visits[selectedVisit].fills[fillIndex]
        message = "Now serving \(f.name) — \(f.plannedLitres) L \(f.product)."
        return true
    }

    /// Advance to next incomplete drop at the current site, or return to Active if none.
    @discardableResult
    public func advanceToNextFillAtSite() -> Bool {
        guard visits.indices.contains(selectedVisit) else { return false }
        if let next = visits[selectedVisit].fills.indices.first(where: { !visits[selectedVisit].fills[$0].completed }) {
            selectedFill = next
            resetDraft()
            workspace = .site
            let f = visits[selectedVisit].fills[next]
            message = "Next drop: \(f.name) — \(f.plannedLitres) L \(f.product)."
            return true
        }
        workspace = .active
        message = "Site visit complete."
        return false
    }
}
