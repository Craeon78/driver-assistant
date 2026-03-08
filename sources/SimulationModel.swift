
import Foundation

  

//======================================

// MARK: - Simulation Model (Fatigue Simulator Only)

//======================================

//

// Purpose:

// - Lightweight sandbox for testing fatigue rules WITHOUT touching live shift data

// - Used ONLY by FatigueSimulationView (in SimulationView.swift)

//

// Critical separation:

// - This model is COMPLETELY ISOLATED from AppModel

// - No shared state, no side effects

// - Changes here do NOT affect the driver's real shift

//

// Why this exists:

// - Pre-persistence testing aid (validate countdown logic)

// - Driver education tool ("what if I work 2 more hours?")

// - Future: may become a planning/forecast engine

//

// Design principles:

// - Simple, deterministic math

// - Mirrors real fatigue rules (uses same FatigueConstants)

// - Always clearly labelled as "simulation" in UI

//

//======================================

  

enum SimActivityType {

  

    case work

    case rest

}

  

struct SimSegment: Identifiable {

    let id = UUID()

    let type: SimActivityType

    let start: TimeInterval

    let end: TimeInterval

    var duration: TimeInterval { end - start }

}

  

/// Represents the next fatigue rule we’re counting down to (simulator UI only).

enum SimFatigueTarget {

    case fiveHoursFifteen(remaining: TimeInterval)

    case sevenPointFive(remainingWork: TimeInterval, remainingRest: TimeInterval)

    case tenHours(remainingWork: TimeInterval, remainingRest: TimeInterval)

    case twelveHours(remaining: TimeInterval)

    case breached(rule: String)   // knows which rule broke

}

  

//======================================

// MARK: - Simulation Model (Fatigue Simulator Only)

//======================================

  

/// A lightweight model used only for the fatigue simulator.

/// This does NOT touch AppModel or real shift data.

///

/// Important: Keep simulator rule maths aligned with the real fatigue engine.

/// If the real rules change, update this file too (or call into shared logic later).

final class SimulationModel: ObservableObject {

    // Legal break threshold (seconds). Simulator mirrors Phase 1 rule: ≥ 15m.

    private let legalBreakSeconds: TimeInterval = FatigueConstants.legalBreak15

    /// A sequence of alternating Work / Rest segments in simulated time.

    @Published var segments: [SimSegment] = []

    /// The last time position chosen by the slider (seconds from "start of scenario").

    @Published var lastSimulatedTime: TimeInterval = 0

    //======================================

    // MARK: - Recording segments

    //======================================

    func addWork(to newTime: TimeInterval) {

        addSegment(type: .work, newTime: newTime)

    }

    func addRest(to newTime: TimeInterval) {

        addSegment(type: .rest, newTime: newTime)

    }

    private func addSegment(type: SimActivityType, newTime: TimeInterval) {

        guard newTime > lastSimulatedTime else { return }

        let seg = SimSegment(

            type: type,

            start: lastSimulatedTime,

            end: newTime

        )

        segments.append(seg)

        lastSimulatedTime = newTime

    }

    //======================================

    // MARK: - Derived totals (simulated "today")

    //======================================

    var workSecondsToday: TimeInterval {

        segments

            .filter { $0.type == .work }

            .map { $0.duration }

            .reduce(0, +)

    }

    /// Total legal rest today (sum of rest segments ≥ 15 minutes).

    var legalRestToday: TimeInterval {

        segments

            .filter { $0.type == .rest && $0.duration >= legalBreakSeconds }

            .map { $0.duration }

            .reduce(0, +)

    }

    /// Same concept as the real engine: work since the *last legal* break.

    func workSinceLastRest() -> TimeInterval {

        var total: TimeInterval = 0

        for seg in segments.reversed() {

            if seg.type == .rest && seg.duration >= legalBreakSeconds {

                break

            }

            if seg.type == .work {

                total += seg.duration

            }

        }

        return total

    }

    //======================================

    // MARK: - Rule picker (simulator-only)

    //======================================

    /// Determine the next rule countdown (simulator approximation).

    /// This is work-time based, not wall-clock based.

    func nextFatigueTarget() -> SimFatigueTarget {

        let work = workSecondsToday

        let rest = legalRestToday

        let sevenFiveLimit: TimeInterval = FatigueConstants.nhvrSevenPointFiveHours

        let tenLimit: TimeInterval      = FatigueConstants.nhvrTenHours

        let twelveLimit: TimeInterval   = FatigueConstants.nhvrDailyCap

        // 0) Check for breaches first (most serious wins)

        if work >= twelveLimit {

            return .breached(rule: "12h daily cap")

        }

        if work >= tenLimit && rest < FatigueConstants.requiredRestAt10h {

            return .breached(rule: "10h rule (60m rest)")

        }

        if work >= sevenFiveLimit && rest < FatigueConstants.requiredRestAt7h30 {

            return .breached(rule: "7.5h rule (30m rest)")

        }

        // 1) No breaches yet – pick the rule with the least remaining work time

        var candidates: [(remaining: TimeInterval, target: SimFatigueTarget)] = []

        // 5.25h since last legal break

        let sinceLast = workSinceLastRest()

        if sinceLast < FatigueConstants.nhvrSpacingLimit {

            let remaining = FatigueConstants.nhvrSpacingLimit - sinceLast

            candidates.append((remaining, .fiveHoursFifteen(remaining: remaining)))

        }

        // 7.5h rule

        if work < sevenFiveLimit {

            let remainingW = sevenFiveLimit - work

            let remainingR = max(FatigueConstants.requiredRestAt7h30 - rest, 0)

            candidates.append((remainingW, .sevenPointFive(remainingWork: remainingW, remainingRest: remainingR)))

        }

        // 10h rule

        if work < tenLimit {

            let remainingW = tenLimit - work

            let remainingR = max(FatigueConstants.requiredRestAt10h - rest, 0)

            candidates.append((remainingW, .tenHours(remainingWork: remainingW, remainingRest: remainingR)))

        }

        // 12h cap

        if work < twelveLimit {

            let remaining = twelveLimit - work

            candidates.append((remaining, .twelveHours(remaining: remaining)))

        }

        // Choose the smallest remaining work time

        if let best = candidates.min(by: { $0.remaining < $1.remaining }) {

            return best.target

        } else {

            // Edge case: no candidates – treat as sitting right on the 12h cap

            return .twelveHours(remaining: 0)

        }

    }

    //======================================

    // MARK: - Reset

    //======================================

    func reset() {

        segments = []

        lastSimulatedTime = 0

    }

}
