import Foundation

/// Driver-domain state. This is intentionally independent of cargo modules.
/// Fatigue and work/rest truth must never depend on GPS distance or Fuel state.
struct DriverRuntimeState {
    var isOnDuty = false
    var isDriving = false
    var isOnBreak = false
    var shiftStartTime: Date?
    var currentActivity: ActivityType = .offDuty
    var currentSegmentStart: Date?
    var segmentsToday: [ActivitySegment] = []
    var driveSecondsToday: TimeInterval = 0
    var sessionBaseTimeZoneID: String = TimeZone.current.identifier
}
