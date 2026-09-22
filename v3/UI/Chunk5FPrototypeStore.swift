import Foundation
import SwiftUI

// MARK: - Evidence source (Fixture vs Live)
// Fixture may never silently initialise the live 5G field path.

public enum Chunk5GEvidenceSource: String, Codable, Sendable {
    case live
    case fixture
}

public enum Chunk5GShiftLifecycle: String, Codable, Sendable {
    case fresh, active, completedLocked, recoveryLocked
}

public enum Chunk5FWorkspaceState: String, CaseIterable, Codable, Sendable {
    case preShift = "Pre-shift"
    case active = "Active"
    case site = "Site"
    case load = "Load"
    case rest = "Rest"
    case otherWork = "Other Work"
}

public enum Chunk5FRunItemKind: String, Codable, Sendable, CaseIterable, Hashable {
    case siteVisit, terminalLoad, plannedRest, plannedOtherWork
}

public struct Chunk5FRunItem: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let kind: Chunk5FRunItemKind
    public let siteVisitID: UUID?
    public var title: String
    public var requestedTime: String?
    public var executionEventID: UUID?
    public var satisfactionEventID: UUID?
    public var legacyExecutionLock: Bool
    public var legacySatisfied: Bool
    /// `nil` is accepted only while decoding the immediately preceding repair
    /// schema; normalized/persisted state always writes an explicit set.
    public var legacyCompletedFillIDs: [UUID]?
    public var hasCommittedExecution: Bool { executionEventID != nil || legacyExecutionLock }
    public var isSatisfied: Bool { satisfactionEventID != nil || legacySatisfied }
    public init(id: UUID = UUID(), kind: Chunk5FRunItemKind, siteVisitID: UUID? = nil, title: String, requestedTime: String? = nil, executionEventID: UUID? = nil, satisfactionEventID: UUID? = nil, legacyExecutionLock: Bool = false, legacySatisfied: Bool = false, legacyCompletedFillIDs: [UUID]? = []) {
        self.id = id; self.kind = kind; self.siteVisitID = siteVisitID; self.title = title
        self.requestedTime = requestedTime; self.executionEventID = executionEventID; self.satisfactionEventID = satisfactionEventID
        self.legacyExecutionLock = legacyExecutionLock; self.legacySatisfied = legacySatisfied
        self.legacyCompletedFillIDs = legacyCompletedFillIDs
    }
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
    var workspace: Chunk5FWorkspaceState
    var runItems: [Chunk5FRunItem]?
    var authoritativeFingerprint: String
}

/// Exact decoder for active shifts written by the pre-PR #36 v2 harness.
/// Migration adds only v3 storage metadata; it does not manufacture operational history.
struct Chunk5GLegacyV2Snapshot: Codable {
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
    private let persistenceDefaults: UserDefaults

    @Published public var workspace: Chunk5FWorkspaceState = .preShift
    @Published public var visits: [Chunk5FSiteVisit] = []
    @Published public var runItems: [Chunk5FRunItem] = []
    @Published public var compartments: [Chunk5FCompartment] = []
    @Published public var draftLitres: [Int] = []
    @Published public var selectedVisit = 0
    @Published public var selectedFill = 0
    @Published public var restMinutes = 18
    @Published public var prototypeSpeedKmh = 0
    @Published public private(set) var simulatedDrivingRunning = false
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
    @Published public var persistenceStatus: Chunk5GCheckStatus = .notTested
    @Published public private(set) var shiftLifecycle: Chunk5GShiftLifecycle = .fresh
    public var completedShiftLocked: Bool { shiftLifecycle == .completedLocked || shiftLifecycle == .recoveryLocked }
    public var hasArchivedGateReport: Bool { lastGateReport != nil }
    public var isResting: Bool { workspace == .rest }
    public var correctableCargoEvents: [Chunk5GEvent] {
        let corrected = Set(eventLog.compactMap { $0.inputCorrection?.originalEventID })
        return eventLog.filter { ($0.kind == .load || $0.kind == .delivery) && $0.relatedOperationID != nil && ($0.committedLitres ?? 0) > 0 && !corrected.contains($0.id) }
    }
    private var mutationAllowed: Bool { shiftLifecycle == .fresh || shiftLifecycle == .active }

    public func presentArchivedGateReport() {
        guard lastGateReport != nil else { return }
        showGateReport = true
    }

    public private(set) var cargoLedger: CargoLedger
    public private(set) var reconciliationLog: CargoReconciliationLog
    private var dieselCargo: CargoKind
    private var ulpCargo: CargoKind
    private var draftBaseline: [Int] = []
    private var loadVisitIndex: Int? = nil
    var loadVisitIndexForTesting: Int? { loadVisitIndex }
    private var activeRunItemID: UUID? = nil
    private var persistedFingerprint: String? = nil
    var varianceFailureForTesting = false

    public static let availableProducts = ["XLS", "ULP"]
    private static let persistenceKey = "chunk5g.live.snapshot.v3"
    private static let legacyV2PersistenceKey = "chunk5g.live.snapshot.v2"
    private static let completedPersistenceKey = "chunk5g.completed.previous.snapshot.v3"

    public convenience init() {
        self.init(evidenceSource: .live, persistenceDefaults: .standard)
        restorePersistedLiveSnapshotOnLaunch()
    }

    public convenience init(evidenceSource: Chunk5GEvidenceSource) {
        self.init(evidenceSource: evidenceSource, persistenceDefaults: .standard)
    }

    /// Isolated recovery surface for deterministic harnesses; production uses standard defaults.
    convenience init(recoveringFrom persistenceDefaults: UserDefaults) {
        self.init(evidenceSource: .live, persistenceDefaults: persistenceDefaults)
        restorePersistedLiveSnapshotOnLaunch()
    }

