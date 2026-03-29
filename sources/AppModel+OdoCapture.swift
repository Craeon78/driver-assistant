//======================================
// MARK: - AppModel+OdoCapture
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+OdoCapture.swift
//
// Purpose:
// - Centralises odo capture workflow, reconciliation, and load-view stopped nudges.
// - Keeps AppModel.swift free of odo prompt and commit logic.
//
// Responsibilities:
// - "You appear stopped" coaching nudge for the Load view.
// - Odo prompt lifecycle (request/commit) and validation.
// - ODO ↔ GPS reconciliation to finalise per-segment kilometres.
// - Load/unload mode toggle handling.
//
// Notes:
// - commitOdoCapture() is the authoritative write-point for odo history in the current app.
// - ODO capture is authoritative; GPS is evidence used for approximation and reconciliation.
// - Thresholds are sourced from GPSConstants / OdoConstants.
// - All @Published stored properties remain on the main AppModel type, not in extensions.
//
// Phase: Pre-persistence
//======================================

import Foundation

//======================================
// MARK: - "Stopped while driving" Nudge
//======================================

extension AppModel {
    func considerStoppedNudgeInLoad(speedMps: Double?) {
        guard isOnDuty, isDriving, !isOnBreak else { cancelStoppedNudge(); return }
        let now = Date()
        if let last = lastStoppedNudgeAt,
           now.timeIntervalSince(last) < GPSConstants.stoppedNudgeCooldownSeconds { return }
        guard let s = speedMps, s >= 0 else { return }
        
        if s > GPSConstants.minMotionSpeedMps {
            stoppedStartAt = nil
            pendingStoppedNudge?.cancel()
            pendingStoppedNudge = nil
            return
        }
        
        if stoppedStartAt == nil {
            stoppedStartAt = now
            scheduleStoppedNudgeCheck()
        }
    }
    
    func primeStoppedNudgeInLoadEntry() {
        guard isOnDuty, isDriving, !isOnBreak else { return }
        guard let s = lastKnownSpeedMps, s >= 0 else { return }
        let now = Date()
        if let last = lastStoppedNudgeAt,
           now.timeIntervalSince(last) < GPSConstants.stoppedNudgeCooldownSeconds { return }
        if s <= GPSConstants.minMotionSpeedMps, stoppedStartAt == nil {
            stoppedStartAt = now
            scheduleStoppedNudgeCheck()
        }
    }
    
    func snoozeStoppedNudgeInLoad() {
        lastStoppedNudgeAt = Date()
        stoppedStartAt = nil
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
                self.lastStoppedNudgeAt = now
                self.stoppedStartAt = nil
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
        isUnloadMode = newIsUnloadMode
    }
}

//======================================
// MARK: - Odo Prompt Setup
//======================================

extension AppModel {
    func requestOdoCapture(_ context: OdoPromptContext, afterSave: (() -> Void)? = nil) {
        pendingActionAfterOdo = afterSave
        odoPromptContext = context
        odoPromptOdoText = odoText
        odoPromptSuburbText = ""
    }
    
    var isMissingShiftStartOdo: Bool {
        isOnDuty && !odoLocationRecords.contains(where: { $0.context == .shiftStart })
    }
}

//======================================
// MARK: - ODO ↔ GPS Reconciliation
//======================================

