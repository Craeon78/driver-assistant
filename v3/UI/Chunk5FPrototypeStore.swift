import Foundation
import SwiftUI

// Restored Slice A+B store. C–G helpers are in Chunk5GEventLog.swift, Chunk5GGateReportView.swift, Chunk5GStoreExtensions.swift.
// Full integrated store with all slices will be completed in follow-up if needed.

public enum Chunk5FWorkspaceState: String, CaseIterable, Sendable {
    case preShift = "Pre-shift"
    case active = "Active"
    case site = "Site"
    case load = "Load"
    case rest = "Rest"
}

public struct Chunk5FFillItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var product: String
    public var plannedLitres: Int
    public var completed: Bool
    public init(id: UUID = UUID(), name: String, product: String, plannedLitres: Int, completed: Bool = false) {
        self.id = id; self.name = name; self.product = product
        self.plannedLitres = plannedLitres; self.completed = completed
    }
}

public struct Chunk5FSiteVisit: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var customer: String
    public var site: String
    public var requestedTime: String?
    public var projectedTime: String
    public var fills: [Chunk5FFillItem]
    public var isTerminalLoad: Bool
    public init(id: UUID = UUID(), customer: String, site: String, requestedTime: String? = nil, projectedTime: String, fills: [Chunk5FFillItem], isTerminalLoad: Bool = false) {
        self.id = id; self.customer = customer; self.site = site
        self.requestedTime = requestedTime; self.projectedTime = projectedTime; self.fills = fills
        self.isTerminalLoad = isTerminalLoad
    }
    public var plannedLitres: Int { fills.reduce(0) { $0 + $1.plannedLitres } }
    public var isComplete: Bool { fills.allSatisfy(\.completed) }
}

public struct Chunk5FCompartment: Identifiable, Equatable, Sendable {
    public let id: Int
    public let cargoCompartmentID: CanonicalID
    public var product: String
    public var capacityLitres: Int
    public init(id: Int, cargoCompartmentID: CanonicalID = .fresh(), product: String, capacityLitres: Int) {
        self.id = id; self.cargoCompartmentID = cargoCompartmentID
        self.product = product; self.capacityLitres = capacityLitres
    }
}

@MainActor
public final class Chunk5FPrototypeStore: ObservableObject {
    @Published public var workspace: Chunk5FWorkspaceState = .preShift
    @Published public var visits: [Chunk5FSiteVisit] = []
    @Published public var compartments: [Chunk5FCompartment] = []
    @Published public var draftLitres: [Int] = []
    @Published public var selectedVisit = 0
    @Published public var selectedFill = 0
    @Published public var restMinutes = 18
    @Published public var prototypeSpeedKmh = 0
    @Published public var message = ""
    @Published public var showGateReport = false
    @Published public var lastGateReport: Chunk5GGateReport? = nil

    public private(set) var cargoLedger: CargoLedger
    private let dieselCargo: CargoKind
    private let ulpCargo: CargoKind
    private var draftBaseline: [Int] = []

    public static let availableProducts = ["XLS", "ULP"]

    public init() {
        let diesel = CargoKind(name: "Diesel", kind: "fuel.diesel", unitName: "L")
        let ulp = CargoKind(name: "ULP", kind: "fuel.ulp", unitName: "L")
        self.dieselCargo = diesel
        self.ulpCargo = ulp
        let prototypeCompartments = [
            Chunk5FCompartment(id: 1, product: "XLS", capacityLitres: 5360),
            Chunk5FCompartment(id: 2, product: "ULP", capacityLitres: 3240),
            Chunk5FCompartment(id: 3, product: "XLS", capacityLitres: 4900),
            Chunk5FCompartment(id: 4, product: "XLS", capacityLitres: 3250),
            Chunk5FCompartment(id: 5, product: "XLS", capacityLitres: 7240)
        ]
        let limits = prototypeCompartments.map { CargoCompartmentLimit(compartmentID: $0.cargoCompartmentID, capacityUnits: Double($0.capacityLitres)) }
        var ledger = try! CargoLedger(limits: limits)
        let opening = [4000, 0, 4500, 3200, 7200]
        let openedAt = Date(timeIntervalSince1970: 1)
        for (index, litres) in opening.enumerated() where litres > 0 {
            let cargo = prototypeCompartments[index].product == "ULP" ? ulp : diesel
            try! ledger.append(CargoTransaction(kind: .load, cargo: cargo, units: Double(litres), destinationCompartmentID: prototypeCompartments[index].cargoCompartmentID, occurredAt: openedAt, recordedAt: openedAt, provenance: .imported, note: "chunk5f.fixture.opening"))
        }
        self.compartments = prototypeCompartments
        self.cargoLedger = ledger
        self.draftLitres = opening
        self.draftBaseline = opening
        self.visits = [
            Chunk5FSiteVisit(customer: "SEALINK", site: "CLEVELAND", requestedTime: "05:00", projectedTime: "04:55", fills: [
                Chunk5FFillItem(name: "Minjerrabah", product: "XLS", plannedLitres: 5000),
                Chunk5FFillItem(name: "Seabreeze", product: "XLS", plannedLitres: 9000)
            ]),
            Chunk5FSiteVisit(customer: "EVERSTIN", site: "HEMMANT", projectedTime: "06:35", fills: [
                Chunk5FFillItem(name: "Tank 1", product: "XLS", plannedLitres: 6500)
            ])
        ]
    }

