import Foundation

public struct FuelDeliveryCommit: Codable, Sendable, Equatable {
    public let serviceJobID: CanonicalID
    public let deliveryCardID: CanonicalID
    public let cargoTransactions: [CargoTransaction]
    public let deliveredLitres: Double
    public let occurredAt: Date

    public init(serviceJobID: CanonicalID, deliveryCardID: CanonicalID, cargoTransactions: [CargoTransaction], deliveredLitres: Double, occurredAt: Date) {
        self.serviceJobID = serviceJobID
        self.deliveryCardID = deliveryCardID
        self.cargoTransactions = cargoTransactions
        self.deliveredLitres = deliveredLitres
        self.occurredAt = occurredAt
    }
}

public enum FuelDeliveryCommitError: Error, Equatable {
    case jobCardMismatch
    case productMismatch
    case noConfirmedDelivery
    case pumpNotFinished
    case jobNotActive
    case invalidCompartmentAllocation
    case allocationTotalMismatch
    case cargoCommitFailed
    case serviceCompletionFailed
    case invalidCommit
}

public enum FuelDeliveryCoordinator {
    public static func prepare(
        job: ServiceJob,
        card: FuelDeliveryCard,
        product: FuelProduct,
        compartmentAllocations: [(compartmentID: CanonicalID, litres: Double)],
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered
    ) throws -> FuelDeliveryCommit {
        guard job.id == card.serviceJobID else { throw FuelDeliveryCommitError.jobCardMismatch }
        guard product.id == card.productID else { throw FuelDeliveryCommitError.productMismatch }
        guard job.state == .active else { throw FuelDeliveryCommitError.jobNotActive }
        guard card.pumpFinishedAt != nil else { throw FuelDeliveryCommitError.pumpNotFinished }
        guard let actual = card.actualDeliveredLitres, actual > 0 else { throw FuelDeliveryCommitError.noConfirmedDelivery }
        guard !compartmentAllocations.isEmpty, compartmentAllocations.allSatisfy({ $0.litres > 0 }) else { throw FuelDeliveryCommitError.invalidCompartmentAllocation }
        let allocated = compartmentAllocations.reduce(0) { $0 + $1.litres }
        guard abs(allocated - actual) < 0.000001 else { throw FuelDeliveryCommitError.allocationTotalMismatch }
        let transactions = compartmentAllocations.map {
            FuelCargoAdapter.delivery(product: product, litres: $0.litres, from: $0.compartmentID, occurredAt: occurredAt, provenance: provenance, destinationDescription: "serviceJob:\(job.id.raw.uuidString)")
        }
        return FuelDeliveryCommit(serviceJobID: job.id, deliveryCardID: card.id, cargoTransactions: transactions, deliveredLitres: actual, occurredAt: occurredAt)
    }

    public static func committing(_ commit: FuelDeliveryCommit, job: ServiceJob, cargoLedger: CargoLedger) throws -> (job: ServiceJob, cargoLedger: CargoLedger) {
        guard job.id == commit.serviceJobID, job.state == .active else { throw FuelDeliveryCommitError.jobNotActive }
        guard !commit.cargoTransactions.isEmpty, commit.deliveredLitres > 0 else { throw FuelDeliveryCommitError.invalidCommit }
        guard commit.cargoTransactions.allSatisfy({
            $0.kind == .unload && $0.sourceCompartmentID != nil && $0.destinationCompartmentID == nil && $0.units > 0 && $0.occurredAt == commit.occurredAt
        }) else { throw FuelDeliveryCommitError.invalidCommit }
        guard abs(commit.cargoTransactions.reduce(0) { $0 + $1.units } - commit.deliveredLitres) < 0.000001 else { throw FuelDeliveryCommitError.invalidCommit }
        guard Set(commit.cargoTransactions.map { $0.cargo.id }).count == 1 else { throw FuelDeliveryCommitError.invalidCommit }
        let expectedDestination = "serviceJob:\(job.id.raw.uuidString)"
        guard commit.cargoTransactions.allSatisfy({ $0.note == expectedDestination }) else { throw FuelDeliveryCommitError.invalidCommit }

        var candidateLedger = cargoLedger
        do { for transaction in commit.cargoTransactions { try candidateLedger.append(transaction) } }
        catch { throw FuelDeliveryCommitError.cargoCommitFailed }

        var candidateJob = job
        guard candidateJob.complete(at: commit.occurredAt) else { throw FuelDeliveryCommitError.serviceCompletionFailed }
        return (candidateJob, candidateLedger)
    }
}
