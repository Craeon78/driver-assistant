
import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - AppConfigV1

//======================================

//

// Purpose:

// - Hot-tweak tunables mid-shift without recompiling.

// - Stored as JSON in Documents/DriverAssistant/JSON/AppConfig/appconfig.json

//

// Safety:

// - Only include values that are safe to change at runtime.

// - Avoid anything that changes meaning of already-recorded history.

//

  

struct AppConfigV1: Codable {

    static let schemaVersion: Int = 1

    var schemaVersion: Int = AppConfigV1.schemaVersion

    var savedAt: Date = Date()

    // Tunables you can safely change mid-shift

    var motion: AppModel.MotionTunables = AppModel.MotionTunables()

    var gps: GpsTunables = GpsTunables()

    // Optional notes for humans (ignored by logic)

    var notes: String? = nil

    static var `default`: AppConfigV1 {

        AppConfigV1(

            schemaVersion: AppConfigV1.schemaVersion,

            savedAt: Date(),

            motion: AppModel.MotionTunables(),

            gps: GpsTunables(),

            notes: "Default config"

        )

    }

    //======================================

    // MARK: - GPS Tunables (hot-tweakable subset)

    //======================================

    struct GpsTunables: Codable {

        // Speed gate: below this, treat as stationary evidence.

        // Used by AppModel distance ingestion guard.

        var minMotionSpeedMps: Double = 1.0              // ~3.6 km/h

        // GPS accuracy gate

        var maxAccuracyMeters: Double = 50

        // Distance gate (anti-teleport)

        var maxSingleUpdateJumpMeters: Double = 250

        // After odo capture, suppress GPS-derived estimates briefly

        var postCaptureGraceSeconds: TimeInterval = 5

        // UI: speed readout stales to 0 after this

        var speedDisplayStaleSeconds: TimeInterval = 2

        // "Are you driving?" nudge

        var movementNudgeMinSpeedMps: Double = 5.5       // ~20 km/h sustained

        var movementNudgeConfirmSeconds: TimeInterval = 12

        var movementNudgeCooldownSeconds: TimeInterval = 600

        // "You appear stopped" nudge (Load tab)

        var stoppedNudgeConfirmSeconds: TimeInterval = 90

        var stoppedNudgeCooldownSeconds: TimeInterval = 300

        // Motion watchdog / auto-recovery

        var autoRecoverCooldownSeconds: TimeInterval = 25

        var autoRecoverLowMotionHoldSeconds: TimeInterval = 8

        var watchdogGpsFreshSeconds: TimeInterval = 5

        var watchdogMovingEvidenceDeltaMeters: Double = 2.0

        var watchdogMinCertaintyScore: Int = 30

        // Plausibility guard for distance ingestion (AppModel side)

        // You can safely drop this from 55 -> 35 m/s mid-shift.

        var maxPlausibleSpeedMpsForDistance: Double = 55.0

        // Slack for jitter/batching

        var distanceGuardSlackMeters: Double = 35.0

    }

}
