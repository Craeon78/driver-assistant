
import SwiftUI

  

extension TodayView {

    //======================================

    // MARK: - Todayview+Fatigue dashboard (right column)

    //

    // Purpose:

    // - Render *today* fatigue indicators using AppModel's current segments.

    //

    // Important constraints (pre-persistence):

    // - These are day-scoped proxies (NOT true rolling windows).

    // - Labels explicitly say "proxy" where NHVR rules are normally rolling.

    // - UI should avoid implying legal compliance guarantees.

    //

    // NOTE ON ICON SEMANTICS:

    // - For 5h15 spacing:

    //   - Grey circle = no ≥15m legal rest logged yet today.

    //   - Green tick = compliant so far since the last ≥15m legal rest.

    //   - Red = breached (worked ≥5h15 since last ≥15m legal rest). post-persistence.

    //======================================

    var workWindowSection: some View {

        let workToday = model.nhvrWorkSecondsToday

        let legalRest = model.totalLegalRestToday

        let inRestLimbo15 = model.isInRestLimbo15

        let limboRemaining15 = model.secondsUntilLegal15

        let hasTakenLegalRest15 = legalRest >= FatigueConstants.legalBreak15

        let twelveHours: TimeInterval = FatigueConstants.nhvrDailyCap

        // NHVR spacing proxy: work since last >=15m legal rest

        let workSinceLegalRest15 = model.nhvrWorkSecondsSinceLastLegalRest(minBreak: FatigueConstants.legalBreak15)

        let ratio = min(workToday / twelveHours, 1.0)

        let elevenHours: TimeInterval = CountdownThresholds.dailyCapWarningThreshold

        let colour: Color

        if workToday <= elevenHours { colour = .green }

        else if workToday <= twelveHours { colour = .orange }

        else { colour = .red }

        return VStack(alignment: .leading, spacing: 12) {

            Text("Fatigue (today • proxy pre-persistence)")

                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {

                HStack {

                    Text("Work today (total NHVR proxy)")

                        .font(.subheadline)

                    Spacer()

                    Text("\(formatTimeHM(workToday)) / 12h 00m")

                        .font(.caption)

                }

                ProgressView(value: ratio)

                    .tint(colour)

                HStack {

                    Text("Total work towards 12h daily cap.")

                    let remaining = max(twelveHours - workToday, 0)

                    Spacer()

                    Text("Remaining: \(formatTimeHM(remaining))")

                }

                .font(.caption2)

                .foregroundColor(.secondary)

            }

            Divider()

                .padding(.vertical, 4)

            // Spacing: true "since last >=15m legal rest" logic (still day-scoped pre-persistence)

            spacingRuleRow(

                title: "5h15 spacing rule (NHVR)",

                description: "Max 5h15 work between ≥15m legal rests.",

                workSinceRest: workSinceLegalRest15,

                limitHours: FatigueConstants.nhvrSpacingLimit / 3600,

                hasTakenLegalRest15: hasTakenLegalRest15,

                inRestLimbo15: inRestLimbo15,

                limboRemaining15: limboRemaining15

            )

            ruleStatusRow(

                title: "7h30 threshold (8h window proxy)",

                description: "If ≥7h30 work, you must have ≥30m legal breaks (today proxy).",

                workToday: workToday,

                limitHours: FatigueConstants.nhvrSevenPointFiveHours / 3600,

                requiredRestSeconds: workToday >= FatigueConstants.nhvrSevenPointFiveHours ? FatigueConstants.legalBreak30 : 0,

                legalRest: legalRest,

                inRestLimbo15: inRestLimbo15,

                limboRemaining15: limboRemaining15

            )

            ruleStatusRow(

                title: "10h threshold (11h window proxy)",

                description: "If ≥10h work, you must have ≥60m legal breaks (today proxy).",

                workToday: workToday,

                limitHours: FatigueConstants.nhvrTenHours / 3600,

                requiredRestSeconds: workToday >= FatigueConstants.nhvrTenHours ? FatigueConstants.legalBreak60 : 0,

                legalRest: legalRest,

                inRestLimbo15: inRestLimbo15,

                limboRemaining15: limboRemaining15

            )

            cap12StatusRow(workToday: workToday)

            nextRuleCountdownSection

            Text("Legal rest today (≥15m blocks): \(formatTimeHM(legalRest))")

                .font(.caption2)

                .foregroundColor(.secondary)

                .padding(.top, 4)

        }

    }

