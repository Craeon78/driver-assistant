
import Foundation

import CoreLocation

  

//======================================

// MARK: - GPSDistanceEngine

//======================================

//

// Central controller for GPS distance

// estimation and correction factor learning.

//

// Responsibilities:

// • Receive GPS updates

// • Accumulate span distance

// • Close spans when OdoCapture occurs

// • Select best GPS evidence source

// • Update correction factor

// • Emit SpanClosureLog diagnostics

//

// Does NOT:

// • Control UI

// • Persist data

// • Modify past spans

//

  

final class GPSDistanceEngine {

    //======================================

    // MARK: - Current span

    //======================================

    private var currentSpan: SpanAccumulator?

    //======================================

    // MARK: - Correction factor state

    //======================================

    private(set) var effectiveCorrectionFactor: Double = 1.0

    private(set) var maturityState: MaturityState = .embryonic

    //======================================

    // MARK: - Diagnostics

    //======================================

    private(set) var spanLogs: [SpanClosureLog] = []

    //======================================

    // MARK: - Public: Start new span

    //======================================

    func startSpan(startOdoKm: Int, at time: Date = Date()) {

        currentSpan = SpanAccumulator(

            startOdoKm: startOdoKm,

            startTime: time

        )

    }

    //======================================

    // MARK: - Public: GPS update

    //======================================

    func handleLocationUpdate(_ location: CLLocation) {

        guard var span = currentSpan else { return }

        // Basic acceptance rules

        if location.horizontalAccuracy > GPSTuning.maxHorizontalAccuracy {

            span.recordRejectedAccuracy()

            currentSpan = span

            return

        }

        let age = Date().timeIntervalSince(location.timestamp)

        if age > GPSTuning.maxSampleAge {

            span.recordRejectedAccuracy()

            currentSpan = span

            return

        }

        // For now: raw delta only

        span.ingestAcceptedLocation(location, filteredDeltaMeters: nil)

        currentSpan = span

    }

    //======================================

    // MARK: - Public: OdoCapture

    //======================================

    func handleOdoCapture(newOdoKm: Int, timestamp: Date = Date()) {

        guard let span = currentSpan else { return }

        let snapshot = span.snapshot()

        let odoDelta = Double(newOdoKm - snapshot.startOdoKm)

        if odoDelta <= 0 { return }

        let raw = snapshot.gpsRawKm

        let filtered = snapshot.gpsFilteredKm

        // Determine errors

        let errorRaw = abs(odoDelta - raw)

        let errorFiltered = abs(odoDelta - filtered)

        let chosenSource: DistanceSource

        if errorRaw <= errorFiltered {

            chosenSource = .raw

        } else {

            chosenSource = .filtered

        }

        let chosenDistance =

        chosenSource == .raw ? raw : filtered

        // Compute correction factor window

        let windowFactor = odoDelta / max(chosenDistance, 0.001)

        let priorFactor = effectiveCorrectionFactor

        let alpha = learningRate(for: maturityState)

        let updatedFactor =

        priorFactor * (1 - alpha) +

        windowFactor * alpha

        effectiveCorrectionFactor =

        clamp(updatedFactor,

              min: GPSTuning.factorMin,

              max: GPSTuning.factorMax)

        // Diagnostic log

         let log = SpanClosureLog(

            timestamp: timestamp,

            odoDeltaKm: odoDelta,

            gpsRawKm: raw,

            gpsFilteredKm: filtered,

            chosenSource: chosenSource,

            priorFactor: priorFactor,

            updatedFactor: effectiveCorrectionFactor,

            maturityState: maturityState,

            errorRawKm: errorRaw,

            errorFilteredKm: errorFiltered

        )

        spanLogs.append(log)

        // Start next span

        startSpan(startOdoKm: newOdoKm, at: timestamp)

    }

    //======================================

    // MARK: - Learning rate

    //======================================

    private func learningRate(for state: MaturityState) -> Double {

        switch state {

        case .embryonic:

            return GPSTuning.alphaEmbryonic

        case .stabilising:

            return GPSTuning.alphaStabilising

        case .mature:

            return GPSTuning.alphaMature

        case .drifting:

            return GPSTuning.alphaDrifting

        }

    }

    //======================================

    // MARK: - Clamp helper

    //======================================

    private func clamp(

        _ value: Double,

        min lower: Double,

        max upper: Double

    ) -> Double {

        return Swift.max(lower, Swift.min(upper, value))

    }

}