extension AppModel {
    private func reconcileDistanceIfPossible(
        afterNewOdoKm newOdoKm: Int,
        at time: Date,
        context: OdoPromptContext
    ) {
        guard let lastKm = lastOdoAnchorKm else {
            lastOdoAnchorKm = newOdoKm
            kmCorrectionFactor = 1.0
            gpsKmSinceLastOdoBySegment.removeAll()
            lastOdoCaptureTime = time
            return
        }
        
        if context == .shiftStart {
            lastOdoAnchorKm = newOdoKm
            kmCorrectionFactor = 1.0
            gpsKmSinceLastOdoBySegment.removeAll()
            lastOdoCaptureTime = time
            return
        }
        
        let odoDelta = newOdoKm - lastKm
        guard odoDelta >= 0 else {
            DebugLog.odo("⚠️ ODO reconcile ignored (negative delta): new=\(newOdoKm) last=\(lastKm)")
            return
        }
        
        if context == .legalBreakEnd && odoDelta == 0 {
            DebugLog.odo("ℹ️ Legal break end odo unchanged — keeping GPS window intact")
            lastOdoCaptureTime = time
            return
        }
        
        guard odoDelta > 0 else {
            DebugLog.odo("ℹ️ ODO reconcile skipped (zero delta): new=\(newOdoKm) last=\(lastKm)")
            lastOdoCaptureTime = time
            return
        }
        
        let gpsWindowKm = gpsKmSinceLastOdoBySegment.values.reduce(0, +)
        let minGpsWindowKm: Double = 1.0
        let maxGpsWindowKm: Double = 200.0
        let gpsUsable = (gpsWindowKm >= minGpsWindowKm && gpsWindowKm <= maxGpsWindowKm)
        
        guard gpsUsable else {
            kmCorrectionFactor = 1.0
            if let sid = runningSegmentID {
                finalisedKmBySegment[sid, default: 0] += Double(odoDelta)
                DebugLog.odo("ODO reconcile (GPS unusable): allocated odoΔ=\(odoDelta)km to sid=\(sid.uuidString.prefix(6)) gpsWindow=\(String(format: "%.2f", gpsWindowKm))km")
            }
            gpsKmSinceLastOdoBySegment.removeAll()
            lastOdoAnchorKm = newOdoKm
            lastOdoCaptureTime = time
            return
        }
        
        let rawFactor = Double(odoDelta) / gpsWindowKm
        let clampedFactor = min(max(rawFactor, GPSConstants.kmCorrectionClampMin), GPSConstants.kmCorrectionClampMax)
        
        if abs(clampedFactor - rawFactor) > 0.0001 {
            DebugLog.odo("⚠️ kmCorrectionFactor CLAMPED raw=\(String(format: "%.2f", rawFactor)) → \(String(format: "%.2f", clampedFactor))")
        }
        
        kmCorrectionFactor = clampedFactor
        
        for (sid, gpsKm) in gpsKmSinceLastOdoBySegment {
            finalisedKmBySegment[sid, default: 0] += gpsKm * kmCorrectionFactor
        }
        
        gpsKmSinceLastOdoBySegment.removeAll()
        lastOdoAnchorKm = newOdoKm
        lastOdoCaptureTime = time
    }
}

//======================================
// MARK: - Commit Odo Capture
//======================================

extension AppModel {
    func commitOdoCapture() {
        guard let ctx = odoPromptContext else { return }
        let capturedContext = ctx
        
        let rawOdo = odoPromptOdoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawOdo.isEmpty, rawOdo.allSatisfy({ $0.isNumber }) else { return }
        
        let cleanedSuburb = odoPromptSuburbText.trimmingCharacters(in: .whitespacesAndNewlines)
        let suburbRequired = OdoConstants.mandatorySuburbContexts.contains(capturedContext)
        if suburbRequired { guard !cleanedSuburb.isEmpty else { return } }
        let suburbToStore = cleanedSuburb.isEmpty ? " " : cleanedSuburb
        
        let saveTime = Date()
        let recordTime: Date = {
            if capturedContext == .shiftStart, let override = odoPromptTimestampOverride {
                return min(override, saveTime)
            }
            return saveTime
        }()
        
        odoText = rawOdo
        
        if pendingStartShiftCapture && capturedContext == .shiftStart {
            pendingStartShiftCapture = false
            isOnDuty = true
            isDriving = false
            isOnBreak = false
            startActivity(.workGeneral, at: saveTime)
            logEvent(.shiftStart, at: recordTime)
        }
        
        let record = OdoLocationRecord(
            id: UUID(),
            timestamp: recordTime,
            context: capturedContext,
            odoText: rawOdo,
            suburb: suburbToStore,
            segmentID: runningSegmentID
        )
        
        odoLocationRecords.append(record)
        
        if let odoKm = Int(rawOdo) {
            reconcileDistanceIfPossible(afterNewOdoKm: odoKm, at: recordTime, context: capturedContext)
            mirrorOdoCaptureToShadow(odoKm: odoKm, at: recordTime)
            lastOdoCaptureTime = recordTime
        }
        
        odoPromptTimestampOverride = nil
        odoPromptContext = nil
        odoPromptOdoText = ""
        odoPromptSuburbText = ""
        
        let action = pendingActionAfterOdo
        pendingActionAfterOdo = nil
        action?()
        
        autosave?.requestAutosave(reason: "Odo/location captured", immediate: true)
        
        if capturedContext == .shiftEnd {
            pendingEndShiftCapture = false
            finalizeEndShift()
            autosave?.requestAutosave(reason: "Shift ended", immediate: true)
        }
    }
    
    func updateOdometer(fromBreak newOdo: String) {
        odoText = newOdo.trimmingCharacters(in: .whitespaces)
    }
}
