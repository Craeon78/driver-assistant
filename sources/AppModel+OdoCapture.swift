  

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - AppModel + OdoCapture

//======================================

  

// Purpose:

// - Centralise odo capture helpers and in-load coaching nudges.

// - Keeps AppModel.swift free of sheet/capture workflow methods.

  

// Owns:

// - "You appear stopped" coaching nudge for the Load view.

// - Odo prompt lifecycle (request/commit) + validation.

// - ODO ↔ GPS reconciliation to finalise per-segment kilometres.

// - Load/unload mode toggle handler.

  

// Notes:

// - All @Published stored properties remain in AppModel.swift.

// - Thresholds are sourced from GPSConstants/OdoConstants to avoid magic numbers.

// - ODO capture is authoritative; GPS is evidence used for approximation.

//======================================

  

//======================================

// MARK: - "Stopped while driving" Nudge (in-load view)

//======================================

  

extension AppModel {

    /// Called on every GPS speed update while the Load view is open.

    func considerStoppedNudgeInLoad(speedMps: Double?) {

        guard isOnDuty else { cancelStoppedNudge(); return }

        guard isDriving else { cancelStoppedNudge(); return }

        guard !isOnBreak else { cancelStoppedNudge(); return }

        let now = Date()

        if let last = lastStoppedNudgeAt,

           now.timeIntervalSince(last) < GPSConstants.stoppedNudgeCooldownSeconds {

            return

        }

        guard let s = speedMps, s >= 0 else { return }

        // Moving → reset stop accumulator.

        if s > GPSConstants.minMotionSpeedMps {

            stoppedStartAt = nil

            pendingStoppedNudge?.cancel()

            pendingStoppedNudge = nil

            return

        }

        // First time we detect stopped → start dwell timer.

        if stoppedStartAt == nil {

            stoppedStartAt = now

            scheduleStoppedNudgeCheck()

        }

    }

    /// Called when entering the Load view — primes the nudge if already stopped.

    func primeStoppedNudgeInLoadEntry() {

        guard isOnDuty, isDriving, !isOnBreak else { return }

        guard let s = lastKnownSpeedMps, s >= 0 else { return }

        let now = Date()

        if let last = lastStoppedNudgeAt,

           now.timeIntervalSince(last) < GPSConstants.stoppedNudgeCooldownSeconds {

            return

        }

        if s <= GPSConstants.minMotionSpeedMps, stoppedStartAt == nil {

            stoppedStartAt = now

            scheduleStoppedNudgeCheck()

        }

    }

    func snoozeStoppedNudgeInLoad() {

        lastStoppedNudgeAt = Date()

        stoppedStartAt     = nil

    }

    func scheduleStoppedNudgeCheck() {

        pendingStoppedNudge?.cancel()

        let workItem = DispatchWorkItem { [weak self] in

            guard let self else { return }

            let now = Date()

            if let start = self.stoppedStartAt,

               now.timeIntervalSince(start) >= GPSConstants.stoppedNudgeConfirmSeconds,

               let lastS = self.lastKnownSpeedMps,

               lastS <= GPSConstants.minMotionSpeedMps {

                self.showStoppedNudgeInLoad = true

                self.lastStoppedNudgeAt     = now

                self.stoppedStartAt         = nil

            }

            self.pendingStoppedNudge = nil

        }

        pendingStoppedNudge = workItem

        DispatchQueue.main.asyncAfter(

            deadline: .now() + GPSConstants.stoppedNudgeConfirmSeconds,

            execute: workItem

        )

    }

    private func cancelStoppedNudge() {

        stoppedStartAt = nil

        pendingStoppedNudge?.cancel()

        pendingStoppedNudge = nil

    }

}

  

  

//======================================

// MARK: - Load / Unload Mode

//======================================

  

extension AppModel {

    func handleModeToggleAttempt(newIsUnloadMode: Bool) {

        // Phase 1: allow unconditionally (coaching deferred to a later phase).

        isUnloadMode = newIsUnloadMode

    }

}

  

  

//======================================

// MARK: - Odo Prompt Setup

//======================================

  

extension AppModel {

    /// Prepares the odometer capture prompt for a specific context

    /// (e.g. shift start, break end, shift end).

    /// This only sets transient UI state — nothing is persisted until `commitOdoCapture()`.

    func requestOdoCapture(_ context: OdoPromptContext, afterSave: (() -> Void)? = nil) {

        pendingActionAfterOdo = afterSave

        odoPromptContext      = context

        odoPromptOdoText      = odoText // prefill with last known odo

        odoPromptSuburbText   = ""      // driver must enter suburb where required

    }

    var isMissingShiftStartOdo: Bool {

        isOnDuty && !odoLocationRecords.contains(where: { $0.context == .shiftStart })

    }

}

  

  

//======================================

