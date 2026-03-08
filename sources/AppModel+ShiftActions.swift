import SwiftUI

import Foundation

//======================================

// MARK: - AppModel+ShiftActions

//======================================

  

extension AppModel {

    // MARK: - Activity button gates (Part C)

    /// True when it is safe to change activity.

    /// This prevents "buttons dead", half-started shift states, and switching during prompts.

    var canChangeActivityNow: Bool {

        // Must be on a shift

        guard isOnDuty else { return false }

        // Must not be in an ODO capture prompt

        guard odoPromptContext == nil else { return false }

        // Must not be in a Guard prompt flow (drive nudge / stopped nudge / etc)

        guard activeGuardPrompt == nil else { return false }

        // Must not be mid-gate for start/end shift

        guard !pendingStartShiftCapture else { return false }

        guard !pendingEndShiftCapture else { return false }

        // Must have completed the shift-start odo capture (your helper)

        guard !isMissingShiftStartOdo else { return false }

        // Must have an active segment to attach evidence + km accumulation

        guard runningSegmentID != nil else { return false }

        return true

    }

    var canPressDrive: Bool {

        canChangeActivityNow && currentActivity != .driving

    }

    var canPressBreak: Bool {

        canChangeActivityNow && currentActivity != .restBreak

    }

    var canPressLoad: Bool {

        canChangeActivityNow && currentActivity != .workLoad

    }

    var canPressUnload: Bool {

        canChangeActivityNow && currentActivity != .workUnload

    }

    var canPressEndShift: Bool {

        // End shift allowed even if you're in work/rest,

        // but not allowed during prompts or while already ending.

        isOnDuty

        && odoPromptContext == nil

        && activeGuardPrompt == nil

        && !pendingEndShiftCapture

        && !pendingStartShiftCapture

        && !isMissingShiftStartOdo

    }

  

    //======================================

    // MARK: - Event logging

    //======================================

    func logEvent(_ kind: EventKind, note: String? = nil, at time: Date = Date()) {

        let event = ShiftEvent(time: time, kind: kind, note: note)

        events.append(event)

        autosave?.requestAutosave(reason: "Event log")

    }

    //======================================

    // MARK: - Tick (for driving time)

    //======================================

    /// Called every second from TodayView's timer.

    /// Only accumulates driving time while `isDriving == true`.

    func tick(now: Date = Date()) {

        // Only accumulate driving time while actually driving

        guard isDriving else {

            lastTick = nil

            return

        }

        if isOnDuty && isGpsConnected {

            motionWatchdogTick()

        }

        if let last = lastTick {

            let delta = now.timeIntervalSince(last)

            // Accept any sane positive delta; reject huge jumps (clock change / app suspended / timer hiccup).

            if delta > 0 && delta < 6 * 3600 {

                driveSecondsToday += delta

            }

        }

        // Always move lastTick forward

        lastTick = now

    }

    //======================================

    // MARK: - Activity engine

    //======================================

    // NOTE ON STATE:

    // - `currentActivity/currentSegmentStart/segmentsToday` is the authoritative source for fatigue maths.

    // - `isOnDuty/isDriving/isOnBreak` are UI convenience flags + drive `tick()` behaviour.

    // If they ever disagree, treat the activity engine as truth and adjust flags accordingly.

    /// Close current segment (if any) and start a new one.

    func startActivity(_ newType: ActivityType) {

        startActivity(newType, at: Date())

    }

    func startActivity(_ newType: ActivityType, at time: Date) {

        // Close existing segment

        if let start = currentSegmentStart, let sid = runningSegmentID {

            let finished = ActivitySegment(id: sid, type: currentActivity, start: start, end: time)

            segmentsToday.append(finished)

            considerGapEstimatePromptIfNeeded(endingSegmentID: sid)

  

            autosave?.requestAutosave(reason: "Activity switch")

        }

        // Switch to new activity

        currentActivity = newType

        if newType == .offDuty {

            currentSegmentStart = nil

            runningSegmentID = nil

        } else {

            currentSegmentStart = time

            runningSegmentID = UUID()            // ✅ NEW segment identity every time

        }

    }

    /// Total WORK seconds today (any work activity).

    /// Includes the current in-progress work segment (if any).

    var workSecondsToday: TimeInterval {

        var total: TimeInterval = 0

        let now = Date()

        for seg in segmentsToday {

            guard seg.type.isWork else { continue }

            let end = seg.end ?? now

            total += end.timeIntervalSince(seg.start)

        }

        if let start = currentSegmentStart, currentActivity.isWork {

            total += now.timeIntervalSince(start)

        }

        return max(total, 0)

    }

