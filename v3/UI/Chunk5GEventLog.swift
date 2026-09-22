import Foundation

public struct Chunk5GCompartmentAdjustment: Codable, Sendable, Equatable {
    public let compartmentIndex: Int
    public let deltaLitres: Int
    public init(compartmentIndex: Int, deltaLitres: Int) {
        self.compartmentIndex = compartmentIndex; self.deltaLitres = deltaLitres
    }
}

public struct Chunk5GTransactionVariance: Codable, Sendable, Equatable {
    public let calculatedLitres: Int
    public let actualLitres: Int
    public let varianceLitres: Int
    public let postTransactionEmpty: Bool?
    public let reconciliationEventIDs: [CanonicalID]
    public let provenance: EventProvenance
    public let note: String?
    public init(calculatedLitres: Int, actualLitres: Int, postTransactionEmpty: Bool?, reconciliationEventIDs: [CanonicalID] = [], provenance: EventProvenance = .driverEntered, note: String? = nil) {
        self.calculatedLitres = calculatedLitres; self.actualLitres = actualLitres
        self.varianceLitres = actualLitres - calculatedLitres
        self.postTransactionEmpty = postTransactionEmpty; self.reconciliationEventIDs = reconciliationEventIDs
        self.provenance = provenance; self.note = note
    }
}

public struct Chunk5GPhysicalCheck: Codable, Sendable, Equatable {
    public let compartmentIndex: Int
    public let calculatedLitres: Int
    public let observedLitres: Int
    public let differenceLitres: Int
    public let reconciliationEventID: CanonicalID
    public let provenance: EventProvenance
    public let note: String?
    public init(compartmentIndex: Int, calculatedLitres: Int, observedLitres: Int, reconciliationEventID: CanonicalID, provenance: EventProvenance = .driverEntered, note: String? = nil) {
        self.compartmentIndex = compartmentIndex; self.calculatedLitres = calculatedLitres
        self.observedLitres = observedLitres; self.differenceLitres = observedLitres - calculatedLitres
        self.reconciliationEventID = reconciliationEventID; self.provenance = provenance; self.note = note
    }
}

public struct Chunk5GInputCorrection: Codable, Sendable, Equatable {
    public let originalEventID: UUID
    public let originalLitres: Int
    public let correctedLitres: Int
    public let deltaLitres: Int
    public let compartmentAdjustments: [Chunk5GCompartmentAdjustment]
    public let correctionTransactionIDs: [CanonicalID]
    public let provenance: EventProvenance
    public let note: String?
    public init(originalEventID: UUID, originalLitres: Int, correctedLitres: Int, compartmentAdjustments: [Chunk5GCompartmentAdjustment], correctionTransactionIDs: [CanonicalID], provenance: EventProvenance = .driverEntered, note: String? = nil) {
        self.originalEventID = originalEventID; self.originalLitres = originalLitres; self.correctedLitres = correctedLitres
        self.deltaLitres = correctedLitres - originalLitres; self.compartmentAdjustments = compartmentAdjustments
        self.correctionTransactionIDs = correctionTransactionIDs; self.provenance = provenance; self.note = note
    }
}

public struct Chunk5GDeliveryOutcome: Codable, Sendable, Equatable {
    public let siteVisitID: UUID
    public let fillID: UUID
    public let runItemID: UUID
    public let plannedLitres: Int
    public let actualLitres: Int
    public let reason: String?
    public let occurredAt: Date
    public let provenance: EventProvenance

    public init(siteVisitID: UUID, fillID: UUID, runItemID: UUID, plannedLitres: Int, actualLitres: Int, reason: String? = nil, occurredAt: Date = Date(), provenance: EventProvenance = .driverEntered) {
        self.siteVisitID = siteVisitID; self.fillID = fillID; self.runItemID = runItemID
        self.plannedLitres = plannedLitres; self.actualLitres = actualLitres
        self.reason = reason; self.occurredAt = occurredAt; self.provenance = provenance
    }
}

