//======================================
// MARK: - AppModel+Guardhelpers
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+Guardhelpers.swift
//
// Purpose:
// - Provides shared guard-prompt helpers for segment-aware coaching and activity switching.
//
// Responsibilities:
// - Present reusable guard prompts for load/unload segment mismatches.
// - Support soft, medium, and hard guard flows around segment-sensitive actions.
// - Make segment switches explicit rather than silent.
//
// Notes:
// - This file supports the Guard layer; it does not own the main intent-routing engine.
// - Guards here are advisory/coaching helpers that reduce wrong-segment actions.
// - Segment changes must always be explicit and user-visible.
// - Confirm blockers require the driver to switch first, then confirm again.
//
// Phase: Pre-persistence
//======================================

import SwiftUI
import Foundation

extension AppModel {
    
    //======================================
    // MARK: - Generic Guard Helpers
    //======================================
    
    func presentGuardPrompt(title: String, message: String, actions: [AppModel.GuardAction]) {
        DispatchQueue.main.async { [weak self] in
            self?.activeGuardPrompt = AppModel.GuardPrompt(title: title, message: message, actions: actions)
        }
    }
    
    func clearGuardPrompt() {
        DispatchQueue.main.async { [weak self] in
            self?.activeGuardPrompt = nil
        }
    }
    
    func promptToSwitchSegment(
        title: String,
        message: String,
        switchTitle: String,
        keepTitle: String = "Keep as-is",
        onSwitch: @escaping () -> Void,
        onKeep: @escaping () -> Void = {}
    ) {
        presentGuardPrompt(
            title: title,
            message: message,
            actions: [
                AppModel.GuardAction(title: switchTitle, role: nil) { [weak self] in
                    self?.activeGuardPrompt = nil   // ✅ dismiss prompt first
                    onSwitch()
                },
                AppModel.GuardAction(title: keepTitle, role: .cancel) { [weak self] in
                    self?.activeGuardPrompt = nil   // ✅ dismiss prompt first
                    onKeep()
                }
            ]
        )
    }
    
    //======================================
    // MARK: - Tier 1: Entry Guards (Soft)
    //======================================
    
    /// Soft prompt when entering LoadView in wrong segment (Load mode)
    func promptToSwitchToLoad() {
        let currentLabel = currentActivity.displayName
        
        promptToSwitchSegment(
            title: "Switch to Loading?",
            message: "You're currently marked as \(currentLabel). Switch to Loading mode to edit the load plan?",
            switchTitle: "Switch to Loading",
            keepTitle: "Stay in \(currentLabel)",
            onSwitch: {
                self.request(.load, source: .userTap)
            }
        )
    }
    
    /// Soft prompt when entering LoadView in wrong segment (Unload mode)
    func promptToSwitchToUnload() {
        let currentLabel = currentActivity.displayName
        
        promptToSwitchSegment(
            title: "Switch to Unloading?",
            message: "You're currently marked as \(currentLabel). Switch to Unloading mode to edit the unload plan?",
            switchTitle: "Switch to Unloading",
            keepTitle: "Stay in \(currentLabel)",
            onSwitch: {
                self.request(.unload, source: .userTap)
            }
        )
    }
    
    //======================================
    // MARK: - Tier 2: Edit Guards (Medium)
    //======================================
    
    /// Medium guard when focusing on editable fields
    func promptToSwitchSegmentForEditing(to expectedSegment: ActivityType) {
        let currentLabel = currentActivity.displayName
        let expectedLabel = expectedSegment.displayName
        
        promptToSwitchSegment(
            title: "Switch to \(expectedLabel) to edit?",
            message: "You're currently marked as: \(currentLabel)\nEditing the load plan requires \(expectedLabel) mode.",
            switchTitle: "Switch to \(expectedLabel)",
            keepTitle: "Cancel",
            onSwitch: {
                if expectedSegment == .workLoad {
                    self.request(.load, source: .userTap)
                    
                } else if expectedSegment == .workUnload {
                    self.request(.unload, source: .userTap)
                    
                }
            },
            onKeep: {
                // Field blur handled by caller via @FocusState
            }
        )
    }
    
    //======================================
    // MARK: - Tier 3: Confirm Guards (Hard)
    //======================================
    
    /// Hard blocker when confirming in wrong segment
    func presentSegmentMismatchBlocker(expected: ActivityType) {
        let currentLabel = currentActivity.displayName
        let expectedLabel = expected.displayName
        
        promptToSwitchSegment(
            title: "Cannot confirm — Wrong segment",
            message: "You're currently marked as: \(currentLabel)\n\nYou cannot confirm a \(expectedLabel.lowercased()) operation while \(currentLabel.lowercased()).\n\nSwitch to \(expectedLabel) first, then confirm.",
            switchTitle: "Switch to \(expectedLabel)",
            keepTitle: "Cancel",
            onSwitch: {
                if expected == .workLoad {
                    self.request(.load, source: .userTap)
                } else if expected == .workUnload {
                    self.request(.unload, source: .userTap)
                }
                // Note: User must press Confirm again after switching
            }
        )
    }
}
