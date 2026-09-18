import Foundation
import SwiftUI

public struct FieldTestSnapshot: Codable, Sendable, Equatable {
    public var jobs: [ServiceJob]
    public var cards: [FuelDeliveryCard]
    public var contexts: [CanonicalID: DeliveryContext]
    public var products: [FuelProduct]
    public var compartmentIDs: [CanonicalID]
    public var cargoLedger: CargoLedger
    public var reconciliationLog: CargoReconciliationLog
}

@MainActor
public final class FieldTestStore: ObservableObject {
    @Published public private(set) var snapshot: FieldTestSnapshot
    private let persistenceURL: URL?

    public var products: [FuelProduct] { snapshot.products }
    public var compartmentIDs: [CanonicalID] { snapshot.compartmentIDs }

    public init(snapshot: FieldTestSnapshot, persistenceURL: URL? = nil) {
        self.snapshot = snapshot
        self.persistenceURL = persistenceURL
    }

    public static func fiveCompartmentFixture(persistenceURL: URL? = nil) throws -> FieldTestStore {
        if let url = persistenceURL, FileManager.default.fileExists(atPath: url.path) {
            let restored = try JSONDecoder().decode(FieldTestSnapshot.self, from: Data(contentsOf: url))
            return FieldTestStore(snapshot: restored, persistenceURL: url)
        }
        let compartments = (0..<5).map { _ in CanonicalID.fresh() }
        let products = FuelCatalogue.supportedNames.map { FuelProduct(name: $0.name, code: $0.code, family: $0.family) }
        let ledger = try CargoLedger(limits: compartments.map { CargoCompartmentLimit(compartmentID: $0, capacityUnits: 8000) })
        let snapshot = FieldTestSnapshot(
            jobs: [], cards: [], contexts: [:], products: products, compartmentIDs: compartments,
            cargoLedger: ledger, reconciliationLog: try CargoReconciliationLog()
        )
        let store = FieldTestStore(snapshot: snapshot, persistenceURL: persistenceURL)
        store.persist()
        return store
    }

    public func establishStartingCargo(product: FuelProduct, litres: Double, compartmentID: CanonicalID) throws {
        guard litres > 0, snapshot.products.contains(where: { $0.id == product.id }) else { return }
        var candidate = snapshot.cargoLedger
        try candidate.append(CargoTransaction(
            kind: .load, cargo: product.cargoKind, units: litres,
            destinationCompartmentID: compartmentID, occurredAt: Date(),
            provenance: .driverEntered, note: "5E field-test starting cargo"
        ))
        snapshot.cargoLedger = candidate
        persist()
    }

    public func addJob(product: FuelProduct, expectedLitres: Double?, context: DeliveryContext) {
        guard snapshot.products.contains(where: { $0.id == product.id }) else { return }
        let job = ServiceJob(identity: ServiceJobIdentity())
        let card = FuelDeliveryCard(serviceJobID: job.id, productID: product.id, expectedDeliveryLitres: expectedLitres)
        snapshot.jobs.append(job)
        snapshot.cards.append(card)
        snapshot.contexts[job.id] = context
        persist()
    }

    public func mutateJob(_ id: CanonicalID, _ body: (inout ServiceJob) -> Void) {
        guard let index = snapshot.jobs.firstIndex(where: { $0.id == id }) else { return }
        body(&snapshot.jobs[index]); persist()
    }

    public func mutateCard(for jobID: CanonicalID, _ body: (inout FuelDeliveryCard) -> Void) {
        guard let index = snapshot.cards.firstIndex(where: { $0.serviceJobID == jobID }) else { return }
        body(&snapshot.cards[index]); persist()
    }

    public func commitDelivery(jobID: CanonicalID, allocations: [(CanonicalID, Double)], occurredAt: Date = Date()) throws {
        guard let jobIndex = snapshot.jobs.firstIndex(where: { $0.id == jobID }),
              let cardIndex = snapshot.cards.firstIndex(where: { $0.serviceJobID == jobID }),
              let product = snapshot.products.first(where: { $0.id == snapshot.cards[cardIndex].productID }) else { return }
        let commit = try FuelDeliveryCoordinator.prepare(
            job: snapshot.jobs[jobIndex], card: snapshot.cards[cardIndex], product: product,
            compartmentAllocations: allocations.map { (compartmentID: $0.0, litres: $0.1) }, occurredAt: occurredAt
        )
        let result = try FuelDeliveryCoordinator.committing(
            commit, job: snapshot.jobs[jobIndex], card: snapshot.cards[cardIndex], cargoLedger: snapshot.cargoLedger
        )
        snapshot.jobs[jobIndex] = result.job
        snapshot.cargoLedger = result.cargoLedger
        persist()
    }

    public func reconcile(compartmentID: CanonicalID, confirmedPhysicalLitres: Double, observedMovementVariance: Double? = nil, note: String? = nil) throws {
        let current = try CargoStateReconciler.currentState(
            ledger: snapshot.cargoLedger, reconciliationLog: snapshot.reconciliationLog, compartmentID: compartmentID
        )
        guard let quantity = current.quantity else { return }
        var candidate = snapshot.reconciliationLog
        try candidate.append(CargoReconciliationEvent(
            compartmentID: compartmentID, cargo: quantity.cargo,
            calculatedUnitsBefore: quantity.units, confirmedPhysicalUnitsAfter: confirmedPhysicalLitres,
            observedMovementVariance: observedMovementVariance, occurredAt: Date(),
            provenance: .driverEntered, note: note
        ))
        _ = try CargoStateReconciler.currentState(
            ledger: snapshot.cargoLedger, reconciliationLog: candidate, compartmentID: compartmentID
        )
        snapshot.reconciliationLog = candidate
        persist()
    }

    public func persist() {
        guard let persistenceURL else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            // Persistence is crash insurance only; failure never fabricates domain success.
        }
    }
}
