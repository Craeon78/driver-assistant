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
    public var product: String
    public var confirmedLitres: Int
    public var capacityLitres: Int

    public init(id: Int, product: String, confirmedLitres: Int, capacityLitres: Int) {
        self.id = id; self.product = product
        self.confirmedLitres = confirmedLitres; self.capacityLitres = capacityLitres
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
    @Published public var message = ""

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
        self.compartments = [
            Chunk5FCompartment(id: 1, product: "DIE", confirmedLitres: 4000, capacityLitres: 5360),
            Chunk5FCompartment(id: 2, product: "ULP", confirmedLitres: 0, capacityLitres: 3240),
            Chunk5FCompartment(id: 3, product: "DIE", confirmedLitres: 4500, capacityLitres: 4900),
            Chunk5FCompartment(id: 4, product: "DIE", confirmedLitres: 3200, capacityLitres: 3250),
            Chunk5FCompartment(id: 5, product: "DIE", confirmedLitres: 7200, capacityLitres: 7240)
        ]
        self.draftLitres = compartments.map(\.confirmedLitres)
        self.draftBaseline = self.draftLitres
    }

    public var currentVisit: Chunk5FSiteVisit? {
        guard visits.indices.contains(selectedVisit) else { return nil }
        return visits[selectedVisit]
    }

    public var currentFill: Chunk5FFillItem? {
        guard let visit = currentVisit, visit.fills.indices.contains(selectedFill) else { return nil }
        return visit.fills[selectedFill]
    }

    public var deliveryMovement: Int {
        zip(compartments, draftLitres).reduce(0) { total, pair in
            total + max(0, pair.0.confirmedLitres - pair.1)
        }
    }

    public var plannedDelivery: Int { currentFill?.plannedLitres ?? 0 }
    public var deliveryDifference: Int { deliveryMovement - plannedDelivery }

    public func startShift() {
        workspace = .active
        message = "Shift started — opening ODO checkpoint is a later harness."
    }

    public func openSite(_ index: Int) {
        guard visits.indices.contains(index) else { return }
        selectedVisit = index
        selectedFill = visits[index].fills.firstIndex(where: { !$0.completed }) ?? 0
        resetDraft()
        workspace = .site
    }

    public func beginRest() {
        workspace = .rest
        restMinutes = 18
    }

    public func endRest() {
        workspace = .active
    }

    public func openLoad() {
        resetDraft()
        workspace = .load
    }

    public func resetDraft() {
        draftLitres = compartments.map(\.confirmedLitres)
        draftBaseline = draftLitres
        message = ""
    }

    public func undoDraft() {
        draftLitres = draftBaseline
        message = "Draft reset."
    }

    public func setDraft(compartment index: Int, litres: Int) {
        guard draftLitres.indices.contains(index), compartments.indices.contains(index) else { return }
        draftLitres[index] = min(max(0, litres), compartments[index].capacityLitres)
    }

    public func snapDelivery(compartment index: Int, proposed: Int) -> Int {
        guard compartments.indices.contains(index) else { return proposed }
        let original = compartments[index].confirmedLitres
        let emptyTolerance = max(80, Int(Double(original) * 0.04))
        if proposed <= emptyTolerance { return 0 }

        let movedElsewhere = zip(compartments.indices, zip(compartments, draftLitres)).reduce(0) { total, entry in
            let (otherIndex, pair) = entry
            guard otherIndex != index else { return total }
            return total + max(0, pair.0.confirmedLitres - pair.1)
        }
        let neededHere = max(0, plannedDelivery - movedElsewhere)
        let plannedRemaining = max(0, original - neededHere)
        if abs(proposed - plannedRemaining) <= 120 { return plannedRemaining }
        return proposed
    }

    public func commitDelivery() {
        guard workspace == .site, deliveryMovement > 0 else { return }
        for index in compartments.indices { compartments[index].confirmedLitres = draftLitres[index] }

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
        for index in draftLitres.indices where index < additions.count {
            setDraft(compartment: index, litres: compartments[index].confirmedLitres + additions[index])
        }
        message = "SCAN RESULT — check the whole DA representation against the physical BOL."
    }

    public func commitLoad() {
        guard workspace == .load else { return }
        for index in compartments.indices { compartments[index].confirmedLitres = draftLitres[index] }
        draftBaseline = draftLitres
        message = "Load recorded from driver-confirmed draft."
        workspace = .active
    }
}
