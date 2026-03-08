
import Foundation

import CoreLocation

  

//======================================

// MARK: - GPSTuning

//======================================

//

// Centralised configuration for all

// GPS engine tunable parameters.

//

// These values can be surfaced in the

// DebugDashboard for live tweaking

// during real-world testing.

//

  

struct GPSTuning {

    //======================================

    // MARK: - Sample acceptance

    //======================================

    /// Maximum allowed horizontal accuracy (meters)

    static var maxHorizontalAccuracy: Double = 30

    /// Maximum age of location sample (seconds)

    static var maxSampleAge: TimeInterval = 15

    /// Maximum allowed speed spike (km/h)

    static var maxSpeedJumpKph: Double = 160

    /// Maximum allowed distance jump between samples (meters)

    static var maxDistanceJumpMeters: Double = 250

    //======================================

    // MARK: - Gap detection

    //======================================

    /// Gap threshold before counting as GPS dropout

    static var gapDetectionSeconds: TimeInterval = 15

    /// Background gap trigger time

    static var backgroundGapSeconds: TimeInterval = 45

    /// Minimum distance before background gap UI triggers (meters)

    static var backgroundGapMinDistance: Double = 800

    //======================================

    // MARK: - Correction factor

    //======================================

    /// Hard lower bound of correction factor

    static var factorMin: Double = 0.70

    /// Hard upper bound of correction factor

    static var factorMax: Double = 1.30

    //======================================

    // MARK: - Learning rates

    //======================================

    /// Aggressive learning (new truck / new driver)

    static var alphaEmbryonic: Double = 0.35

    /// Moderate learning

    static var alphaStabilising: Double = 0.18

    /// Light correction once stable

    static var alphaMature: Double = 0.06

    /// When drift increases again

    static var alphaDrifting: Double = 0.25

    //======================================

    // MARK: - Maturity thresholds

    //======================================

    /// Span closures required before leaving embryonic

    static var embryonicSpanCount: Int = 3

    /// Span closures required before reaching mature

    static var matureSpanCount: Int = 10

    /// Allowed variance before drift detection

    static var driftVarianceThreshold: Double = 0.08

}
