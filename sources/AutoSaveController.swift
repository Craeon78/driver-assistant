
import Foundation

import SwiftUI

  

//======================================

// MARK: - AutoSaveController (debounced autosave)

//======================================

//

// Strategy:

// - Debounce frequent changes (avoid writing every second).

// - Force-save on high-value events (confirm load, activity switch, odo capture).

// - Optional: call `flushNow()` when app is backgrounding.

  

@MainActor

final class AutoSaveController: ObservableObject{

    weak var model: AppModel?

    init(model: AppModel) { self.model = model }

    private let store = SaveStore()

    private var pendingWorkItem: DispatchWorkItem?

    private let debounceSeconds: TimeInterval = 1.25

    private var shouldWriteResumable: Bool = true

    // Debug / UI hook (optional)

    @Published var lastAutosaveAt: Date? = nil

    @Published var lastAutosaveReason: String? = nil

    @Published var lastAutosaveFailed: Bool = false

    // MARK: - Restore

    func restoreIfAvailable() {

        guard let model else { return }

        guard let save = store.loadBestResumableAutosave() else { return }

        let age = Date().timeIntervalSince(save.savedAt)

        if age > 14400 {  // 4 hours

            DebugLog.autosave("💾 Stale autosave skipped: \(age/3600) hours old")

            store.clearAutosaves()  // Auto-nuke

            return

        }

        // Then prompt (e.g., set model.activeGuardPrompt for a "Resume crashed shift?" dialog)

        let pretty = model.time.formatDateTimeShort(save.savedAt, context: .ui)

        model.presentGuardPrompt(

            title: "Resume previous session?",

            message: "Found mid-shift data from \(pretty). Resume or start fresh?",

            actions: [

                AppModel.GuardAction(title: "Resume", role: nil) {

                    save.apply(to: model)

                },

                AppModel.GuardAction(title: "Start Fresh", role: .destructive) {

                    self.clearAutosaves()

                },

                AppModel.GuardAction(title: "Cancel", role: .cancel) {

                    // do nothing

                }

            ]

        )

    }

    // MARK: - Autosave requests

    func requestAutosave(reason: String, immediate: Bool = false) {

        pendingWorkItem?.cancel()

        if immediate {

            flushNow(reason: reason)

            return

        }

        let task = DispatchWorkItem { [weak self] in

            self?.flushNow(reason: reason)

        }

        pendingWorkItem = task

        DispatchQueue.main.asyncAfter(deadline: .now() + debounceSeconds, execute: task)

    }

    func clearAutosaves() {

        store.clearAutosaves()

    }

    func flushNow(reason: String) {

        guard let model else { return }

        do {

            let payload = AppSaveV1.build(from: model)

            try store.writeAutosave(payload: payload, resumable: shouldWriteResumable)

            lastAutosaveAt = Date()

            lastAutosaveReason = reason

            lastAutosaveFailed = false

            DebugLog.autosave("💾 Autosaved(\(shouldWriteResumable ? "resumable" : "not-resumable")): \(reason)")

        } catch {

            lastAutosaveFailed = true

            DebugLog.autosave("❌ Autosave failed: \(error)")

        }

    }

    func markResumableNow(reason: String = "Shift active") {

        shouldWriteResumable = true

        DebugLog.autosave("💾 Autosave marked resumable: \(reason)")

    }

    func markNotResumableNow(reason: String = "Shift ended", clearFiles: Bool = false) {

        pendingWorkItem?.cancel()

        pendingWorkItem = nil

        shouldWriteResumable = false

        guard let model else { return }

        do {

            let payload = AppSaveV1.build(from: model)

            try store.writeAutosave(payload: payload, resumable: false)

            DebugLog.autosave("💾 Autosave marked NOT resumable: \(reason)")

            if clearFiles {

                store.clearAutosaves()

                DebugLog.autosave("🧹 Autosave files cleared")

            }

            if store.hasAutosaveFiles() { DebugLog.autosave("⚠️ Autosave clear incomplete—retrying"); store.clearAutosaves() }

        } catch {

            DebugLog.autosave("❌ Failed to mark not resumable: \(error)")

        }

    }

}
