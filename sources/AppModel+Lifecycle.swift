import Foundation

import CoreLocation

  

extension AppModel {

    // MARK: - Lifecycle hooks

    @MainActor

    func onAppBackgrounded(locationManager lm: LocationManager) {

        guard isOnDuty else { return }

        let now = Date()

        // Prefer a "good" fix (accuracy-gated) rather than just "lastLocation"

        guard let loc = lm.lastGoodLocation ?? lm.lastLocation else { return }

        // Avoid anchoring on stale samples

        guard now.timeIntervalSince(loc.timestamp) < 60 else { return }

        backgroundGapCoordinator.markBackgroundStart(at: now, coord: loc.coordinate)

        backgroundGapResumePending = true

        DebugLog.lifecycle("🌙 BG anchor set at=\(now) acc=\(Int(loc.horizontalAccuracy))m")

    }

    @MainActor

    func onAppBecameActive(locationManager lm: LocationManager) {

        guard isOnDuty else {

            backgroundGapResumePending = false

            return

        }

        // We’ll complete once we have a fresh good fix (see connect() sink).

        backgroundGapResumePending = true

        DebugLog.lifecycle("🌞 Foregrounded — waiting for fresh GPS to estimate BG gap")

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
