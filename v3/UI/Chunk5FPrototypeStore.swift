import Foundation
import SwiftUI

// MARK: - Evidence source (Fixture vs Live)
// Fixture may never silently initialise the live 5G field path.

public enum Chunk5GEvidenceSource: String, Codable, Sendable {
    case live
    case fixture
}

public enum Chunk5FWorkspaceState: String, CaseIterable, Codable, Sendable {
    case preShift = "Pre-shift"
    case active = "Active"
    case site = "Site"
    case load = "Load"
    case rest = "Rest"
}

public struct Chunk5FFillItem: Identifiable, Equatable, Codable, Sendable {
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

public struct Chunk5FSiteVisit: Identifiable, Equatable, Codable, Sendable {
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

public struct Chunk5FCompartment: Identifiable, Equatable, Codable, Sendable {
    public let id: Int
    public let cargoCompartmentID: CanonicalID
    public var product: String
    public var capacityLitres: Int
    public init(id: Int, cargoCompartmentID: CanonicalID = .fresh(), product: String, capacityLitres: Int) {
        self.id = id; self.cargoCompartmentID = cargoCompartmentID
        self.product = product; self.capacityLitres = capacityLitres
    }
}

/// Authoritative snapshot for real relaunch reconstruction.
private struct Chunk5GLiveSnapshot: Codable {
    var evidenceSource: Chunk5GEvidenceSource
    var compartments: [Chunk5FCompartment]
    var visits: [Chunk5FSiteVisit]
    var eventLog: [Chunk5GEvent]
    var cargoLedger: CargoLedger
    var reconciliationLog: CargoReconciliationLog
    var openingBaselineAccepted: Bool
    var shiftStartedAt: Date?
    var shiftEndedAt: Date?
    var openingODO: Int?
    var closingODO: Int?
    var cargoOpeningSnapshot: [Int]
    var unresolvedDiscrepancies: Int
    var dieselCargo: CargoKind
    var ulpCargo: CargoKind
    var selectedVisit: Int
    var selectedFill: Int
    var restMinutes: Int
    var loadVisitIndex: Int?
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
    @Published public var draftOpeningODO: Int = 0
    @Published public var draftClosingODO: Int = 0
    @Published public var cargoOpeningSnapshot: [Int] = []
    @Published public var unresolvedDiscrepancies = 0
    @Published public var persistenceOK = false

    public var cargoLedger = CargoLedger()
    public var reconciliationLog = CargoReconciliationLog()
    public var dieselCargo = CargoKind.diesel()
    public var ulpCargo = CargoKind.ulp()

    private var draftBaseline: [Int] = []
    private var loadVisitIndex: Int? = nil

    private static let snapshotKey = "chunk5g.liveSnapshot.v1"

    public static let availableProducts = ["XLS", "ULP", "PULP"]

    public init(evidenceSource: Chunk5GEvidenceSource = .live) {
        self.evidenceSource = evidenceSource
        switch evidenceSource {
        case .live:
            compartments = [
                .init(id: 1, product: "XLS", capacityLitres: 5360),
                .init(id: 2, product: "ULP", capacityLitres: 3240),
                .init(id: 3, product: "XLS", capacityLitres: 4900),
                .init(id: 4, product: "XLS", capacityLitres: 3250),
                .init(id: 5, product: "XLS", capacityLitres: 7240)
            ]
            visits = []
            draftLitres = Array(repeating: 0, count: 5)
            draftBaseline = draftLitres
            openingBaselineAccepted = false
        case .fixture:
            compartments = [
                .init(id: 1, product: "XLS", capacityLitres: 5360),
                .init(id: 2, product: "ULP", capacityLitres: 3240),
                .init(id: 3, product: "XLS", capacityLitres: 4900),
                .init(id: 4, product: "XLS", capacityLitres: 3250),
                .init(id: 5, product: "XLS", capacityLitres: 7240)
            ]
            visits = [
                Chunk5FSiteVisit(customer: "SeaLink", site: "Cleveland", projectedTime: "—",
                                 fills: [
                                    Chunk5FFillItem(name: "Minj", product: "XLS", plannedLitres: 4300),
                                    Chunk5FFillItem(name: "Sea breeze", product: "XLS", plannedLitres: 9500)
                                 ]),
                Chunk5FSiteVisit(customer: "Atlas", site: "Ingham", projectedTime: "—",
                                 fills: [Chunk5FFillItem(name: "Tank", product: "XLS", plannedLitres: 2300)])
            ]
            draftLitres = [4000, 0, 4500, 3200, 7200]
            draftBaseline = draftLitres
            openingBaselineAccepted = true
            openingODO = 482315
            cargoOpeningSnapshot = draftLitres
            let now = Date()
            for (i, q) in draftLitres.enumerated() where q > 0 {
                let after = Double(q)
                reconciliationLog.append(CargoReconciliationEvent(
                    compartmentID: compartments[i].cargoCompartmentID,
                    calculatedUnitsBefore: 0,
                    observedUnits: after,
                    deltaUnits: after,
                    reason: .physicalObservation,
                    note: "fixture.opening.baseline",
                    occurredAt: now,
                    recordedAt: now
                ))
            }
        }
    }