    init(evidenceSource: Chunk5GEvidenceSource, persistenceDefaults: UserDefaults) {
        self.evidenceSource = evidenceSource
        self.persistenceDefaults = persistenceDefaults
        let diesel = CargoKind(name: "Diesel", kind: "fuel.diesel", unitName: "L")
        let ulp = CargoKind(name: "ULP", kind: "fuel.ulp", unitName: "L")
        self.dieselCargo = diesel
        self.ulpCargo = ulp
        self.reconciliationLog = try! CargoReconciliationLog()

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
            self.openingODO = 482315
            self.draftOpeningODO = 482315
            self.visits = [
                Chunk5FSiteVisit(customer: "SEALINK", site: "CLEVELAND", requestedTime: "05:00", projectedTime: "04:55", fills: [
                    Chunk5FFillItem(name: "Minjerrabah", product: "XLS", plannedLitres: 5000),
                    Chunk5FFillItem(name: "Seabreeze", product: "XLS", plannedLitres: 9000)
                ]),
                Chunk5FSiteVisit(customer: "EVERSTIN", site: "HEMMANT", projectedTime: "06:35", fills: [
                    Chunk5FFillItem(name: "Tank 1", product: "XLS", plannedLitres: 6500)
                ])
            ]
            self.runItems = self.visits.map { Chunk5FRunItem(kind: .siteVisit, siteVisitID: $0.id, title: "\($0.customer) — \($0.site)", requestedTime: $0.requestedTime) }
        } else {
            self.compartments = prototypeCompartments
            self.cargoLedger = ledger
            self.draftLitres = Array(repeating: 0, count: prototypeCompartments.count)
            self.draftBaseline = self.draftLitres
            self.visits = []
            self.runItems = []
            self.openingBaselineAccepted = false
            self.draftOpeningODO = 0
            self.draftClosingODO = 0
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

    public var currentVisit: Chunk5FSiteVisit? { visits.indices.contains(selectedVisit) ? visits[selectedVisit] : nil }
    public var nextUnexecutedRunItem: Chunk5FRunItem? { runItems.first(where: { !$0.isSatisfied }) }
    public var nextIncompleteVisitIndex: Int? {
        for item in runItems where item.kind == .siteVisit && !item.isSatisfied {
            if let id = item.siteVisitID, let index = visits.firstIndex(where: { $0.id == id && !$0.isComplete }) { return index }
        }
        return visits.indices.first(where: { !visits[$0].isTerminalLoad && !visits[$0].isComplete })
    }
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
    public var canReorderRun: Bool { mutationAllowed && prototypeSpeedKmh <= 5 }
    public var canOpenOperationalWorkspace: Bool { mutationAllowed && prototypeSpeedKmh <= 5 }
    public var canMutateRemainingPlan: Bool { mutationAllowed && (workspace == .preShift || (workspace == .active && prototypeSpeedKmh <= 5)) }
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

    @discardableResult
    private func appendEvent(_ kind: Chunk5GEvent.Kind, _ summary: String, _ detail: String = "", relatedOperationID: String? = nil, relatedRunItemID: UUID? = nil, committedLitres: Int? = nil, transactionVariance: Chunk5GTransactionVariance? = nil, physicalCheck: Chunk5GPhysicalCheck? = nil, inputCorrection: Chunk5GInputCorrection? = nil, deliveryOutcome: Chunk5GDeliveryOutcome? = nil) -> UUID {
        let event = Chunk5GEvent(timestamp: Date(), kind: kind, summary: summary, detail: detail, relatedOperationID: relatedOperationID, relatedRunItemID: relatedRunItemID, committedLitres: committedLitres, transactionVariance: transactionVariance, physicalCheck: physicalCheck, inputCorrection: inputCorrection, deliveryOutcome: deliveryOutcome)
        eventLog.append(event); return event.id
    }

    private func nextOperationID(_ kind: String) -> String {
        "chunk5g.\(kind).op.\(UUID().uuidString)"
    }

    private func persistPlanMutation() {
        if evidenceSource == .live { persistLiveSnapshot() }
    }

    // MARK: - Opening baseline (reconciliation boundary — not a Load)

    public func setOpeningDraft(compartment index: Int, litres: Int) {
        guard mutationAllowed, draftLitres.indices.contains(index), !openingBaselineAccepted else { return }
        draftLitres[index] = min(max(0, litres), compartments[index].capacityLitres)
    }

    public func acceptOpeningBaseline() {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard !openingBaselineAccepted else { message = "Baseline already accepted."; return }
        guard draftOpeningODO > 0 else {
            message = "Enter opening ODO before accepting baseline."; return
        }
        var log = try! CargoReconciliationLog()
        let now = Date()
        do {
            for index in compartments.indices {
                let litres = draftLitres[index]
                guard litres > 0 else { continue }
                try log.append(CargoReconciliationEvent(
                    compartmentID: compartments[index].cargoCompartmentID,
                    cargo: cargo(for: compartments[index].product),
                    calculatedUnitsBefore: 0,
                    confirmedPhysicalUnitsAfter: Double(litres),
                    occurredAt: now, recordedAt: now,
                    provenance: .driverEntered,
                    note: "chunk5g.opening.baseline"
                ))
            }
            reconciliationLog = log
        } catch {
            message = "Opening baseline failed: \(error)"; return
        }
        openingBaselineAccepted = true
        openingODO = draftOpeningODO
        cargoOpeningSnapshot = confirmedLitres
        draftBaseline = confirmedLitres
        draftLitres = confirmedLitres
        appendEvent(.cargoBaseline, "Opening cargo baseline accepted",
                    "ODO \(draftOpeningODO); " + confirmedLitres.map(String.init).joined(separator: ","))
        message = "Opening cargo baseline accepted (not a Load)."
        persistLiveSnapshot()
    }

    // MARK: - Shift lifecycle

    public func startShift() {
        guard mutationAllowed else { message = "Previous shift is locked until recovery succeeds."; return }
        guard !completedShiftLocked else { message = "Previous shift is locked until its archive is valid."; return }
        guard openingBaselineAccepted else { message = "Accept opening baseline first."; return }
        guard let odo = openingODO, odo > 0 else { message = "Opening ODO required."; return }
        lastGateReport = nil; showGateReport = false; shiftEndedAt = nil; closingODO = nil; draftClosingODO = 0
        shiftLifecycle = .active
        shiftStartedAt = Date()
        appendEvent(.shiftStart, "Shift started", "Opening ODO \(odo)")
        workspace = .active
        message = "Shift started."
        persistLiveSnapshot()
    }

    public func returnToActive() {
        guard mutationAllowed else { return }
        resetDraft(); loadVisitIndex = nil; activeRunItemID = nil; workspace = .active
        message = "Returned to Active. Draft discarded; no event committed."
    }

    public func endShift() {
        guard draftClosingODO >= (openingODO ?? 0) else { message = "Closing ODO must be ≥ opening ODO."; return }
        closingODO = draftClosingODO; shiftEndedAt = Date()
        appendEvent(.shiftEnd, "Shift ended", "Closing ODO \(draftClosingODO)")
        shiftLifecycle = .completedLocked
        workspace = .preShift
        message = "Finalising completed shift..."
        persistLiveSnapshot()

        guard evidenceSource == .live, let data = persistenceDefaults.data(forKey: Self.persistenceKey) else {
            persistenceStatus = .fail
            lastGateReport = nil; showGateReport = false; shiftLifecycle = .recoveryLocked
            message = "Shift ended, but no durable snapshot was available. Completed truth is locked for recovery."
            return
        }
        do {
            let snapshot = try JSONDecoder().decode(Chunk5GLiveSnapshot.self, from: data)
            try archiveCompletedSnapshot(data, snapshot: snapshot)
            persistenceStatus = .pass
            lastGateReport = try gateReport(fromValidated: snapshot, persistenceStatus: .pass)
            showGateReport = true
            persistenceDefaults.removeObject(forKey: Self.persistenceKey)
            resetForNewShift(preservingCompletedReport: true)
            message = "Shift ended and archived."
        } catch {
            persistenceStatus = .fail
            lastGateReport = nil; showGateReport = false; shiftLifecycle = .recoveryLocked
            message = "Shift ended, but archive validation failed. Previous shift is locked for recovery: \(error)"
        }
    }

    private func resetForNewShift(preservingCompletedReport: Bool = false) {
        let limits = compartments.map {
            CargoCompartmentLimit(compartmentID: $0.cargoCompartmentID, capacityUnits: Double($0.capacityLitres))
        }
        cargoLedger = try! CargoLedger(limits: limits)
        reconciliationLog = try! CargoReconciliationLog()
        visits = []; runItems = []; eventLog = []; openingBaselineAccepted = false
        shiftStartedAt = nil; shiftEndedAt = nil; openingODO = nil; closingODO = nil
        draftOpeningODO = 0; draftClosingODO = 0; cargoOpeningSnapshot = []
        unresolvedDiscrepancies = 0; selectedVisit = 0; selectedFill = 0; loadVisitIndex = nil; activeRunItemID = nil
        workspace = .preShift; persistedFingerprint = nil; shiftLifecycle = .fresh
        if !preservingCompletedReport { persistenceStatus = .notTested }
        draftLitres = Array(repeating: 0, count: compartments.count); draftBaseline = draftLitres
    }

    // MARK: - Plan mutation

    public func addSiteVisit(customer: String, site: String, fillName: String, product: String, plannedLitres: Int) {
        guard canMutateRemainingPlan else { return }
        let visit = Chunk5FSiteVisit(customer: customer, site: site, projectedTime: "—", fills: [Chunk5FFillItem(name: fillName, product: product, plannedLitres: plannedLitres)])
        visits.append(visit)
        runItems.append(Chunk5FRunItem(kind: .siteVisit, siteVisitID: visit.id, title: "\(customer) — \(site)"))
        appendEvent(.planChange, "Added site visit", "\(customer) — \(site)"); persistPlanMutation()
    }
    public func addTerminalLoad() {
        guard canMutateRemainingPlan else { return }
        runItems.append(Chunk5FRunItem(kind: .terminalLoad, title: "Terminal / Load"))
        appendEvent(.planChange, "Added Terminal / Load"); persistPlanMutation()
    }
    public func addPlannedRest() { guard canMutateRemainingPlan else { return }; runItems.append(Chunk5FRunItem(kind: .plannedRest, title: "Rest")); appendEvent(.planChange, "Added planned Rest"); persistPlanMutation() }
    public func addPlannedOtherWork(title: String = "Other Work") { guard canMutateRemainingPlan else { return }; let clean = title.trimmingCharacters(in: .whitespacesAndNewlines); runItems.append(Chunk5FRunItem(kind: .plannedOtherWork, title: clean.isEmpty ? "Other Work" : clean)); appendEvent(.planChange, "Added planned Other Work", clean); persistPlanMutation() }
    public func addFill(toVisitIndex index: Int, name: String, product: String, plannedLitres: Int) {
        guard canMutateRemainingPlan, visits.indices.contains(index), !visits[index].fills.contains(where: \.completed) else { return }
        visits[index].fills.append(Chunk5FFillItem(name: name, product: product, plannedLitres: plannedLitres))
        appendEvent(.planChange, "Added fill", "\(visits[index].customer)/\(name)"); persistPlanMutation()
    }
    public func updateVisit(at index: Int, customer: String, site: String) { guard canMutateRemainingPlan, visits.indices.contains(index), !visits[index].fills.contains(where: \.completed) else { return }; visits[index].customer = customer; visits[index].site = site; if let ri = runItems.firstIndex(where: { $0.siteVisitID == visits[index].id }) { runItems[ri].title = "\(customer) — \(site)" }; appendEvent(.planChange, "Updated site visit", "\(customer) — \(site)"); persistPlanMutation() }
    public func updateFill(visitIndex: Int, fillIndex: Int, name: String, product: String, plannedLitres: Int) { guard canMutateRemainingPlan, visits.indices.contains(visitIndex), visits[visitIndex].fills.indices.contains(fillIndex), !visits[visitIndex].fills.contains(where: \.completed) else { return }; visits[visitIndex].fills[fillIndex].name = name; visits[visitIndex].fills[fillIndex].product = product; visits[visitIndex].fills[fillIndex].plannedLitres = plannedLitres; appendEvent(.planChange, "Updated fill", "\(name) — \(plannedLitres) L \(product)"); persistPlanMutation() }
    public func removeVisit(at index: Int) { guard canMutateRemainingPlan, visits.indices.contains(index), !visits[index].fills.contains(where: \.completed) else { return }; let removed=visits.remove(at:index); runItems.removeAll { $0.siteVisitID == removed.id }; appendEvent(.planChange, "Removed site visit", "\(removed.customer) — \(removed.site)"); persistPlanMutation() }
    public func removeFill(visitIndex: Int, fillIndex: Int) { guard canMutateRemainingPlan, visits.indices.contains(visitIndex), visits[visitIndex].fills.indices.contains(fillIndex), !visits[visitIndex].fills.contains(where: \.completed), visits[visitIndex].fills.count > 1 else { return }; let removed=visits[visitIndex].fills.remove(at:fillIndex); appendEvent(.planChange, "Removed fill", removed.name); persistPlanMutation() }
    public func moveVisit(from source: IndexSet, to destination: Int) { guard canReorderRun, source.allSatisfy({ visits.indices.contains($0) && !visits[$0].fills.contains(where: \.completed) }) else { return }; visits.move(fromOffsets: source, toOffset: destination); appendEvent(.planChange, "Reordered remaining run"); persistPlanMutation() }
    public func moveRunItem(from source: IndexSet, to destination: Int) {
        guard canReorderRun, !source.isEmpty, (0...runItems.count).contains(destination),
              source.allSatisfy({ runItems.indices.contains($0) && !runItems[$0].hasCommittedExecution }) else { return }

        // SwiftUI reports source/destination in full-list coordinates. Project
        // that move to the mutable subsequence, then write it back only through
        // mutable slots so every committed or partial row stays anchored.
        var projected = runItems
        projected.move(fromOffsets: source, toOffset: destination)
        let reorderedMutableItems = projected.filter { !$0.hasCommittedExecution }
        let mutableSlots = runItems.indices.filter { !runItems[$0].hasCommittedExecution }
        guard reorderedMutableItems.count == mutableSlots.count else { return }

        var candidate = runItems
        for (slot, item) in zip(mutableSlots, reorderedMutableItems) { candidate[slot] = item }
        guard candidate != runItems else { return }
        runItems = candidate
        appendEvent(.planChange, "Reordered remaining run")
        persistPlanMutation()
    }
    public func updateRunItem(at index: Int, title: String, requestedTime: String? = nil) { guard canMutateRemainingPlan, runItems.indices.contains(index), !runItems[index].hasCommittedExecution else { return }; let clean = title.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { return }; runItems[index].title = clean; runItems[index].requestedTime = requestedTime?.trimmingCharacters(in: .whitespacesAndNewlines); appendEvent(.planChange, "Updated planned \(runItems[index].kind.rawValue)", clean); persistPlanMutation() }
    public func removeRunItem(at index: Int) { guard canMutateRemainingPlan, runItems.indices.contains(index), !runItems[index].hasCommittedExecution else { return }; let item = runItems.remove(at: index); if let visitID = item.siteVisitID, let vi = visits.firstIndex(where: { $0.id == visitID && !$0.fills.contains(where: \.completed) }) { visits.remove(at: vi) }; appendEvent(.planChange, "Removed planned \(item.kind.rawValue)", item.title); persistPlanMutation() }
    public func visitIndex(for item: Chunk5FRunItem) -> Int? { item.siteVisitID.flatMap { id in visits.firstIndex(where: { $0.id == id }) } }
    public func openRunItem(at index: Int) { guard runItems.indices.contains(index), !runItems[index].isSatisfied else { return }; let item = runItems[index]; activeRunItemID = item.id; switch item.kind { case .siteVisit: if let vi = visitIndex(for: item) { _ = openSite(vi) }; case .terminalLoad: openLoad(); case .plannedRest: beginRest(); case .plannedOtherWork: beginOtherWork(title: item.title) } }
    public func setPrototypeMoving(_ moving: Bool) {
        simulatedDrivingRunning = moving
        prototypeSpeedKmh = moving ? 42 : 0
    }
    public func startSimulatedDriving() { setPrototypeMoving(true) }
    public func stopSimulatedDriving() { setPrototypeMoving(false) }

    @discardableResult public func openSite(_ index: Int) -> Bool { guard canOpenOperationalWorkspace, visits.indices.contains(index), !visits[index].isTerminalLoad, let nf = visits[index].fills.firstIndex(where: { !$0.completed }) else { return false }; selectedVisit = index; selectedFill = nf; loadVisitIndex = nil; resetDraft(); workspace = .site; return true }
    @discardableResult public func openNextIncompleteSite() -> Bool { guard let i = nextIncompleteVisitIndex else { return false }; return openSite(i) }
    public func beginRest() {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard workspace == .active else { message = "Rest can start only while working."; return }
        let runID = activeRunItemID.flatMap { id in runItems.first(where: { $0.id == id && $0.kind == .plannedRest })?.id }
        let eventID = appendEvent(.restStart, "Rest started", relatedRunItemID: runID)
        linkActiveRunItem(kind: .plannedRest, to: eventID)
        workspace = .rest; restMinutes = 18; persistLiveSnapshot() }
    public func endRest() {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard workspace == .rest else { message = "No active Rest to end."; return }
        workspace = .active; appendEvent(.restEnd, "Rest ended"); activeRunItemID = nil; persistLiveSnapshot() }
    public func beginOtherWork(title _: String = "Other Work") { guard mutationAllowed, workspace == .active else { return }; let runID = activeRunItemID.flatMap { id in runItems.first(where: { $0.id == id && $0.kind == .plannedOtherWork })?.id }; let eventID = appendEvent(.workRest, "Work started", relatedRunItemID: runID); linkActiveRunItem(kind: .plannedOtherWork, to: eventID); workspace = .otherWork; persistLiveSnapshot() }
    public func endOtherWork() { guard mutationAllowed, workspace == .otherWork else { return }; workspace = .active; appendEvent(.workRest, "Work context ended"); activeRunItemID = nil; persistLiveSnapshot() }
    private func linkActiveRunItem(kind: Chunk5FRunItemKind, to eventID: UUID) { if let id = activeRunItemID, let index = runItems.firstIndex(where: { $0.id == id && $0.kind == kind }) { if runItems[index].executionEventID == nil { runItems[index].executionEventID = eventID }; runItems[index].satisfactionEventID = eventID } }
    private func linkSiteRunItem(visitID: UUID, to eventID: UUID) { if let index = runItems.firstIndex(where: { $0.kind == .siteVisit && $0.siteVisitID == visitID }) { if runItems[index].executionEventID == nil { runItems[index].executionEventID = eventID }; if visits.first(where: { $0.id == visitID })?.isComplete == true { runItems[index].satisfactionEventID = eventID } } }
    func finishCurrentSiteRunContext() { activeRunItemID = nil }
    public func openLoad(visitIndex: Int? = nil) {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard canOpenOperationalWorkspace || workspace == .active else { return }; loadVisitIndex = visitIndex; if let vi = visitIndex { selectedVisit = vi }; resetDraft(); workspace = .load }
    public func resetDraft() {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        draftLitres = confirmedLitres; draftBaseline = draftLitres }
    public func undoDraft() {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        draftLitres = draftBaseline; message = "Draft reset" }
    public func setProduct(compartment index: Int, product: String) {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard compartments.indices.contains(index), Self.availableProducts.contains(product) else { return }; if confirmedLitres[index] > 0 && compartments[index].product != product { message = "Cannot change product while liquid remains"; return }; compartments[index].product = product }
    public func setDraft(compartment index: Int, litres: Int) {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard draftLitres.indices.contains(index) else { return }; let clamped = min(max(0, litres), compartments[index].capacityLitres); if workspace == .site, let fill = currentFill { guard compartments[index].product == fill.product, clamped <= confirmedLitres[index] else { return } }; draftLitres[index] = clamped }
    public func snapDelivery(compartment index: Int, proposed: Int) -> Int {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return proposed }
        guard let fill = currentFill, compartments[index].product == fill.product else { return proposed }; let original = confirmedLitres[index]; if proposed <= max(80, Int(Double(original) * 0.04)) { return 0 }; let plannedRemaining = max(0, original - plannedDelivery); return abs(proposed - plannedRemaining) <= 150 ? plannedRemaining : proposed }