// MARK: - ODO ↔ GPS Reconciliation (private)

//======================================

  

extension AppModel {

    private func reconcileDistanceIfPossible(

        afterNewOdoKm newOdoKm: Int,

        at time: Date,

        context: OdoPromptContext

    ) {

        // 0) First ever anchor

        guard let lastKm = lastOdoAnchorKm else {

            lastOdoAnchorKm = newOdoKm

            kmCorrectionFactor = 1.0

            gpsKmSinceLastOdoBySegment.removeAll()

            lastOdoCaptureTime = time

            return

        }

        // 1) Shift start is a boundary marker, not a measurement window

        if context == .shiftStart {

            lastOdoAnchorKm = newOdoKm

            kmCorrectionFactor = 1.0

            gpsKmSinceLastOdoBySegment.removeAll()

            lastOdoCaptureTime = time

            return

        }

        // 2) Odo delta sanity

        let odoDelta = newOdoKm - lastKm

        guard odoDelta >= 0 else {

            DebugLog.odo("⚠️ ODO reconcile ignored (negative delta): new=\(newOdoKm) last=\(lastKm)")

            return

        }

        guard odoDelta > 0 else {

            // No movement since last anchor → just reset window cleanly

            gpsKmSinceLastOdoBySegment.removeAll()

            kmCorrectionFactor = 1.0

            lastOdoAnchorKm = newOdoKm

            lastOdoCaptureTime = time

            return

        }

        // 3) Gather GPS window

        let gpsWindowKm = gpsKmSinceLastOdoBySegment.values.reduce(0, +)

        // 4) Decide whether GPS is usable for calibration

        let minGpsWindowKm: Double = 1.0   // <-- key guard: prevents tiny denominator

        let maxGpsWindowKm: Double = 200.0 // defensive (won't hit in real life)

        let gpsUsable: Bool = (gpsWindowKm >= minGpsWindowKm && gpsWindowKm <= maxGpsWindowKm)

        // 5) If GPS isn't usable, allocate odoDelta to current segment (or buffer if nil)

        guard gpsUsable else {

            kmCorrectionFactor = 1.0

            if let sid = runningSegmentID {

                finalisedKmBySegment[sid, default: 0] += Double(odoDelta)

                DebugLog.odo("ODO reconcile (GPS unusable): allocated odoΔ=\(odoDelta)km to sid=\(sid.uuidString.prefix(6)) gpsWindow=\(String(format: "%.2f", gpsWindowKm))km")

            } else {

                DebugLog.odo("⚠️ Odo capture with no running segment - odoΔ=\(odoDelta)km gpsWindow=\(String(format: "%.2f", gpsWindowKm))km")

            }

            gpsKmSinceLastOdoBySegment.removeAll()

            lastOdoAnchorKm = newOdoKm

            lastOdoCaptureTime = time

            return

        }

        // 6) Compute factor and clamp to sane bounds

        let rawFactor = Double(odoDelta) / gpsWindowKm

        let clampedFactor =

        min(max(rawFactor, GPSConstants.kmCorrectionClampMin),

            GPSConstants.kmCorrectionClampMax)

        // If we had to clamp hard, log it (this is the smoking gun for later debugging)

        if abs(clampedFactor - rawFactor) > 0.0001 {

            DebugLog.odo("⚠️ kmCorrectionFactor CLAMPED raw=\(String(format: "%.2f", rawFactor)) → \(String(format: "%.2f", clampedFactor)) (odoΔ=\(odoDelta) gpsWindow=\(String(format: "%.2f", gpsWindowKm)))")

        }

        kmCorrectionFactor = clampedFactor

        // 7) Finalise per segment using CLAMPED factor

        for (sid, gpsKm) in gpsKmSinceLastOdoBySegment {

            finalisedKmBySegment[sid, default: 0] += gpsKm * kmCorrectionFactor

        }

        let finalisedKm = gpsWindowKm * kmCorrectionFactor

        let note =

        "ODO reconcile: odoΔ=\(odoDelta)km, gpsWindow=\(String(format: "%.2f", gpsWindowKm))km, " +

        "rawFactor=\(String(format: "%.2f", rawFactor)), factor=\(String(format: "%.2f", kmCorrectionFactor)), " +

        "finalised≈\(String(format: "%.2f", finalisedKm))km"

        logEvent(.other, note: note, at: time)

        // 8) Reset window + anchor

        gpsKmSinceLastOdoBySegment.removeAll()

        lastOdoAnchorKm = newOdoKm

        lastOdoCaptureTime = time

    }

}

  

//======================================

// MARK: - Commit Odo Capture (authoritative write-point)

//======================================

  

extension AppModel {

    /// Validates and commits an odometer capture into `odoLocationRecords`.

    /// - Enforces numeric-only odometer values.

