import Foundation

public struct FuelDeliveryCommit: Codable, Sendable, Equatable {
    public let serviceJobID: CanonicalID
    public let deliveryCardID: CanonicalID
    /// Product identity captured at prepare-time and revalidated at commit-time.
    public let productID: CanonicalID
    public let cargoTransactions: [CargoTransaction]
    public let deliveredLitres: Double
    public let occurredAt: Date

    public init(serviceJobID: CanonicalID, deliveryCardID: CanonicalID, productID: CanonicalID, cargoTransactions: [CargoTransaction], deliveredLitres: Double, occurredAt: Date) {
        self.serviceJobID=serviceJobID; self.deliveryCardID=deliveryCardID; self.productID=productID
        self.cargoTransactions=cargoTransactions; self.deliveredLitres=deliveredLitres; self.occurredAt=occurredAt
    }
}

public enum FuelDeliveryCommitError: Error, Equatable {
    case jobCardMismatch, productMismatch, noConfirmedDelivery, pumpNotFinished, jobNotActive
    case invalidCompartmentAllocation, allocationTotalMismatch, cargoCommitFailed, serviceCompletionFailed, invalidCommit
}

public enum FuelDeliveryCoordinator {
    public static func prepare(job:ServiceJob,card:FuelDeliveryCard,product:FuelProduct,compartmentAllocations:[(compartmentID:CanonicalID,litres:Double)],occurredAt:Date,provenance:EventProvenance = .driverEntered)throws->FuelDeliveryCommit {
        guard job.id==card.serviceJobID else{throw FuelDeliveryCommitError.jobCardMismatch}
        guard product.id==card.productID else{throw FuelDeliveryCommitError.productMismatch}
        guard job.state == .active else{throw FuelDeliveryCommitError.jobNotActive}
        guard card.pumpFinishedAt != nil else{throw FuelDeliveryCommitError.pumpNotFinished}
        guard let actual=card.actualDeliveredLitres,actual>0 else{throw FuelDeliveryCommitError.noConfirmedDelivery}
        guard !compartmentAllocations.isEmpty,compartmentAllocations.allSatisfy({$0.litres>0}) else{throw FuelDeliveryCommitError.invalidCompartmentAllocation}
        guard abs(compartmentAllocations.reduce(0){$0+$1.litres}-actual)<0.000001 else{throw FuelDeliveryCommitError.allocationTotalMismatch}
        let transactions=compartmentAllocations.map{FuelCargoAdapter.delivery(product:product,litres:$0.litres,from:$0.compartmentID,occurredAt:occurredAt,provenance:provenance,destinationDescription:"serviceJob:\(job.id.raw.uuidString)")}
        return FuelDeliveryCommit(serviceJobID:job.id,deliveryCardID:card.id,productID:product.id,cargoTransactions:transactions,deliveredLitres:actual,occurredAt:occurredAt)
    }

    /// Commit requires the original card so decoded/externally constructed commits cannot
    /// substitute another product or card while still completing the ServiceJob.
    public static func committing(_ commit:FuelDeliveryCommit,job:ServiceJob,card:FuelDeliveryCard,cargoLedger:CargoLedger)throws->(job:ServiceJob,cargoLedger:CargoLedger) {
        guard job.id==commit.serviceJobID,job.state == .active else{throw FuelDeliveryCommitError.jobNotActive}
        guard card.id==commit.deliveryCardID,card.serviceJobID==job.id else{throw FuelDeliveryCommitError.jobCardMismatch}
        guard card.productID==commit.productID else{throw FuelDeliveryCommitError.productMismatch}
        guard card.pumpFinishedAt != nil,let actual=card.actualDeliveredLitres,actual>0,abs(actual-commit.deliveredLitres)<0.000001 else{throw FuelDeliveryCommitError.invalidCommit}
        guard !commit.cargoTransactions.isEmpty,commit.deliveredLitres>0 else{throw FuelDeliveryCommitError.invalidCommit}
        guard commit.cargoTransactions.allSatisfy({
            $0.kind == .unload && $0.sourceCompartmentID != nil && $0.destinationCompartmentID == nil &&
            $0.units > 0 && $0.occurredAt == commit.occurredAt && $0.cargo.id == commit.productID
        }) else{throw FuelDeliveryCommitError.invalidCommit}
        guard abs(commit.cargoTransactions.reduce(0){$0+$1.units}-commit.deliveredLitres)<0.000001 else{throw FuelDeliveryCommitError.invalidCommit}
        let expectedDestination="serviceJob:\(job.id.raw.uuidString)"
        guard commit.cargoTransactions.allSatisfy({$0.note==expectedDestination}) else{throw FuelDeliveryCommitError.invalidCommit}

        var candidateLedger=cargoLedger
        do{for transaction in commit.cargoTransactions{try candidateLedger.append(transaction)}}catch{throw FuelDeliveryCommitError.cargoCommitFailed}
        var candidateJob=job
        guard candidateJob.complete(at:commit.occurredAt) else{throw FuelDeliveryCommitError.serviceCompletionFailed}
        return(candidateJob,candidateLedger)
    }
}
