
import Foundation

import CoreLocation

  

//======================================

// MARK: - SpanAccumulator

//======================================

//

// Purpose:

// Tracks the open GPS span between two OdoCapture anchors.

// Accumulates raw and filtered GPS distance and telemetry.

// Does NOT perform learning or correction factor updates.

//

// Lifecycle:

// startSpan()   -> called after OdoCapture

// ingest()      -> called for each accepted location sample

// snapshot()    -> read-only inspection

//

  

struct SpanAccumulator {

    // MARK: - Identity

    let spanId: UUID

    let startTime: Date

    let startOdoKm: Int

    // MARK: - Distance accumulation (km)

    private(set) var gpsRawKm: Double = 0

    private(set) var gpsFilteredKm: Double = 0

    // MARK: - Telemetry counters

    private(set) var acceptedSamples: Int = 0

    private(set) var rejectedByAccuracy: Int = 0

    private(set) var rejectedByJump: Int = 0

    private(set) var rejectedBySpeed: Int = 0

    // MARK: - Gap tracking

    private(set) var gapCount: Int = 0

    private(set) var maxGapSeconds: Double = 0

    // MARK: - Last sample state

    private(set) var lastAcceptedLocation: CLLocation?

    private(set) var lastAcceptedTime: Date?

    //======================================

    // MARK: - Init

    //======================================

    init(startOdoKm: Int, startTime: Date = Date()) {

        self.spanId = UUID()

        self.startOdoKm = startOdoKm

        self.startTime = startTime

    }

    //======================================

    // MARK: - Ingest accepted location

    //======================================

    mutating func ingestAcceptedLocation(

        _ location: CLLocation,

        filteredDeltaMeters: Double?

    ) {

        if let last = lastAcceptedLocation {

            let rawDelta = location.distance(from: last)

            gpsRawKm += rawDelta / 1000

            if let filtered = filteredDeltaMeters {

                gpsFilteredKm += filtered / 1000

            } else {

                gpsFilteredKm += rawDelta / 1000

            }

        }

        acceptedSamples += 1

        if let lastTime = lastAcceptedTime {

            let gap = location.timestamp.timeIntervalSince(lastTime)

            if gap > 15 {

                gapCount += 1

                maxGapSeconds = max(maxGapSeconds, gap)

            }

        }

        lastAcceptedLocation = location

        lastAcceptedTime = location.timestamp

    }

    //======================================

    // MARK: - Telemetry rejection markers

    //======================================

    mutating func recordRejectedAccuracy() {

        rejectedByAccuracy += 1

    }

    mutating func recordRejectedJump() {

        rejectedByJump += 1

    }

    mutating func recordRejectedSpeed() {

        rejectedBySpeed += 1

    }

    //======================================

    // MARK: - Snapshot

    //======================================

    func snapshot() -> SpanSnapshot {

        SpanSnapshot(

            spanId: spanId,

            startOdoKm: startOdoKm,

            startTime: startTime,

            gpsRawKm: gpsRawKm,

            gpsFilteredKm: gpsFilteredKm,

            acceptedSamples: acceptedSamples,

            rejectedByAccuracy: rejectedByAccuracy,

            rejectedByJump: rejectedByJump,

            rejectedBySpeed: rejectedBySpeed,

            gapCount: gapCount,

            maxGapSeconds: maxGapSeconds

        )

    }

}

  

  

//======================================

// MARK: - SpanSnapshot

//======================================

//

// Immutable inspection view used by

// DebugDashboard or GPSDistanceEngine.

//

  

struct SpanSnapshot {

    let spanId: UUID

    let startOdoKm: Int

    let startTime: Date

    let gpsRawKm: Double

    let gpsFilteredKm: Double

    let acceptedSamples: Int

    let rejectedByAccuracy: Int

    let rejectedByJump: Int

    let rejectedBySpeed: Int

    let gapCount: Int

    let maxGapSeconds: Double

}
