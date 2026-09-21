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

    public private(set) var cargoLedger: CargoLedger
    public private(set) var reconciliationLog: CargoReconciliationLog
    private var dieselCargo: CargoKind
    private var ulpCargo: CargoKind
    private var draftBaseline: [Int] = []
    private var loadVisitIndex: Int? = nil

    public static let availableProducts = ["XLS", "ULP"]
    private static let persistenceKey = "chunk5g.live.snapshot.v2"

    public convenience init() {
        self.init(evidenceSource: .live)
    }

    public init(evidenceSource: Chunk5GEvidenceSource) {
        self.evidenceSource = evidenceSource
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
        } else {
            self.compartments = prototypeCompartments
            self.cargoLedger = ledger
            self.draftLitres = Array(repeating: 0, count: prototypeCompartments.count)
            self.draftBaseline = self.draftLitres
            self.visits = []
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

    // MARK: - Opening baseline (reconciliation boundary — not a Load)

    public func setOpeningDraft(compartment index: Int, litres: Int) {
        guard draftLitres.indices.contains(index), !openingBaselineAccepted else { return }
        draftLitres[index] = min(max(0, litres), compartments[index].capacityLitres)
    }

    public func acceptOpeningBaseline() {
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
    }

    // REST OF FILE CONTINUES IN NEXT COMMIT - SEE REPO
}
