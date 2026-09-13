import Foundation
import CoreLocation

struct BackgroundGapState {
    var lastEstimate: BackgroundGapEstimate?
    var history: [BackgroundGapEstimate] = []
    var startAt: Date?
    var startCoordinate: CLLocationCoordinate2D?
    var endAt: Date?
    var endCoordinate: CLLocationCoordinate2D?
    var pendingEstimateMeters: Double?
    var pendingEstimateSegmentID: UUID?
    var pendingReason: String?
    var pendingSegmentID: UUID?
    var resumePending = false
    var records: [BackgroundGapRecord] = []
    var activeGapID: UUID?
}
