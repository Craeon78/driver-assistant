//======================================
// MARK: - DiaryProjection (V3 Policy)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Representations over exact Driver ledger truth.
// Projection never mutates canonical timestamps.
//======================================

import Foundation

public enum DiaryProjectionMode: String, Codable, Sendable {
    case actualExact
    case ewdStyle
    case wwd
    case localAreaRecord
}

public struct DiaryProjectedEntry: Identifiable, Sendable, Equatable {
    public let id: CanonicalID
    public let kind: WorkRestKind
    public let actualStart: Date
    public let actualEnd: Date?
    public let displayedStart: Date
    public let displayedEnd: Date?
    public let stationaryRest: Bool
    public let provenance: EventProvenance
}

public enum DiaryProjector {

    public static func project(
        entries: [WorkRestEntry],
        mode: DiaryProjectionMode,
        baseTimeZone: TimeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
    ) -> [DiaryProjectedEntry] {
        entries.map { e in
            let projected = projectedTimes(for: e, mode: mode, baseTimeZone: baseTimeZone)
            return DiaryProjectedEntry(
                id: e.id,
                kind: e.kind,
                actualStart: e.start,
                actualEnd: e.end,
                displayedStart: projected.start,
                displayedEnd: projected.end,
                stationaryRest: e.stationaryRest,
                provenance: e.provenance
            )
        }
    }

    private static func projectedTimes(
        for entry: WorkRestEntry,
        mode: DiaryProjectionMode,
        baseTimeZone: TimeZone
    ) -> (start: Date, end: Date?) {
        switch mode {
        case .actualExact, .localAreaRecord:
            return (entry.start, entry.end)

        case .ewdStyle:
            // Keep occurrence times intact. Completed-minute regulatory credit is
            // evaluated by Policy rather than by rewriting the diary event.
            return (entry.start, entry.end)

        case .wwd:
            // WWD representation is conservative in 15-minute blocks:
            // work is represented so work is not understated; rest so rest is
            // not overstated. This projection is display/reconciliation only.
            guard let end = entry.end else {
                return (floorQuarter(entry.start, timeZone: baseTimeZone), nil)
            }
            if entry.kind == .work {
                return (
                    floorQuarter(entry.start, timeZone: baseTimeZone),
                    ceilQuarter(end, timeZone: baseTimeZone)
                )
            } else {
                return (
                    ceilQuarter(entry.start, timeZone: baseTimeZone),
                    floorQuarter(end, timeZone: baseTimeZone)
                )
            }
        }
    }

    private static func floorQuarter(_ date: Date, timeZone: TimeZone) -> Date {
        let seconds = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: floor(seconds / 900) * 900)
    }

    private static func ceilQuarter(_ date: Date, timeZone: TimeZone) -> Date {
        let seconds = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: ceil(seconds / 900) * 900)
    }
}
