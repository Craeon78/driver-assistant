import Foundation

public enum EvidenceStatus: String, Codable, Sendable, CaseIterable {
    case suggested, observed, confirmed, derived, administrative
}

/// Minimal evidence wrapper for operational quantities.
/// Resolution records what the instrument can actually support; it must not be
/// mistaken for mathematical precision of a driver's interpretation.
public struct OperationalQuantityEvidence: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let value: Double
    public let unitName: String
    public let status: EvidenceStatus
    public let occurredAt: Date
    public let recordedAt: Date
    public let provenance: EventProvenance
    public let resolution: Double?
    public let sourceDescription: String?

    public init(
        id: CanonicalID = .fresh(),
        value: Double,
        unitName: String,
        status: EvidenceStatus,
        occurredAt: Date,
        recordedAt: Date = Date(),
        provenance: EventProvenance = .driverEntered,
        resolution: Double? = nil,
        sourceDescription: String? = nil
    ) {
        self.id = id; self.value = value; self.unitName = unitName; self.status = status
        self.occurredAt = occurredAt; self.recordedAt = recordedAt; self.provenance = provenance
        self.resolution = resolution; self.sourceDescription = sourceDescription
    }
}

/// Fuel's rich evidence attached to a generic Operations ServiceJob.
/// It contains no transported-inventory balance; Cargo remains the quantity truth source.
public struct FuelDeliveryCard: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let serviceJobID: CanonicalID
    public let productID: CanonicalID
    public var expectedDeliveryLitres: ConfirmedValue<Double>
    public var expectedPumpFinish: Date?
    public var expectedDeparture: Date?
    public private(set) var pumpStartedAt: Date?
    public private(set) var pumpFinishedAt: Date?
    public private(set) var openingLevelEvidence: [OperationalQuantityEvidence]
    public private(set) var closingLevelEvidence: [OperationalQuantityEvidence]
    public private(set) var deliveredLitresEvidence: [OperationalQuantityEvidence]

    public init(
        id: CanonicalID = .fresh(),
        serviceJobID: CanonicalID,
        productID: CanonicalID,
        expectedDeliveryLitres: Double? = nil,
        expectedPumpFinish: Date? = nil,
        expectedDeparture: Date? = nil
    ) {
        self.id = id; self.serviceJobID = serviceJobID; self.productID = productID
        self.expectedDeliveryLitres = ConfirmedValue(suggestedValue: expectedDeliveryLitres)
        self.expectedPumpFinish = expectedPumpFinish; self.expectedDeparture = expectedDeparture
        self.openingLevelEvidence = []; self.closingLevelEvidence = []; self.deliveredLitresEvidence = []
    }

    public mutating func confirmExpectedDelivery(_ litres: Double, at date: Date, provenance: EventProvenance = .driverEntered) {
        expectedDeliveryLitres = expectedDeliveryLitres.confirming(litres, at: date, provenance: provenance)
    }

    public mutating func startPump(at date: Date) -> Bool {
        guard pumpStartedAt == nil else { return false }
        pumpStartedAt = date; return true
    }

    public mutating func finishPump(at date: Date) -> Bool {
        guard pumpFinishedAt == nil, let start = pumpStartedAt, date >= start else { return false }
        pumpFinishedAt = date; return true
    }

    public mutating func recordOpeningLevel(_ evidence: OperationalQuantityEvidence) {
        openingLevelEvidence.append(evidence)
    }

    public mutating func recordClosingLevel(_ evidence: OperationalQuantityEvidence) {
        closingLevelEvidence.append(evidence)
    }

    public mutating func recordDeliveredLitres(_ evidence: OperationalQuantityEvidence) {
        deliveredLitresEvidence.append(evidence)
    }

    public var actualDeliveredLitres: Double? {
        deliveredLitresEvidence.last(where: { $0.status == .confirmed || $0.status == .observed })?.value
    }

    public var pumpDuration: TimeInterval? {
        guard let start = pumpStartedAt, let finish = pumpFinishedAt else { return nil }
        return finish.timeIntervalSince(start)
    }
}
