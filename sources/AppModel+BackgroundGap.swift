//======================================
// MARK: - AppModel+BackgroundGap
//======================================
//
// Path: AppModels/AppModel+BackgroundGap.swift
//
// Purpose:
// - Resets background gap recovery state after a gap is resolved or dismissed.
//
// Responsibilities:
// - Clear pending background gap estimate and UI state
// - Reset background gap coordinator anchors and resume flags
//
// Notes:
// - Safe to call from multiple workflows (odo capture, guard prompts, refocus handling)
// - This is cleanup/reset logic only; estimation logic belongs elsewhere
//
// Phase: Pre-persistence
//======================================

import Foundation
import CoreLocation

extension AppModel {
    
    /// Clears any in-flight background gap state + coordinator anchor.
    /// Safe to call from anywhere (odo capture, guard prompt actions, etc).
    @MainActor
    func clearBackgroundGapState(reason: String = "") {
        if !reason.isEmpty {
            DebugLog.lifecycle("🧹 Clear background gap state: \(reason)")
        }
        
        // Coordinator anchor (prevents re-trigger)
        backgroundGapCoordinator.clear()
        
        // Old markers (if still present)
        backgroundGapStartAt = nil
        backgroundGapStartCoord = nil
        backgroundGapEndAt = nil
        backgroundGapEndCoord = nil
        
        // Pending UI/apply state
        pendingGapEstimateMeters = nil
        pendingGapEstimateSegmentID = nil
        pendingGapReason = nil
        pendingGapSegmentID = nil
        backgroundGapResumePending = false
    }
}
