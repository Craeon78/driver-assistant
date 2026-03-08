import SwiftUI

import Foundation

  

//======================================

// File: AppModel+GuardHelpers.swift

//======================================

//

// Purpose:

// - Guard prompt helpers for segment correction

// - Prevents events from being logged in wrong segments

// - Provides explicit (not silent) segment switching

//

// Three-tier system:

// 1. Entry guard (soft): prompt when entering LoadView in wrong segment

// 2. Edit guard (medium): prompt when focusing editable fields

// 3. Confirm guard (hard): block confirm if segment is wrong

//

// Design principle:

// - No silent segment changes

// - Driver always sees why/when segment changes

// - Explicit user choice required

//

//======================================

  

  

  

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

                    self?.activeGuardPrompt = nil   // ✅ dismiss prompt first

                    onSwitch()

                },

                AppModel.GuardAction(title: keepTitle, role: .cancel) { [weak self] in

                    self?.activeGuardPrompt = nil   // ✅ dismiss prompt first

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