    var nextRuleCountdownSection: some View {

        let workToday     = model.nhvrWorkSecondsToday

        let legalRest     = model.totalLegalRestToday

        let inRestLimbo15 = model.isInRestLimbo15

        let limboRemaining15 = model.secondsUntilLegal15

        let workSinceRest = model.nhvrWorkSecondsSinceLastLegalRest(minBreak: FatigueConstants.legalBreak15)

        let next = determineNextRule(

            workSinceRest: workSinceRest,

            workToday: workToday,

            legalRest: legalRest

        )

        let severity = countdownSeverity(

            forRemaining: next.remaining,

            window: next.window

        )

        // NOTE: This ratio is used as a "remaining" bar, not "progress used".

        // (If you later prefer a "time used" bar, invert this maths.)

        let ratio = max(0.0, min(next.remaining / max(next.limit, 1), 1.0))

        let barColor: Color = {

            switch severity {

            case .normal:   return .green

            case .caution:  return .yellow

            case .warning:  return .orange

            case .critical: return .red

            case .breached: return .red

            }

        }()

        let barOpacity: Double =

        (severity == .breached && countdownFlashOn) ? 0.3 : 1.0

        let remaining = next.remaining

        let remainingText = formatTimeHM(abs(remaining))

        let sign = remaining >= 0 ? "" : "-"

        var subtitleText: String

        var subtitleColor: Color

        // --- Rest-state messaging must override severity messaging ---

        // 1) Limbo: break is happening but < 15m → still counts as work for NHVR.

        if inRestLimbo15 {

            subtitleText = "Rest in progress (<15m) — still counts as NHVR work. Legal rest begins counting in \(formatTimeHM(limboRemaining15))."

            subtitleColor = .secondary

        } else {

            // 2) If currently resting AND we've already crossed ≥15m,

            // NHVR work is paused and remaining time can increase.

            // (We infer "currently resting" from currentActivity; avoids needing extra state.)

            let currentlyResting = !model.currentActivity.isWork && model.isOnDuty

            let currentlyLegalResting = currentlyResting && (model.secondsUntilLegal15 <= 0)

            if currentlyLegalResting {

                subtitleText = "Legal rest in progress (≥15m). NHVR work is paused — remaining time may increase while resting."

                subtitleColor = .secondary

            } else {

                // 3) Normal severity-driven messaging

                switch severity {

                case .breached:

                    let ruleName = next.title.replacingOccurrences(of: "Next rule: ", with: "")

                    subtitleText = "\(ruleName) is now due / exceeded. Take legal rest as soon as practicable."

                    subtitleColor = .red

                case .critical:

                    subtitleText = "\(next.descriptionPrefix) in \(remainingText)."

                    subtitleColor = .red

                default:

                    subtitleText = "\(next.descriptionPrefix) in \(remainingText)."

                    subtitleColor = .secondary

                }

            }

        }

        return VStack(alignment: .leading, spacing: 4) {

            HStack {

                Text(next.title)

                    .font(.subheadline)

                Spacer()

                Text("\(sign)\(remainingText) remaining")

                    .font(.caption)

            }

            ProgressView(value: ratio)

                .tint(barColor)

                .opacity(barOpacity)

                .onAppear {

                    updateCountdownFlashing(for: severity)

                }

                .onChange(of: severity, initial: false) { _, newSeverity in

                    updateCountdownFlashing(for: newSeverity)

                }

            Text(subtitleText)

                .font(.caption2)

                .foregroundColor(subtitleColor)

                .fixedSize(horizontal: false, vertical: true)

        }

        .padding(.top, 8)

    }

    func updateCountdownFlashing(for severity: CountdownSeverity) {

        if severity == .breached {

            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {

                countdownFlashOn = true

            }

        } else {

            countdownFlashOn = false

        }

    }

    //======================================

    // MARK: - Rule rows (UI helpers)

    //======================================

    // Spacing rule row:

    // - Uses work time since last >=15m legal rest

    // - Grey until the first >=15m legal rest exists (avoids “always green” vibe)

    // - Green means "compliant so far since last legal rest"

    // - Red means breached (work since last legal rest >= limit)

