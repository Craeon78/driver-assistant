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
