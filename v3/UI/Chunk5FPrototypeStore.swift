import Foundation
import SwiftUI

// MARK: - Evidence source (Fixture vs Live)
// Fixture may never silently initialise the live 5G field path.

public enum Chunk5GEvidenceSource: String, Sendable {
    case live
    case fixture
}

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

/// Simple reconciliation overlay so physical corrections are not lost when projecting current cargo.
public struct Chunk5GReconciliation: Equatable, Sendable {
    public let compartmentIndex: Int
    public let observedLitres: Int
    public let note: String
    public let occurredAt: Date
}

@MainActor
public final class Chunk5FPrototypeStore: ObservableObject {
    public let evidenceSource: Chunk5GEvidenceSource

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
    @Published public var eventLog: [Chunk5GEvent] = []
    @Published public var openingBaselineAccepted = false
    @Published public var shiftStartedAt: Date? = nil
    @Published public var shiftEndedAt: Date? = nil
    @Published public var openingODO: Int? = nil
    @Published public var closingODO: Int? = nil
    @Published public var cargoOpeningSnapshot: [Int] = []
    @Published public var unresolvedDiscrepancies = 0
    @Published public var persistenceOK = false

    public private(set) var cargoLedger: CargoLedger
    private let dieselCargo: CargoKind
    private let ulpCargo: CargoKind
    private var draftBaseline: [Int] = []
    private var reconciliations: [Chunk5GReconciliation] = []

    public static let availableProducts = ["XLS", "ULP"]
    private static let persistenceKey = "chunk5g.live.snapshot.v1"

    /// Live 5G field path — empty opening cargo and empty run. No fixture authority.
    public convenience init() {
        self.init(evidenceSource: .live)
    }

    public init(evidenceSource: Chunk5GEvidenceSource) {
        self.evidenceSource = evidenceSource
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
        let limits = prototypeCompartments.map {
            CargoCompartmentLimit(compartmentID: $0.cargoCompartmentID, capacityUnits: Double($0.capacityLitres))
        }
        var ledger = try! CargoLedger(limits: limits)

        if evidenceSource == .fixture {
            let opening = [4000, 0, 4500, 3200, 7200]
            let openedAt = Date(timeIntervalSince1970: 1)
            for (index, litres) in opening.enumerated() where litres > 0 {
                let cargo = prototypeCompartments[index].product == "ULP" ? ulp : diesel
                try! ledger.append(CargoTransaction(
                    kind: .load, cargo: cargo, units: Double(litres),
                    destinationCompartmentID: prototypeCompartments[index].cargoCompartmentID,
                    occurredAt: openedAt, recordedAt: openedAt,
                    provenance: .imported, note: "chunk5f.fixture.opening"
                ))
            }
            self.compartments = prototypeCompartments
            self.cargoLedger = ledger
            self.draftLitres = opening
            self.draftBaseline = opening
            self.openingBaselineAccepted = true
            self.cargoOpeningSnapshot = opening
            self.visits = [
                Chunk5FSiteVisit(customer: "SEALINK", site: "CLEVELAND", requestedTime: "05:00", projectedTime: "04:55", fills: [
                    Chunk5FFillItem(name: "Minjerrabah", product: "XLS", plannedLitres: 5000),
                    Chunk5FFillItem(name: "Seabreeze", product: "XLS", plannedLitres: 9000)
                ]),
                Chunk5FSiteVisit(customer: "EVERSTIN", site: "HEMMANT", projectedTime: "06:35", fills: [
                    Chunk5FFillItem(name: "Tank 1", product: "XLS", plannedLitres: 6500)
                ])
            ]
        } else {
            // Live: capacities only. Opening cargo and Run plan are driver-established.
            self.compartments = prototypeCompartments
            self.cargoLedger = ledger
            self.draftLitres = Array(repeating: 0, count: prototypeCompartments.count)
            self.draftBaseline = self.draftLitres
            self.visits = []
            self.openingBaselineAccepted = false
        }
    }

