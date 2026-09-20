import Foundation
import SwiftUI

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

    public init(id: UUID = UUID(), customer: String, site: String, requestedTime: String? = nil, projectedTime: String, fills: [Chunk5FFillItem]) {
        self.id = id; self.customer = customer; self.site = site
        self.requestedTime = requestedTime; self.projectedTime = projectedTime; self.fills = fills
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
    @Published public var visits: [Chunk5FSiteVisit]
    @Published public var compartments: [Chunk5FCompartment]
    @Published public var draftLitres: [Int]
    @Published public var selectedVisit = 0
    @Published public var selectedFill = 0
    @Published public var restMinutes = 18
    @Published public var prototypeSpeedKmh = 0
    @Published public var message = ""

    public private(set) var cargoLedger: CargoLedger
    private let dieselCargo: CargoKind
    private let ulpCargo: CargoKind
    private var draftBaseline: [Int]

    public init() {
        self.visits = [
            Chunk5FSiteVisit(
                customer: "SEALINK", site: "CLEVELAND", requestedTime: "05:00",
                projectedTime: "04:55",
                fills: [
                    Chunk5FFillItem(name: "Minjerrabah", product: "DIE", plannedLitres: 5000),
                    Chunk5FFillItem(name: "Seabreeze", product: "DIE", plannedLitres: 9000)
                ]
            ),
            Chunk5FSiteVisit(
                customer: "EVERSTIN", site: "HEMMANT", projectedTime: "06:35",
                fills: [Chunk5FFillItem(name: "Tank 1", product: "DIE", plannedLitres: 6500)]
            )
        ]
        let diesel = CargoKind(name: "Diesel", kind: "fuel.diesel", unitName: "L")
        let ulp = CargoKind(name: "ULP", kind: "fuel.ulp", unitName: "L")
        self.dieselCargo = diesel
        self.ulpCargo = ulp

        let prototypeCompartments = [
            Chunk5FCompartment(id: 1, product: "DIE", capacityLitres: 5360),
            Chunk5FCompartment(id: 2, product: "ULP", capacityLitres: 3240),
            Chunk5FCompartment(id: 3, product: "DIE", capacityLitres: 4900),
            Chunk5FCompartment(id: 4, product: "DIE", capacityLitres: 3250),
            Chunk5FCompartment(id: 5, product: "DIE", capacityLitres: 7240)
        ]

        let limits = prototypeCompartments.map {
            CargoCompartmentLimit(
                compartmentID: $0.cargoCompartmentID,
                capacityUnits: Double($0.capacityLitres)
            )
        }

        var ledger = try! CargoLedger(limits: limits)
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
    }

    public var currentVisit: Chunk5FSiteVisit? {
        guard visits.indices.contains(selectedVisit) else { return nil }
        return visits[selectedVisit]
    }

    public var nextIncompleteVisitIndex: Int? {
        visits.indices.first(where: { !visits[$0].isComplete })
    }

    public var nextIncompleteVisit: Chunk5FSiteVisit? {
        guard let index = nextIncompleteVisitIndex else { return nil }
        return visits[index]
    }

    public var currentFill: Chunk5FFillItem? {
        guard let visit = currentVisit, visit.fills.indices.contains(selectedFill) else { return nil }
        return visit.fills[selectedFill]
    }

    public var confirmedLitres: [Int] {
        compartments.map { compartment in
            guard let state = try? cargoLedger.state(compartmentID: compartment.cargoCompartmentID),
                  let quantity = state.quantity else { return 0 }
            return Int(quantity.units.rounded())
        }
    }

    public var deliveryMovement: Int {
        guard let fill = currentFill else { return 0 }
        return compartments.indices.reduce(0) { total, index in
            guard compartments[index].product == fill.product else { return total }
            return total + max(0, confirmedLitres[index] - draftLitres[index])
        }
    }

    public var canReorderRun: Bool { prototypeSpeedKmh <= 5 }
    public var canOpenOperationalWorkspace: Bool { prototypeSpeedKmh <= 5 }

    public var deliveryDraftIsValid: Bool {
        guard let fill = currentFill else { return false }
        let before = confirmedLitres
        for index in compartments.indices {
            if compartments[index].product != fill.product && draftLitres[index] != before[index] { return false }
            if draftLitres[index] > before[index] { return false }
        }
        return deliveryMovement > 0
    }

    public var plannedDelivery: Int { currentFill?.plannedLitres ?? 0 }
    public var deliveryDifference: Int { deliveryMovement - plannedDelivery }

    public func startShift() {
        workspace = .active
        message = "Shift started — opening ODO checkpoint is a later harness."
    }

    public func moveVisit(from source: IndexSet, to destination: Int) {
        guard canReorderRun else {
            message = "Run reorder unavailable while moving."
            return
        }
        visits.move(fromOffsets: source, toOffset: destination)
        message = "Run order updated."
    }

    public func setPrototypeMoving(_ moving: Bool) {
        prototypeSpeedKmh = moving ? 42 : 0
        message = moving ? "Prototype moving state — run is view-only." : "Prototype stationary state — run can be reordered."
    }

    @discardableResult
    public func openSite(_ index: Int) -> Bool {
        guard canOpenOperationalWorkspace else {
            message = "Site workspace unavailable while moving."
            return false
        }
        guard visits.indices.contains(index) else { return false }
        guard let nextFill = visits[index].fills.firstIndex(where: { !$0.completed }) else {
            message = "\(visits[index].customer) — \(visits[index].site) is complete. Review/history is a later path."
            return false
        }
        selectedVisit = index
        selectedFill = nextFill
        resetDraft()
        workspace = .site
        return true
    }

    @discardableResult
    public func openNextIncompleteSite() -> Bool {
        guard let index = nextIncompleteVisitIndex else {
            message = "No incomplete site visits."
            return false
        }
        return openSite(index)
    }

    public func beginRest() {
        workspace = .rest
        restMinutes = 18
    }

    public func endRest() {
        workspace = .active
    }

    public func openLoad() {
        guard canOpenOperationalWorkspace else {
            message = "Load workspace unavailable while moving."
            return
        }
        resetDraft()
        workspace = .load
    }

    public func resetDraft() {
        draftLitres = confirmedLitres
        draftBaseline = draftLitres
        message = ""
    }

    public func undoDraft() {
        draftLitres = draftBaseline
        message = "Draft reset."
    }

    public func setDraft(compartment index: Int, litres: Int) {
        guard draftLitres.indices.contains(index), compartments.indices.contains(index) else { return }
        let clamped = min(max(0, litres), compartments[index].capacityLitres)

        if workspace == .site {
            guard let fill = currentFill else { return }
            guard compartments[index].product == fill.product else {
                message = "\(compartments[index].product) cannot be used for this \(fill.product) fill."
                return
            }
            let before = confirmedLitres[index]
            guard clamped <= before else {
                message = "Delivery cannot increase a compartment. Record a physical discrepancy through reconciliation."
                return
            }
        }

        draftLitres[index] = clamped
    }

    public func snapDelivery(compartment index: Int, proposed: Int) -> Int {
        guard compartments.indices.contains(index), let fill = currentFill,
              compartments[index].product == fill.product else {
            return confirmedLitres.indices.contains(index) ? confirmedLitres[index] : proposed
        }
        let confirmed = confirmedLitres
        let original = confirmed[index]
        let emptyTolerance = max(80, Int(Double(original) * 0.04))
        if proposed <= emptyTolerance { return 0 }

        let movedElsewhere = zip(compartments.indices, zip(confirmed, draftLitres)).reduce(0) { total, entry in
            let (otherIndex, pair) = entry
            guard otherIndex != index else { return total }
            return total + max(0, pair.0 - pair.1)
        }
        let neededHere = max(0, plannedDelivery - movedElsewhere)
        let plannedRemaining = max(0, original - neededHere)
        if abs(proposed - plannedRemaining) <= 120 { return plannedRemaining }
        return proposed
    }

    public func commitDelivery() {
        guard workspace == .site, deliveryDraftIsValid, let fill = currentFill else {
            message = "Delivery draft not committed. Check product and compartment quantities."
            return
        }
        let before = confirmedLitres
        var candidate = cargoLedger
        let now = Date()
        do {
            for index in compartments.indices {
                guard compartments[index].product == fill.product else { continue }
                let removed = before[index] - draftLitres[index]
                guard removed >= 0 else {
                    message = "Delivery draft not committed: compartment increase requires reconciliation."
                    return
                }
                if removed > 0 {
                    let cargo = compartments[index].product == "ULP" ? ulpCargo : dieselCargo
                    try candidate.append(CargoTransaction(
                        kind: .unload, cargo: cargo, units: Double(removed),
                        sourceCompartmentID: compartments[index].cargoCompartmentID,
                        occurredAt: now, provenance: .driverEntered,
                        note: "chunk5f.delivery:\(fill.name)"
                    ))
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

        message = "Confirmed \(deliveryMovement) L movement."
        if let next = visits[selectedVisit].fills.indices.first(where: { !visits[selectedVisit].fills[$0].completed }) {
            selectedFill = next
            resetDraft()
            workspace = .site
        } else {
            resetDraft()
            workspace = .active
        }
    }

    public func simulateBOLScan() {
        // Simulates extracted structured data only. No image is created or retained.
        resetDraft()
        let additions = [1000, 2000, 0, 0, 0]
        let before = confirmedLitres
        for index in draftLitres.indices where index < additions.count {
            setDraft(compartment: index, litres: before[index] + additions[index])
        }
        message = "SCAN RESULT — check the whole DA representation against the physical BOL."
    }

    public func commitLoad() {
        guard workspace == .load else { return }
        let before = confirmedLitres
        var candidate = cargoLedger
        let now = Date()
        do {
            for index in compartments.indices {
                let added = draftLitres[index] - before[index]
                guard added >= 0 else {
                    message = "Load draft cannot silently remove confirmed cargo."
                    return
                }
                if added > 0 {
                    let cargo = compartments[index].product == "ULP" ? ulpCargo : dieselCargo
                    try candidate.append(CargoTransaction(
                        kind: .load, cargo: cargo, units: Double(added),
                        destinationCompartmentID: compartments[index].cargoCompartmentID,
                        occurredAt: now, provenance: .driverEntered,
                        note: "chunk5f.load.confirmed"
                    ))
                }
            }
            cargoLedger = candidate
        } catch {
            message = "Load not committed: \(error)"
            return
        }
        resetDraft()
        message = "Load recorded through CargoLedger from driver-confirmed draft."
        workspace = .active
    }
}