/// Minimal chronological event for 5G reconstruction (Slice F) and Gate Report (Slice G).
public struct Chunk5GEvent: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: Kind
    public let summary: String
    public let detail: String
    public let relatedOperationID: String?
    public let relatedRunItemID: UUID?
    public let committedLitres: Int?
    public let transactionVariance: Chunk5GTransactionVariance?
    public let physicalCheck: Chunk5GPhysicalCheck?
    public let inputCorrection: Chunk5GInputCorrection?
    public let deliveryOutcome: Chunk5GDeliveryOutcome?

    public enum Kind: String, Codable, Sendable {
        case shiftStart, shiftEnd
        case load, delivery, transfer, reconciliation
        case transactionVariance, physicalCheck
        case correction
        case workRest, restStart, restEnd
        case planChange
        case cargoBaseline
        case relaunch
    }

    public init(id: UUID = UUID(), timestamp: Date = Date(), kind: Kind, summary: String, detail: String = "", relatedOperationID: String? = nil, relatedRunItemID: UUID? = nil, committedLitres: Int? = nil, transactionVariance: Chunk5GTransactionVariance? = nil, physicalCheck: Chunk5GPhysicalCheck? = nil, inputCorrection: Chunk5GInputCorrection? = nil, deliveryOutcome: Chunk5GDeliveryOutcome? = nil) {
        self.id = id; self.timestamp = timestamp; self.kind = kind
        self.summary = summary; self.detail = detail
        self.relatedOperationID = relatedOperationID; self.relatedRunItemID = relatedRunItemID; self.committedLitres = committedLitres
        self.transactionVariance = transactionVariance; self.physicalCheck = physicalCheck; self.inputCorrection = inputCorrection; self.deliveryOutcome = deliveryOutcome
    }
}

/// Convenience alias used by the 5G store / gate builders.
public typealias Chunk5GEventKind = Chunk5GEvent.Kind

/// End-Shift Gate Report (Slice G) — derived solely from DA records.
public enum Chunk5GCheckStatus: String, Equatable, Sendable { case pass = "PASS", fail = "FAIL", notTested = "NOT TESTED" }

public struct Chunk5GGateReport: Equatable, Sendable {
    public var shiftStart: Date?
    public var shiftEnd: Date?
    public var openingODO: Int?
    public var closingODO: Int?
    public var derivedKm: Int {
        guard let o = openingODO, let c = closingODO else { return 0 }
        return max(0, c - o)
    }
    public var events: [Chunk5GEvent]
    public var cargoOpening: [Int]
    public var cargoClosing: [Int]
    public var unresolvedDiscrepancies: Int
    public var loadsRepresented: Bool
    public var deliveriesRepresented: Bool
    public var transfersRepresented: Bool
    public var reconciliationsRepresented: Bool
    public var correctionsRepresented: Bool
    public var cargoArithmeticOK: Bool
    public var odoAnchorsOK: Bool
    public var persistenceStatus: Chunk5GCheckStatus
    public var representationIntegrityStatus: Chunk5GCheckStatus
    public var operationalCompletenessStatus: Chunk5GCheckStatus
    public var plannedDeliveries: Int
    public var completedPlannedDeliveries: Int

    public var externalComparisonNote: String { "EXTERNAL REPORT COMPARISON: NOT YET CHECKED" }

    public init(
        shiftStart: Date? = nil, shiftEnd: Date? = nil,
        openingODO: Int? = nil, closingODO: Int? = nil,
        events: [Chunk5GEvent] = [],
        cargoOpening: [Int] = [], cargoClosing: [Int] = [],
        unresolvedDiscrepancies: Int = 0,
        loadsRepresented: Bool = true, deliveriesRepresented: Bool = true,
        transfersRepresented: Bool = true, reconciliationsRepresented: Bool = true, correctionsRepresented: Bool = true,
        cargoArithmeticOK: Bool = true, odoAnchorsOK: Bool = true, persistenceStatus: Chunk5GCheckStatus = .notTested,
        representationIntegrityStatus: Chunk5GCheckStatus = .notTested, operationalCompletenessStatus: Chunk5GCheckStatus = .notTested,
        plannedDeliveries: Int = 0, completedPlannedDeliveries: Int = 0
    ) {
        self.shiftStart = shiftStart; self.shiftEnd = shiftEnd
        self.openingODO = openingODO; self.closingODO = closingODO
        self.events = events
        self.cargoOpening = cargoOpening; self.cargoClosing = cargoClosing
        self.unresolvedDiscrepancies = unresolvedDiscrepancies
        self.loadsRepresented = loadsRepresented; self.deliveriesRepresented = deliveriesRepresented
        self.transfersRepresented = transfersRepresented; self.reconciliationsRepresented = reconciliationsRepresented
        self.correctionsRepresented = correctionsRepresented
        self.cargoArithmeticOK = cargoArithmeticOK; self.odoAnchorsOK = odoAnchorsOK; self.persistenceStatus = persistenceStatus
        self.representationIntegrityStatus = representationIntegrityStatus; self.operationalCompletenessStatus = operationalCompletenessStatus
        self.plannedDeliveries = plannedDeliveries; self.completedPlannedDeliveries = completedPlannedDeliveries
    }
}