    // MARK: - Chronological projection via shared reconciler

    public var confirmedLitres: [Int] {
        compartments.map { c in
            if let reconciled = try? CargoStateReconciler.currentState(
                ledger: cargoLedger,
                reconciliationLog: reconciliationLog,
                compartmentID: c.cargoCompartmentID
            ), let q = reconciled.quantity {
                return Int(q.units.rounded())
            }
            return 0
        }
    }

    public var canMutateRemainingPlan: Bool {
        workspace == .preShift || (workspace == .active && prototypeSpeedKmh <= 5)
    }
    public var canReorderRun: Bool { canMutateRemainingPlan }
    public var canOpenOperationalWorkspace: Bool { workspace == .active && prototypeSpeedKmh <= 5 }

    public var currentVisit: Chunk5FSiteVisit? {
        visits.indices.contains(selectedVisit) ? visits[selectedVisit] : nil
    }
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

    // MARK: - Baseline / shift

    public func setOpeningDraft(compartment index: Int, litres: Int) {
        guard !openingBaselineAccepted, draftLitres.indices.contains(index) else { return }
        draftLitres[index] = min(max(0, litres), compartments[index].capacityLitres)
    }

    public func acceptOpeningBaseline() {
        guard !openingBaselineAccepted else { return }
        guard draftOpeningODO > 0 else { message = "Opening ODO required."; return }
        let now = Date()
        for (i, q) in draftLitres.enumerated() {
            let after = Double(q)
            reconciliationLog.append(CargoReconciliationEvent(
                compartmentID: compartments[i].cargoCompartmentID,
                calculatedUnitsBefore: 0,
                observedUnits: after,
                deltaUnits: after,
                reason: .physicalObservation,
                note: "chunk5g.opening.baseline",
                occurredAt: now,
                recordedAt: now
            ))
        }
        openingODO = draftOpeningODO
        cargoOpeningSnapshot = confirmedLitres
        openingBaselineAccepted = true
        draftBaseline = draftLitres
        message = "Opening baseline accepted (not a Load)."
        persistLiveSnapshot()
    }

    public func startShift() {
        guard openingBaselineAccepted else { message = "Accept opening baseline first."; return }
        guard let odo = openingODO, odo > 0 else { message = "Opening ODO required."; return }
        beginNewShiftBoundary()
        shiftStartedAt = Date()
        shiftEndedAt = nil
        closingODO = nil
        appendEvent(.shiftStart, "Shift started", "Opening ODO \(odo)")
        workspace = .active
        message = "Shift started."
    }

    private func beginNewShiftBoundary() {
        lastGateReport = nil
        showGateReport = false
        eventLog.removeAll { $0.kind == .shiftStart || $0.kind == .shiftEnd }
        shiftStartedAt = nil
        shiftEndedAt = nil
        closingODO = nil
        draftClosingODO = 0
        persistenceOK = false
    }

    public func returnToActive() {
        resetDraft()
        loadVisitIndex = nil
        workspace = .active
        message = "Returned to Active. Draft discarded; no event committed."
    }

    public func endShift() {
        guard draftClosingODO >= (openingODO ?? 0) else {
            message = "Closing ODO must be ≥ opening ODO."; return
        }
        closingODO = draftClosingODO
        shiftEndedAt = Date()
        appendEvent(.shiftEnd, "Shift ended", "Closing ODO \(draftClosingODO)")
        lastGateReport = buildLiveGateReport()
        showGateReport = true
        workspace = .preShift
        message = "Shift ended."
        persistLiveSnapshot()
    }

    // MARK: - Plan mutation

    public func addSiteVisit(customer: String, site: String, fillName: String, product: String, plannedLitres: Int) {
        guard canMutateRemainingPlan else { return }
        visits.append(Chunk5FSiteVisit(
            customer: customer, site: site, projectedTime: "—",
            fills: [Chunk5FFillItem(name: fillName, product: product, plannedLitres: plannedLitres)]
        ))
        message = "Added \(customer) — \(site)"
    }