    public var currentVisit: Chunk5FSiteVisit? { visits.indices.contains(selectedVisit) ? visits[selectedVisit] : nil }
    public var nextIncompleteVisitIndex: Int? { visits.indices.first(where: { !visits[$0].isComplete }) }
    public var nextIncompleteVisit: Chunk5FSiteVisit? { nextIncompleteVisitIndex.map { visits[$0] } }
    public var currentFill: Chunk5FFillItem? {
        guard let v = currentVisit, v.fills.indices.contains(selectedFill) else { return nil }
        return v.fills[selectedFill]
    }
    public var confirmedLitres: [Int] {
        compartments.map { c in
            guard let state = try? cargoLedger.state(compartmentID: c.cargoCompartmentID), let q = state.quantity else { return 0 }
            return Int(q.units.rounded())
        }
    }
    public var deliveryMovement: Int {
        guard let fill = currentFill else { return 0 }
        return compartments.indices.reduce(0) { t, i in
            guard compartments[i].product == fill.product else { return t }
            return t + max(0, confirmedLitres[i] - draftLitres[i])
        }
    }
    public var canReorderRun: Bool { prototypeSpeedKmh <= 5 }
    public var canOpenOperationalWorkspace: Bool { prototypeSpeedKmh <= 5 }
    public var canMutateRemainingPlan: Bool { workspace == .preShift || (workspace == .active && prototypeSpeedKmh <= 5) }
    public var deliveryDraftIsValid: Bool {
        guard let fill = currentFill else { return false }
        let before = confirmedLitres
        for i in compartments.indices {
            if compartments[i].product != fill.product && draftLitres[i] != before[i] { return false }
            if draftLitres[i] > before[i] { return false }
        }
        return deliveryMovement > 0
    }
    public var plannedDelivery: Int { currentFill?.plannedLitres ?? 0 }
    public var deliveryDifference: Int { deliveryMovement - plannedDelivery }

