import Foundation

@MainActor
public enum Chunk5FAdaptiveWorkspaceTests {
    public static func run() -> [String] {
        var output = ["=== V3 Chunk 5F Adaptive Workspace Gate ==="]
        func check(_ label: String, _ condition: @autoclosure () -> Bool) {
            output.append("\(label): \(condition() ? "PASS" : "FAIL")")
        }

        // Deterministic 5F gate must use explicit Fixture source — never silent live defaults.
        let store = Chunk5FPrototypeStore(evidenceSource: .fixture)
        check("Starts pre-shift", store.workspace == .preShift)
        check("Fixture has baseline accepted", store.openingBaselineAccepted)
        check("Fixture has SeaLink visit", !store.visits.isEmpty)
        store.startShift()
        check("Start Shift enters Active", store.workspace == .active)
        let firstSite = store.visits[0].site
        store.setPrototypeMoving(true)
        check("Moving makes Run view-only", !store.canReorderRun)
        store.moveVisit(from: IndexSet(integer: 0), to: 2)
        check("Moving prevents Run reorder", store.visits[0].site == firstSite)
        let workspaceBeforeMovingOpen = store.workspace
        check("Moving prevents Site workspace open", !store.openSite(0) && store.workspace == workspaceBeforeMovingOpen)
        store.setPrototypeMoving(false)
        store.moveVisit(from: IndexSet(integer: 0), to: 2)
        check("Stationary permits Run reorder", store.visits[0].site != firstSite)
        store.moveVisit(from: IndexSet(integer: 1), to: 0)

        store.openSite(0)
        check("SeaLink Cleveland is one Site Visit", store.currentVisit?.site == "CLEVELAND")
        check("SeaLink Cleveland contains two Fill Items", store.currentVisit?.fills.count == 2)
        check("First Fill is Minjerrabah", store.currentFill?.name == "Minjerrabah")
        store.workspace = .load
        store.setDraft(compartment: 1, litres: 1000)
        store.commitLoad()
        store.openSite(0)
        let c2BeforeWrongProduct = store.draftLitres[1]
        check("Wrong-product fixture is non-zero", c2BeforeWrongProduct == 1000)
        store.setDraft(compartment: 1, litres: 500)
        check("Wrong-product compartment reduction is rejected for DIE fill", store.draftLitres[1] == c2BeforeWrongProduct)
        let c2ConfirmedBeforeDelivery = store.confirmedLitres[1]
        let unloadCountBeforeDelivery = store.cargoLedger.transactions.filter { $0.kind == .unload }.count
        let c4BeforeIncrease = store.draftLitres[3]
        store.setDraft(compartment: 3, litres: c4BeforeIncrease + 50)
        check("Delivery increase is rejected for reconciliation path", store.draftLitres[3] == c4BeforeIncrease)

        store.setDraft(compartment: 3, litres: 0)
        store.setDraft(compartment: 4, litres: 5400)
        check("C4/C5 field case derives 5000 L", store.deliveryMovement == 5000)
        check("Confirmed C4 unchanged before Confirm", store.confirmedLitres[3] == 3200)
        check("Confirmed C5 unchanged before Confirm", store.confirmedLitres[4] == 7200)

        store.commitDelivery()
        check("Confirm commits C4 empty", store.confirmedLitres[3] == 0)
        check("Confirm commits C5 5400", store.confirmedLitres[4] == 5400)
        let deliveryUnloads = store.cargoLedger.transactions.filter { $0.kind == .unload }
        check("Confirm appends two matching-product unload transactions", deliveryUnloads.count == unloadCountBeforeDelivery + 2)
        check("Wrong-product confirmed quantity survives DIE Confirm", store.confirmedLitres[1] == c2ConfirmedBeforeDelivery)
        check("No ULP unload reaches CargoLedger during DIE Confirm", !deliveryUnloads.contains { $0.cargo.kind == "fuel.ulp" })
        check("Confirm first fill advances within same Site", store.workspace == .site && store.currentFill?.name == "Seabreeze")
        store.setDraft(compartment: 0, litres: 0)
        store.setDraft(compartment: 2, litres: 0)
        store.setDraft(compartment: 4, litres: 0)
        store.commitDelivery()
        check("Final fill returns Active", store.workspace == .active)
        check("Completed SeaLink visit cannot reopen", !store.openSite(0) && store.workspace == .active)
        check("Next-site projection skips completed visit", store.nextIncompleteVisit?.site == "HEMMANT")
        check("Open next skips completed visit", store.openNextIncompleteSite() && store.currentVisit?.site == "HEMMANT")
        store.workspace = .active

        let beforeLoad = store.confirmedLitres[0]
        store.openLoad()
        store.setDraft(compartment: 0, litres: beforeLoad + 1000)
        check("Load draft is additive to returned cargo", store.draftLitres[0] == beforeLoad + 1000)
        check("Draft does not mutate confirmed cargo", store.confirmedLitres[0] == beforeLoad)
        let transactionCountBeforeLoadConfirm = store.cargoLedger.transactions.count
        store.commitLoad()
        check("Load Confirm appends through CargoLedger", store.cargoLedger.transactions.count > transactionCountBeforeLoadConfirm)
        check("Load Confirm derives new confirmed quantity", store.confirmedLitres[0] == beforeLoad + 1000)
        let afterLoad = store.confirmedLitres[0]
        store.openLoad()
        store.setDraft(compartment: 0, litres: afterLoad + 200)
        store.undoDraft()
        check("Undo restores load draft", store.draftLitres[0] == afterLoad)

        store.workspace = .active
        store.beginRest()
        check("Rest state is explicit", store.workspace == .rest)
        check("Rest start is logged", store.eventLog.contains { $0.kind == .restStart && $0.summary.contains("Rest started") })
        store.endRest()
        check("End Rest returns Active", store.workspace == .active)
        check("Rest end is logged", store.eventLog.contains { $0.kind == .restEnd && $0.summary.contains("Rest ended") })

        output.append("---")
        output.append(output.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return output
    }
}
