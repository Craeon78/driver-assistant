
import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

// This application and its contents are proprietary and confidential.

//======================================

// MARK: - Fatigue Rule Models + Today Helpers (Phase 1)

//======================================

//

// Purpose:

// 1. Define `FatigueRuleState` (UI row model for Today fatigue section)

// 2. Provide Phase 1 helper methods on AppModel:

//    - workSecondsSinceLastLegalRest()

//    - totalLegalRestToday

//    - dailyFatigueRules() → builds rule rows for UI

//

// Important (Phase 1 scope):

// - "Today-only" proxies (not true rolling windows)

// - Legal rest = sum of >=15m blocks (today session)

// - Work since last rest = work after the most recent >=15m rest

//

// Post-persistence evolution:

// - These helpers will query SQLite for multi-day windows

// - Rolling 24h / 7-day / 14-day calculations replace today-only

// - Same function signatures, smarter implementations

//

// Separation of concerns:

// - This file: UI models + helper methods

// - FatigueCountdownLogic.swift: countdown rule picker (pure logic)

// - AppModel+RestLogic.swift: planning helpers (earliest start, etc)

//

//======================================

  

enum FatigueRuleStatus {

    case ok

    case warning

    case over

}

  

  

/// One row shown in Today → Fatigue.

/// `worked` and `limit` are in seconds (TimeInterval).

struct FatigueRuleState: Identifiable {

    let id = UUID()

    let title: String

    let detail: String

    let worked: TimeInterval

    let limit: TimeInterval

    /// Remaining time until limit (clamped at 0 for display).

    var remaining: TimeInterval {

        max(limit - worked, 0)

    }

    /// 0.0 = none used, 1.0 = at limit, >1.0 = over.

    var ratio: Double {

        guard limit > 0 else { return 0 }

        return worked / limit

    }

    /// Simple traffic-light for the progress bar.

    /// Note: "over" means you've reached/exceeded the limit (ratio >= 1.0),

    /// not that you have breached a specific NHVR offence in Phase 1.

    var status: FatigueRuleStatus {

        guard limit > 0 else { return .ok }

        let r = ratio

        if r >= 1.0 { return .over }

        if r >= 0.8 { return .warning }

        return .ok

    }

}

  

//======================================

// MARK: - APPMODEL FATIGUE HELPERS (PHASE 1)

//======================================

  

extension AppModel {

    /// Work time (WORK seconds, not clock time) since the last *legal* rest segment

    /// of at least `minBreak`.

    ///

    /// Definitions (Phase 1):

    /// - "WORK" is any `ActivityType` where `isWork == true`.

    /// - "REST" is any `ActivityType` where `isWork == false`.

    /// - A "legal rest segment" for this helper is a REST segment whose duration >= minBreak.

    ///

    /// Implementation notes:

    /// - We include the current in-progress segment (if any) by appending a synthetic segment with end=nil.

    /// - We scan for the *last* qualifying rest segment and anchor from its end time.

    /// - Then we sum WORK time after that anchor.

    ///

    /// Phase 1 limitation:

    /// - This does not do rolling-window logic; it is “today/session” based.

    func workSecondsSinceLastLegalRest(

        minBreak: TimeInterval = FatigueConstants.legalBreak15,

        now: Date? = nil

    ) -> TimeInterval {

        let now = now ?? time.now()

        // Collect all segments, including the current in-progress one.

        var allSegments = segmentsToday

        if let start = currentSegmentStart {

            let current = ActivitySegment(

                type: currentActivity,

                start: start,

                end: nil

            )

            allSegments.append(current)

        }

        guard !allSegments.isEmpty else { return 0 }

        // Sort by start time to ensure we evaluate in chronological order.

        allSegments.sort { $0.start < $1.start }

        // Find the end time of the last "legal" rest segment (REST duration >= minBreak).

        var lastLegalRestEnd: Date? = nil

        for seg in allSegments {

            let segEnd = seg.end ?? now

            guard !seg.type.isWork else { continue } // REST only

            let duration = segEnd.timeIntervalSince(seg.start)

            if duration >= minBreak {

                lastLegalRestEnd = segEnd

            }

        }

        // If we've never had a legal rest, anchor at the very first segment start.

        let anchor = lastLegalRestEnd ?? allSegments.first!.start

        // Sum all WORK time that occurs after `anchor`.

        var totalWork: TimeInterval = 0

        for seg in allSegments {

            let segEnd = seg.end ?? now

            if segEnd <= anchor { continue }          // ends before anchor

            guard seg.type.isWork else { continue }    // WORK only

            let effectiveStart = max(seg.start, anchor)

            totalWork += segEnd.timeIntervalSince(effectiveStart)

        }

        return max(totalWork, 0)

    }

    /// Total "legal" rest today (sum of REST segments that are >= 15 minutes).

    ///

    /// Purpose:

    /// - Used by Phase 1 “threshold” rows (7.5 / 10) and the countdown helper as a proxy.

    ///

    /// Phase 1 limitation:

    /// - This is not a rolling-window calculation; it is “today/session” only.

    var totalLegalRestToday: TimeInterval {

        let now = time.now()

        var total: TimeInterval = 0

        // Completed segments

        for seg in segmentsToday {

            guard !seg.type.isWork else { continue }

            let end = seg.end ?? now

            let duration = end.timeIntervalSince(seg.start)

            if duration >= FatigueConstants.legalBreak15 {

                total += duration

            }

        }

        // Current in-progress REST segment (only counts once it reaches 15 minutes)

        if let start = currentSegmentStart, !currentActivity.isWork {

            let duration = now.timeIntervalSince(start)

            if duration >= FatigueConstants.legalBreak15 {

                total += duration

            }

        }

        return max(total, 0)

    }

    /// Builds a Phase 1 list of “today” fatigue rules for the UI.

    ///

    /// IMPORTANT: Separation of concerns (Phase 1):

    /// - Company policy lives here (e.g. “5h target between preferred breaks”).

    /// - NHVR “fine-risk” rules / rolling windows are handled separately by:

    ///   - countdown logic (determineNextRule)

    ///   - TodayView threshold rows (labelled as NHVR/proxy)

    func dailyFatigueRules(now _: Date = Date()) -> [FatigueRuleState] {

        var rules: [FatigueRuleState] = []

        // 1) COMPANY POLICY (example):

        // removed for phase 1. return phase 3

        // 2–4) Phase 1 “today-only” thresholds (proxy).

        // These are UI cues that become meaningful once the work threshold is reached.

        // The actual rolling-window NHVR implementation arrives post-persistence.

        rules.append(

            FatigueRuleState(

                title: "Work today (7.5h threshold)",

                detail: "At ≥7.5h work (today proxy), aim for ≥30m legal breaks",

                worked: workSecondsToday,

                limit: FatigueConstants.nhvrSevenPointFiveHours

            )

        )

        rules.append(

            FatigueRuleState(

                title: "Work today (10h threshold)",

                detail: "At ≥10h work (today proxy), aim for ≥60m legal breaks",

                worked: workSecondsToday,

                limit: FatigueConstants.nhvrTenHours

            )

        )

        rules.append(

            FatigueRuleState(

                title: "Work today (12h cap)",

                detail: "Simple cap – 12h work max in a day (Phase 1 proxy)",

                worked: workSecondsToday,

                limit: FatigueConstants.nhvrDailyCap

            )

        )

        return rules

    }

}