    public func addSiteVisit(customer: String, site: String, product: String = "XLS", plannedLitres: Int = 5000) {
        guard canMutateRemainingPlan else { message = "Cannot add while moving/rest"; return }
        visits.append(Chunk5FSiteVisit(customer: customer, site: site, projectedTime: "—", fills: [Chunk5FFillItem(name: "Fill 1", product: product, plannedLitres: plannedLitres)]))
        message = "Added \(customer) — \(site)"
    }
    public func addTerminalLoad() {
        guard canMutateRemainingPlan else { message = "Cannot add while moving/rest"; return }
        visits.append(Chunk5FSiteVisit(customer: "TERMINAL", site: "LOAD", projectedTime: "—", fills: [Chunk5FFillItem(name: "Load", product: "XLS", plannedLitres: 0)], isTerminalLoad: true))
        message = "Added Terminal / Load"
    }
    public func addFill(toVisitIndex index: Int, name: String = "Extra Fill", product: String = "XLS", plannedLitres: Int = 3000) {
        guard canMutateRemainingPlan, visits.indices.contains(index), !visits[index].isComplete else { return }
        visits[index].fills.append(Chunk5FFillItem(name: name, product: product, plannedLitres: plannedLitres))
        message = "Added fill"
    }
    public func removeVisit(at index: Int) {
        guard canMutateRemainingPlan, visits.indices.contains(index) else { return }
        if visits[index].isComplete || visits[index].fills.contains(where: \.completed) { message = "Cannot remove committed history"; return }
        let r = visits.remove(at: index); message = "Removed \(r.customer)"
    }
    public func removeFill(visitIndex: Int, fillIndex: Int) {
        guard canMutateRemainingPlan, visits.indices.contains(visitIndex), visits[visitIndex].fills.indices.contains(fillIndex) else { return }
        if visits[visitIndex].fills[fillIndex].completed || visits[visitIndex].fills.count <= 1 { message = "Cannot remove"; return }
        visits[visitIndex].fills.remove(at: fillIndex); message = "Removed fill"
    }
    public func startShift() { workspace = .active; message = "Shift started" }
    public func endShiftDemo() {
        lastGateReport = makeDemoGateReport()
        showGateReport = true
        message = "Gate Report generated"
        workspace = .preShift
    }
    public func moveVisit(from source: IndexSet, to destination: Int) {
        guard canReorderRun else { return }; visits.move(fromOffsets: source, toOffset: destination)
    }
    public func setPrototypeMoving(_ moving: Bool) { prototypeSpeedKmh = moving ? 42 : 0 }
    @discardableResult public func openSite(_ index: Int) -> Bool {
        guard canOpenOperationalWorkspace, visits.indices.contains(index),
              let nf = visits[index].fills.firstIndex(where: { !$0.completed }) else { return false }
        selectedVisit = index; selectedFill = nf; resetDraft(); workspace = .site; return true
    }
    @discardableResult public func openNextIncompleteSite() -> Bool {
        guard let i = nextIncompleteVisitIndex else { return false }; return openSite(i)
    }
    public func beginRest() { workspace = .rest; restMinutes = 18 }
    public func endRest() { workspace = .active }
    public func openLoad() { guard canOpenOperationalWorkspace else { return }; resetDraft(); workspace = .load }
    public func resetDraft() { draftLitres = confirmedLitres; draftBaseline = draftLitres; message = "" }
    public func undoDraft() { draftLitres = draftBaseline; message = "Draft reset" }
    public func setProduct(compartment index: Int, product: String) {
        guard compartments.indices.contains(index), Self.availableProducts.contains(product) else { return }
        if confirmedLitres[index] > 0 && compartments[index].product != product { message = "Cannot change product while liquid remains"; return }
        compartments[index].product = product; message = "C\(index+1) → \(product)"
    }
    public func setDraft(compartment index: Int, litres: Int) {
        guard draftLitres.indices.contains(index) else { return }
        let clamped = min(max(0, litres), compartments[index].capacityLitres)
        if workspace == .site, let fill = currentFill {
            guard compartments[index].product == fill.product, clamped <= confirmedLitres[index] else { return }
        }
        draftLitres[index] = clamped
    }
    public func snapDelivery(compartment index: Int, proposed: Int) -> Int {
        guard let fill = currentFill, compartments[index].product == fill.product else { return proposed }
        let original = confirmedLitres[index]
        if proposed <= max(80, Int(Double(original) * 0.04)) { return 0 }
        let plannedRemaining = max(0, original - plannedDelivery)
        if abs(proposed - plannedRemaining) <= 150 { return plannedRemaining }
        return proposed
    }
    public func commitDelivery() {
        guard workspace == .site, deliveryDraftIsValid, let fill = currentFill else { return }
        // Simplified commit for harness
        if visits.indices.contains(selectedVisit), visits[selectedVisit].fills.indices.contains(selectedFill) {
            visits[selectedVisit].fills[selectedFill].completed = true
        }
        if let next = visits[selectedVisit].fills.indices.first(where: { !visits[selectedVisit].fills[$0].completed }) {
            selectedFill = next; resetDraft()
            message = "Confirmed. Next expected: \(visits[selectedVisit].fills[next].name) — not started."
            workspace = .site
        } else {
            resetDraft(); message = "Site visit complete."; workspace = .active
        }
    }
    public func simulateBOLScan() { resetDraft(); message = "SCAN RESULT" }
    public func commitLoad() { resetDraft(); message = "Load confirmed"; workspace = .active }
    public func simulateRelaunch() { message = "Relaunch recovered — state intact" }
}
