
import Foundation

import CoreLocation

  

//======================================

// MARK: - BackgroundGapCoordinator

//======================================

//

// Purpose:

// - Glue layer around BackgroundGapEstimator.

// - Stores a "background start anchor" (time + coord).

// - On return to foreground, produces a BackgroundGapEstimate? for UI/debug.

// - Advisory only: NEVER feeds correction factor learning.

//======================================

  

final class BackgroundGapCoordinator {

    struct Anchor: Codable {

        var at: Date

        var coord: CodableCoordinate

    }

    private let estimator: BackgroundGapEstimator

    private var anchor: Anchor?

    init(estimator: BackgroundGapEstimator = BackgroundGapEstimator()) {

        self.estimator = estimator

    }

    // MARK: - Public API

    /// Call when app is *about to* background, using your last known good GPS fix.

    func markBackgroundStart(at: Date, coord: CLLocationCoordinate2D) {

        anchor = Anchor(at: at, coord: CodableCoordinate(coord))

    }

    /// Call once you have a fresh fix after returning to foreground.

    /// Completion returns nil if it doesn't qualify (short gap / tiny displacement).

    func estimateOnForegroundReturn(

        at endAt: Date,

        coord endCoord: CLLocationCoordinate2D,

        completion: @escaping (BackgroundGapEstimate?) -> Void

    ) {

        guard let anchor else {

            completion(nil)

            return

        }

        // Clear anchor immediately so we don't double-run.

        self.anchor = nil

        estimator.estimateIfQualifies(

            startAt: anchor.at,

            startCoord: anchor.coord.cl,

            endAt: endAt,

            endCoord: endCoord,

            completion: completion

        )

    }

    /// Optional: allow caller to drop the anchor (eg. manual reset).

    func clear() {

        anchor = nil

    }

}