    // MARK: - Cargo commits

    public func commitLoad(actualLitres: Int? = nil, postTransactionEmpty: Bool? = nil, varianceNote: String = "") {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        let originalLedger = cargoLedger
        let originalReconciliationLog = reconciliationLog
        let originalEvents = eventLog
        let originalVisits = visits
        let originalRunItems = runItems
        let originalUnresolved = unresolvedDiscrepancies
        let originalWorkspace = workspace
        let originalLoadVisitIndex = loadVisitIndex
        let originalActiveRunItemID = activeRunItemID
        let before = confirmedLitres
        let now = Date()
        let operationID = nextOperationID("load")
        var candidate = cargoLedger
        var added = 0
        do {
            for i in compartments.indices where draftLitres[i] > before[i] {
                let delta = draftLitres[i] - before[i]
                try candidate.append(CargoTransaction(kind: .load, cargo: cargo(for: compartments[i].product), units: Double(delta), destinationCompartmentID: compartments[i].cargoCompartmentID, occurredAt: now, recordedAt: now, provenance: .driverEntered, note: operationID), reconciliationLog: reconciliationLog)
                added += delta
            }
            guard added > 0 else { message = "Load not committed: no added cargo."; return }
            cargoLedger = candidate
            if let vi = loadVisitIndex, visits.indices.contains(vi) {
                for fi in visits[vi].fills.indices { visits[vi].fills[fi].completed = true }
            }
            let terminalRunID = activeRunItemID.flatMap { id in runItems.first(where: { $0.id == id && $0.kind == .terminalLoad })?.id }
            let loadEventID = appendEvent(.load, "Load confirmed", "\(added) L", relatedOperationID: operationID, relatedRunItemID: terminalRunID, committedLitres: added)
            linkActiveRunItem(kind: .terminalLoad, to: loadEventID)
            try recordTransactionVarianceIfRequired(calculatedLitres: added, actualLitres: actualLitres, postTransactionEmpty: postTransactionEmpty, operationID: operationID, note: varianceNote)
            activeRunItemID = nil
            resetDraft(); loadVisitIndex = nil; workspace = .active
            message = "Load committed: \(added) L."; persistLiveSnapshot()
        } catch {
            cargoLedger = originalLedger; reconciliationLog = originalReconciliationLog; eventLog = originalEvents
            visits = originalVisits; runItems = originalRunItems; unresolvedDiscrepancies = originalUnresolved
            workspace = originalWorkspace; loadVisitIndex = originalLoadVisitIndex; activeRunItemID = originalActiveRunItemID
            message = "Load not committed: \(error)"
        }
    }

    public func commitDelivery(actualLitres: Int? = nil, postTransactionEmpty: Bool? = nil, varianceNote: String = "") {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard deliveryDraftIsValid, let fill = currentFill, visits.indices.contains(selectedVisit), visits[selectedVisit].fills.indices.contains(selectedFill) else { message = "Delivery not committed: invalid draft."; return }
        guard let runItemID = runItems.first(where: { $0.kind == .siteVisit && $0.siteVisitID == visits[selectedVisit].id })?.id else { message = "Delivery not committed: Site Run item is missing."; return }
        let before = confirmedLitres
        let now = Date()
        let operationID = nextOperationID("delivery")
        var candidate = cargoLedger
        var delivered = 0
        do {
            for i in compartments.indices where compartments[i].product == fill.product && draftLitres[i] < before[i] {
                let delta = before[i] - draftLitres[i]
                try candidate.append(CargoTransaction(kind: .unload, cargo: cargo(for: fill.product), units: Double(delta), sourceCompartmentID: compartments[i].cargoCompartmentID, occurredAt: now, recordedAt: now, provenance: .driverEntered, note: operationID), reconciliationLog: reconciliationLog)
                delivered += delta
            }
            guard delivered > 0 else { message = "Delivery not committed: zero movement."; return }
            cargoLedger = candidate
            let identity = "\(visits[selectedVisit].customer) — \(visits[selectedVisit].site) / \(fill.name)"
            let outcome = Chunk5GDeliveryOutcome(siteVisitID: visits[selectedVisit].id, fillID: fill.id, runItemID: runItemID, plannedLitres: fill.plannedLitres, actualLitres: delivered, occurredAt: now)
            let deliveryEventID = appendEvent(.delivery, "Delivery \(delivered) L", "\(identity); \(fill.product)", relatedOperationID: operationID, relatedRunItemID: runItemID, committedLitres: delivered, deliveryOutcome: outcome)
            visits[selectedVisit].fills[selectedFill].completed = true
            linkSiteRunItem(visitID: visits[selectedVisit].id, to: deliveryEventID)
            try recordTransactionVarianceIfRequired(calculatedLitres: delivered, actualLitres: actualLitres, postTransactionEmpty: postTransactionEmpty, operationID: operationID, note: varianceNote)
            resetDraft()
            _ = advanceToNextFillAtSite()
            message = visits[selectedVisit].isComplete ? "Delivery committed: \(delivered) L. Site visit complete." : "Delivery committed: \(delivered) L. Next fill ready."
            persistLiveSnapshot()
        } catch { message = "Delivery not committed: \(error)" }
    }