    /// Total REST seconds today (everything that isn't work).

    /// Includes the current in-progress rest segment (if any).

    var restSecondsToday: TimeInterval {

        var total: TimeInterval = 0

        let now = Date()

        for seg in segmentsToday {

            guard !seg.type.isWork else { continue }

            let end = seg.end ?? now

            total += end.timeIntervalSince(seg.start)

        }

        if let start = currentSegmentStart, !currentActivity.isWork {

            total += now.timeIntervalSince(start)

        }

        return max(total, 0)

    }

    // Close the current segment and start a new one.

        // If leaving a legal break (>=15m), require odo+suburb BEFORE switching.

        private func switchActivityWithLegalBreakGate(

            to newType: ActivityType,

            log kind: EventKind?,

            note: String? = nil

        ) {

            guard isOnDuty else { return }

            // ✅ Shift-start ODO gate: if we haven't captured shift-start yet,

            // queue this activity change and prompt for ODO.

            if pendingStartShiftCapture || isMissingShiftStartOdo {

                // Queue the switch to run AFTER the ODO capture commits

                pendingActionAfterOdo = { [weak self] in

                    guard let self = self else { return }

                    // Do the actual switch now (no further gating needed here)

                    self.isDriving = (newType == .driving)

                    self.isOnBreak = (!newType.isWork && newType != .offDuty)

                    self.lastTick = self.isDriving ? Date() : nil

                    self.startActivity(newType)

                    if let kind {

                        self.logEvent(kind, note: note)

                    }

                }

                // Only show the prompt if it's not already on screen

                if odoPromptContext == nil {

                    requestOdoCapture(.shiftStart)

                }

                return

            }

            let now = Date()

            // Detect: are we currently on a rest break, and is it legal?

            // Detect: are we currently in a restBreak segment?

            let leavingRestBreak = (currentActivity == .restBreak)

            let breakStart = currentSegmentStart ?? now

            let breakSeconds = leavingRestBreak ? now.timeIntervalSince(breakStart) : 0

            let isLegalBreak = leavingRestBreak && breakSeconds >= FatigueConstants.legalBreak15

            // The actual switch work (what we want to happen AFTER any odo gate)

            let performSwitch: () -> Void = { [weak self] in

                guard let self = self else { return }

                // Update UI flags based on newType

                self.isDriving = (newType == .driving)

                self.isOnBreak = (!newType.isWork && newType != .offDuty)

                if self.isDriving { self.lastTick = Date() } else { self.lastTick = nil }

                self.startActivity(newType)

                // Only log an event if caller asked for one

                if let kind {

                    self.logEvent(kind, note: note)

                }

            }

            // If leaving a legal break, odo capture is mandatory before switching

            if isLegalBreak {

                requestOdoCapture(.legalBreakEnd, afterSave: performSwitch)

                return

            }

            // Otherwise switch immediately

            performSwitch()

        }

    //======================================

    // MARK: - Shift / drive / break actions

    //======================================

    /// Starts a new shift and resets "today/shift" tracking.

    /// - Parameter previousMinutes: Manual backfill to account for work done before opening the app.

    ///   This creates a synthetic earlier WORK segment so fatigue calculations reflect the full shift.

    ///   (Phase 1 only — persistence will replace this with real history.)

    func startShift(previousMinutes: Int, backfillKind: BackfillKind = .onDutyNotDriving) {

          let now = time.now()

        // ✅ Compliance TZ (Mode B): freeze at shift start for NHVR counting

        // Capture the timezone in effect at the moment the shift begins (not after backfill).

        sessionBaseTimeZoneID = TimeZone.current.identifier  // if you have this persisted field

        DebugLog.lifecycle("🕒 Compliance TZ locked: \(sessionBaseTimeZoneID)")

      let clampedMinutes = min(max(previousMinutes, 0), 240) // Phase 1 cap: 4 hours

        let previousSeconds = TimeInterval(clampedMinutes * 60)

        events.removeAll()

        segmentsToday.removeAll()

        isOnDuty = true

        isDriving = false

        isOnBreak = false

        let backdatedStart = now.addingTimeInterval(-previousSeconds)

        shiftStartTime = backdatedStart

        if clampedMinutes > 0 {

            let backfillType: ActivityType = {

                switch backfillKind {

                case .onDutyNotDriving: return .workGeneral

                case .driving:         return .driving

                case .rest:            return .restBreak

                case .other(let a):    return a.isWork ? .workGeneral : .restBreak

                }

            }()

            segmentsToday.append(ActivitySegment(type: backfillType, start: backdatedStart, end: now))

            driveSecondsToday = (backfillKind == .driving) ? previousSeconds : 0

        } else {

            driveSecondsToday = 0

        }

        lastTick = nil

        // Don’t start live segment until odo is committed

        currentActivity = .offDuty

        currentSegmentStart = nil

        // Optional backfill note event

        if clampedMinutes > 0 {

            switch backfillKind {

            case .other(let act):   logEvent(.other, note: "Backfill — \(act.name)", at: backdatedStart)

            case .driving:          logEvent(.other, note: "Backfill — Driving", at: backdatedStart)

            case .rest:             logEvent(.other, note: "Backfill — Rest", at: backdatedStart)

            case .onDutyNotDriving: logEvent(.other, note: "Backfill — On duty (Paperwork)", at: backdatedStart)

            }

        }

        pendingStartShiftCapture = true

        odoPromptTimestampOverride = shiftStartTime

        requestOdoCapture(.shiftStart)

        autosave?.markResumableNow(reason: "Shift started")

        autosave?.requestAutosave(reason: "Shift started", immediate: true)

    }

  

