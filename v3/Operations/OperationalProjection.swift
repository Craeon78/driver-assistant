import Foundation

/// Read-only operational consequence view. It presents what the known plan implies;
/// it does not choose routes, reorder work, or decide whether the driver should proceed.
public struct OperationalProjection: Codable, Sendable, Equatable {
    public let currentJobID: CanonicalID?
    public let currentExpectedCompletion: Date?
    public let currentExpectedDeparture: Date?
    public let nextJobID: CanonicalID?
    public let nextRequiredCargoUnits: Double?
    public let availableCargoUnits: Double?
    public let projectedCargoShortfallUnits: Double?
    public let relevantConstraintAt: Date?
    public let projectedNextArrival: Date?
    public let constraintMarginSeconds: TimeInterval?
    public let generatedAt: Date

    public init(
        currentJobID: CanonicalID? = nil,
        currentExpectedCompletion: Date? = nil,
        currentExpectedDeparture: Date? = nil,
        nextJobID: CanonicalID? = nil,
        nextRequiredCargoUnits: Double? = nil,
        availableCargoUnits: Double? = nil,
        relevantConstraintAt: Date? = nil,
        projectedNextArrival: Date? = nil,
        generatedAt: Date = Date()
    ) {
        self.currentJobID = currentJobID
        self.currentExpectedCompletion = currentExpectedCompletion
        self.currentExpectedDeparture = currentExpectedDeparture
        self.nextJobID = nextJobID
        self.nextRequiredCargoUnits = nextRequiredCargoUnits
        self.availableCargoUnits = availableCargoUnits
        if let required = nextRequiredCargoUnits, let available = availableCargoUnits {
            self.projectedCargoShortfallUnits = max(0, required - available)
        } else {
            self.projectedCargoShortfallUnits = nil
        }
        self.relevantConstraintAt = relevantConstraintAt
        self.projectedNextArrival = projectedNextArrival
        if let constraint = relevantConstraintAt, let arrival = projectedNextArrival {
            self.constraintMarginSeconds = constraint.timeIntervalSince(arrival)
        } else {
            self.constraintMarginSeconds = nil
        }
        self.generatedAt = generatedAt
    }
}

public struct OperationalReplayEvidence: Codable, Sendable, Equatable {
    public let serviceJobID: CanonicalID
    public let plannedArrival: Date?
    public let actualArrival: Date?
    public let plannedCompletion: Date?
    public let actualCompletion: Date?
    public let expectedDeparture: Date?
    public let actualDeparture: Date?
    public let pumpStartedAt: Date?
    public let pumpFinishedAt: Date?
    public let expectedDeliveryUnits: Double?
    public let actualDeliveryUnits: Double?

    public init(job: ServiceJob, card: FuelDeliveryCard? = nil) {
        serviceJobID = job.id
        plannedArrival = job.plannedArrival
        actualArrival = job.actualArrival
        plannedCompletion = job.plannedCompletion
        actualCompletion = job.actualCompletion
        expectedDeparture = card?.expectedDeparture
        actualDeparture = job.actualDeparture
        pumpStartedAt = card?.pumpStartedAt
        pumpFinishedAt = card?.pumpFinishedAt
        expectedDeliveryUnits = card?.expectedDeliveryLitres.suggestedValue
        actualDeliveryUnits = card?.actualDeliveredLitres
    }

    public var arrivalDeltaSeconds: TimeInterval? {
        guard let plannedArrival, let actualArrival else { return nil }
        return actualArrival.timeIntervalSince(plannedArrival)
    }

    public var completionDeltaSeconds: TimeInterval? {
        guard let plannedCompletion, let actualCompletion else { return nil }
        return actualCompletion.timeIntervalSince(plannedCompletion)
    }

    public var departureDeltaSeconds: TimeInterval? {
        guard let expectedDeparture, let actualDeparture else { return nil }
        return actualDeparture.timeIntervalSince(expectedDeparture)
    }

    public var deliveryDeltaUnits: Double? {
        guard let expectedDeliveryUnits, let actualDeliveryUnits else { return nil }
        return actualDeliveryUnits - expectedDeliveryUnits
    }
}

public enum OperationalProjectionBuilder {
    public static func currentAndNext(
        currentJob: ServiceJob?,
        currentCard: FuelDeliveryCard?,
        nextJob: ServiceJob?,
        nextRequiredCargoUnits: Double?,
        availableCargoUnits: Double?,
        projectedNextArrival: Date?,
        relevantConstraintAt: Date?,
        generatedAt: Date = Date()
    ) -> OperationalProjection {
        OperationalProjection(
            currentJobID: currentJob?.id,
            currentExpectedCompletion: currentCard?.expectedPumpFinish ?? currentJob?.plannedCompletion,
            currentExpectedDeparture: currentCard?.expectedDeparture,
            nextJobID: nextJob?.id,
            nextRequiredCargoUnits: nextRequiredCargoUnits,
            availableCargoUnits: availableCargoUnits,
            relevantConstraintAt: relevantConstraintAt,
            projectedNextArrival: projectedNextArrival,
            generatedAt: generatedAt
        )
    }
}