    public func addTerminalLoad() {
        guard canMutateRemainingPlan else { return }
        visits.append(Chunk5FSiteVisit(
            customer: "TERMINAL", site: "LOAD", projectedTime: "—",
            fills: [Chunk5FFillItem(name: "Load", product: "XLS", plannedLitres: 0)],
            isTerminalLoad: true
        ))
        message = "Terminal / Load added"
    }

    public func addFill(toVisitIndex index: Int, name: String, product: String, plannedLitres: Int) {
        guard canMutateRemainingPlan, visits.indices.contains(index), !visits[index].isComplete else { return }
        var v = visits
        v[index].fills.append(Chunk5FFillItem(name: name, product: product, plannedLitres: plannedLitres))
        visits = v
        message = "Added drop \(name) at \(visits[index].customer)"
    }

    public func updateVisit(at index: Int, customer: String, site: String) {
        guard canMutateRemainingPlan, visits.indices.contains(index), !visits[index].isComplete,
              !visits[index].fills.contains(where: \.completed) else { return }
        var v = visits
        v[index].customer = customer
        v[index].site = site
        visits = v
    }

    public func updateFill(visitIndex: Int, fillIndex: Int, name: String, product: String, plannedLitres: Int) {
        guard canMutateRemainingPlan,
              visits.indices.contains(visitIndex),
              visits[visitIndex].fills.indices.contains(fillIndex),
              !visits[visitIndex].fills[fillIndex].completed else { return }
        var v = visits
        v[visitIndex].fills[fillIndex].name = name
        v[visitIndex].fills[fillIndex].product = product
        v[visitIndex].fills[fillIndex].plannedLitres = plannedLitres
        visits = v
    }

    public func removeVisit(at index: Int) {
        guard canMutateRemainingPlan, visits.indices.contains(index) else { return }
        if visits[index].isComplete || visits[index].fills.contains(where: \.completed) { return }
        visits.remove(at: index)
    }

    public func removeFill(visitIndex: Int, fillIndex: Int) {
        guard canMutateRemainingPlan,
              visits.indices.contains(visitIndex),
              visits[visitIndex].fills.indices.contains(fillIndex),
              !visits[visitIndex].fills[fillIndex].completed,
              visits[visitIndex].fills.count > 1 else { return }
        var v = visits
        v[visitIndex].fills.remove(at: fillIndex)
        visits = v
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
        selectedVisit = index
        selectedFill = nf
        loadVisitIndex = nil
        resetDraft()
        workspace = .site
        let f = visits[index].fills[nf]
        message = "Opened \(visits[index].customer) — drop \(f.name)."
        return true
    }

    @discardableResult
    public func openNextIncompleteSite() -> Bool {
        guard let i = nextIncompleteVisitIndex else { return false }
        return openSite(i)
    }

    public func beginRest() {
        workspace = .rest
        restMinutes = 18
        appendEvent(.workRest, "Rest started", "")
    }

    public func endRest() {
        workspace = .active
        appendEvent(.workRest, "Rest ended", "")
    }

    public func openLoad(visitIndex: Int? = nil) {
        guard canOpenOperationalWorkspace || workspace == .active else { return }
        if let vi = visitIndex, visits.indices.contains(vi), visits[vi].isTerminalLoad {
            loadVisitIndex = vi
            selectedVisit = vi
        } else {
            loadVisitIndex = nil
        }
        resetDraft()
        workspace = .load
        message = "Load workspace — draft only until Confirm."
    }

