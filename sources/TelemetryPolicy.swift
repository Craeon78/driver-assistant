
import Foundation

import CoreLocation

  

//======================================

// MARK: - Telemetry Policy (v0.2)

//======================================

//

// Single source of truth for telemetry policy + constants.

// This file intentionally contains:

// - thresholds (time/distance/heading/speed)

// - retention horizons

// - UI lockout rules (policy only)

// - suggestion thresholds (arrival radius etc)

//

// This file intentionally does NOT contain:

// - persistence implementation (CoreData/SwiftData)

// - business rules (shift logic, fatigue, DG etc)

// - location manager wiring

//

// NOTE: Some policy items are declared for Phase 2+ but are not yet enforced

// by the helper functions at the bottom of this file (explicitly tagged below).

//======================================

  

struct TelemetryPolicy {

    //==================================

    // MARK: - Capture Modes

    //==================================

    enum CaptureMode: String, CaseIterable, Codable {

        case off

        case minimal

        case standard

        case diagnostic

    }

    /// Default for new installs (conservative: fewer breadcrumbs).

    static let defaultMode: CaptureMode = .minimal

    //==================================

    // MARK: - Speed Thresholds

    //==================================

    /// Above this speed, UI safety lockout may apply (ENFORCED by `shouldLockoutUI`).

    static let drivingSpeedKPH: Double = 20        // TODO: calibrate

    /// Considered stationary below this speed (DECLARED ONLY; not enforced here yet).

    static let stationarySpeedKPH: Double = 2      // TODO: calibrate

    //==================================

    // MARK: - Time Triggers

    //==================================

    /// Minimum seconds between breadcrumb captures (ENFORCED by `shouldCapture`).

    static func minTimeInterval(for mode: CaptureMode) -> TimeInterval {

        switch mode {

        case .off:        return .infinity

        case .minimal:    return 300      // 5 min (TODO: calibrate)

        case .standard:   return 60       // 1 min (TODO: calibrate)

        case .diagnostic: return 10       // TODO: calibrate

        }

    }

    /// Stationary dwell before logging a stop (DECLARED ONLY; not enforced here yet).

    static let stopDwellSeconds: TimeInterval = 180   // 3 min (TODO: calibrate)

    //==================================

    // MARK: - Distance Triggers

    //==================================

    /// Minimum distance moved before capture (ENFORCED by `shouldCapture`).

    static func minDistanceMeters(for mode: CaptureMode) -> CLLocationDistance {

        switch mode {

        case .off:        return .infinity

        case .minimal:    return 500      // TODO: calibrate

        case .standard:   return 100      // TODO: calibrate

        case .diagnostic: return 20       // TODO: calibrate

        }

    }

    //==================================

    // MARK: - Heading Triggers

    //==================================

    /// Heading change required to force a capture (DECLARED ONLY; not enforced here yet).

    static func headingDeltaDegrees(for mode: CaptureMode) -> Double {

        switch mode {

        case .off:        return .infinity

        case .minimal:    return 60        // TODO: calibrate

        case .standard:   return 45        // TODO: calibrate

        case .diagnostic: return 15        // TODO: calibrate

        }

    }

    //==================================

    // MARK: - Retention Windows

    //==================================

    // DECLARED ONLY: retention is enforced by persistence layer (Phase 2+).

    static let hotRetentionHours: Int = 24     // raw points

    static let warmRetentionDays: Int = 14     // simplified path

    static let coldRetentionDays: Int = 120    // compressed/purged horizon

    //==================================

    // MARK: - UI Safety Lockout

    //==================================

    /// Whether speed-based UI lockout is allowed at all (ENFORCED by `shouldLockoutUI`).

    static let lockoutAvailable: Bool = true

    /// Policy toggle: restrict critical actions while moving (ENFORCED by caller, not here).

    static let lockoutAppliesToCriticalActions = true

    /// Always-allowed actions (even while moving). Caller decides how to apply.

    static let alwaysAllowedActions: [ActionKind] = [

        .undo,

        .startBreak,

        .openSettings

    ]

    //==================================

    // MARK: - Telemetry → Suggestion Rules

    //==================================

    // DECLARED ONLY: suggestion engine comes later (Phase 2+).

    static let arrivalRadiusMeters: CLLocationDistance = 150   // TODO: calibrate

    static let arrivalMaxSpeedKPH: Double = 15                  // TODO: calibrate

    //==================================

    // MARK: - Breadcrumb Thinning

    //==================================

    // DECLARED ONLY: replay/thinning comes later (Phase 2+).

    static let playbackSpeedMultiplier: Double = 10.0

    static let replaySpacingSeconds: TimeInterval = 30         // TODO: calibrate

}

  

//======================================

// MARK: - Telemetry Data Model (Minimal)

//======================================

//

// Minimal breadcrumb representation, suitable for persistence later.

// Intentionally stores derived scalar fields (speed/heading/accuracy) so the

// replay/analysis layer doesn't depend on CLLocation serialization.

//

  

struct TelemetryPoint: Identifiable, Codable {

    let id: UUID

    let timestamp: Date

    let latitude: Double

    let longitude: Double

    let speedKPH: Double?

    let headingDegrees: Double?

    let horizontalAccuracy: Double?

    let captureMode: TelemetryPolicy.CaptureMode

    let source: Source

    enum Source: String, Codable {

        case gps

        case derived

    }

}

  

//======================================

// MARK: - Telemetry Evaluation Helpers (Phase 1)

//======================================

//

// These helpers enforce ONLY the Phase 1 rules currently wired:

// - speed lockout threshold

// - min time + min distance capture triggers

//

// Heading trigger + dwell logic are intentionally not implemented yet.

//

  

extension TelemetryPolicy {

    /// Determines whether UI lockout should apply (speed threshold only).

    static func shouldLockoutUI(

        speedKPH: Double,

        modeEnabled: Bool

    ) -> Bool {

        guard lockoutAvailable, modeEnabled else { return false }

        return speedKPH >= drivingSpeedKPH

    }

    /// Determines whether a breadcrumb capture should occur (time OR distance).

    static func shouldCapture(

        lastPoint: TelemetryPoint?,

        newLocation: CLLocation,

        mode: CaptureMode

    ) -> Bool {

        guard mode != .off else { return false }

        if let last = lastPoint {

            let timeDelta = newLocation.timestamp.timeIntervalSince(last.timestamp)

            if timeDelta >= minTimeInterval(for: mode) {

                return true

            }

            let distance = newLocation.distance(

                from: CLLocation(latitude: last.latitude, longitude: last.longitude)

            )

            if distance >= minDistanceMeters(for: mode) {

                return true

            }

            // Phase 2+ idea (not implemented):

            // - compare heading delta against headingDeltaDegrees(for: mode)

            // - force capture if the route changes meaningfully

        }

        // First point in a session should usually be captured by the caller

        // (or handled here later if needed).

        return false

    }

}

  

//======================================

// MARK: - Action Kind (for lockout policy)

//======================================

  

enum ActionKind {

    case startShift

    case endShift

    case confirmLoad

    case confirmUnload

    case editTimeline

    case undo

    case startBreak

    case openSettings

}
