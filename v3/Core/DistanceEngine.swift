//======================================
// MARK: - DistanceEngine (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Canonical distance truth engine.
// ODO anchors close spans. GPS is evidence only.
// Learning of correction factor is preserved from V2 behaviour.
//
// Phase: Chunk 2 — Distance truth engine
//======================================

import Foundation

public final class DistanceEngine: DistanceEvidenceEngine {
    public private(set) var effectiveCorrectionFactor: Double = 1.0
    private var previousLocation: CLLocationLike?
    private var rawMeters: Double = 0
    private var filteredMeters: Double = 0
    private var currentStartAnchor: ODOAnchor?
    private var currentPoweredVehicleID: CanonicalID?
    private var closed: [DistanceInterval] = []
    private var spanCount: Int = 0
    private let tuning: GPSFilterTuning
    private let factorMin: Double = 0.70
    private let factorMax: Double = 1.30

    public init(tuning: GPSFilterTuning = .default) { self.tuning = tuning }

    public func ingestLocation(_ location: CLLocationLike) -> Bool {
        let result = GPSFilter.evaluate(newLocation: location, previousLocation: previousLocation, tuning: tuning)
        switch result {
        case .accept(let delta):
            rawMeters += location.distance(from: previousLocation ?? location)
            if previousLocation != nil { filteredMeters += delta }
            previousLocation = location
            return true
        default: return false
        }
    }

    /// Legacy single-domain entry point retained for Chunk 2 callers/tests.
    /// Cross-domain callers must use the vehicle-aware overload below.
    public func handleODOAnchor(_ anchor: ODOAnchor) -> DistanceInterval? {
        handleODOAnchorInternal(anchor)
    }

    /// Cross-domain commit boundary. A powered-vehicle change opens a fresh
    /// span before any interval is calculated or correction factor is learned.
    /// Thus odometers from two trucks can never poison one distance interval.
    public func handleODOAnchor(_ anchor: ODOAnchor, poweredVehicleID: CanonicalID) -> DistanceInterval? {
        if let currentVehicle = currentPoweredVehicleID, currentVehicle != poweredVehicleID {
            currentStartAnchor = anchor
            currentPoweredVehicleID = poweredVehicleID
            clearOpenGPSSpan()
            return nil
        }
        currentPoweredVehicleID = poweredVehicleID
        return handleODOAnchorInternal(anchor)
    }

    private func handleODOAnchorInternal(_ anchor: ODOAnchor) -> DistanceInterval? {
        let odoDelta: Double
        if let start = currentStartAnchor {
            odoDelta = Double(anchor.km - start.km)
        } else {
            currentStartAnchor = anchor
            clearOpenGPSSpan()
            return nil
        }
        guard odoDelta > 0 else { return nil }
        let rawKm = rawMeters / 1000.0
        let filteredKm = filteredMeters / 1000.0
        let errorRaw = abs(odoDelta - rawKm)
        let errorFiltered = abs(odoDelta - filteredKm)
        let chosenSource: DistanceSource
        let chosenKm: Double
        if errorRaw <= errorFiltered { chosenSource = .raw; chosenKm = rawKm }
        else { chosenSource = .filtered; chosenKm = filteredKm }
        let windowFactor = odoDelta / max(chosenKm, 0.001)
        let alpha = learningRate()
        let updated = effectiveCorrectionFactor * (1 - alpha) + windowFactor * alpha
        effectiveCorrectionFactor = clamp(updated, min: factorMin, max: factorMax)
        let interval = DistanceInterval(startAnchor: currentStartAnchor, endAnchor: anchor, odoDeltaKm: odoDelta, gpsRawKm: rawKm, gpsFilteredKm: filteredKm, chosenSource: chosenSource, chosenKm: chosenKm, correctionFactorUsed: effectiveCorrectionFactor, closedAt: anchor.recordedAt)
        closed.append(interval)
        spanCount += 1
        currentStartAnchor = anchor
        clearOpenGPSSpan()
        return interval
    }

    public func closedIntervals() -> [DistanceInterval] { closed }

    public func reset() {
        clearOpenGPSSpan()
        currentStartAnchor = nil
        currentPoweredVehicleID = nil
        closed = []
        spanCount = 0
        effectiveCorrectionFactor = 1.0
    }

    private func clearOpenGPSSpan() {
        previousLocation = nil
        rawMeters = 0
        filteredMeters = 0
    }
    private func learningRate() -> Double { if spanCount < 3 { return 0.35 }; if spanCount < 10 { return 0.18 }; return 0.06 }
    private func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double { Swift.max(lower, Swift.min(upper, value)) }
}