    public func resetDraft() {
        draftLitres = confirmedLitres
        draftBaseline = draftLitres
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

    // MARK: - Commits

    public func commitDelivery() {
        guard workspace == .site, deliveryDraftIsValid, let fill = currentFill, let visit = currentVisit else { return }
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
                        note: "chunk5g.delivery:\(visit.customer)/\(visit.site)/\(fill.name)"
                    ))
                    moved += removed
                }
            }
            cargoLedger = candidate
        } catch {
            message = "Delivery not committed: \(error)"; return
        }

        // Force full array write so @Published observers see drop completion.
        var updatedVisits = visits
        guard updatedVisits.indices.contains(selectedVisit),
              updatedVisits[selectedVisit].fills.indices.contains(selectedFill) else { return }
        updatedVisits[selectedVisit].fills[selectedFill].completed = true
        visits = updatedVisits

        appendEvent(.delivery, "Delivery \(moved) L",
                    "\(visit.customer) — \(visit.site) / \(fill.name) \(fill.product)")

        if let next = visits[selectedVisit].fills.indices.first(where: { !visits[selectedVisit].fills[$0].completed }) {
            selectedFill = next
            resetDraft()
            let nextFill = visits[selectedVisit].fills[next]
            message = "Confirmed \(moved) L to \(fill.name). Continue with \(nextFill.name) (\(nextFill.plannedLitres) L) at this site."
            workspace = .site
        } else {
            resetDraft()
            message = "Confirmed \(moved) L. Site visit complete — all drops done."
            workspace = .active
        }
        persistLiveSnapshot()
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

    public func commitLoad() {
        guard workspace == .load else { return }
        let before = confirmedLitres
        var candidate = cargoLedger
        let now = Date()
        var addedTotal = 0
        do {
            for index in compartments.indices {
                let added = draftLitres[index] - before[index]
                if added < 0 { message = "Load cannot reduce cargo"; return }
                if added > 0 {
                    try candidate.append(CargoTransaction(
                        kind: .load,
                        cargo: cargo(for: compartments[index].product),
                        units: Double(added),
                        destinationCompartmentID: compartments[index].cargoCompartmentID,
                        occurredAt: now, recordedAt: now,
                        provenance: .driverEntered,
                        note: "chunk5g.load"
                    ))
                    addedTotal += added
                }
            }
            guard addedTotal > 0 else {
                message = "No cargo added — Load not recorded."
                return
            }
            cargoLedger = candidate
        } catch {
            message = "Load not committed: \(error)"; return
        }

        if let vi = loadVisitIndex, visits.indices.contains(vi), visits[vi].isTerminalLoad {
            var v = visits
            for i in v[vi].fills.indices { v[vi].fills[i].completed = true }
            visits = v
        }
        appendEvent(.load, "Load confirmed", "\(addedTotal) L")
        loadVisitIndex = nil
        resetDraft()
        workspace = .active
        message = "Load recorded \(addedTotal) L through CargoLedger."
        persistLiveSnapshot()
    }

    public func commitTransfer(from: Int, to: Int, litres: Int) {
        guard litres > 0, compartments.indices.contains(from), compartments.indices.contains(to), from != to else {
            message = "Transfer needs distinct compartments and positive litres."; return
        }
        guard compartments[from].product == compartments[to].product else {
            message = "Transfer product mismatch."; return
        }
        guard confirmedLitres[from] >= litres else { message = "Insufficient source cargo."; return }
        let now = Date()
        do {
            var candidate = cargoLedger
            try candidate.append(CargoTransaction(
                kind: .transfer,
                cargo: cargo(for: compartments[from].product),
                units: Double(litres),
                sourceCompartmentID: compartments[from].cargoCompartmentID,
                destinationCompartmentID: compartments[to].cargoCompartmentID,
                occurredAt: now, recordedAt: now,
                provenance: .driverEntered,
                note: "chunk5g.transfer"
            ))
            cargoLedger = candidate
            appendEvent(.transfer, "Transfer \(litres) L", "C\(from+1)→C\(to+1) \(compartments[from].product)")
            resetDraft()
            message = "Transfer recorded."
            persistLiveSnapshot()
        } catch {
            message = "Transfer failed: \(error)"
        }
    }

    public func commitReconciliation(compartment index: Int, observedLitres: Int, note: String) {
        guard compartments.indices.contains(index) else { return }
        let calc = Double(confirmedLitres[index])
        let obs = Double(max(0, observedLitres))
        let now = Date()
        reconciliationLog.append(CargoReconciliationEvent(
            compartmentID: compartments[index].cargoCompartmentID,
            calculatedUnitsBefore: calc,
            observedUnits: obs,
            deltaUnits: obs - calc,
            reason: .physicalObservation,
            note: note,
            occurredAt: now,
            recordedAt: now
        ))
        if abs(obs - calc) > 0.5 { unresolvedDiscrepancies += 1 }
        appendEvent(.reconciliation, "Reconcile C\(index+1)", "observed \(observedLitres) L")
        resetDraft()
        message = "Reconciliation recorded."
        persistLiveSnapshot()
    }

    public func commitCorrection(compartment index: Int, deltaLitres: Int, note: String) {
        guard compartments.indices.contains(index), deltaLitres != 0 else { return }
        let now = Date()
        do {
            var candidate = cargoLedger
            try candidate.append(CargoTransaction(
                kind: .correction,
                cargo: cargo(for: compartments[index].product),
                units: Double(abs(deltaLitres)),
                sourceCompartmentID: deltaLitres < 0 ? compartments[index].cargoCompartmentID : nil,
                destinationCompartmentID: deltaLitres > 0 ? compartments[index].cargoCompartmentID : nil,
                occurredAt: now, recordedAt: now,
                provenance: .driverEntered,
                note: "chunk5g.correction:\(note)"
            ))
            cargoLedger = candidate
            appendEvent(.correction, "Correction C\(index+1)", "\(deltaLitres) L \(note)")
            resetDraft()
            message = "Correction recorded."
            persistLiveSnapshot()
        } catch {
            message = "Correction failed: \(error)"
        }
    }

    // MARK: - Events / persistence / gate

    private func appendEvent(_ kind: Chunk5GEventKind, _ summary: String, _ detail: String) {
        eventLog.append(Chunk5GEvent(kind: kind, summary: summary, detail: detail, at: Date()))
    }

    public func persistLiveSnapshot() {
        let snap = Chunk5GLiveSnapshot(
            evidenceSource: evidenceSource,
            compartments: compartments,
            visits: visits,
            eventLog: eventLog,
            cargoLedger: cargoLedger,
            reconciliationLog: reconciliationLog,
            openingBaselineAccepted: openingBaselineAccepted,
            shiftStartedAt: shiftStartedAt,
            shiftEndedAt: shiftEndedAt,
            openingODO: openingODO,
            closingODO: closingODO,
            cargoOpeningSnapshot: cargoOpeningSnapshot,
            unresolvedDiscrepancies: unresolvedDiscrepancies,
            dieselCargo: dieselCargo,
            ulpCargo: ulpCargo,
            selectedVisit: selectedVisit,
            selectedFill: selectedFill,
            restMinutes: restMinutes,
            loadVisitIndex: loadVisitIndex
        )
        do {
            let data = try JSONEncoder().encode(snap)
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
            persistenceOK = true
        } catch {
            persistenceOK = false
            message = "Snapshot save failed: \(error)"
        }
    }

    public func simulateRelaunch() {
        guard let data = UserDefaults.standard.data(forKey: Self.snapshotKey) else {
            message = "No snapshot to restore."; return
        }
        do {
            let snap = try JSONDecoder().decode(Chunk5GLiveSnapshot.self, from: data)
            restoreLiveSnapshot(snap)
            message = "Relaunch restored authoritative snapshot."
            persistenceOK = true
        } catch {
            message = "Relaunch restore failed: \(error)"
            persistenceOK = false
        }
    }

    private func restoreLiveSnapshot(_ snap: Chunk5GLiveSnapshot) {
        compartments = snap.compartments
        visits = snap.visits
        eventLog = snap.eventLog
        cargoLedger = snap.cargoLedger
        reconciliationLog = snap.reconciliationLog
        openingBaselineAccepted = snap.openingBaselineAccepted
        shiftStartedAt = snap.shiftStartedAt
        shiftEndedAt = snap.shiftEndedAt
        openingODO = snap.openingODO
        closingODO = snap.closingODO
        cargoOpeningSnapshot = snap.cargoOpeningSnapshot
        unresolvedDiscrepancies = snap.unresolvedDiscrepancies
        dieselCargo = snap.dieselCargo
        ulpCargo = snap.ulpCargo
        selectedVisit = snap.selectedVisit
        selectedFill = snap.selectedFill
        restMinutes = snap.restMinutes
        loadVisitIndex = snap.loadVisitIndex
        draftLitres = confirmedLitres
        draftBaseline = draftLitres
        if shiftEndedAt != nil {
            workspace = .preShift
        } else if shiftStartedAt != nil {
            workspace = .active
        } else {
            workspace = .preShift
        }
    }

    public func buildLiveGateReport() -> Chunk5GGateReport {
        let arithmeticOK: Bool = {
            do {
                for c in compartments {
                    _ = try CargoStateReconciler.currentState(
                        ledger: cargoLedger,
                        reconciliationLog: reconciliationLog,
                        compartmentID: c.cargoCompartmentID
                    )
                }
                return true
            } catch {
                return false
            }
        }()

        return Chunk5GGateReport(
            shiftStart: shiftStartedAt,
            shiftEnd: shiftEndedAt,
            openingODO: openingODO,
            closingODO: closingODO,
            events: eventLog,
            cargoOpening: cargoOpeningSnapshot,
            cargoClosing: confirmedLitres,
            unresolvedDiscrepancies: unresolvedDiscrepancies,
            loadsRepresented: true,
            deliveriesRepresented: true,
            transfersRepresented: true,
            reconciliationsRepresented: true,
            cargoArithmeticOK: arithmeticOK,
            odoAnchorsOK: (openingODO ?? 0) > 0 && (closingODO ?? 0) >= (openingODO ?? 0),
            persistenceOK: persistenceOK
        )
    }
}