    public func commitZeroDelivery(reason: String) {
        guard mutationAllowed, workspace == .site,
              visits.indices.contains(selectedVisit), visits[selectedVisit].fills.indices.contains(selectedFill),
              !visits[selectedVisit].fills[selectedFill].completed else { message = "0 L outcome not committed: no current incomplete fill."; return }
        let clean = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 120 else { message = "0 L outcome requires a short reason (1–120 characters)."; return }
        guard draftLitres == confirmedLitres else { message = "0 L outcome requires an unchanged delivery draft."; return }
        let fill = visits[selectedVisit].fills[selectedFill]
        let visit = visits[selectedVisit]
        guard let runItemID = runItems.first(where: { $0.kind == .siteVisit && $0.siteVisitID == visit.id })?.id else { message = "0 L outcome not committed: Site Run item is missing."; return }
        let now = Date()
        let outcome = Chunk5GDeliveryOutcome(siteVisitID: visit.id, fillID: fill.id, runItemID: runItemID, plannedLitres: fill.plannedLitres, actualLitres: 0, reason: clean, occurredAt: now)
        let deliveryEventID = appendEvent(.delivery, "Delivery outcome 0 L", "\(visit.customer) — \(visit.site) / \(fill.name); reason: \(clean)", relatedRunItemID: runItemID, committedLitres: 0, deliveryOutcome: outcome)
        visits[selectedVisit].fills[selectedFill].completed = true
        linkSiteRunItem(visitID: visit.id, to: deliveryEventID)
        _ = advanceToNextFillAtSite()
        message = visits[selectedVisit].isComplete ? "0 L delivery outcome recorded. Site visit complete." : "0 L delivery outcome recorded. Next fill ready."
        persistLiveSnapshot()
    }

    private func recordTransactionVarianceIfRequired(calculatedLitres: Int, actualLitres: Int?, postTransactionEmpty: Bool?, operationID: String, note: String) throws {
        if varianceFailureForTesting { throw CocoaError(.fileWriteUnknown) }
        guard let actualLitres, actualLitres > 0 else { return }
        let variance = actualLitres - calculatedLitres
        var reconciliationIDs: [CanonicalID] = []

        if postTransactionEmpty == true {
            // "Truck empty" is whole-vehicle physical evidence, not a statement
            // about only the product involved in the transaction.
            let eligible = Array(compartments.indices)
            guard let first = eligible.first else { throw CargoReconciliationError.unknownCompartment }
            let relatedTransactionID = cargoLedger.transactions.first(where: { $0.note == operationID })?.id
            var varianceAttached = false
            for index in eligible {
                let calculated = confirmedLitres[index]
                guard calculated > 0 else { continue }
                let event = CargoReconciliationEvent(
                    compartmentID: compartments[index].cargoCompartmentID,
                    cargo: cargo(for: compartments[index].product),
                    calculatedUnitsBefore: Double(calculated),
                    confirmedPhysicalUnitsAfter: 0,
                    observedMovementVariance: !varianceAttached && variance != 0 ? Double(variance) : nil,
                    occurredAt: Date().addingTimeInterval(0.001 + Double(reconciliationIDs.count) * 0.001),
                    recordedAt: Date(),
                    provenance: .driverEntered,
                    relatedCargoTransactionID: relatedTransactionID,
                    note: "TRANSACTION VARIANCE: \(operationID); post-state empty"
                )
                try reconciliationLog.append(event)
                reconciliationIDs.append(event.id)
                if variance != 0 { varianceAttached = true }
            }
            if variance != 0 && !varianceAttached {
                let event = CargoReconciliationEvent(
                    compartmentID: compartments[first].cargoCompartmentID,
                    cargo: cargo(for: compartments[first].product),
                    calculatedUnitsBefore: 0,
                    confirmedPhysicalUnitsAfter: 0,
                    observedMovementVariance: Double(variance),
                    occurredAt: Date().addingTimeInterval(0.001),
                    recordedAt: Date(),
                    provenance: .driverEntered,
                    relatedCargoTransactionID: relatedTransactionID,
                    note: "TRANSACTION VARIANCE: \(operationID); post-state empty"
                )
                try reconciliationLog.append(event); reconciliationIDs.append(event.id)
            }
        } else if variance != 0 {
            unresolvedDiscrepancies += 1
        }

        let payload = Chunk5GTransactionVariance(
            calculatedLitres: calculatedLitres,
            actualLitres: actualLitres,
            postTransactionEmpty: postTransactionEmpty,
            reconciliationEventIDs: reconciliationIDs,
            provenance: .driverEntered,
            note: note.isEmpty ? nil : note
        )
        appendEvent(
            .transactionVariance,
            variance == 0 ? "Transaction evidence — totals match" : "Transaction variance \(variance >= 0 ? "+" : "")\(variance) L",
            "calculated \(calculatedLitres) L; actual \(actualLitres) L",
            relatedOperationID: operationID,
            committedLitres: actualLitres,
            transactionVariance: payload
        )
    }

    public func commitTransfer(from: Int, to: Int, litres: Int) {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard compartments.indices.contains(from), compartments.indices.contains(to), from != to, litres > 0 else { message = "Transfer not committed: invalid input."; return }
        guard compartments[from].product == compartments[to].product else { message = "Transfer not committed: product mismatch."; return }
        let now = Date()
        let operationID = nextOperationID("transfer")
        var candidate = cargoLedger
        do {
            try candidate.append(CargoTransaction(kind: .transfer, cargo: cargo(for: compartments[from].product), units: Double(litres), sourceCompartmentID: compartments[from].cargoCompartmentID, destinationCompartmentID: compartments[to].cargoCompartmentID, occurredAt: now, recordedAt: now, provenance: .driverEntered, note: operationID), reconciliationLog: reconciliationLog)
            cargoLedger = candidate
            appendEvent(.transfer, "Transfer \(litres) L", "C\(from + 1) → C\(to + 1); \(compartments[from].product)")
            resetDraft(); message = "Transfer committed."; persistLiveSnapshot()
        } catch { message = "Transfer not committed: \(error)" }
    }

    public func commitCorrection(eventID: UUID, correctedLitres: Int, compartment index: Int, note: String) {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard workspace == .active else { message = "Correction is available only while working in Active."; return }
        guard compartments.indices.contains(index),
              let originalEvent = eventLog.first(where: { $0.id == eventID }),
              let operationID = originalEvent.relatedOperationID,
              let originalLitres = originalEvent.committedLitres,
              originalEvent.kind == .load || originalEvent.kind == .delivery else {
            message = "Correction not committed: select an original Load or Delivery event."; return
        }
        let deltaLitres = correctedLitres - originalLitres
        guard correctedLitres > 0, deltaLitres != 0 else {
            message = "Correction not committed: corrected total must be positive and different."; return
        }
        let compartmentID = compartments[index].cargoCompartmentID
        let expectedKind: CargoTransactionKind = originalEvent.kind == .load ? .load : .unload
        guard let target = cargoLedger.transactions.first(where: {
            $0.note == operationID && $0.kind == expectedKind &&
            (expectedKind == .load ? $0.destinationCompartmentID == compartmentID : $0.sourceCompartmentID == compartmentID)
        }) else {
            message = "Correction not committed: the selected compartment was not part of the original event."; return
        }
        let replacementUnits = Int(target.units.rounded()) + deltaLitres
        guard replacementUnits > 0 else {
            message = "Correction not committed: compartment adjustment would be zero or negative."; return
        }
        let now = Date()
        // A correction is learned now but supersedes the original movement at
        // its historical position. This prevents a corrected Load from
        // requiring all originally loaded cargo to remain on board.
        let replayTime = target.occurredAt.addingTimeInterval(0.000001)
        let correctionOperationID = nextOperationID("correction")
        let reversal = CargoTransaction(
            kind: .correction, cargo: target.cargo, units: target.units,
            sourceCompartmentID: target.destinationCompartmentID,
            destinationCompartmentID: target.sourceCompartmentID,
            occurredAt: replayTime, recordedAt: now, provenance: .corrected,
            correctsTransactionID: target.id, note: correctionOperationID
        )
        let replacement = CargoTransaction(
            kind: target.kind, cargo: target.cargo, units: Double(replacementUnits),
            sourceCompartmentID: target.sourceCompartmentID,
            destinationCompartmentID: target.destinationCompartmentID,
            occurredAt: replayTime.addingTimeInterval(0.000001), recordedAt: now,
            provenance: .corrected, note: correctionOperationID
        )
        var candidate = cargoLedger
        do {
            try candidate.appendCorrectionPair(reversal: reversal, replacement: replacement, reconciliationLog: reconciliationLog)
            cargoLedger = candidate
            let payload = Chunk5GInputCorrection(
                originalEventID: originalEvent.id,
                originalLitres: originalLitres,
                correctedLitres: correctedLitres,
                compartmentAdjustments: [Chunk5GCompartmentAdjustment(compartmentIndex: index, deltaLitres: deltaLitres)],
                correctionTransactionIDs: [reversal.id, replacement.id],
                provenance: .corrected,
                note: note.isEmpty ? nil : note
            )
            appendEvent(
                .correction,
                "Input correction \(originalLitres) → \(correctedLitres) L",
                "C\(index + 1) \(deltaLitres > 0 ? "+" : "")\(deltaLitres) L; original retained",
                relatedOperationID: correctionOperationID,
                committedLitres: correctedLitres,
                inputCorrection: payload
            )
            resetDraft(); message = "Correction committed."; persistLiveSnapshot()
        } catch { message = "Correction not committed: \(error)" }
    }

    public func commitPhysicalCheck(compartment index: Int, observedLitres: Int, note: String) {
        guard mutationAllowed else { message = "Completed shift is locked for recovery."; return }
        guard compartments.indices.contains(index) else { return }
        guard observedLitres >= 0, observedLitres <= compartments[index].capacityLitres else {
            message = "Physical Check not committed: observed litres must be 0...\(compartments[index].capacityLitres)."
            return
        }
        let calc = Double(confirmedLitres[index]); let obs = Double(observedLitres); let now = Date()
        do {
            let boundary = CargoReconciliationEvent(compartmentID: compartments[index].cargoCompartmentID, cargo: cargo(for: compartments[index].product), calculatedUnitsBefore: calc, confirmedPhysicalUnitsAfter: obs, occurredAt: now, recordedAt: now, provenance: .driverEntered, note: "PHYSICAL CHECK: " + note)
            try reconciliationLog.append(boundary)
            let payload = Chunk5GPhysicalCheck(
                compartmentIndex: index,
                calculatedLitres: Int(calc.rounded()),
                observedLitres: observedLitres,
                reconciliationEventID: boundary.id,
                provenance: .driverEntered,
                note: note.isEmpty ? nil : note
            )
            appendEvent(
                .physicalCheck,
                "Physical Check C\(index + 1)",
                "calculated \(Int(calc.rounded())) L; observed \(observedLitres) L; difference \(observedLitres - Int(calc.rounded())) L",
                physicalCheck: payload
            )
            resetDraft(); message = "Physical Check committed."; persistLiveSnapshot()
        } catch { message = "Physical Check failed: \(error)" }
    }

    /// Compatibility entry point for callers compiled against the pre-Field-Test-02 label.
    public func commitReconciliation(compartment index: Int, observedLitres: Int, note: String) {
        commitPhysicalCheck(compartment: index, observedLitres: observedLitres, note: note)
    }

    // MARK: - Persistence / gate