    func spacingRuleRow(

        title: String,

        description: String,

        workSinceRest: TimeInterval,

        limitHours: Double,

        hasTakenLegalRest15: Bool,

        inRestLimbo15: Bool,

        limboRemaining15: TimeInterval

    ) -> some View {

        let limitSeconds = FatigueConstants.nhvrSpacingLimit

        if inRestLimbo15 {

            let remaining = formatTimeHM(limboRemaining15)

            return HStack(alignment: .top, spacing: 8) {

                Image(systemName: "hourglass")

                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {

                    Text(title).font(.subheadline)

                    Text(description).font(.caption2).foregroundColor(.secondary)

                    Text("Rest in progress — qualifies as ≥15m legal rest in \(remaining).")

                        .font(.caption2)

                        .foregroundColor(.secondary)

                }

            }

            .padding(.vertical, 2)

        }

        let symbolName: String

        let color: Color

        let statusText: String

        if workSinceRest < limitSeconds {

            let remaining = formatTimeHM(limitSeconds - workSinceRest)

            if !hasTakenLegalRest15 {

                // Before any >=15m legal rest exists today,

                // show neutral “pending” state (like 7.5/10h rows).

                symbolName = "circle"

                color = .gray

                statusText = "No ≥15m legal rest logged yet. First legal rest due in \(remaining)."

            } else {

                // Normal operating state once at least one legal rest exists.

                symbolName = "checkmark.circle.fill"

                color = .green

                statusText = "OK. Next legal rest due in \(remaining)."

            }

        } else {

            symbolName = "xmark.octagon.fill"

            color = .red

            let over = formatTimeHM(workSinceRest - limitSeconds)

            statusText = "Over by \(over). Take ≥15m legal rest ASAP."

        }

        return HStack(alignment: .top, spacing: 8) {

            Image(systemName: symbolName)

                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {

                Text(title)

                    .font(.subheadline)

                Text(description)

                    .font(.caption2)

                    .foregroundColor(.secondary)

                Text(statusText)

                    .font(.caption2)

                    .foregroundColor(color)

            }

        }

        .padding(.vertical, 2)

    }

    func ruleStatusRow(

        title: String,

        description: String,

        workToday: TimeInterval,

        limitHours: Double,

        requiredRestSeconds: TimeInterval,

        legalRest: TimeInterval,

        inRestLimbo15: Bool,

        limboRemaining15: TimeInterval

    ) -> some View {

        let limitSeconds = limitHours * 3600

        let symbolName: String

        let color: Color

        let statusText: String

        if workToday < limitSeconds {

            symbolName = "circle"

            color = .gray

            statusText = "Not yet reached \(String(format: "%.2f", limitHours))h of work."

        } else {

            if inRestLimbo15 && requiredRestSeconds > 0 {

                let remaining = formatTimeHM(limboRemaining15)

                symbolName = "hourglass"

                color = .secondary

                statusText = "Rest in progress — legal rest starts counting in \(remaining)."

            } else if legalRest >= requiredRestSeconds {

                symbolName = "checkmark.circle.fill"

                color = .green

                statusText = "Requirement met (legal rest \(formatTimeHM(legalRest)))."

            } else {

                symbolName = "xmark.octagon.fill"

                color = .red

                let needed = formatTimeHM(requiredRestSeconds)

                let actual = formatTimeHM(legalRest)

                statusText = "Need \(needed) legal rest; currently \(actual)."

            }

        }

        return HStack(alignment: .top, spacing: 8) {

            Image(systemName: symbolName).foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {

                Text(title).font(.subheadline)

                Text(description).font(.caption2).foregroundColor(.secondary)

                Text(statusText).font(.caption2).foregroundColor(color)

            }

        }

        .padding(.vertical, 2)

    }

    func cap12StatusRow(workToday: TimeInterval) -> some View {

        let elevenHours: TimeInterval = CountdownThresholds.dailyCapWarningThreshold

        let twelveHours: TimeInterval = FatigueConstants.nhvrDailyCap

        let symbolName: String

        let color: Color

        let statusText: String

        if workToday < elevenHours {

            symbolName = "checkmark.circle.fill"

            color = .green

            statusText = "Well within 12h daily cap."

        } else if workToday <= twelveHours {

            symbolName = "exclamationmark.triangle.fill"

            color = .orange

            statusText = "Within 1 hour of 12h daily cap."

        } else {

            symbolName = "xmark.octagon.fill"

            color = .red

            statusText = "Exceeded 12h daily cap."

        }

        return HStack(alignment: .top, spacing: 8) {

            Image(systemName: symbolName)

                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {

                Text("12h cap")

                    .font(.subheadline)

                Text("Simple cap – 12h max work in any day.")

                    .font(.caption2)

                    .foregroundColor(.secondary)

                Text(statusText)

                    .font(.caption2)

                    .foregroundColor(color)

            }

        }

        .padding(.vertical, 2)

    }

}
