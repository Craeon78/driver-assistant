
import Foundation

// © 2026 Cory Russell Olsen. All rights reserved.

// This application and its contents are proprietary and confidential.

//======================================

// MARK: - Fatigue Countdown Logic (Rule Picker)

//======================================

//

// Purpose:

// - Determine which rule is "on the radar" (due soonest or already breached)

// - Shared between TodayView (live) and SimulationView (what-if)

// - Single source of truth for countdown bar logic

//

// Scope (Phase 1 / Pre-persistence):

// - Today-only proxies (not true rolling 24h windows)

// - Uses work/rest totals from current session only

// - No multi-day accumulation yet

//

// Post-persistence evolution:

// - Will operate on queried windows (last 7/14/28 days)

// - True rolling 24h / 7-day / 14-day calculations

// - Same function signature, smarter inputs

//

// Design principles:

// - Deterministic (same inputs → same output)

// - Explainable (UI can show *why* a rule is next)

// - Severity-aware (countdown thresholds inform UI color/urgency)

//

//======================================

  

//======================================

// MARK: - Rule window identifiers (for UI + severity thresholds)

//======================================

  

/// Which logical window/threshold the countdown belongs to (used only for UI severity rules).

enum RuleWindow {

    case work5h15_in5h30

    case work7h30_in8h

    case work10h_in11h

    case work12h_in24h

}

  

/// How urgent the countdown is for UI treatment.

/// - `breached` means remaining < 0.

enum CountdownSeverity {

    case normal

    case caution

    case warning

    case critical

    case breached

}

  

/// Convert remaining time into a severity bucket.

/// `remaining` is seconds until due; can be negative after breach.

func countdownSeverity(

    forRemaining remaining: TimeInterval,

    window: RuleWindow

) -> CountdownSeverity {

    let mins = remaining / 60.0

    switch window {

    case .work5h15_in5h30, .work7h30_in8h, .work10h_in11h:

        if mins > 60 { return .normal }    // > 60 min

        if mins > 30 { return .caution }   // 60–30

        if mins > 15 { return .warning }   // 30–15

        if mins >= 0 { return .critical }  // 15–0

        return .breached                   // < 0

    case .work12h_in24h:

        if mins > 60 { return .normal }    // > 60 min

        if mins >= 0 { return .warning }   // 60–0

        return .breached                   // < 0

    }

}

  

//======================================

// MARK: - Output payload

//======================================

  

/// Payload describing whichever rule is currently “on the radar”.

struct CountdownRuleInfo {

    /// Stable key for UI/debug (not shown to driver).

    let key: String              // e.g. "5.25h", "7.5h", "10h", "12h"

    /// UI title line.

    let title: String            // e.g. "Next rule: 5.25h rule"

    /// Text prefix used by the UI to build the subtitle sentence.

    let descriptionPrefix: String

    /// Seconds remaining; may be negative once breached.

    let remaining: TimeInterval

    /// The limit/threshold in seconds this rule is counting toward.

    let limit: TimeInterval

    /// Which window bucket it belongs to (controls severity thresholds).

    let window: RuleWindow

}

  

//======================================

// MARK: - Rule picker used by Today (+ later Sim)

//======================================

  

/// Determine the “next” rule to show in the countdown panel.

/// Selection logic:

/// 1) If ANY rule is already breached (remaining < 0), return the one closest to zero

///    (most recently broken).

/// 2) Otherwise return the rule with the smallest positive remaining (due soonest).