        var activityDisabledReason: String? {

            if !isOnDuty { return "Start shift to enable activities." }

            if odoPromptContext != nil { return "Finish odometer capture first." }

            if activeGuardPrompt != nil { return "Respond to the prompt first." }

            if pendingStartShiftCapture { return "Confirm shift-start odometer first." }

            if pendingEndShiftCapture { return "Finalising shift — please wait." }

            if isMissingShiftStartOdo { return "Shift-start odometer is required." }

            if runningSegmentID == nil { return "Activity engine not ready (no segment)." }

            return nil

        }

    func pressDrive() {

        guard canPressDrive else { return }

        switchActivityWithLegalBreakGate(to: .driving, log: .driveStart)

    }

    func pressBreak() {

        guard canPressBreak else { return }

        switchActivityWithLegalBreakGate(to: .restBreak, log: .breakStart)

    }

    func pressLoad() {

        if !canPressLoad {

            DebugLog.lifecycle("❌ pressLoad blocked:  \(activityDisabledReason ?? "unknown")")

            return

        }

        DebugLog.lifecycle("✅ pressLoad allowed")

        isUnloadMode = false

        switchActivityWithLegalBreakGate(to: .workLoad, log: nil)

    }

    func pressUnload() {

        guard canPressUnload else { return }

        isUnloadMode = true

        switchActivityWithLegalBreakGate(to: .workUnload, log: nil)

    }

    func pressIncidentQuick() {

        // Pre-persistence: treat it as an EVENT only, do NOT change segments automatically.

        // (Later: incident types can optionally become segments.)

        logEvent(.incident)

    }

    func endShift() {

        guard isOnDuty else { return }

        let now = Date()

        let leavingRest = !currentActivity.isWork

        let breakStart = currentSegmentStart ?? now

        let breakSeconds = leavingRest ? now.timeIntervalSince(breakStart) : 0

        let isLegalBreak = leavingRest && breakSeconds >= FatigueConstants.legalBreak15

        // If we’re leaving a legal break, do THAT capture first, then shift end capture.

        if isLegalBreak {

            requestOdoCapture(.legalBreakEnd, afterSave: { [weak self] in

                guard let self = self else { return }

                self.pendingEndShiftCapture = true

                self.requestOdoCapture(.shiftEnd)

            })

            return

        }

        pendingEndShiftCapture = true

        requestOdoCapture(.shiftEnd)

    }

    func finalizeEndShift() {

        let now = Date()

        // Close any running segment

        startActivity(.offDuty)

        // Build summary (keep)

        let shiftStart = shiftStartTime ?? .distantPast

        let loads = confirmedLoads.filter { $0.timestamp >= shiftStart && $0.mode == .loadConfirmed }.count

        let unloads = confirmedLoads.filter { $0.timestamp >= shiftStart && $0.mode == .unloadSnapshot }.count

        gpsShiftMetersLive = 0

        requestLmResetShiftMetersFromUI?("Shift ended (finalizeEndShift)")

        lastShiftSummary = ShiftSummary(

            date: now,

            start: shiftStartTime,

            end: now,

            workSeconds: workSecondsToday,

            restSeconds: restSecondsToday,

            driveSeconds: driveSecondsToday,

            loadCount: loads,

            unloadCount: unloads

        )

        // Turn shift OFF

        isOnDuty = false

        isDriving = false

        isOnBreak = false

        shiftStartTime = nil

        driveSecondsToday = 0

        lastTick = nil

        // Clear "within-shift only" state (your policy)

        events.removeAll()

        segmentsToday.removeAll()

        confirmedLoads.removeAll()

        unloadFinalised = false

        isUnloadMode = false

        suppressPlacardUntilNextConfirm = false

        // Optional: clear current load plan UI (draft)

        for i in compartments.indices {

            compartments[i].litresText = ""

            compartments[i].selectedProduct = nil

            compartments[i].isDegassed = false

        }

        // Clear prompts/timers etc

        resetTransientWorkflows()

        // ✅ This is the key: kill resumability + remove the files

        autosave?.markNotResumableNow(reason: "Shift ended", clearFiles: true)

        saveStore.clearAutosaves()

    }

