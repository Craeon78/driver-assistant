import Foundation

//======================================

// MARK: - AppModel+RestLogic

//======================================

//

//======================================

// MARK: - Phase 1 Start Planning (pre-persistence, single-day only)

//======================================

// Phase 1 goal: provide a simple "earliest next start" + "latest finish" planner

// without rolling 24h / multi-day rules (those require persistence).

// Assumptions:

// - "Legal rest today" = sum of rest segments ≥ 15 minutes (see FatigueRules.swift).

// - Post-shift rest requirement is approximated as:

//   max(7h continuous rest, (12h total rest target - legal rest already taken today)).

// This is a planning heuristic and will be refined in Phase 3+.

  

extension AppModel {

    /// Phase 1 definition of "legal rest today":

    /// sum of rest segments ≥ 15 minutes (see `totalLegalRestToday` in FatigueRules.swift).

    var phase1_restToday: TimeInterval {

        totalLegalRestToday

    }

    /// Phase 1 post-shift rest requirement (planning heuristic).

    /// Returns the minimum rest needed after finishing, based on:

    /// - 7h continuous rest minimum, and

    /// - a 12h "total rest target" where today's already-taken legal rest counts toward the 12h.

    /// Note: This does NOT implement rolling 24h windows or multi-day NHVR logic (Phase 3+).

    func phase1_requiredRestAfterShift(restToday: TimeInterval) -> TimeInterval {

        let needForTotal = max(FatigueConstants.targetTotalRest24h - restToday, 0)

        let needForContinuous = FatigueConstants.minContinuousRest

        return max(needForContinuous, needForTotal)

    }

  

    /// Phase 1: can the driver legally start work *immediately* (same day proxy)?

    ///

    /// Intent:

    /// - If the driver ends a short "test/admin" shift, the app should not imply

    ///   they must take 7h continuous rest before doing anything else.

    /// - This answers: "Can I start again now under today's proxy limits?"

    ///

    /// Notes:

    /// - Still NOT a rolling 24h engine (Phase 3+).

    /// - Uses today's proxies:

    ///   • 12h daily cap

    ///   • 5h15 spacing between ≥15m legal rests

    ///   • 7h30/10h thresholds requiring 30m/60m legal rest (today proxy)

    func phase1_canStartAgainNow() -> Bool {

        let workToday = workSecondsToday

        let legalRest = totalLegalRestToday

        let workSinceLegal15 = workSecondsSinceLastLegalRest(minBreak: FatigueConstants.legalBreak15)

        // 12h cap proxy

        if workToday >= FatigueConstants.nhvrDailyCap { return false }

        // 5h15 spacing proxy

        if workSinceLegal15 >= FatigueConstants.nhvrSpacingLimit { return false }

        // Threshold proxies

        if workToday >= FatigueConstants.nhvrSevenPointFiveHours && 

            legalRest < FatigueConstants.requiredRestAt7h30 { 

            return false 

        }

        if workToday >= FatigueConstants.nhvrTenHours && 

            legalRest < FatigueConstants.requiredRestAt10h { 

            return false 

        }

        return true

    }

  

    /// Earliest next start time if you finish at `end`, using Phase 1 rest requirement.

    func phase1_earliestNextStart(from end: Date) -> Date {

        // If today's proxy limits still allow work, you can start again immediately.

        // (Ending a short "shift" shouldn't force a 7h rest block in Phase 1.)

        if phase1_canStartAgainNow() {

            return end

        }

        // Otherwise, fall back to the post-shift rest heuristic.

        let required = phase1_requiredRestAfterShift(restToday: phase1_restToday)

        return end.addingTimeInterval(required)

    }

    /// Reverse planner:

    /// Given a desired next start time, calculates the latest finish time

    /// that would still allow enough post-shift rest (Phase 1 heuristic).

    func phase1_backCalculateFinish(desiredStart: Date) -> Phase1StartPlanning {

        let restToday = phase1_restToday

        let requiredAfterShift = phase1_requiredRestAfterShift(restToday: restToday)

        let latestFinish = desiredStart.addingTimeInterval(-requiredAfterShift)

        return Phase1StartPlanning(

            restToday: restToday,

            requiredRestAfterShift: requiredAfterShift,

            latestFinishToStartAtDesired: latestFinish

        )

    }

}

  

extension AppModel {

