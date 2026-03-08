
import Foundation

  

  

// =========================

// FatigueRuleModels.swift

// =========================

//

//  Shared model types for fatigue rules, countdowns, and future multi-day status.

//  NOTE: This file is intentionally "types only" (no business logic).

//  Safe to extend without affecting current Phase 1 behaviour.

//

//  Phase 1 scope:

//  - FatigueRuleID enum defines canonical rule identifiers

//  - RuleStatusLevel provides traffic-light states (ok/warning/breached)

//  - FatigueRuleStatusV2 is a future-ready status payload

//

//  Post-persistence scope:

//  - Multi-day support types (WorkDaySummary, MultiDayFatigueStatus)

//  - Night rest tracking

//  - Rolling window summaries

//

//  Design principle:

//  - These are data structures, not calculations

//  - Calculations live in Logic/ folder

//  - UI uses these as view models

//

  

  

//======================================

// MARK: - Rule Identifiers

//======================================

  

  

/// Canonical identifiers for fatigue rules.

/// These IDs let UI + logic refer to the same rule without string keys.

///

/// Notes on intent:

/// - Some IDs mirror Phase 1 UI (pre-persistence “today proxies”).

/// - Some IDs represent true NHVR rolling-window rules (Phase 3+).

/// - A few IDs may sound similar; keep them distinct on purpose so the UI

///   can label “policy coaching” vs “legal breach” clearly.

enum FatigueRuleID: String, Hashable, CaseIterable, Codable {

    // MARK: Phase 1 “today” / shift-facing rules (pre-persistence)

    /// Company coaching rule: aim to take a preferred 30m break around 5h work.

    /// (Not an NHVR infringement rule — used for early warning.)

    case fiveHourCompanySoft

    /// NHVR spacing rule proxy: max 5h15 work between qualifying rests.

    /// (Pre-persistence proxy: does not yet model the full 5h30 window mechanics.)

    case fiveHourFifteenLegal

    /// Today proxy: when ≥7h30 work (8h window proxy), require ≥30m legal rest (today).

    case sevenPointFive

    /// Today proxy: when ≥10h work (11h window proxy), require ≥60m legal rest (today).

    case tenHour

    /// Today proxy hard cap: 12h max work (pre-persistence simplification).

    /// (True NHVR is “12h work in any rolling 24h” — handled later.)

    case workTodayTotal

    // MARK: Phase 3+ rolling window rules (true multi-day / rolling)

    /// True rule: 12h max work in any rolling 24h window (post-persistence).

    case twelveHourCap

    /// Placeholder: ≤6 consecutive work days before a qualifying 24h continuous rest.

    case sixConsecutiveDays

    /// Placeholder: ≤72h work in any rolling 7 days.

    case weekly72Hours

    /// Placeholder: ≤144h work in any rolling 14 days.

    case fortnight144Hours

    // MARK: Night rest rules (post-persistence)

    /// Placeholder: at least 4 night rests in 14 days (definition implemented later).

    case nightRestFourInFourteen

    /// Placeholder: at least 2 consecutive night rests (definition implemented later).

    case nightRestTwoConsecutive

    // MARK: Optional / legacy mapping (kept for backwards UI phrasing)

    /// Legacy-friendly alias: “work since last break” (typically driven by the spacing rule).

    /// Keep until the UI is fully migrated to the ID set above.

    case workSinceLastBreak

}

  

//======================================

// MARK: - Generic Status Types

//======================================

  

/// High-level traffic-light status for any rule.

/// Kept view-agnostic so multiple panels can reuse it.

enum RuleStatusLevel: String, Codable {

    case ok        // compliant / comfortably within limits

    case warning   // approaching limit, attention needed

    case breached  // non-compliant or exceeded

}

  

/// Generic status payload for any fatigue rule.

/// Designed to support:

/// - Phase 1 tick-box rows (7.5h, 10h, 12h)

/// - “next rule” countdown card

/// - Phase 3+ multi-day panels (72h/7 days, night rests, etc.)

struct FatigueRuleStatusV2: Identifiable, Codable {

    /// Which rule this status refers to.

    let id: FatigueRuleID

    /// Short title for UI (e.g. "7h30 threshold", "Night rests").

    var title: String

    /// Optional one-liner explanation / hint.

    var message: String?

    /// Traffic-light status.

    var level: RuleStatusLevel

    /// Optional progress 0.0 ... 1.0 for bars / rings.

    /// Example: workSoFar / limit, workedDays / 6, etc.

    var progress: Double?

    /// Optional minutes remaining until breach (work-time based for Phase 1).

    /// For rolling-window rules, this may become “minutes remaining in window” later.

    var minutesUntilBreach: Int?

    /// Optional legal rest minutes accumulated (useful for 7h30/10h thresholds and night rests).

    var legalRestMinutes: Int?

    var isBreached: Bool { level == .breached }

    var isWarning: Bool { level == .warning }

}

  

//======================================

// MARK: - Multi-day Support Types (Phase 3+)

//======================================

  

/// Summary of one calendar day used for multi-day rules.

/// Persistence will populate this from stored segments / events.

struct WorkDaySummary: Codable {

    /// Midnight-anchored date (local calendar day).

    var date: Date

    /// Total *work* minutes logged that day (driving + other work).

    var workMinutes: Int

    /// Total minutes counted as “legal rest” (e.g. ≥15m blocks).

    var legalRestMinutes: Int

    /// Placeholder: whether this day contained a qualifying night rest.

    /// Exact definition (time window + continuous duration) is implemented later.

    var hadNightRest: Bool

}

  

/// Aggregate status for multi-day rules.

/// The UI can render this as a separate “Multi-day” panel post-persistence.

struct MultiDayFatigueStatus: Codable {

    /// Last N days considered (e.g. last 14).

    var days: [WorkDaySummary]

    /// Computed status for each multi-day rule.

    var ruleStatuses: [FatigueRuleStatusV2]

}
