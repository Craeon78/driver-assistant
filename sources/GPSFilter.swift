
import Foundation

import CoreLocation

  

//======================================

// MARK: - GPSFilter

//======================================

//

// Evaluates incoming GPS samples and

// determines whether they should be

// accepted for span accumulation.

//

// Responsibilities:

//

// • Reject poor accuracy samples

// • Reject stale samples

// • Reject impossible jumps

// • Produce a filtered delta distance

//

// Does NOT:

// • Accumulate span distance

// • Update correction factor

//

  

struct GPSFilter {

    //======================================

    // MARK: - Evaluation Result

    //======================================

    enum Result {

        case accept(deltaMeters: Double)

        case rejectAccuracy

        case rejectJump

        case rejectSpeed

    }

    //======================================

    // MARK: - Evaluate sample

    //======================================

    static func evaluate(

        newLocation: CLLocation,

        previousLocation: CLLocation?

    ) -> Result {

        // No previous sample → accept first fix

        guard let previous = previousLocation else {

            return .accept(deltaMeters: 0)

        }

        // Accuracy check

        if newLocation.horizontalAccuracy > GPSTuning.maxHorizontalAccuracy {

            return .rejectAccuracy

        }

        // Sample age check

        let age = Date().timeIntervalSince(newLocation.timestamp)

        if age > GPSTuning.maxSampleAge {

            return .rejectAccuracy

        }

        // Distance delta

        let distance = newLocation.distance(from: previous)

        // Jump rejection

        if distance > GPSTuning.maxDistanceJumpMeters {

            return .rejectJump

        }

        // Speed sanity check

        let time = newLocation.timestamp.timeIntervalSince(previous.timestamp)

        if time > 0 {

            let speedMps = distance / time

            let speedKph = speedMps * 3.6

            if speedKph > GPSTuning.maxSpeedJumpKph {

                return .rejectSpeed

            }

        }

        return .accept(deltaMeters: distance)

    }

}