    private func stableJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return (try? encoder.encode(value).base64EncodedString()) ?? "ENCODING-FAILED"
    }

    /// Keeps the exact legacy history fingerprint for events without Field Test 02
    /// payloads, while covering every structured exception fact and its linked
    /// authoritative records for new snapshots.
    private func historyFingerprint(
        events: [Chunk5GEvent],
        ledger: CargoLedger,
        reconciliationLog: CargoReconciliationLog
    ) -> String {
        events.map { event in
            let legacy = "\(event.id.uuidString):\(event.kind.rawValue):\(event.summary):\(event.detail)"
            var exceptionFacts: [String] = []
            if event.relatedOperationID != nil || event.relatedRunItemID != nil || event.committedLitres != nil || event.transactionVariance != nil || event.physicalCheck != nil || event.inputCorrection != nil || event.deliveryOutcome != nil {
                let metadata = event.relatedRunItemID == nil
                    ? [event.relatedOperationID ?? "", event.committedLitres.map(String.init) ?? ""]
                    : [event.relatedOperationID ?? "", event.relatedRunItemID?.uuidString ?? "", event.committedLitres.map(String.init) ?? ""]
                exceptionFacts.append("eventMeta=\(stableJSON(metadata))")
            }
            if let variance = event.transactionVariance {
                let linked = reconciliationLog.events.filter { variance.reconciliationEventIDs.contains($0.id) }
                let transactionIDs = Set(linked.compactMap(\.relatedCargoTransactionID))
                let linkedTransactions = ledger.transactions.filter { transactionIDs.contains($0.id) }
                exceptionFacts.append("variance=\(stableJSON(variance))")
                exceptionFacts.append("varianceLinks=\(stableJSON(linked))")
                exceptionFacts.append("varianceTransactions=\(stableJSON(linkedTransactions))")
            }
            if let physical = event.physicalCheck {
                let linked = reconciliationLog.events.filter { $0.id == physical.reconciliationEventID }
                exceptionFacts.append("physical=\(stableJSON(physical))")
                exceptionFacts.append("physicalLinks=\(stableJSON(linked))")
            }
            if let correction = event.inputCorrection {
                let correctionTransactions = ledger.transactions.filter { correction.correctionTransactionIDs.contains($0.id) }
                let targetIDs = Set(correctionTransactions.compactMap(\.correctsTransactionID))
                let linked = ledger.transactions.filter { correction.correctionTransactionIDs.contains($0.id) || targetIDs.contains($0.id) }
                exceptionFacts.append("correction=\(stableJSON(correction))")
                exceptionFacts.append("correctionLinks=\(stableJSON(linked))")
            }
            if let outcome = event.deliveryOutcome { exceptionFacts.append("deliveryOutcome=\(stableJSON(outcome))") }
            return exceptionFacts.isEmpty ? legacy : legacy + "::" + exceptionFacts.joined(separator: ";")
        }.joined(separator: "||")
    }

    /// Legacy v3 snapshots did not protect this counter. Add it only when a
    /// Field Test 02 structured event is present so those snapshots remain
    /// replay-compatible while new exception consequences cannot be zeroed.
    private func exceptionConsequenceFingerprint(events: [Chunk5GEvent], unresolvedDiscrepancies: Int) -> String {
        let hasStructuredException = events.contains {
            $0.transactionVariance != nil || $0.physicalCheck != nil || $0.inputCorrection != nil || $0.deliveryOutcome != nil
        }
        return hasStructuredException ? "##exceptions:unresolved=\(unresolvedDiscrepancies)" : ""
    }

    private func authoritativeFingerprint() -> String {
        let cargo = confirmedLitres.map(String.init).joined(separator: ",")
        let run = visits.map { v in
            let fills = v.fills.map { "\($0.id.uuidString):\($0.name):\($0.product):\($0.plannedLitres):\($0.completed)" }.joined(separator: "|")
            return "\(v.id.uuidString):\(v.customer):\(v.site):\(v.isTerminalLoad):\(fills)"
        }.joined(separator: "||")
        let history = historyFingerprint(events: eventLog, ledger: cargoLedger, reconciliationLog: reconciliationLog)
        return cargo + "##" + run + "##" + history + exceptionConsequenceFingerprint(events: eventLog, unresolvedDiscrepancies: unresolvedDiscrepancies) + "##runItems:" + stableJSON(runItems)
    }

    public func persistLiveSnapshot() {
        guard evidenceSource == .live else { return }
        let fingerprint = authoritativeFingerprint()
        let snap = Chunk5GLiveSnapshot(evidenceSource: evidenceSource, compartments: compartments, visits: visits, eventLog: eventLog, cargoLedger: cargoLedger, reconciliationLog: reconciliationLog, openingBaselineAccepted: openingBaselineAccepted, shiftStartedAt: shiftStartedAt, shiftEndedAt: shiftEndedAt, openingODO: openingODO, closingODO: closingODO, cargoOpeningSnapshot: cargoOpeningSnapshot, unresolvedDiscrepancies: unresolvedDiscrepancies, dieselCargo: dieselCargo, ulpCargo: ulpCargo, selectedVisit: selectedVisit, selectedFill: selectedFill, restMinutes: restMinutes, loadVisitIndex: loadVisitIndex, workspace: workspace, runItems: runItems, authoritativeFingerprint: fingerprint)
        do { persistenceDefaults.set(try JSONEncoder().encode(snap), forKey: Self.persistenceKey); persistedFingerprint = fingerprint } catch { message = "Snapshot save failed: \(error)" }
    }

    /// Recomputes only the persistence seal so deterministic fixtures can prove
    /// semantic validation, rather than being rejected by a stale fingerprint.
    func refingerprintPersistedSnapshotForTesting() throws {
        guard let data = persistenceDefaults.data(forKey: Self.persistenceKey) else { throw CocoaError(.fileNoSuchFile) }
        var snapshot = try JSONDecoder().decode(Chunk5GLiveSnapshot.self, from: data)
        let cargo = try snapshot.compartments.map { compartment -> String in
            let state = try CargoStateReconciler.currentState(
                ledger: snapshot.cargoLedger,
                reconciliationLog: snapshot.reconciliationLog,
                compartmentID: compartment.cargoCompartmentID
            )
            return String(Int((state.quantity?.units ?? 0).rounded()))
        }.joined(separator: ",")
        let run = snapshot.visits.map { visit in
            let fills = visit.fills.map { "\($0.id.uuidString):\($0.name):\($0.product):\($0.plannedLitres):\($0.completed)" }.joined(separator: "|")
            return "\(visit.id.uuidString):\(visit.customer):\(visit.site):\(visit.isTerminalLoad):\(fills)"
        }.joined(separator: "||")
        let history = historyFingerprint(events: snapshot.eventLog, ledger: snapshot.cargoLedger, reconciliationLog: snapshot.reconciliationLog)
        let runItemsSuffix = snapshot.runItems.map { "##runItems:" + stableJSON($0) } ?? ""
        snapshot.authoritativeFingerprint = cargo + "##" + run + "##" + history + exceptionConsequenceFingerprint(events: snapshot.eventLog, unresolvedDiscrepancies: snapshot.unresolvedDiscrepancies) + runItemsSuffix
        persistenceDefaults.set(try JSONEncoder().encode(snapshot), forKey: Self.persistenceKey)
    }

    func validateExceptionFacts(
        events: [Chunk5GEvent],
        ledger: CargoLedger,
        reconciliationLog: CargoReconciliationLog,
        compartments: [Chunk5FCompartment]
    ) throws {
        let transactionByID = Dictionary(uniqueKeysWithValues: ledger.transactions.map { ($0.id, $0) })
        let reconciliationByID = Dictionary(uniqueKeysWithValues: reconciliationLog.events.map { ($0.id, $0) })

        for event in events {
            if event.kind == .delivery, let outcome = event.deliveryOutcome, outcome.actualLitres == 0 {
                guard event.committedLitres == 0,
                      event.relatedOperationID == nil,
                      !(outcome.reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw CocoaError(.coderReadCorrupt)
                }
            } else if event.kind == .load || event.kind == .delivery {
                if event.relatedOperationID != nil || event.committedLitres != nil {
                    guard let operationID = event.relatedOperationID,
                          let committedLitres = event.committedLitres,
                          committedLitres > 0 else { throw CocoaError(.coderReadCorrupt) }
                    let transactionKind: CargoTransactionKind = event.kind == .load ? .load : .unload
                    let operationRows = ledger.transactions.filter { $0.kind == transactionKind && $0.note == operationID }
                    guard !operationRows.isEmpty,
                          Int(operationRows.reduce(0) { $0 + $1.units }.rounded()) == committedLitres else {
                        throw CocoaError(.coderReadCorrupt)
                    }
                }
            }
            if event.kind == .transactionVariance, event.transactionVariance == nil { throw CocoaError(.coderReadCorrupt) }
            if event.kind == .physicalCheck, event.physicalCheck == nil { throw CocoaError(.coderReadCorrupt) }
            if event.kind == .correction,
               (event.relatedOperationID != nil || event.committedLitres != nil),
               event.inputCorrection == nil { throw CocoaError(.coderReadCorrupt) }

            if let variance = event.transactionVariance {
                guard event.kind == .transactionVariance,
                      variance.calculatedLitres > 0,
                      variance.actualLitres > 0,
                      variance.varianceLitres == variance.actualLitres - variance.calculatedLitres,
                      event.committedLitres == variance.actualLitres,
                      let operationID = event.relatedOperationID,
                      events.contains(where: {
                          ($0.kind == .load || $0.kind == .delivery) &&
                          $0.relatedOperationID == operationID &&
                          $0.committedLitres == variance.calculatedLitres
                      }),
                      Set(variance.reconciliationEventIDs).count == variance.reconciliationEventIDs.count else {
                    throw CocoaError(.coderReadCorrupt)
                }
                let boundaries = try variance.reconciliationEventIDs.map { id -> CargoReconciliationEvent in
                    guard let boundary = reconciliationByID[id] else { throw CocoaError(.coderReadCorrupt) }
                    return boundary
                }
                if variance.postTransactionEmpty == true {
                    guard (!boundaries.isEmpty || variance.varianceLitres == 0),
                          boundaries.allSatisfy({ abs($0.confirmedPhysicalUnitsAfter) < 0.000001 }),
                          boundaries.allSatisfy({ $0.provenance == variance.provenance }),
                          abs(boundaries.compactMap(\.observedMovementVariance).reduce(0, +) - Double(variance.varianceLitres)) < 0.000001,
                          (boundaries.isEmpty && variance.varianceLitres == 0 || boundaries.contains(where: { boundary in
                              guard let id = boundary.relatedCargoTransactionID,
                                    let transaction = transactionByID[id] else { return false }
                              return transaction.note == operationID
                          })) else { throw CocoaError(.coderReadCorrupt) }
                } else {
                    guard boundaries.isEmpty else { throw CocoaError(.coderReadCorrupt) }
                }
            }

            if let physical = event.physicalCheck {
                guard event.kind == .physicalCheck,
                      compartments.indices.contains(physical.compartmentIndex),
                      physical.calculatedLitres >= 0,
                      physical.observedLitres >= 0,
                      physical.differenceLitres == physical.observedLitres - physical.calculatedLitres,
                      let boundary = reconciliationByID[physical.reconciliationEventID],
                      boundary.compartmentID == compartments[physical.compartmentIndex].cargoCompartmentID,
                      abs(boundary.calculatedUnitsBefore - Double(physical.calculatedLitres)) < 0.000001,
                      abs(boundary.confirmedPhysicalUnitsAfter - Double(physical.observedLitres)) < 0.000001,
                      boundary.provenance == physical.provenance else {
                    throw CocoaError(.coderReadCorrupt)
                }
            }

            if let correction = event.inputCorrection {
                guard event.kind == .correction,
                      correction.provenance == .corrected,
                      correction.originalLitres > 0,
                      correction.correctedLitres > 0,
                      correction.deltaLitres == correction.correctedLitres - correction.originalLitres,
                      correction.compartmentAdjustments.count == 1,
                      correction.compartmentAdjustments.reduce(0, { $0 + $1.deltaLitres }) == correction.deltaLitres,
                      correction.compartmentAdjustments.allSatisfy({ compartments.indices.contains($0.compartmentIndex) }),
                      Set(correction.compartmentAdjustments.map(\.compartmentIndex)).count == correction.compartmentAdjustments.count,
                      correction.correctionTransactionIDs.count == 2,
                      Set(correction.correctionTransactionIDs).count == 2,
                      event.committedLitres == correction.correctedLitres,
                      let correctionOperationID = event.relatedOperationID,
                      let original = events.first(where: { $0.id == correction.originalEventID }),
                      original.kind == .load || original.kind == .delivery,
                      original.timestamp <= event.timestamp,
                      original.committedLitres == correction.originalLitres,
                      let originalOperationID = original.relatedOperationID,
                      let reversal = transactionByID[correction.correctionTransactionIDs[0]],
                      let replacement = transactionByID[correction.correctionTransactionIDs[1]],
                      reversal.kind == .correction,
                      reversal.provenance == .corrected,
                      replacement.provenance == .corrected,
                      reversal.note == correctionOperationID,
                      replacement.note == correctionOperationID,
                      let correctedTargetID = reversal.correctsTransactionID,
                      let correctedTarget = transactionByID[correctedTargetID],
                      correctedTarget.note == originalOperationID,
                      correctedTarget.kind == (original.kind == .load ? .load : .unload),
                      replacement.kind == correctedTarget.kind,
                      replacement.cargo == correctedTarget.cargo,
                      replacement.sourceCompartmentID == correctedTarget.sourceCompartmentID,
                      replacement.destinationCompartmentID == correctedTarget.destinationCompartmentID,
                      reversal.units == correctedTarget.units,
                      reversal.sourceCompartmentID == correctedTarget.destinationCompartmentID,
                      reversal.destinationCompartmentID == correctedTarget.sourceCompartmentID else {
                    throw CocoaError(.coderReadCorrupt)
                }
                let compartmentAdjustment = correction.compartmentAdjustments[0]
                let adjustedCompartmentID = compartments[compartmentAdjustment.compartmentIndex].cargoCompartmentID
                let targetCompartmentID = correctedTarget.kind == .load ? correctedTarget.destinationCompartmentID : correctedTarget.sourceCompartmentID
                guard targetCompartmentID == adjustedCompartmentID,
                      abs(replacement.units - (correctedTarget.units + Double(compartmentAdjustment.deltaLitres))) < 0.000001 else {
                    throw CocoaError(.coderReadCorrupt)
                }
            }

            let structuredPayloadCount = [event.transactionVariance != nil, event.physicalCheck != nil, event.inputCorrection != nil].filter { $0 }.count
            guard structuredPayloadCount <= 1 else { throw CocoaError(.coderReadCorrupt) }
        }

        let representedCorrectionIDs = Set(events.compactMap(\.inputCorrection).flatMap(\.correctionTransactionIDs))
        let ledgerCorrectionIDs = Set(ledger.transactions.filter { $0.note?.hasPrefix("chunk5g.correction.op.") == true }.map(\.id))
        guard representedCorrectionIDs == ledgerCorrectionIDs else { throw CocoaError(.coderReadCorrupt) }
    }

    private func validate(snapshot s: Chunk5GLiveSnapshot) throws {
        guard s.evidenceSource == .live else { throw CocoaError(.coderReadCorrupt) }
        try validateExceptionFacts(events: s.eventLog, ledger: s.cargoLedger, reconciliationLog: s.reconciliationLog, compartments: s.compartments)
        let snapshotRunItems = s.runItems ?? s.visits.map { Chunk5FRunItem(kind: $0.isTerminalLoad ? .terminalLoad : .siteVisit, siteVisitID: $0.isTerminalLoad ? nil : $0.id, title: $0.isTerminalLoad ? "Terminal / Load" : "\($0.customer) — \($0.site)", requestedTime: $0.requestedTime) }
        if s.runItems != nil {
            guard Set(snapshotRunItems.map(\.id)).count == snapshotRunItems.count,
                  snapshotRunItems.allSatisfy({ item in
                      switch item.kind {
                      case .siteVisit: return item.siteVisitID.map { id in s.visits.contains(where: { $0.id == id }) } == true
                      case .terminalLoad, .plannedRest, .plannedOtherWork: return item.siteVisitID == nil
                      }
                  }),
                  s.visits.filter({ !$0.isTerminalLoad }).allSatisfy({ visit in snapshotRunItems.contains(where: { $0.kind == .siteVisit && $0.siteVisitID == visit.id }) }) else { throw CocoaError(.coderReadCorrupt) }

            func matches(_ event: Chunk5GEvent, _ item: Chunk5FRunItem) -> Bool {
                switch item.kind {
                case .siteVisit: return event.kind == .delivery && event.deliveryOutcome?.siteVisitID == item.siteVisitID
                case .terminalLoad: return event.kind == .load
                case .plannedRest: return event.kind == .restStart
                case .plannedOtherWork: return event.kind == .workRest && event.summary == "Work started"
                }
            }
            for item in snapshotRunItems {
                let linkedVisit = item.siteVisitID.flatMap { id in s.visits.first(where: { $0.id == id }) }
                let deliveryEvents = s.eventLog.filter {
                    $0.kind == .delivery && $0.relatedRunItemID == item.id && $0.deliveryOutcome?.siteVisitID == item.siteVisitID
                }
                let representedFillIDs = deliveryEvents.compactMap { $0.deliveryOutcome?.fillID }
                let legacyFillIDs: [UUID]
                if let storedLegacyFillIDs = item.legacyCompletedFillIDs {
                    legacyFillIDs = storedLegacyFillIDs
                } else if item.kind == .siteVisit && (item.legacyExecutionLock || item.legacySatisfied) {
                    // Compatibility for snapshots written by the immediately
                    // preceding repair before the explicit ID set existed. Any
                    // structured Delivery already proves the newly completed
                    // side, so the exact legacy set is the completed remainder.
                    let represented = Set(representedFillIDs)
                    legacyFillIDs = linkedVisit?.fills.filter { $0.completed && !represented.contains($0.id) }.map(\.id) ?? []
                } else {
                    guard item.legacyCompletedFillIDs != nil || (!item.legacyExecutionLock && !item.legacySatisfied) else { throw CocoaError(.coderReadCorrupt) }
                    legacyFillIDs = []
                }
                guard Set(legacyFillIDs).count == legacyFillIDs.count else { throw CocoaError(.coderReadCorrupt) }
                if item.kind == .siteVisit, let visit = linkedVisit {
                    let allFillIDs = Set(visit.fills.map(\.id))
                    let completedFillIDs = Set(visit.fills.filter(\.completed).map(\.id))
                    let legacySet = Set(legacyFillIDs)
                    let representedSet = Set(representedFillIDs)
                    guard representedSet.count == representedFillIDs.count,
                          legacySet.isSubset(of: completedFillIDs), legacySet.isSubset(of: allFillIDs),
                          legacySet.isDisjoint(with: representedSet),
                          completedFillIDs == legacySet.union(representedSet),
                          item.legacyExecutionLock == !legacySet.isEmpty,
                          item.legacySatisfied == (visit.isComplete && legacySet == allFillIDs) else {
                        throw CocoaError(.coderReadCorrupt)
                    }
                } else {
                    guard legacyFillIDs.isEmpty, !item.legacyExecutionLock, !item.legacySatisfied else { throw CocoaError(.coderReadCorrupt) }
                }
                if let eventID = item.executionEventID {
                    guard let event = s.eventLog.first(where: { $0.id == eventID }), event.relatedRunItemID == item.id, matches(event, item) else { throw CocoaError(.coderReadCorrupt) }
                }
                if let eventID = item.satisfactionEventID {
                    guard item.executionEventID != nil,
                          let event = s.eventLog.first(where: { $0.id == eventID }), event.relatedRunItemID == item.id, matches(event, item) else { throw CocoaError(.coderReadCorrupt) }
                }
                guard !item.legacySatisfied || item.legacyExecutionLock else { throw CocoaError(.coderReadCorrupt) }
                if item.kind == .siteVisit, linkedVisit?.fills.contains(where: \.completed) == true,
                   !item.hasCommittedExecution { throw CocoaError(.coderReadCorrupt) }
                if item.kind == .siteVisit, linkedVisit?.isComplete == true,
                   !item.isSatisfied { throw CocoaError(.coderReadCorrupt) }
                if item.kind == .siteVisit, item.isSatisfied, linkedVisit?.isComplete != true {
                    throw CocoaError(.coderReadCorrupt)
                }
                if item.kind == .siteVisit, let satisfactionEventID = item.satisfactionEventID,
                   let visit = linkedVisit {
                    let completingDeliveries = deliveryEvents
                    let completedFillIDs = Set(visit.fills.filter(\.completed).map(\.id))
                    let representedFillIDs = Set(completingDeliveries.compactMap { $0.deliveryOutcome?.fillID })
                    let legacyFillIDSet = Set(legacyFillIDs)
                    guard let finalDelivery = completingDeliveries.last,
                          completingDeliveries.count == representedFillIDs.count,
                          completedFillIDs == legacyFillIDSet.union(representedFillIDs),
                          finalDelivery.id == satisfactionEventID,
                          finalDelivery.deliveryOutcome?.runItemID == item.id,
                          visit.fills.contains(where: { $0.id == finalDelivery.deliveryOutcome?.fillID && $0.completed }) else {
                        throw CocoaError(.coderReadCorrupt)
                    }
                }
            }
            for event in s.eventLog where event.relatedRunItemID != nil {
                guard let id = event.relatedRunItemID,
                      let item = snapshotRunItems.first(where: { $0.id == id }),
                      item.hasCommittedExecution, matches(event, item) else { throw CocoaError(.coderReadCorrupt) }
            }
            for event in s.eventLog where event.kind == .load || (event.kind == .delivery && (event.deliveryOutcome?.actualLitres ?? 1) > 0) {
                guard let operationID = event.relatedOperationID, (event.committedLitres ?? 0) > 0,
                      s.cargoLedger.transactions.contains(where: { $0.note == operationID && $0.kind == (event.kind == .load ? .load : .unload) }) else { throw CocoaError(.coderReadCorrupt) }
            }
        }
        for event in s.eventLog where event.deliveryOutcome != nil {
            guard event.kind == .delivery, let outcome = event.deliveryOutcome,
                  outcome.actualLitres >= 0, outcome.plannedLitres >= 0,
                  event.committedLitres == outcome.actualLitres,
                  event.relatedRunItemID == outcome.runItemID,
                  let visit = s.visits.first(where: { $0.id == outcome.siteVisitID }),
                  let fill = visit.fills.first(where: { $0.id == outcome.fillID }), fill.completed,
                  fill.plannedLitres == outcome.plannedLitres,
                  snapshotRunItems.contains(where: { $0.id == outcome.runItemID && $0.siteVisitID == outcome.siteVisitID }) else { throw CocoaError(.coderReadCorrupt) }
            if outcome.actualLitres == 0 {
                guard event.relatedOperationID == nil,
                      !(outcome.reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CocoaError(.coderReadCorrupt) }
            } else {
                guard event.relatedOperationID?.hasPrefix("chunk5g.delivery.op.") == true else { throw CocoaError(.coderReadCorrupt) }
            }
        }
        for c in s.compartments {
            _ = try CargoStateReconciler.currentState(
                ledger: s.cargoLedger,
                reconciliationLog: s.reconciliationLog,
                compartmentID: c.cargoCompartmentID
            )
        }
        let cargo = try s.compartments.map { c -> String in
            let state = try CargoStateReconciler.currentState(
                ledger: s.cargoLedger,
                reconciliationLog: s.reconciliationLog,
                compartmentID: c.cargoCompartmentID
            )
            return String(Int((state.quantity?.units ?? 0).rounded()))
        }.joined(separator: ",")
        let run = s.visits.map { v in
            let fills = v.fills.map { "\($0.id.uuidString):\($0.name):\($0.product):\($0.plannedLitres):\($0.completed)" }.joined(separator: "|")
            return "\(v.id.uuidString):\(v.customer):\(v.site):\(v.isTerminalLoad):\(fills)"
        }.joined(separator: "||")
        let history = historyFingerprint(events: s.eventLog, ledger: s.cargoLedger, reconciliationLog: s.reconciliationLog)
        let runItemsSuffix = s.runItems.map { "##runItems:" + stableJSON($0) } ?? ""
        let expectedFingerprint = cargo + "##" + run + "##" + history + exceptionConsequenceFingerprint(events: s.eventLog, unresolvedDiscrepancies: s.unresolvedDiscrepancies) + runItemsSuffix
        guard expectedFingerprint == s.authoritativeFingerprint else {
            throw CocoaError(.coderReadCorrupt)
        }
    }

    private func installValidated(snapshot s: Chunk5GLiveSnapshot) throws {
        try validate(snapshot: s)
        let retainedVisits = s.visits.filter { !$0.isTerminalLoad }
        let normalizedRunItems: [Chunk5FRunItem]
        if let persistedRunItems = s.runItems {
            normalizedRunItems = persistedRunItems.map { persisted in
                var item = persisted
                if item.legacyCompletedFillIDs == nil {
                    let represented = Set(s.eventLog.filter {
                        $0.kind == .delivery && $0.relatedRunItemID == item.id && $0.deliveryOutcome?.siteVisitID == item.siteVisitID
                    }.compactMap { $0.deliveryOutcome?.fillID })
                    item.legacyCompletedFillIDs = item.kind == .siteVisit && (item.legacyExecutionLock || item.legacySatisfied)
                        ? s.visits.first(where: { $0.id == item.siteVisitID })?.fills.filter { $0.completed && !represented.contains($0.id) }.map(\.id) ?? []
                        : []
                }
                return item
            }
        } else {
            normalizedRunItems = s.visits.map {
                let completedFillIDs = $0.fills.filter(\.completed).map(\.id)
                return Chunk5FRunItem(kind: $0.isTerminalLoad ? .terminalLoad : .siteVisit, siteVisitID: $0.isTerminalLoad ? nil : $0.id, title: $0.isTerminalLoad ? "Terminal / Load" : "\($0.customer) — \($0.site)", requestedTime: $0.requestedTime, legacyExecutionLock: !$0.isTerminalLoad && !completedFillIDs.isEmpty, legacySatisfied: !$0.isTerminalLoad && $0.isComplete, legacyCompletedFillIDs: $0.isTerminalLoad ? [] : completedFillIDs)
            }
        }
        let selectedVisitID = s.visits.indices.contains(s.selectedVisit) ? s.visits[s.selectedVisit].id : nil
        let selectedWasTerminal = s.visits.indices.contains(s.selectedVisit) && s.visits[s.selectedVisit].isTerminalLoad
        let remappedSelected = selectedVisitID.flatMap { id in retainedVisits.firstIndex(where: { $0.id == id }) } ?? 0
        let loadVisitID = s.loadVisitIndex.flatMap { index in s.visits.indices.contains(index) ? s.visits[index].id : nil }
        let remappedLoad = loadVisitID.flatMap { id in retainedVisits.firstIndex(where: { $0.id == id }) }
        compartments=s.compartments; visits=retainedVisits; runItems=normalizedRunItems; eventLog=s.eventLog; cargoLedger=s.cargoLedger; reconciliationLog=s.reconciliationLog
        openingBaselineAccepted=s.openingBaselineAccepted; shiftStartedAt=s.shiftStartedAt; shiftEndedAt=s.shiftEndedAt
        openingODO=s.openingODO; closingODO=s.closingODO; cargoOpeningSnapshot=s.cargoOpeningSnapshot
        unresolvedDiscrepancies=s.unresolvedDiscrepancies; dieselCargo=s.dieselCargo; ulpCargo=s.ulpCargo
        let recoveredLegacyLoad = s.runItems == nil && s.workspace == .load
        selectedVisit=remappedSelected; selectedFill=s.selectedFill; restMinutes=s.restMinutes
        loadVisitIndex=recoveredLegacyLoad ? nil : remappedLoad
        workspace=(recoveredLegacyLoad || (s.workspace == .site && selectedWasTerminal)) ? .active : s.workspace
        shiftLifecycle = s.shiftEndedAt != nil ? .completedLocked : (s.shiftStartedAt != nil ? .active : .fresh)
        resetDraft()
        persistedFingerprint=s.authoritativeFingerprint
    }

    private func archiveCompletedSnapshot(_ data: Data, snapshot: Chunk5GLiveSnapshot) throws {
        guard snapshot.shiftEndedAt != nil else { return }
        try validate(snapshot: snapshot)
        persistenceDefaults.set(data, forKey: Self.completedPersistenceKey)
    }

    func reconciliationsRepresented(events: [Chunk5GEvent], log: CargoReconciliationLog) -> Bool {
        let expected = log.events.filter { $0.note != "chunk5g.opening.baseline" }
        var linked = Set<CanonicalID>()
        for event in events {
            if let physicalCheck = event.physicalCheck { linked.insert(physicalCheck.reconciliationEventID) }
            if let variance = event.transactionVariance {
                linked.formUnion(variance.reconciliationEventIDs)
            }
        }
        let expectedIDs = Set(expected.map(\.id))
        let legacyCount = events.filter {
            $0.kind == .reconciliation || ($0.kind == .correction && $0.inputCorrection == nil)
        }.count
        return linked.isSubset(of: expectedIDs) && expected.count == linked.count + legacyCount
    }

    func correctionsRepresented(events: [Chunk5GEvent], ledger: CargoLedger) -> Bool {
        let eventIDs = Set(events.compactMap(\.inputCorrection).flatMap(\.correctionTransactionIDs))
        let ledgerIDs = Set(ledger.transactions.filter { $0.note?.hasPrefix("chunk5g.correction.op.") == true }.map(\.id))
        return eventIDs == ledgerIDs
    }

    private func gateReport(fromValidated s: Chunk5GLiveSnapshot, persistenceStatus status: Chunk5GCheckStatus) throws -> Chunk5GGateReport {
        try validate(snapshot: s)
        let cargoClosing = try s.compartments.map { c -> Int in
            let state = try CargoStateReconciler.currentState(ledger: s.cargoLedger, reconciliationLog: s.reconciliationLog, compartmentID: c.cargoCompartmentID)
            return Int((state.quantity?.units ?? 0).rounded())
        }
        let arithmeticOK = s.compartments.allSatisfy { c in
            (try? CargoStateReconciler.currentState(ledger: s.cargoLedger, reconciliationLog: s.reconciliationLog, compartmentID: c.cargoCompartmentID)) != nil
        }
        let loadsRepresented = s.eventLog.filter { $0.kind == .load }.count == Set(s.cargoLedger.transactions.filter { $0.kind == .load && ($0.note?.hasPrefix("chunk5g.load.op.") ?? false) }.compactMap(\.note)).count
        let deliveriesRepresented = s.eventLog.filter { $0.kind == .delivery && ($0.deliveryOutcome?.actualLitres ?? 1) > 0 }.count == Set(s.cargoLedger.transactions.filter { $0.kind == .unload && ($0.note?.hasPrefix("chunk5g.delivery.op.") ?? false) }.compactMap(\.note)).count && s.eventLog.filter { $0.deliveryOutcome?.actualLitres == 0 }.allSatisfy { $0.relatedOperationID == nil }
        let transfersRepresented = s.eventLog.filter { $0.kind == .transfer }.count == Set(s.cargoLedger.transactions.filter { $0.kind == .transfer && ($0.note?.hasPrefix("chunk5g.transfer.op.") ?? false) }.compactMap(\.note)).count
        let reconciliationRepresentation = reconciliationsRepresented(events: s.eventLog, log: s.reconciliationLog)
        let correctionRepresentation = correctionsRepresented(events: s.eventLog, ledger: s.cargoLedger)
        let odoAnchorsOK = (s.openingODO ?? 0) > 0 && (s.closingODO ?? 0) >= (s.openingODO ?? 0)
        let integrity: Chunk5GCheckStatus = arithmeticOK && odoAnchorsOK && loadsRepresented && deliveriesRepresented && transfersRepresented && reconciliationRepresentation && correctionRepresentation ? .pass : .fail
        return Chunk5GGateReport(
            shiftStart: s.shiftStartedAt, shiftEnd: s.shiftEndedAt, openingODO: s.openingODO, closingODO: s.closingODO,
            events: s.eventLog, cargoOpening: s.cargoOpeningSnapshot, cargoClosing: cargoClosing,
            unresolvedDiscrepancies: s.unresolvedDiscrepancies,
            loadsRepresented: loadsRepresented,
            deliveriesRepresented: deliveriesRepresented,
            transfersRepresented: transfersRepresented,
            reconciliationsRepresented: reconciliationRepresentation,
            correctionsRepresented: correctionRepresentation,
            cargoArithmeticOK: arithmeticOK,
            odoAnchorsOK: odoAnchorsOK,
            persistenceStatus: status,
            representationIntegrityStatus: integrity,
            operationalCompletenessStatus: .notTested,
            plannedDeliveries: s.visits.filter { !$0.isTerminalLoad }.flatMap(\.fills).count,
            completedPlannedDeliveries: s.visits.filter { !$0.isTerminalLoad }.flatMap(\.fills).filter(\.completed).count
        )
    }

    private func fingerprint(
        compartments: [Chunk5FCompartment],
        visits: [Chunk5FSiteVisit],
        eventLog: [Chunk5GEvent],
        ledger: CargoLedger,
        reconciliationLog: CargoReconciliationLog,
        unresolvedDiscrepancies: Int
    ) throws -> String {
        let cargo = try compartments.map { c -> String in
            let state = try CargoStateReconciler.currentState(
                ledger: ledger,
                reconciliationLog: reconciliationLog,
                compartmentID: c.cargoCompartmentID
            )
            return String(Int((state.quantity?.units ?? 0).rounded()))
        }.joined(separator: ",")
        let run = visits.map { v in
            let fills = v.fills.map { "\($0.id.uuidString):\($0.name):\($0.product):\($0.plannedLitres):\($0.completed)" }.joined(separator: "|")
            return "\(v.id.uuidString):\(v.customer):\(v.site):\(v.isTerminalLoad):\(fills)"
        }.joined(separator: "||")
        let history = historyFingerprint(events: eventLog, ledger: ledger, reconciliationLog: reconciliationLog)
        return cargo + "##" + run + "##" + history + exceptionConsequenceFingerprint(events: eventLog, unresolvedDiscrepancies: unresolvedDiscrepancies)
    }

    /// Converts the former active-shift envelope without installing it into live state.
    /// The v2 bytes are removed only after the v3 write has been read back and validated.
    private func migrateLegacyV2SnapshotIfRequired() throws {
        guard persistenceDefaults.data(forKey: Self.persistenceKey) == nil,
              let legacyData = persistenceDefaults.data(forKey: Self.legacyV2PersistenceKey) else { return }

        let old = try JSONDecoder().decode(Chunk5GLegacyV2Snapshot.self, from: legacyData)
        guard old.evidenceSource == .live else { throw CocoaError(.coderReadCorrupt) }

        let derivedWorkspace: Chunk5FWorkspaceState
        if old.shiftStartedAt != nil && old.shiftEndedAt == nil {
            derivedWorkspace = .active
        } else {
            derivedWorkspace = .preShift
        }

        let derivedFingerprint = try fingerprint(
            compartments: old.compartments,
            visits: old.visits,
            eventLog: old.eventLog,
            ledger: old.cargoLedger,
            reconciliationLog: old.reconciliationLog,
            unresolvedDiscrepancies: old.unresolvedDiscrepancies
        )
        let migrated = Chunk5GLiveSnapshot(
            evidenceSource: old.evidenceSource,
            compartments: old.compartments,
            visits: old.visits,
            eventLog: old.eventLog,
            cargoLedger: old.cargoLedger,
            reconciliationLog: old.reconciliationLog,
            openingBaselineAccepted: old.openingBaselineAccepted,
            shiftStartedAt: old.shiftStartedAt,
            shiftEndedAt: old.shiftEndedAt,
            openingODO: old.openingODO,
            closingODO: old.closingODO,
            cargoOpeningSnapshot: old.cargoOpeningSnapshot,
            unresolvedDiscrepancies: old.unresolvedDiscrepancies,
            dieselCargo: old.dieselCargo,
            ulpCargo: old.ulpCargo,
            selectedVisit: old.selectedVisit,
            selectedFill: old.selectedFill,
            restMinutes: old.restMinutes,
            loadVisitIndex: old.loadVisitIndex,
            workspace: derivedWorkspace,
            runItems: nil,
            authoritativeFingerprint: derivedFingerprint
        )

        try validate(snapshot: migrated)
        let migratedData = try JSONEncoder().encode(migrated)
        persistenceDefaults.set(migratedData, forKey: Self.persistenceKey)

        guard let writtenData = persistenceDefaults.data(forKey: Self.persistenceKey) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let written = try JSONDecoder().decode(Chunk5GLiveSnapshot.self, from: writtenData)
        try validate(snapshot: written)
        guard written.authoritativeFingerprint == derivedFingerprint else {
            throw CocoaError(.coderReadCorrupt)
        }

        persistenceDefaults.removeObject(forKey: Self.legacyV2PersistenceKey)
    }

    private func restoreArchivedGateReport() {
        guard let data = persistenceDefaults.data(forKey: Self.completedPersistenceKey) else { return }
        do {
            let snapshot = try JSONDecoder().decode(Chunk5GLiveSnapshot.self, from: data)
            lastGateReport = try gateReport(fromValidated: snapshot, persistenceStatus: .pass)
        } catch {
            persistenceStatus = .fail
            message = "Previous completed shift archive failed validation: \(error)"
        }
    }

    private func restorePersistedLiveSnapshotOnLaunch() {
        guard evidenceSource == .live else { return }
        restoreArchivedGateReport()
        do {
            try migrateLegacyV2SnapshotIfRequired()
        } catch {
            shiftLifecycle = .recoveryLocked
            persistenceStatus = .fail
            message = "Legacy shift migration failed; original v2 evidence remains preserved: \(error)"
            return
        }
        guard let data=persistenceDefaults.data(forKey:Self.persistenceKey) else { return }
        do {
            let snapshot=try JSONDecoder().decode(Chunk5GLiveSnapshot.self,from:data)
            if snapshot.shiftEndedAt != nil { shiftLifecycle = .completedLocked }
            try validate(snapshot: snapshot)
            // A validated v3 snapshot supersedes legacy v2. Retire v2 now so it
            // cannot resurrect after the current v3 live key is later removed.
            persistenceDefaults.removeObject(forKey: Self.legacyV2PersistenceKey)
            if snapshot.shiftEndedAt != nil {
                try archiveCompletedSnapshot(data, snapshot: snapshot)
                persistenceDefaults.removeObject(forKey: Self.persistenceKey)
                persistenceStatus = .pass
                lastGateReport = try gateReport(fromValidated: snapshot, persistenceStatus: .pass)
                shiftLifecycle = .fresh
                message = "Previous shift validated and archived. Ready for a new shift."
                return
            }
            try installValidated(snapshot:snapshot)
            persistenceStatus = .pass
            message = "Recovered persisted live shift."
        } catch {
            shiftLifecycle = .recoveryLocked
            persistenceStatus = .fail
            message = "Persisted shift recovery failed; stored evidence remains locked: \(error)"
        }
    }

    public func simulateRelaunch() {
        guard let data=persistenceDefaults.data(forKey:Self.persistenceKey) else { message="No snapshot to restore."; return }
        do {
            let snapshot=try JSONDecoder().decode(Chunk5GLiveSnapshot.self,from:data)
            try installValidated(snapshot:snapshot)
            persistenceStatus = .pass
            appendEvent(.relaunch,"Relaunch restored authoritative snapshot")
            message="Relaunch restored authoritative snapshot."
        } catch {
            persistenceStatus = .fail
            message="Relaunch restore failed: \(error)"
        }
    }

    public func buildLiveGateReport() -> Chunk5GGateReport {
        let arithmeticOK = compartments.allSatisfy { (try? CargoStateReconciler.currentState(ledger: cargoLedger, reconciliationLog: reconciliationLog, compartmentID: $0.cargoCompartmentID)) != nil }
        let loadsRepresented = eventLog.filter { $0.kind == .load }.count == Set(cargoLedger.transactions.filter { $0.kind == .load && ($0.note?.hasPrefix("chunk5g.load.op.") ?? false) }.compactMap(\.note)).count
        let deliveriesRepresented = eventLog.filter { $0.kind == .delivery && ($0.deliveryOutcome?.actualLitres ?? 1) > 0 }.count == Set(cargoLedger.transactions.filter { $0.kind == .unload && ($0.note?.hasPrefix("chunk5g.delivery.op.") ?? false) }.compactMap(\.note)).count && eventLog.filter { $0.deliveryOutcome?.actualLitres == 0 }.allSatisfy { $0.relatedOperationID == nil }
        let transfersRepresented = eventLog.filter { $0.kind == .transfer }.count == Set(cargoLedger.transactions.filter { $0.kind == .transfer && ($0.note?.hasPrefix("chunk5g.transfer.op.") ?? false) }.compactMap(\.note)).count
        let reconciliationRepresentation = reconciliationsRepresented(events: eventLog, log: reconciliationLog)
        let correctionRepresentation = correctionsRepresented(events: eventLog, ledger: cargoLedger)
        let odoAnchorsOK = (openingODO ?? 0) > 0 && (closingODO ?? 0) >= (openingODO ?? 0)
        let integrity: Chunk5GCheckStatus = arithmeticOK && odoAnchorsOK && loadsRepresented && deliveriesRepresented && transfersRepresented && reconciliationRepresentation && correctionRepresentation ? .pass : .fail
        return Chunk5GGateReport(shiftStart: shiftStartedAt, shiftEnd: shiftEndedAt, openingODO: openingODO, closingODO: closingODO, events: eventLog, cargoOpening: cargoOpeningSnapshot, cargoClosing: confirmedLitres, unresolvedDiscrepancies: unresolvedDiscrepancies, loadsRepresented: loadsRepresented, deliveriesRepresented: deliveriesRepresented, transfersRepresented: transfersRepresented, reconciliationsRepresented: reconciliationRepresentation, correctionsRepresented: correctionRepresentation, cargoArithmeticOK: arithmeticOK, odoAnchorsOK: odoAnchorsOK, persistenceStatus: persistenceStatus, representationIntegrityStatus: integrity, operationalCompletenessStatus: .notTested, plannedDeliveries: visits.filter { !$0.isTerminalLoad }.flatMap(\.fills).count, completedPlannedDeliveries: visits.filter { !$0.isTerminalLoad }.flatMap(\.fills).filter(\.completed).count)
    }
}
