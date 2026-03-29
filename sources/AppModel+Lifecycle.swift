//======================================
// MARK: - AppModel+Lifecycle
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+Lifecycle.swift
//
// Purpose:
// - Handles app lifecycle transitions that affect GPS continuity and background gap recovery.
//
// Responsibilities:
// - Capture background anchors when the app leaves the foreground during an on-duty shift.
// - Resume background gap estimation flow when the app becomes active again.
// - Clear lifecycle-driven background gap advisory state when required.
//
// Notes:
// - This file is lifecycle coordination logic, not general GPS ingestion logic.
// - It works with BackgroundGapCoordinator and fresh GPS fixes to estimate off-screen movement.
// - Background gap handling is advisory only; it should not fabricate authoritative movement history.
//
// Phase: Pre-persistence
//======================================

import Foundation
import CoreLocation

extension AppModel {
    
    // MARK: - Lifecycle hooks
    
    @MainActor
    func onAppBackgrounded(locationManager lm: LocationManager) {
        guard isOnDuty else { return }
        
        let now = Date()
        
        guard let loc = lm.lastGoodLocation ?? lm.lastLocation else {
            DebugLog.lifecycle("🌙 BG skipped: no location available")
            return
        }
        
        let source = (lm.lastGoodLocation != nil) ? "good" : "last"
        let age = now.timeIntervalSince(loc.timestamp)
        let lat = String(format: "%.6f", loc.coordinate.latitude)
        let lon = String(format: "%.6f", loc.coordinate.longitude)
        let acc = Int(loc.horizontalAccuracy)
        let ageText = String(format: "%.1f", age)
        
        guard age < 60 else {
            DebugLog.lifecycle("🌙 BG skipped: stale loc source=\(source) age=\(ageText)s acc=\(acc)m lat=\(lat) lon=\(lon)")
            return
        }
        
        backgroundGapCoordinator.markBackgroundStart(at: now, coord: loc.coordinate)
        backgroundGapStartAt = now
        backgroundGapStartCoord = loc.coordinate
        backgroundGapResumePending = true
        
        DebugLog.lifecycle("🌙 BG anchor set source=\(source) at=\(now) fix=\(loc.timestamp) age=\(ageText)s acc=\(acc)m lat=\(lat) lon=\(lon)")
    }
    
    @MainActor
    func onAppBecameActive(locationManager lm: LocationManager) {
        guard isOnDuty else {
            backgroundGapResumePending = false
            return
        }
        
        backgroundGapResumePending = true
        hasLoggedResumeNotPending = false
        
        if let loc = lm.lastGoodLocation ?? lm.lastLocation {
            let source = (lm.lastGoodLocation != nil) ? "good" : "last"
            let age = Date().timeIntervalSince(loc.timestamp)
            let lat = String(format: "%.6f", loc.coordinate.latitude)
            let lon = String(format: "%.6f", loc.coordinate.longitude)
            let acc = Int(loc.horizontalAccuracy)
            let ageText = String(format: "%.1f", age)
            
            DebugLog.lifecycle("🌞 Foregrounded — waiting for fresh GPS source=\(source) fix=\(loc.timestamp) age=\(ageText)s acc=\(acc)m lat=\(lat) lon=\(lon)")
        } else {
            DebugLog.lifecycle("🌞 Foregrounded — waiting for fresh GPS (no current loc)")
        }
    }
    
    // Optional helper if you want a manual “clear” button in debug.
    @MainActor
    func clearBackgroundGapAdvisory(reason: String = "") {
        if !reason.isEmpty {
            DebugLog.lifecycle("🧹 Clear BG advisory: \(reason)")
        }
        backgroundGapCoordinator.clear()
        backgroundGapResumePending = false
        lastBackgroundGapEstimate = nil
        // keep history unless you explicitly want to wipe it too
    }
}