    //======================================

    // MARK: - Other activities

    //======================================

    func openIncidentSheet() {

        // If a prompt is stuck on screen, kill it first

        activeGuardPrompt = nil

        beginIncidentDraft()

        isShowingIncidentSheet = true

    }

    /// Start a user-defined "Other" activity (work or rest).

    func startOtherActivity(_ activity: OtherActivity, note: String? = nil) {

        guard isOnDuty else { return }

        isDriving = false

        if activity.isWork {

            isOnBreak = false

            startActivity(.workGeneral)

        } else {

            isOnBreak = true

            startActivity(.restBreak)

        }

        // If driver adds a note, append it after the label

        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let combinedNote = trimmed.isEmpty ? activity.name : "\(activity.name) — \(trimmed)"

        logEvent(.other, note: combinedNote)

    }

}

  

extension AppModel {

    /// Pre-persistence: the canonical segment list for display (finished + current running).

    var timelineSegmentsIncludingCurrent: [ActivitySegment] {

        var segs = segmentsToday

        if let start = currentSegmentStart,

           currentActivity != .offDuty,

           let sid = runningSegmentID {

            segs.append(ActivitySegment(id: sid, type: currentActivity, start: start, end: nil))

        }

        return segs.sorted { $0.start < $1.start }

    } 

    /// Find the most relevant odo record for a segment:

    /// Prefer one that falls within the segment window; otherwise nil.

    func odoRecord(for segment: ActivitySegment) -> OdoLocationRecord? {

        odoLocationRecords.last(where: { $0.segmentID == segment.id })

    }

    /// Events that happened during a segment (pre-persistence)

    func events(during segment: ActivitySegment) -> [ShiftEvent] {

        let segEnd = segment.end ?? Date()

        return events.filter { $0.time >= segment.start && $0.time <= segEnd }

    }

    /// Confirmed loads during a segment (pre-persistence)

    func confirmedLoadsDuring(_ segment: ActivitySegment) -> [ConfirmedLoad] {

        let segEnd = segment.end ?? Date()

        return confirmedLoads.filter { $0.timestamp >= segment.start && $0.timestamp <= segEnd }

    }

    func considerGapEstimatePromptIfNeeded(endingSegmentID sid: UUID) {

        guard let pendingSid = pendingGapSegmentID,

              pendingSid == sid

        else { return }

        guard let meters = pendingGapEstimateMeters else {

            // We detected a gap but have no estimate; still can prompt for odo capture if you want.

            pendingGapSegmentID = nil

            pendingGapReason = nil

            return

        }

        let km = meters / 1000.0

        // ✅ Use your existing GuardPrompt pipe (shown globally in ContentView)

        activeGuardPrompt = GuardPrompt(

            title: "Distance gap detected",

            message: """

        The app was inactive and likely missed GPS updates.

        Estimated road distance: \(String(format: "%.1f", km)) km.

        \(pendingGapReason ?? "")

        Confirm with odometer?

        """,

            actions: [

                GuardAction(title: "Apply estimate", role: nil) { [weak self] in

                    guard let self else { return }

                    self.finalisedKmBySegment[sid, default: 0] += km

                    Task { @MainActor in

                        self.clearBackgroundGapState(reason: "User applied estimate")

                    }

                },

                GuardAction(title: "Capture odo now", role: nil) { [weak self] in

                    guard let self else { return }

                    Task { @MainActor in

                        self.clearBackgroundGapState(reason: "User chose capture odo")

                        self.requestOdoCapture(.odoUpdate)

                    }

                },

                GuardAction(title: "Ignore", role: .cancel) { [weak self] in

                    Task { @MainActor in

                        self?.clearBackgroundGapState(reason: "User ignored gap")

                    }

                }

            ]

        )

    }

    private func clearPendingGap() {

        pendingGapEstimateMeters = nil

        pendingGapSegmentID = nil

        pendingGapReason = nil

    }

}
