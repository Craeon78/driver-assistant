//======================================
// MARK: - AppModel+Guard
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+Guard.swift
//
// Purpose:
// - Routes driver intent through an advisory guard layer before state changes are applied.
// - Coaches when detected context and requested action do not align.
//
// Responsibilities:
// - Define DriverIntent and DriverIntentSource types.
// - Define GuardPrompt and GuardAction types.
// - Own the request(_:source:) entry point for intent-driven state changes.
// - Present advisory prompts when inferred context conflicts with requested activity.
//
// Notes:
// - Prompts are advisory only; this file coaches rather than enforces.
// - userTap = trust explicit driver input and execute directly unless future rules say otherwise.
// - movementNudge = inferred movement may trigger coaching prompts.
// - contextAuto = silent context-driven correction path.
// - Pre-persistence scope: reduce accidental timeline/state errors without mutating history semantics.
// - Post-persistence: may emit advisory events, but should not silently rewrite authoritative truth.
//======================================

import SwiftUI

// MARK: - Intent Types

enum DriverIntent {
    case drive
    case breakTime
    case load
    case unload
    case incident
    case other(name: String, isWork: Bool)
}

// Where a request originated determines whether coaching prompts are shown.
enum DriverIntentSource {
    case userTap        // driver explicitly pressed a button — do not nag
    case movementNudge  // automatic movement detection — coach if state mismatch
    case contextAuto    // inferred from UI context — switch silently, no prompt
}


// MARK: - Guard Prompt Types

extension AppModel {
    
    struct GuardPrompt: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let actions: [GuardAction]
    }
    
    struct GuardAction {
        let title: String
        let role: ButtonRole?
        let handler: () -> Void
    }
}


// MARK: - Guard Engine

extension AppModel {
    
    /// Single entry point for all driver intent, whether from button taps or motion inference.
    /// Coaching prompts are only shown when source == .movementNudge.
    func request(_ intent: DriverIntent, source: DriverIntentSource = .userTap) {
        guard isOnDuty else { return }
        guard activeGuardPrompt == nil else { return }
        
        let shouldCoach = (source == .movementNudge)
        
        switch intent {
            
        case .drive:
            if shouldCoach, (isOnBreak || currentActivity == .workLoad || currentActivity == .workUnload) {
                presentGuard(
                    title: "You're not marked as driving",
                    message: "Movement suggests you're driving, but you're currently in \(humanActivityLabel()). Switch to Driving?",
                    primaryTitle: "Switch to Driving",
                    primary:      { [weak self] in self?.pressDrive() },
                    secondaryTitle: "Not driving",
                    secondary:    { [weak self] in self?.activeGuardPrompt = nil }
                )
                return
            }
            pressDrive()
            
        case .breakTime:
            pressBreak()
            
        case .load:
            if shouldCoach, isDriving {
                presentGuard(
                    title: "You appear to be driving",
                    message: "You tapped Load while marked Driving. Are you actually stopped and loading now?",
                    primaryTitle: "Switch to LOAD",
                    primary:      { [weak self] in self?.pressLoad() },
                    secondaryTitle: "Keep Driving",
                    secondary:    { [weak self] in self?.activeGuardPrompt = nil }
                )
                return
            }
            pressLoad()
            
        case .unload:
            if shouldCoach, isDriving {
                presentGuard(
                    title: "You appear to be driving",
                    message: "You tapped Unload while marked Driving. Are you actually stopped and unloading now?",
                    primaryTitle: "Switch to UNLOAD",
                    primary:      { [weak self] in self?.pressUnload() },
                    secondaryTitle: "Keep Driving",
                    secondary:    { [weak self] in self?.activeGuardPrompt = nil }
                )
                return
            }
            pressUnload()
            
        case .incident:
            // Incidents are event-only; allowed from any state.
            beginIncidentDraft()
            isShowingIncidentSheet = true
            
        case .other(let name, let isWork):
            let a = OtherActivity(id: UUID(), name: name, isWork: isWork)
            if shouldCoach, isDriving, isWork {
                presentGuard(
                    title: "You appear to be driving",
                    message: "Movement suggests you're driving. Switch out of Driving into '\(name)'?",
                    primaryTitle: "Switch to \(name)",
                    primary:      { [weak self] in self?.startOtherActivity(a) },
                    secondaryTitle: "Keep Driving",
                    secondary:    { [weak self] in self?.activeGuardPrompt = nil }
                )
                return
            }
            startOtherActivity(a)
        }
    }
}


// MARK: - Guard Helpers (private)

extension AppModel {
    
    private func presentGuard(
        title: String,
        message: String,
        primaryTitle: String,
        primary: @escaping () -> Void,
        secondaryTitle: String,
        secondary: @escaping () -> Void
    ) {
        activeGuardPrompt = GuardPrompt(
            title: title,
            message: message,
            actions: [
                GuardAction(title: primaryTitle, role: nil) { [weak self] in
                    self?.activeGuardPrompt = nil
                    primary()
                },
                GuardAction(title: secondaryTitle, role: .cancel) { [weak self] in
                    self?.activeGuardPrompt = nil
                    secondary()
                }
            ]
        )
    }
    
    private func humanActivityLabel() -> String {
        switch currentActivity {
        case .driving:       return "Driving"
        case .workLoad:      return "Load"
        case .workUnload:    return "Unload"
        case .workGeneral:   return "On duty"
        case .restBreak:     return "Break"
        case .restBreakdown: return "Breakdown"
        case .offDuty:       return "Off duty"
        }
    }
}