    /// - Requires suburb for mandatory contexts (as defined in OdoConstants).

    /// - Acts as the single authoritative write-point for odo history.

    func commitOdoCapture() {

        guard let ctx = odoPromptContext else { return }

        let capturedContext = ctx // keep stable copy (we nil UI state later)

        let rawOdo = odoPromptOdoText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawOdo.isEmpty, rawOdo.allSatisfy({ $0.isNumber }) else { return }

        let cleanedOdo = rawOdo

        let cleanedSuburb = odoPromptSuburbText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Suburb mandatory/optional rules live in constants.

        let suburbRequired = OdoConstants.mandatorySuburbContexts.contains(capturedContext)

        if suburbRequired {

            guard !cleanedSuburb.isEmpty else { return }

        }

        // Store a single space when suburb is optional and left blank (preserves "intentionally blank").

        let suburbToStore = cleanedSuburb.isEmpty ? " " : cleanedSuburb

        let saveTime = Date()

        // Shift-start may be backdated (override), but never after the save moment.

        let recordTime: Date = {

            if capturedContext == .shiftStart, let override = odoPromptTimestampOverride {

                return min(override, saveTime)

            }

            return saveTime

        }()

        // Update current odo display immediately.

        odoText = cleanedOdo

        // SHIFT START: create the first segment BEFORE recording/reconciling.

        if pendingStartShiftCapture && capturedContext == .shiftStart {

            pendingStartShiftCapture = false

            isOnDuty  = true

            isDriving = false

            isOnBreak = false

            // Create the first segment now.

            startActivity(.workGeneral, at: saveTime)

            // Log event at the backdated time.

            logEvent(.shiftStart, at: recordTime)

        }

        // Associate odo record to the current running segment (should exist by now).

        let associatedSegmentID: UUID? = runningSegmentID

        // Create and store the record.

        let record = OdoLocationRecord(

            id: UUID(),

            timestamp: recordTime,

            context: capturedContext,

            odoText: cleanedOdo,

            suburb: suburbToStore,

            segmentID: associatedSegmentID

        )

        odoLocationRecords.append(record)

        // If this odo capture closes a segment that had a background gap,

        // apply the estimated meters as finalised km.

        if let gapSeg = pendingGapSegmentID,

           let estimateMeters = pendingGapEstimateMeters,

           gapSeg == associatedSegmentID {

            let km = estimateMeters / 1000.0

            finalisedKmBySegment[gapSeg, default: 0] += km

            distanceEvents.append(

                DistanceEvent(

                    at: Date(),

                    segmentID: gapSeg,

                    kind: .backgroundGapApplied,

                    deltaKm: km,

                    note: pendingGapReason ?? "Background gap applied"

                )

            )

            DebugLog.gps("🟣 Background gap applied: \(String(format: "%.2f", km)) km")

            clearBackgroundGapState(reason: "Gap applied via odo capture")

        }

        // Reconcile distance AFTER segment exists.

        if let odoKm = Int(cleanedOdo) {

            reconcileDistanceIfPossible(afterNewOdoKm: odoKm, at: recordTime, context: capturedContext)

            // Shadow-mode mirror only: alternate engine learns from the same odo anchor.

            mirrorOdoCaptureToShadow(odoKm: odoKm, at: recordTime)

            lastOdoCaptureTime = recordTime

        }

        // Clear timestamp override.

        odoPromptTimestampOverride = nil

        // Clear prompt UI state.

        odoPromptContext    = nil

        odoPromptOdoText    = ""

        odoPromptSuburbText = ""

        // Release shift-start gate here.

        // (DO NOT clear pendingEndShiftCapture here — we act on context below)

        if capturedContext == .shiftStart {

            pendingStartShiftCapture = false

        }

        // Run queued action (e.g. legal break end -> switch activity).

        let action = pendingActionAfterOdo

        pendingActionAfterOdo = nil

        action?()

        // Always autosave after a committed capture.

        autosave?.requestAutosave(reason: "Odo/location captured", immediate: true)

        // SHIFT END: finalize immediately and deterministically.

        if capturedContext == .shiftEnd {

            pendingEndShiftCapture = false

            finalizeEndShift()

            autosave?.requestAutosave(reason: "Shift ended", immediate: true)

            return

        }

        // If some other pathway set this flag, honour it (belt + suspenders).

        if pendingEndShiftCapture {

            pendingEndShiftCapture = false

            finalizeEndShift()

            autosave?.requestAutosave(reason: "Shift ended (pending)", immediate: true)

        }

    }

    /// Lightweight helper used during breaks to update the current odometer display.

    /// Does NOT write to `odoLocationRecords`.

    /// Phase 1 only — future versions may link this to shift history.

    func updateOdometer(fromBreak newOdo: String) {

        odoText = newOdo.trimmingCharacters(in: .whitespaces)

    }

}
