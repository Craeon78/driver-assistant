import Foundation

/// V3-facing distance evidence boundary.
/// ODO observations are authoritative anchors. GPS contributes measured evidence
/// between anchors and must not become authoritative journey distance by itself.
struct DistanceEvidence {
    var odometerObservations: [OdometerObservation] = []
    var gpsKmSinceLastOdoBySegment: [UUID: Double] = [:]
    var finalisedKmBySegment: [UUID: Double] = [:]
    var runningSegmentID: UUID?
    var correctionFactor = 1.0

    var lastOdometerObservation: OdometerObservation? {
        odometerObservations.last
    }

    var gpsWindowKm: Double {
        gpsKmSinceLastOdoBySegment.values.reduce(0, +)
    }
}
