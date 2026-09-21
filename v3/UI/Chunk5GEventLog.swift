import Foundation

/// Minimal chronological event for 5G reconstruction (Slice F) and Gate Report (Slice G).
public struct Chunk5GEvent: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: Kind
    public let summary: String
    public let detail: String

    public enum Kind: String, Codable, Sendable {
        case shiftStart, shiftEnd
        case load, delivery, transfer, reconciliation
        case correction
        case workRest
        case planChange
        case cargoBaseline
        case relaunch
    }

    public init(id: UUID = UUID(), timestamp: Date = Date(), kind: Kind, summary: String, detail: String = "") {
        self.id = id; self.timestamp = timestamp; self.kind = kind
        self.summary = summary; self.detail = detail
    }
}

/// Convenience alias used by the 5G store / gate builders.
public typealias Chunk5GEventKind = Chunk5GEvent.Kind

/// End-Shift Gate Report (Slice G) — derived solely from DA records.
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
    public var cargoArithmeticOK: Bool
    public var odoAnchorsOK: Bool
    public var persistenceOK: Bool

    public var externalComparisonNote: String { "EXTERNAL REPORT COMPARISON: NOT YET CHECKED" }

    public init(
        shiftStart: Date? = nil, shiftEnd: Date? = nil,
        openingODO: Int? = nil, closingODO: Int? = nil,
        events: [Chunk5GEvent] = [],
        cargoOpening: [Int] = [], cargoClosing: [Int] = [],
        unresolvedDiscrepancies: Int = 0,
        loadsRepresented: Bool = true, deliveriesRepresented: Bool = true,
        transfersRepresented: Bool = true, reconciliationsRepresented: Bool = true,
        cargoArithmeticOK: Bool = true, odoAnchorsOK: Bool = true, persistenceOK: Bool = true
    ) {
        self.shiftStart = shiftStart; self.shiftEnd = shiftEnd
        self.openingODO = openingODO; self.closingODO = closingODO
        self.events = events
        self.cargoOpening = cargoOpening; self.cargoClosing = cargoClosing
        self.unresolvedDiscrepancies = unresolvedDiscrepancies
        self.loadsRepresented = loadsRepresented; self.deliveriesRepresented = deliveriesRepresented
        self.transfersRepresented = transfersRepresented; self.reconciliationsRepresented = reconciliationsRepresented
        self.cargoArithmeticOK = cargoArithmeticOK; self.odoAnchorsOK = odoAnchorsOK; self.persistenceOK = persistenceOK
    }
}
