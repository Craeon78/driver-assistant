import Foundation

struct DistanceState {
    var gpsKmSinceLastOdoBySegment: [UUID: Double] = [:]
    var finalisedKmBySegment: [UUID: Double] = [:]
    var runningSegmentID: UUID?
    var lastOdoAnchorRecordID: UUID?
    var lastOdoAnchorKm: Int?
    var kmCorrectionFactor = 1.0
    var lastOdoCaptureTime: Date?
    var gpsKmPendingUntilFirstSegment = 0.0
    var gpsIngestSeq = 0
    var gpsShiftMetersLive = 0.0
    var lastGpsUpdateAt: Date?
    var lastGpsAccuracyMeters: Double?
    var lastGpsWasStalled = false
    var lastLmDeltaMeters = 0.0
    var lastLmValidSpeedMps: Double?
}
