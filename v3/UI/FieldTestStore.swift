import Foundation

public struct FieldTestSnapshot: Codable, Sendable, Equatable {
    public var jobs: [ServiceJob]
    public var cards: [FuelDeliveryCard]
    public var contexts: [CanonicalID: DeliveryContext]
    public var cargoLedger: CargoLedger
    public var reconciliationLog: CargoReconciliationLog
}

@MainActor
public final class FieldTestStore: ObservableObject {
    @Published public private(set) var snapshot: FieldTestSnapshot
    public let products: [FuelProduct]
    public let compartmentIDs: [CanonicalID]
    private let persistenceURL: URL?

    public init(snapshot: FieldTestSnapshot, products: [FuelProduct], compartmentIDs: [CanonicalID], persistenceURL: URL? = nil) {
        self.snapshot = snapshot
        self.products = products
        self.compartmentIDs = compartmentIDs
        self.persistenceURL = persistenceURL
    }

    public static func fiveCompartmentFixture(persistenceURL: URL? = nil) throws -> FieldTestStore {
        let compartments = (0..<5).map { _ in CanonicalID.fresh() }
        let product = FuelProduct(name: "Diesel", code: "DIESEL", family: .diesel)
        let ledger = try CargoLedger(limits: compartments.map { CargoCompartmentLimit(compartmentID: $0, capacityUnits: 8000) })
        let snapshot = FieldTestSnapshot(jobs: [], cards: [], contexts: [:], cargoLedger: ledger, reconciliationLog: try CargoReconciliationLog())
        return FieldTestStore(snapshot: snapshot, products: [product], compartmentIDs: compartments, persistenceURL: persistenceURL)
    }

    public func addJob(product: FuelProduct, expectedLitres: Double?, context: DeliveryContext) {
        let job = ServiceJob(identity: ServiceJobIdentity())
        let card = FuelDeliveryCard(serviceJobID: job.id, productID: product.id, expectedDeliveryLitres: expectedLitres)
        snapshot.jobs.append(job)
        snapshot.cards.append(card)
        snapshot.contexts[job.id] = context
        persist()
    }

    public func mutateJob(_ id: CanonicalID, _ body: (inout ServiceJob) -> Void) {
        guard let index = snapshot.jobs.firstIndex(where: { $0.id == id }) else { return }
        body(&snapshot.jobs[index])
        persist()
    }

    public func mutateCard(for jobID: CanonicalID, _ body: (inout FuelDeliveryCard) -> Void) {
        guard let index = snapshot.cards.firstIndex(where: { $0.serviceJobID == jobID }) else { return }
        body(&snapshot.cards[index])
        persist()
    }

    public func commitDelivery(jobID: CanonicalID, allocations: [(CanonicalID, Double)], occurredAt: Date = Date()) throws {
        guard let jobIndex = snapshot.jobs.firstIndex(where: { $0.id == jobID }),
              let cardIndex = snapshot.cards.firstIndex(where: { $0.serviceJobID == jobID }),
              let product = products.first(where: { $0.id == snapshot.cards[cardIndex].productID }) else { return }
        let commit = try FuelDeliveryCoordinator.prepare(
            job: snapshot.jobs[jobIndex],
            card: snapshot.cards[cardIndex],
            product: product,
            compartmentAllocations: allocations.map { (compartmentID: $0.0, litres: $0.1) },
            occurredAt: occurredAt
        )
        let result = try FuelDeliveryCoordinator.committing(
            commit,
            job: snapshot.jobs[jobIndex],
            card: snapshot.cards[cardIndex],
            cargoLedger: snapshot.cargoLedger
        )
        snapshot.jobs[jobIndex] = result.job
        snapshot.cargoLedger = result.cargoLedger
        persist()
    }

    public func persist() {
        guard let persistenceURL else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            // Field-test persistence failure must never fabricate domain success.
        }
    }

    public func restoreIfPresent() throws {
        guard let persistenceURL, FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        snapshot = try JSONDecoder().decode(FieldTestSnapshot.self, from: Data(contentsOf: persistenceURL))
    }
}