    /// NHVR "legal rest" today = sum of rest segments >= 15 minutes.

    var legalRestSecondsToday: TimeInterval {

        // If you already have totalLegalRestToday, use that instead.

        totalLegalRestToday

    }

    /// Short rest today = rest segments < 15 minutes (these count as WORK for NHVR rolling windows).

    var shortRestSecondsToday: TimeInterval {

        max(restSecondsToday - legalRestSecondsToday, 0)

    }

    /// NHVR work today = work + short rest (because <15m rest counts as work).

    var nhvrWorkSecondsToday: TimeInterval {

        workSecondsToday + shortRestSecondsToday

    }

    /// NHVR rest today = legal rest only (>=15m).

    var nhvrRestSecondsToday: TimeInterval {

        legalRestSecondsToday

    }

}

  

//======================================

// MARK: - Rest-in-progress (Limbo) helpers

//======================================

//

// Purpose (Phase 1):

// - While the driver is currently resting, but the break has not yet reached

//   the ≥15m "legal rest" threshold, the UI should not scream ❌.

// - This does NOT change NHVR maths. It only gives the UI a “provisional” state.

//

// Post-persistence:

// - This can become rule-aware (e.g. 30m / 60m targets) and location-aware.

//

  

extension AppModel {

    /// True if the current activity is a REST-type activity (not work, not off duty filter here).

    var isCurrentlyResting: Bool {

        currentSegmentStart != nil && !currentActivity.isWork

    }

    /// Duration (seconds) of the current in-progress rest segment. 0 if not currently resting.

    var currentRestDurationSeconds: TimeInterval {

        guard isCurrentlyResting, let start = currentSegmentStart else { return 0 }

        return max(time.now().timeIntervalSince(start), 0)

    }

    /// Limbo state: currently resting, but not yet qualified as ≥15m legal rest.

    var isInRestLimbo15: Bool {

        guard isCurrentlyResting else { return false }

        let d = currentRestDurationSeconds

        return d > 0 && d < FatigueConstants.legalBreak15

    }

    /// Seconds remaining until the current rest becomes ≥15m legal rest.

    /// Returns 0 if not resting or already qualified.

    var secondsUntilLegal15: TimeInterval {

        guard isCurrentlyResting else { return 0 }

        return max(FatigueConstants.legalBreak15 - currentRestDurationSeconds, 0)

    }

    /// Convenience text hook if you want it later.

    /// (UI can format secondsUntilLegal15 using formatTimeHM.)

    var currentRestIsQualifiedLegal15: Bool {

        guard isCurrentlyResting else { return false }

        return currentRestDurationSeconds >= FatigueConstants.legalBreak15

    }

}

  

extension AppModel {

    private var todayActivitySegmentsIncludingCurrent: [ActivitySegment] {

        let cal = complianceCalendar

        let now = time.now()

        // You already keep today's completed segments here:

        var segs = segmentsToday.filter { cal.isDate($0.start, inSameDayAs: now) }

        // If there's an in-progress activity, synthesize a "current" segment

        if let start = currentSegmentStart,

           cal.isDate(start, inSameDayAs: now),

           currentActivity != .offDuty {

            let current = ActivitySegment(

                type: currentActivity,

                start: start,

                end: nil

            )

            segs.append(current)

        }

        segs.sort { $0.start < $1.start }

        return segs

    }

    /// NHVR work since last ≥minBreak rest.

    /// NHVR work = work + short rest (<15m) because short rest counts as work for NHVR.

    /// Resets only when a rest segment ≥minBreak occurs.

    func nhvrWorkSecondsSinceLastLegalRest(minBreak: TimeInterval) -> TimeInterval {

        let segments = todayActivitySegmentsIncludingCurrent

        var acc: TimeInterval = 0

        let now = time.now()

        for seg in segments.reversed() {

            let end = seg.end ?? now

            let dur = max(end.timeIntervalSince(seg.start), 0)

            if seg.type.isWork {

                acc += dur

            } else {

                if dur >= minBreak {

                    break

                } else {

                    // short rest counts as work for NHVR

                    acc += dur

                }

            }

        }

        return acc

    }

}

  

//======================================

// MARK: - UI payload for Phase 1 start planning

//======================================

  

struct Phase1StartPlanning {

    let restToday: TimeInterval

    let requiredRestAfterShift: TimeInterval

    let latestFinishToStartAtDesired: Date

}
