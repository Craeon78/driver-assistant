
  

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - Constants

//======================================

  

// Purpose:

// - Single source of truth for all business-logic values.

// - Prevents magic numbers from scattering across files.

  

// Rules for adding constants:

// - Only values with business meaning (not UI layout or animation).

// - Prefer here when a value appears in 2+ files, or represents a named rule.

// - Always add a comment explaining the regulation or intent.

  

// Never change these values without:

// - Understanding the regulatory impact (NHVR rules).

// - Testing all affected calculations.

// - Documenting the change in PATCHLOG.md.

//======================================

  

  

//======================================

// MARK: - GPS / Motion Constants

//======================================

//

// Shared thresholds for GPS ingestion, motion inference, and load nudges.

// Values used in both AppModel+GPS.swift and LocationManager.swift are

// defined here to keep both files in sync.

//======================================

  

enum GPSConstants {

    // Speed gate: below this (m/s) the vehicle is considered stationary.

    // Used by LocationManager distance accumulation and AppModel GPS guards.

    static let minMotionSpeedMps: Double = 1.0              // ~3.6 km/h

    // GPS accuracy gate: reject fixes worse than this (metres).

    static let maxAccuracyMeters: Double = 50

    // Distance gate: reject GPS deltas larger than this in one update (anti-teleport).

    static let maxSingleUpdateJumpMeters: Double = 250

    // After an odo capture, suppress GPS-derived estimates for this long.

    // Prevents GPS noise from immediately dirtying a fresh anchor.

    static let postCaptureGraceSeconds: TimeInterval = 5

    // Treat a speed sample as stale for UI display after this interval.

    static let speedDisplayStaleSeconds: TimeInterval = 2

    // "Are you driving?" movement nudge thresholds.

    static let movementNudgeMinSpeedMps: Double = 5.5       // ~20 km/h sustained

    static let movementNudgeConfirmSeconds: TimeInterval = 12

    static let movementNudgeCooldownSeconds: TimeInterval = 600     // 10 min

    // "You appear stopped" nudge thresholds (in-load view).

    static let stoppedNudgeConfirmSeconds: TimeInterval = 90

    static let stoppedNudgeCooldownSeconds: TimeInterval = 300      // 5 min

    // Motion watchdog / auto-recovery thresholds.

    static let autoRecoverCooldownSeconds: TimeInterval = 25

    static let autoRecoverLowMotionHoldSeconds: TimeInterval = 8

    static let watchdogGpsFreshSeconds: TimeInterval = 5

    static let watchdogMovingEvidenceDeltaMeters: Double = 2.0

    static let watchdogMinCertaintyScore: Int = 30

    // Plausibility guard for distance ingestion (AppModel side).

    // 55 m/s ≈ 198 km/h (well above truck reality) — this is an "impossible" ceiling.

    static let maxPlausibleSpeedMpsForDistance: Double = 55.0

    // Allow some slack for jitter / batching / rounding.

    static let distanceGuardSlackMeters: Double = 35.0

    // Clamp km correction factor to prevent runaway km multiplication.

    // Keep wide for now; tighten later once calibration exists.

    static let kmCorrectionClampMin: Double = 0.9

    static let kmCorrectionClampMax: Double = 1.1

}

  

  

//======================================

// MARK: - Fatigue Time Constants (NHVR)

//======================================

//

// Raw threshold values only.

// Rolling-window compliance logic lives in FatigueRules / CountdownLogic.

//

// Naming convention:

// - legalBreak*  → minimum rest durations recognised by NHVR.

// - nhvr*        → NHVR legal work thresholds (standard solo).

// - dailyCap     → absolute 12h work cap (pre-persistence scope).

//======================================

  

enum FatigueConstants {

    // Minimum rest durations that count for NHVR purposes.

    static let legalBreak15: TimeInterval = 15 * 60

    static let legalBreak30: TimeInterval = 30 * 60

    static let legalBreak60: TimeInterval = 60 * 60

    // Maximum work time between legal rests (5h 15m).

    static let nhvrSpacingLimit: TimeInterval = 5.25 * 3600

    // Work threshold requiring 30m legal rest (7h 30m).

    static let nhvrSevenPointFiveHours: TimeInterval = 7.5 * 3600

    // Work threshold requiring 60m legal rest (10h).

    static let nhvrTenHours: TimeInterval = 10 * 3600

    // Absolute daily work cap (12h).

    static let nhvrDailyCap: TimeInterval = 12 * 3600

    // Required legal rest at each work threshold.

    static let requiredRestAt7h30: TimeInterval = 30 * 60

    static let requiredRestAt10h: TimeInterval  = 60 * 60

    // Minimum continuous rest after any shift (7h) — Phase 1 proxy, not rolling 24h yet.

    static let minContinuousRest: TimeInterval = 7 * 3600

    // Target total rest in a 24h window.

    static let targetTotalRest24h: TimeInterval = 12 * 3600

    static let secondsPerMinute: TimeInterval = 60

    static let secondsPerHour: TimeInterval   = 3600

    static let secondsPerDay: TimeInterval    = 86400

}

  

  

//======================================

// MARK: - Dangerous Goods Constants

//======================================

  

enum DGConstants {

    /// UN 1203 – PETROL (ULP 91/95/98)

    static let ulpUN = 1203

    /// UN 1202 – DIESEL.

    /// In AU road transport, diesel is treated as Combustible Liquid

    /// and typically NOT placarded with UN 1202.

    static let dieselUN = 1202

}

  

  

//======================================

// MARK: - Countdown / UI Severity Thresholds

//======================================

  

enum CountdownThresholds {

    // Minutes-remaining bands that control colour / urgency of countdown bars.

    static let normalThresholdMinutes: Double   = 60

    static let cautionThresholdMinutes: Double  = 30

    static let warningThresholdMinutes: Double  = 15

    static let criticalThresholdMinutes: Double = 0     // flashing starts below 0

    // Show warning colour when within 1h of the 12h daily cap.

    static let dailyCapWarningThreshold: TimeInterval = 11 * 3600

}

  

  

//======================================

// MARK: - Odometer Capture Rules

//======================================

  

enum OdoConstants {

    /// Contexts that require suburb capture (mandatory).

    static let mandatorySuburbContexts: Set<OdoPromptContext> = [

        .shiftStart,

        .legalBreakEnd,

        .shiftEnd

    ]

    /// Contexts where suburb is optional.

    static let optionalSuburbContexts: Set<OdoPromptContext> = [

        .odoUpdate

    ]

}

  

  

//======================================

// MARK: - Load Planning Limits

//======================================

  

enum LoadConstants {

    // Visual guidance thresholds only — not legal limits.

    static let massWarningThreshold: Double  = 0.90   // 90% of limit → show warning

    static let massCriticalThreshold: Double = 1.0    // 100% of limit → show critical

    // Typical specific gravity ranges per product.

    static let ulpSgMin: Double = 0.710

    static let ulpSgMax: Double = 0.750

    static let ulpSgDefault: Double = 0.724

    static let dieselSgMin: Double = 0.810

    static let dieselSgMax: Double = 0.855

    static let dieselSgDefault: Double = 0.835

    static let biodieselSgMin: Double = 0.860

    static let biodieselSgMax: Double = 0.900

    static let biodieselSgDefault: Double = 0.880

}

  

  

//======================================

// MARK: - Simulation Limits

//======================================

  

enum SimulationConstants {

    static let maxSimulationHours: Double  = 25

    static let sliderStepMinutes: Double   = 1

    static let defaultStartHour: Int       = 4

}