func determineNextRule(

    workSinceRest: TimeInterval,

    workToday: TimeInterval,

    legalRest: TimeInterval

) -> CountdownRuleInfo {

    struct Candidate {

        let remaining: TimeInterval   // < 0 = breached, >= 0 = future

        let info: CountdownRuleInfo

    }

    // Phase 1 thresholds (seconds)

    // - 5.25h spacing threshold is based on WORK since last legal rest

    // - 7.5h / 10h thresholds are based on WORK today + required legal rest today

    // - 12h is a simple daily cap in Phase 1 (not rolling 24h)

    let workLimit_5h15 = FatigueConstants.nhvrSpacingLimit

    let workLimit_7h30 = FatigueConstants.nhvrSevenPointFiveHours

    let workLimit_10h = FatigueConstants.nhvrTenHours

    let workLimit_12h = FatigueConstants.nhvrDailyCap

    var candidates: [Candidate] = []

    // 1) 5h15 spacing rule — always track it, even when breached

    // NOTE (Phase 1 UX semantics):

    // The 5h15 spacing rule currently shows as "OK" (green) while work is below the threshold.

    // This is legally correct (not breached), but semantically premature for drivers,

    // who interpret green as "requirement satisfied" rather than "not yet due".

    // This will be reworked post-persistence to distinguish:

    //   - not yet due

    //   - approaching threshold

    //   - breached

    // without marking the rule as satisfied before a qualifying legal rest resets it.

    do {

        let remaining = workLimit_5h15 - workSinceRest

        let info = CountdownRuleInfo(

            key: "5.25h",

            title: "Next rule: 5.25h rule",

            descriptionPrefix: "If you keep working without extra legal rest, you'll hit the 5.25h rule",

            remaining: remaining,

            limit: workLimit_5h15,

            window: .work5h15_in5h30

        )

        candidates.append(Candidate(remaining: remaining, info: info))

    }

    // Helper for “daily threshold + required rest” rules (7.5h, 10h)

    func addDailyRule(

        key: String,

        title: String,

        description: String,

        limit: TimeInterval,

        requiredRest: TimeInterval,

        window: RuleWindow

    ) {

        let workOverLimit = workToday - limit

        let restShortfall = requiredRest - legalRest

        // Case A: threshold reached AND rest requirement already met → ignore

        if workToday >= limit && restShortfall <= 0 {

            return

        }

        // Case B: not yet at threshold

        if workToday < limit {

            // If you’ve already banked enough legal rest, you cannot fail this rule.

            guard restShortfall > 0 else { return }

            let remaining = limit - workToday

            let info = CountdownRuleInfo(

                key: key,

                title: title,

                descriptionPrefix: description,

                remaining: remaining,

                limit: limit,

                window: window

            )

            candidates.append(Candidate(remaining: remaining, info: info))

            return

        }

        // Case C: past threshold and still short on rest → breached

        if restShortfall > 0 {

            let remaining = -workOverLimit   // negative seconds past the threshold

            let info = CountdownRuleInfo(

                key: key,

                title: title,

                descriptionPrefix: description,

                remaining: remaining,

                limit: limit,

                window: window

            )

            candidates.append(Candidate(remaining: remaining, info: info))

        }

    }

    // 2) 7.5h rule (needs ≥ 30 min legal rest today)

    addDailyRule(

        key: "7.5h",

        title: "Next rule: 7.5h rule",

        description: "If you keep working without extra legal rest, you'll hit the 7.5h rule",

        limit: workLimit_7h30,

        requiredRest: FatigueConstants.requiredRestAt7h30,

        window: .work7h30_in8h

    )

    // 3) 10h rule (needs ≥ 60 min legal rest today)

    addDailyRule(

        key: "10h",

        title: "Next rule: 10h rule",

        description: "If you keep working without extra legal rest, you'll hit the 10h rule",

        limit: workLimit_10h,

        requiredRest: FatigueConstants.requiredRestAt10h,

        window: .work10h_in11h

    )

  

    // 4) 12h daily cap — always track it

    do {

        let remaining = workLimit_12h - workToday

        let info = CountdownRuleInfo(

            key: "12h",

            title: "Next rule: 12h daily cap",

            descriptionPrefix: "If you keep working without extra legal rest, you'll hit the 12h daily cap",

            remaining: remaining,

            limit: workLimit_12h,

            window: .work12h_in24h

        )

        candidates.append(Candidate(remaining: remaining, info: info))

    }

    // Safety fallback: should never happen, but keep UI stable.

    guard !candidates.isEmpty else {

        let remaining = workLimit_12h - workToday

        return CountdownRuleInfo(

            key: "12h",

            title: "Next rule: 12h daily cap",

            descriptionPrefix: "If you keep working without extra legal rest, you'll hit the 12h daily cap",

            remaining: remaining,

            limit: workLimit_12h,

            window: .work12h_in24h

        )

    }

    // Split into breached vs future

    let breached = candidates.filter { $0.remaining < 0 }

    let future   = candidates.filter { $0.remaining >= 0 }

    // If anything is breached, report the one closest to zero (most recently broken).

    if let mostRecentBreach = breached.sorted(by: { $0.remaining > $1.remaining }).first {

        return mostRecentBreach.info

    }

    // Otherwise, pick the one due soonest.

    let next = future.min(by: { $0.remaining < $1.remaining })!

    return next.info

}