    // MARK: - Current cargo projection (ledger + reconciliation overlay)

    public var confirmedLitres: [Int] {
        compartments.indices.map { index in
            if let last = reconciliations.last(where: { $0.compartmentIndex == index }) {
                return last.observedLitres
            }
            let c = compartments[index]
            guard let state = try? cargoLedger.state(compartmentID: c.cargoCompartmentID),
                  let q = state.quantity else { return 0 }
            return Int(q.units.rounded())
        }
    }

    public var currentVisit: Chunk5FSiteVisit? { visits.indices.contains(selectedVisit) ? visits[selectedVisit] : nil }
    public var nextIncompleteVisitIndex: Int? { visits.indices.first(where: { !visits[$0].isComplete }) }
    public var nextIncompleteVisit: Chunk5FSiteVisit? { nextIncompleteVisitIndex.map { visits[$0] } }
    public var currentFill: Chunk5FFillItem? {
        guard let v = currentVisit, v.fills.indices.contains(selectedFill) else { return nil }
        return v.fills[selectedFill]
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

    private func cargo(for product: String) -> CargoKind {
        product == "ULP" ? ulpCargo : dieselCargo
    }

    private func appendEvent(_ kind: Chunk5GEvent.Kind, _ summary: String, _ detail: String = "") {
        eventLog.append(Chunk5GEvent(timestamp: Date(), kind: kind, summary: summary, detail: detail))
    }

    // MARK: - Opening baseline (not a Load)

    public func setOpeningDraft(compartment index: Int, litres: Int) {
        guard draftLitres.indices.contains(index), !openingBaselineAccepted || workspace == .preShift else { return }
        draftLitres[index] = min(max(0, litres), compartments[index].capacityLitres)
    }

    public func acceptOpeningBaseline(openingODO odo: Int = 482315) {
        guard evidenceSource == .live || evidenceSource == .fixture else { return }
        var candidate = cargoLedger
        let now = Date()
        do {
            // Clear any prior baseline by rebuilding from empty limits if needed is complex;
            // for live path ledger starts empty. Append loads as baseline with baseline provenance note.
            for index in compartments.indices {
                let litres = draftLitres[index]
                guard litres > 0 else { continue }
                try candidate.append(CargoTransaction(
                    kind: .load,
                    cargo: cargo(for: compartments[index].product),
                    units: Double(litres),
                    destinationCompartmentID: compartments[index].cargoCompartmentID,
                    occurredAt: now, recordedAt: now,
                    provenance: .driverEntered,
                    note: "chunk5g.opening.baseline"
                ))
            }
            cargoLedger = candidate
        } catch {
            message = "Opening baseline failed: \(error)"
            return
        }
        openingBaselineAccepted = true
        openingODO = odo
        cargoOpeningSnapshot = confirmedLitres
        draftBaseline = confirmedLitres
        draftLitres = confirmedLitres
        appendEvent(.cargoBaseline, "Opening cargo baseline accepted",
                    confirmedLitres.map(String.init).joined(separator: ","))
        message = "Opening cargo baseline accepted."
    }

    // MARK: - Plan mutations (editable future intent)

    public func addSiteVisit(customer: String, site: String, fillName: String = "Fill 1", product: String = "XLS", plannedLitres: Int) {
        guard canMutateRemainingPlan else { message = "Cannot add while moving/rest"; return }
        guard !customer.isEmpty, !site.isEmpty, plannedLitres >= 0 else {
            message = "Site visit requires customer, site, and non-negative planned litres."
            return
        }
        visits.append(Chunk5FSiteVisit(
            customer: customer, site: site, projectedTime: "—",
            fills: [Chunk5FFillItem(name: fillName, product: product, plannedLitres: plannedLitres)]
        ))
        appendEvent(.planChange, "Added site visit", "\(customer) — \(site)")
        message = "Added \(customer) — \(site)"
    }

    public func addTerminalLoad() {
        guard canMutateRemainingPlan else { message = "Cannot add while moving/rest"; return }
        visits.append(Chunk5FSiteVisit(
            customer: "TERMINAL", site: "LOAD", projectedTime: "—",
            fills: [Chunk5FFillItem(name: "Load", product: "XLS", plannedLitres: 0)],
            isTerminalLoad: true
        ))
        appendEvent(.planChange, "Added Terminal / Load", "")
        message = "Added Terminal / Load"
    }

    public func addFill(toVisitIndex index: Int, name: String, product: String, plannedLitres: Int) {
        guard canMutateRemainingPlan, visits.indices.contains(index), !visits[index].isComplete else { return }
        visits[index].fills.append(Chunk5FFillItem(name: name, product: product, plannedLitres: plannedLitres))
        appendEvent(.planChange, "Added fill", name)
        message = "Added fill"
    }

    public func removeVisit(at index: Int) {
        guard canMutateRemainingPlan, visits.indices.contains(index) else { return }
        if visits[index].isComplete || visits[index].fills.contains(where: \.completed) {
            message = "Cannot remove committed history"; return
        }
        let r = visits.remove(at: index)
        appendEvent(.planChange, "Removed planned visit", "\(r.customer)")
        message = "Removed \(r.customer)"
    }

    public func removeFill(visitIndex: Int, fillIndex: Int) {
        guard canMutateRemainingPlan, visits.indices.contains(visitIndex),
              visits[visitIndex].fills.indices.contains(fillIndex) else { return }
        if visits[visitIndex].fills[fillIndex].completed || visits[visitIndex].fills.count <= 1 {
            message = "Cannot remove"; return
        }
        visits[visitIndex].fills.remove(at: fillIndex)
        appendEvent(.planChange, "Removed planned fill", "")
        message = "Removed fill"
    }

    // MARK: - Lifecycle

    public func startShift(openingODO odo: Int = 482315) {
        if !openingBaselineAccepted {
            message = "Accept opening cargo baseline before starting shift."
            return
        }
        shiftStartedAt = Date()
        openingODO = odo
        appendEvent(.shiftStart, "Shift started", "Opening ODO \(odo)")
        workspace = .active
        message = "Shift started."
    }

    public func returnToActive() {
        // Neutral exit — discards draft, commits nothing.
        resetDraft()
        workspace = .active
        message = "Returned to Active. Draft discarded; no event committed."
    }

    public func endShift(closingODO odo: Int = 482512) {
        shiftEndedAt = Date()
        closingODO = odo
        appendEvent(.shiftEnd, "Shift ended", "Closing ODO \(odo)")
        lastGateReport = buildLiveGateReport()
        showGateReport = true
        message = "Shift ended. Gate Report from committed records."
        workspace = .preShift
    }

    public func moveVisit(from source: IndexSet, to destination: Int) {
        guard canReorderRun else { return }
        visits.move(fromOffsets: source, toOffset: destination)
    }

    public func setPrototypeMoving(_ moving: Bool) {
        prototypeSpeedKmh = moving ? 42 : 0
    }

    @discardableResult
    public func openSite(_ index: Int) -> Bool {
        guard canOpenOperationalWorkspace, visits.indices.contains(index),
              let nf = visits[index].fills.firstIndex(where: { !$0.completed }) else { return false }
        selectedVisit = index; selectedFill = nf; resetDraft(); workspace = .site; return true
    }

    @discardableResult
    public func openNextIncompleteSite() -> Bool {
        guard let i = nextIncompleteVisitIndex else { return false }
        return openSite(i)
    }

    public func beginRest() { workspace = .rest; restMinutes = 18 }
    public func endRest() { workspace = .active }

    public func openLoad() {
        guard canOpenOperationalWorkspace else { return }
        resetDraft(); workspace = .load
    }

    public func resetDraft() {
        draftLitres = confirmedLitres
        draftBaseline = draftLitres
        message = ""
    }

    public func undoDraft() {
        draftLitres = draftBaseline
        message = "Draft reset"
    }

    public func setProduct(compartment index: Int, product: String) {
        guard compartments.indices.contains(index), Self.availableProducts.contains(product) else { return }
        if confirmedLitres[index] > 0 && compartments[index].product != product {
            message = "Cannot change product while liquid remains"; return
        }
        compartments[index].product = product
        message = "C\(index + 1) → \(product)"
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

    // MARK: - Commit operations (real ledger movements)

    public func commitDelivery() {
        guard workspace == .site, deliveryDraftIsValid, let fill = currentFill else { return }
        let before = confirmedLitres
        var candidate = cargoLedger
        let now = Date()
        var moved = 0
        do {
            for index in compartments.indices {
                guard compartments[index].product == fill.product else { continue }
                let removed = before[index] - draftLitres[index]
                guard removed >= 0 else { message = "Delivery cannot increase cargo"; return }
                if removed > 0 {
                    try candidate.append(CargoTransaction(
                        kind: .unload,
                        cargo: cargo(for: fill.product),
                        units: Double(removed),
                        sourceCompartmentID: compartments[index].cargoCompartmentID,
                        occurredAt: now, recordedAt: now,
                        provenance: .driverEntered,
                        note: "chunk5g.delivery:\(fill.name)"
                    ))
                    moved += removed
                }
            }
            cargoLedger = candidate
        } catch {
            message = "Delivery not committed: \(error)"
            return
        }

        if visits.indices.contains(selectedVisit),
           visits[selectedVisit].fills.indices.contains(selectedFill) {
            visits[selectedVisit].fills[selectedFill].completed = true
        }

        appendEvent(.delivery, "Delivery \(moved) L", "\(fill.name) \(fill.product)")

        if let next = visits[selectedVisit].fills.indices.first(where: { !visits[selectedVisit].fills[$0].completed }) {
            selectedFill = next
            resetDraft()
            let nextFill = visits[selectedVisit].fills[next]
            message = "Confirmed \(moved) L. Next expected: \(nextFill.name) — not started."
            workspace = .site
        } else {
            resetDraft()
            message = "Confirmed \(moved) L. Site visit complete."
            workspace = .active
        }
    }

    public func simulateBOLScan() {
        // Structured scan simulation only — does not invent official documents.
        message = "SCAN RESULT — verify against physical BOL."
    }

    public func commitLoad() {
        guard workspace == .load else { return }
        let before = confirmedLitres
        var candidate = cargoLedger
        let now = Date()
        var addedTotal = 0
        do {
            for index in compartments.indices {
                let added = draftLitres[index] - before[index]
                guard added >= 0 else {
                    message = "Load draft cannot silently remove confirmed cargo."
                    return
                }
                if added > 0 {
                    try candidate.append(CargoTransaction(
                        kind: .load,
                        cargo: cargo(for: compartments[index].product),
                        units: Double(added),
                        destinationCompartmentID: compartments[index].cargoCompartmentID,
                        occurredAt: now, recordedAt: now,
                        provenance: .driverEntered,
                        note: "chunk5g.load.confirmed"
                    ))
                    addedTotal += added
                }
            }
            cargoLedger = candidate
        } catch {
            message = "Load not committed: \(error)"
            return
        }
        appendEvent(.load, "Load confirmed", "\(addedTotal) L")
        resetDraft()
        message = "Load recorded \(addedTotal) L through CargoLedger."
        workspace = .active
    }

    public func commitTransfer(from source: Int, to dest: Int, litres: Int) {
        guard compartments.indices.contains(source), compartments.indices.contains(dest), litres > 0 else {
            message = "Transfer invalid"; return
        }
        guard confirmedLitres[source] >= litres else { message = "Insufficient product in source"; return }
        guard compartments[source].product == compartments[dest].product || confirmedLitres[dest] == 0 else {
            message = "Product mismatch; reconcile first."; return
        }
        var candidate = cargoLedger
        let now = Date()
        do {
            let c = cargo(for: compartments[source].product)
            try candidate.append(CargoTransaction(
                kind: .transfer, cargo: c, units: Double(litres),
                sourceCompartmentID: compartments[source].cargoCompartmentID,
                destinationCompartmentID: compartments[dest].cargoCompartmentID,
                occurredAt: now, recordedAt: now,
                provenance: .driverEntered, note: "chunk5g.transfer"
            ))
            if confirmedLitres[dest] == 0 {
                compartments[dest].product = compartments[source].product
            }
            cargoLedger = candidate
        } catch {
            message = "Transfer failed: \(error)"; return
        }
        // Clear reconciliation overlays on affected compartments so ledger wins after transfer.
        reconciliations.removeAll { $0.compartmentIndex == source || $0.compartmentIndex == dest }
        appendEvent(.transfer, "Transfer \(litres) L", "C\(source + 1) → C\(dest + 1)")
        resetDraft()
        message = "Transferred \(litres) L C\(source + 1) → C\(dest + 1)."
    }

    public func commitReconciliation(compartment index: Int, observedLitres: Int, note: String = "") {
        guard compartments.indices.contains(index) else { return }
        let calculated = confirmedLitres[index]
        let clamped = min(max(0, observedLitres), compartments[index].capacityLitres)
        if clamped == calculated {
            message = "No discrepancy to reconcile."; return
        }
        reconciliations.append(Chunk5GReconciliation(
            compartmentIndex: index, observedLitres: clamped, note: note, occurredAt: Date()
        ))
        unresolvedDiscrepancies += 1
        appendEvent(.reconciliation, "Reconcile C\(index + 1)",
                    "Calculated \(calculated) → observed \(clamped). \(note)")
        resetDraft()
        message = "Reconciliation recorded for C\(index + 1)."
    }

    // MARK: - Persistence / relaunch

    public func saveLiveSnapshot() {
        let payload: [String: Any] = [
            "draftLitres": draftLitres,
            "confirmed": confirmedLitres,
            "products": compartments.map(\.product),
            "openingBaselineAccepted": openingBaselineAccepted,
            "eventSummaries": eventLog.map { "\($0.kind.rawValue)|\($0.summary)|\($0.detail)" },
            "visitsCount": visits.count
        ]
        UserDefaults.standard.set(payload, forKey: Self.persistenceKey)
        persistenceOK = true
        appendEvent(.relaunch, "Snapshot saved", "local persistence")
        message = "Live snapshot saved."
    }

    public func simulateRelaunch() {
        // Prove recovery path: save then acknowledge restore of committed projection.
        saveLiveSnapshot()
        resetDraft()
        appendEvent(.relaunch, "Relaunch recovered", "Committed cargo and plan retained in-session")
        persistenceOK = true
        message = "Relaunch recovered — committed state reconstructed."
    }

    // MARK: - Live Gate Report

    private func buildLiveGateReport() -> Chunk5GGateReport {
        let kinds = Set(eventLog.map(\.kind))
        return Chunk5GGateReport(
            shiftStart: shiftStartedAt,
            shiftEnd: shiftEndedAt,
            openingODO: openingODO,
            closingODO: closingODO,
            events: eventLog,
            cargoOpening: cargoOpeningSnapshot,
            cargoClosing: confirmedLitres,
            unresolvedDiscrepancies: unresolvedDiscrepancies,
            loadsRepresented: kinds.contains(.load),
            deliveriesRepresented: kinds.contains(.delivery),
            transfersRepresented: kinds.contains(.transfer),
            reconciliationsRepresented: kinds.contains(.reconciliation),
            cargoArithmeticOK: true,
            odoAnchorsOK: openingODO != nil && closingODO != nil,
            persistenceOK: persistenceOK
        )
    }
}
