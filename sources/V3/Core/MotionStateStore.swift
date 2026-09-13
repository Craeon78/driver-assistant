import Foundation

struct MotionStateStore {
    var lastKnownCourseDegrees: Double?
    var lastKnownSpeedMps: Double?
    var lastSpeedSampleAt: Date?
    var motionState: MotionState = .unsure
    var motionUncertaintyReasons: [String] = []
    var motionCertaintyReasons: [String] = []
    var speedSamples: [SpeedSample] = []
    var courseSamples: [Double] = []
    var stateChangeHistory: [Date] = []
    var stoppedAccumulatorStart: Date?
    var pendingStoppedAt: Date?
    var pendingMovingAt: Date?
    var lastDistanceIngestAt: Date?
    var distanceSpikeCount = 0
    var motionQualityStrikes = 0
    var motionLastQualityStrikeAt: Date?
    var decelUnsureGraceStartedAt: Date?
    var lastAutoRecoverAt: Date?
    var lowMotionSince: Date?
}
