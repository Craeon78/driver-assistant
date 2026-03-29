//======================================
// MARK: - AppModel+GPS
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+GPS.swift
//
// Purpose:
// - Isolate GPS-derived evidence, motion inference, and distance interpretation from core app state.
// - Keeps AppModel.swift focused on orchestration and stored state ownership.
//
// Responsibilities:
// - GPS distance ingestion and per-segment accumulation.
// - ODO-constrained kilometre estimation and display helpers.
// - Latest speed/course sample handling (evidence only).
// - MotionState inference using dwell, trend, and data-quality guards.
// - Movement nudges, certainty scoring, watchdog recovery, and shadow telemetry bridging.
//
// Notes:
// - GPS is NOT authoritative. It is evidence used for coaching, approximation, and reconciliation.
// - ODO anchors remain the authoritative distance truth; GPS helps estimate between anchors.
// - Time + dwell confirm motion states to reduce flapping and jitter.
// - MotionState and certainty are operational/diagnostic signals, not canonical truth.
// - @Published stored properties must live on the main AppModel type, not in extensions.
//======================================

import Foundation
import CoreLocation

// MARK: - Nested Types

extension AppModel {
    
    enum MotionState: String, Codable, CaseIterable {
        case stopped        // truly stationary (~0 km/h)
        case crawling       // slow maneuvering, 3–15 km/h, sketchy heading
        case accelerating   // >20 km/h, gaining speed
        case decelerating   // >20 km/h, losing speed
        case cruising       // >20 km/h, steady speed
        case unsure         // invalid/stale GPS or data quality issues
        
        var shortLabel: String {
            switch self {
            case .stopped:      return "STOP"
            case .crawling:     return "CRAWL"
            case .accelerating: return "ACCEL"
            case .decelerating: return "DECEL"
            case .cruising:     return "MOTION"
            case .unsure:       return "UNSURE"
            }
        }
    }
    
    struct MotionTunables: Codable {
        // Speed thresholds (m/s)
        var stoppedBelowMps: Double  = 0.9     // ~3 km/h
        var crawlAboveMps: Double    = 0.9     // ~3 km/h
        var crawlBelowMps: Double    = 4.1     // ~15 km/h
        var movingAboveMps: Double   = 4.8     // ~20 km/h
        
        // Dwell: seconds at low speed required to confirm stopped.
        var stoppedDwell: TimeInterval = 2.5
        
        // Acceleration thresholds (m/s²), applied only for speeds >20 km/h.
        var accelMps2: Double = 0.25
        var decelMps2: Double = 0.4
        
        // Data quality (strike-based unsure)
        var qualityStrikesToUnsure: Int = 3          // Option A: 3 consecutive bad samples
        var qualityStrikeDecaySeconds: TimeInterval = 3.0 // Optional: forgive strikes after some clean time
        
        // Data quality gates.
        var maxSpeedJumpMps: Double     = 13.9   // ~50 km/h impossible jump in <2s
        var maxStateFlapsIn5s: Int      = 5
        var gpsLostSeconds: TimeInterval = 10.0
        var gpsStaleSeconds: TimeInterval = 2.5
        var decelUnsureGraceSeconds: TimeInterval = 2.0
        
        // Heading variance threshold (degrees) above which heading is "sketchy".
        var courseVarianceThreshold: Double = 30.0
    }
    
    // Small rolling window of speed samples for trend calculation.
    struct SpeedSample {
        let t: Date
        let s: Double  // m/s
    }
    
    // Recorded distance events for audit / reconciliation display.
    struct DistanceEvent: Identifiable, Codable {
        var id: UUID
        let at: Date
        let segmentID: UUID?
        let kind: Kind
        let deltaKm: Double
        let note: String
        
        enum Kind: String, Codable {
            case backgroundGapApplied
            case odoReconciliation
        }
        
        init(id: UUID = UUID(), at: Date, segmentID: UUID?, kind: Kind, deltaKm: Double, note: String) {
            self.id        = id
            self.at        = at
            self.segmentID = segmentID
            self.kind      = kind
            self.deltaKm   = deltaKm
            self.note      = note
        }
    }
    
    enum CertaintyBucket {
        case high, medium, low, untrustworthy
    }
}

// MARK: - Distance (GPS estimate + ODO reconciliation)

extension AppModel {
    
    var suggestedOdoFromGps: Int? {
        guard let anchor = lastOdoAnchorKm else { return nil }
        
        // Grace period: if we just captured odo, ignore GPS noise.
        if let lastCapture = lastOdoCaptureTime,
           Date().timeIntervalSince(lastCapture) < gpsT.postCaptureGraceSeconds {
            return anchor
        }
        
        let windowKm = gpsKmSinceLastOdoBySegment.values.reduce(0, +)
        let est = Double(anchor) + (windowKm * effectiveKmCorrectionFactor)
        return Int(est.rounded())
    }
    
    func kmApprox(for segment: ActivitySegment) -> Double {
        let sid      = segment.id
        let finalised = finalisedKmBySegment[sid] ?? 0
        let pending = gpsKmSinceLastOdoBySegment[sid] ?? 0
        return finalised + pending
    }
    
    // Segment km (AppModel ingest + correction factor + odo reconciliation). Journal/analysis number.
    var shiftKmBySegmentsApprox: Double {
        let finalised = finalisedKmBySegment.values.reduce(0, +)
        let pendingRaw = gpsKmSinceLastOdoBySegment.values.reduce(0, +)
        let pendingCorrected = pendingRaw * effectiveKmCorrectionFactor
        return finalised + pendingCorrected
    }
    
    // Live GPS (LocationManager mirror). Driver-facing “trust” number.
    var shiftKmLiveGps: Double { gpsShiftMetersLive / 1000.0 }
    
    var currentSegmentKmApprox: Double {
        guard let sid = runningSegmentID else { return 0 }
        let finalised = finalisedKmBySegment[sid] ?? 0
        let pendingRaw = gpsKmSinceLastOdoBySegment[sid] ?? 0
        let pendingCorrected = pendingRaw * effectiveKmCorrectionFactor
        return finalised + pendingCorrected
    }

    
    // TODO: dt should be based on ingest cadence (lastDistanceIngestAt), not CLLocation.timestamp.
    func ingestGpsDeltaMeters(_ meters: Double) {
        guard isOnDuty, meters > 0 else { return }
        
        let now = Date()
        
        // While a background gap is pending resolution, halt accumulation to avoid compounding error.
        if pendingGapSegmentID != nil {
            DebugLog.motion("🧱 GPS IGNORE (background gap pending) meters=\(String(format: "%.2f", meters))")
            return
        }
        
        // If motion is untrustworthy, don't count distance.
        if motionState == .unsure {
            DebugLog.motion("🧯 GPS IGNORE (motion unsure) meters=\(String(format: "%.2f", meters))")
            return
        }
        
        // Reject GPS noise when speed evidence is below the motion threshold.
        if let s = lastKnownSpeedMps, s >= 0, s < gpsT.minMotionSpeedMps {
            DebugLog.motion("🧯 GPS IGNORE (speed<\(gpsT.minMotionSpeedMps)) meters=\(String(format: "%.2f", meters)) speed=\(String(format: "%.2f", s))")
            return
        }
        
        // Reject fixes with poor accuracy.
        if let acc = lastGpsAccuracyMeters, (acc < 0 || acc > gpsT.maxAccuracyMeters) {
            DebugLog.motion("🧯 GPS IGNORE (acc>\(gpsT.maxAccuracyMeters)) meters=\(String(format: "%.2f", meters)) acc=\(String(format: "%.0f", acc))")
            return
        }
        
        // Reject teleport-sized deltas.
        if meters > gpsT.maxSingleUpdateJumpMeters {
            DebugLog.motion("🧯 GPS IGNORE (jump>\(gpsT.maxSingleUpdateJumpMeters)m) meters=\(String(format: "%.2f", meters))")
            return
        }
        
        // -----------------------------
        // NEW: time-aware plausibility guard
        // -----------------------------
        let dt: TimeInterval = {
            if let t = lastDistanceIngestAt { return max(0.01, now.timeIntervalSince(t)) }
            if let t = lastGpsUpdateAt      { return max(0.01, now.timeIntervalSince(t)) }
            return 1.0
        }()
        
        let maxMetersThisTick =
        (gpsT.maxPlausibleSpeedMpsForDistance * dt) + gpsT.distanceGuardSlackMeters
        
        if meters > maxMetersThisTick {
            distanceSpikeCount += 1
            DebugLog.motion("🧯 GPS IGNORE (implausible delta) meters=\(String(format: "%.2f", meters)) dt=\(String(format: "%.2f", dt)) max=\(String(format: "%.2f", maxMetersThisTick)) spike#=\(distanceSpikeCount)")
            return
        } else {
            distanceSpikeCount = 0
        }
        
        lastDistanceIngestAt = now
        
        gpsIngestSeq += 1
        DebugLog.gps("📏 GPS INGEST #\(gpsIngestSeq)  meters=\(String(format: "%.3f", meters))  sid=\(runningSegmentID?.uuidString.prefix(6) ?? "nil")  t=\(now)")
        
        let km = meters / 1000.0
        
        guard let sid = runningSegmentID else {
            // Shift started but first segment not committed yet — buffer until ready.
            gpsKmPendingUntilFirstSegment += km
            return
        }
        
        // Flush any buffered pre-segment distance into the first real segment.
        if gpsKmPendingUntilFirstSegment > 0 {
            gpsKmSinceLastOdoBySegment[sid, default: 0] += gpsKmPendingUntilFirstSegment
            gpsKmPendingUntilFirstSegment = 0
        }
        
        gpsKmSinceLastOdoBySegment[sid, default: 0] += km
    }
}


// MARK: - Speed Sample Ingestion

extension AppModel {
    
    private var effectiveKmCorrectionFactor: Double {
        min(max(kmCorrectionFactor, GPSConstants.kmCorrectionClampMin),
            GPSConstants.kmCorrectionClampMax)
    }
    
    // Speed in km/h for UI display; returns 0 if the sample is stale.
    var speedKmh: Double? {
        if let t = lastSpeedSampleAt, Date().timeIntervalSince(t) > gpsT.speedDisplayStaleSeconds {
            return 0
        }
        guard let mps = lastKnownSpeedMps, mps >= 0 else { return nil }
        return mps * 3.6
    }
    
    func ingestSpeedSample(_ mps: Double?, course: Double?) {
        // Do NOT write lastSpeedSampleAt here — timing is managed inside
        // ingestSpeedSampleForMotionState to keep "previous sample" comparisons consistent.
        lastKnownCourseDegrees = course
        ingestSpeedSampleForMotionState(mps, course: course, at: Date())
    }
    
    func ingestSpeedSampleForMotionState(_ speedMps: Double?, course: Double?, at time: Date = Date()) {
        let prevSampleAt  = lastSpeedSampleAt
        let prevSpeedMps  = lastKnownSpeedMps
        
        
            let kmh = (speedMps ?? -1) * 3.6
            let c   = course ?? -1
            DebugLog.motion("🧭 Motion ingest: speed=\(String(format: "%.1f", kmh)) km/h  course=\(String(format: "%.0f", c))°  t=\(time)")
        
        guard let s = speedMps, s >= 0 else {
            // Don’t insta-UNSURE on a single nil/-1 tick.
            // Treat as “no evidence” and let tickMotionState decide stale/lost.
            return
        }
        
        lastSpeedSampleAt = time
        
        if let issue = checkDataQuality(speed: s, time: time, prevSpeed: prevSpeedMps, prevTime: prevSampleAt) {
            
            if issue == .unsure,
               isInPlausibleDecelTransition(speed: s, prevSpeed: prevSpeedMps, prevTime: prevSampleAt, now: time) {
                
                if decelUnsureGraceStartedAt == nil {
                    decelUnsureGraceStartedAt = time
                    DebugLog.motion("⏳ Decel grace started")
                    return
                }
                
                if let started = decelUnsureGraceStartedAt,
                   time.timeIntervalSince(started) < motionTunables.decelUnsureGraceSeconds {
                    
                    DebugLog.motion("⏳ Decel grace holding UNSURE")
                    return
                }
            }
            
            decelUnsureGraceStartedAt = nil
            
            motionState = issue
            recordStateChange(at: time)
            speedSamples.removeAll(keepingCapacity: true)
            courseSamples.removeAll(keepingCapacity: true)
            return
        }
        
        lastKnownSpeedMps = s
        speedSamples.append(SpeedSample(t: time, s: s))
        if speedSamples.count > maxSpeedSamples { speedSamples.removeFirst() }
        
        if checkStopped(speed: s, time: time) {
            if motionState != .stopped {
                motionState = .stopped
                recordStateChange(at: time)
                speedSamples.removeAll(keepingCapacity: true)
                courseSamples.removeAll(keepingCapacity: true)
            }
            return
        }
        
        // Good sample
        decelUnsureGraceStartedAt = nil
        
        let newState = determineMotionFromSpeed(speed: s, course: course, time: time)
        if motionState != newState {
            motionState = newState
            recordStateChange(at: time)
        }
        
        if motionState == .unsure {
            refreshMotionUncertaintyReasons(now: time)
        } else {
            clearMotionUncertaintyReasons()
        }
    }
}


// MARK: - Movement → "Are you driving?" Nudge

extension AppModel {
    
    func considerMovementPrompt(speedMps: Double?) {
        guard isOnDuty else { return }
        guard activeGuardPrompt == nil else { return }
        
        guard !isDriving else { movementStartAt = nil; return }
        guard !isOnBreak  else { movementStartAt = nil; return }
        
        guard let s = speedMps, s >= gpsT.movementNudgeMinSpeedMps else {
            movementStartAt = nil
            return
        }
        
        let now = Date()
        
        if let last = lastNudgeAt, now.timeIntervalSince(last) < gpsT.movementNudgeCooldownSeconds {
            return
        }
        
        if movementStartAt == nil {
            movementStartAt = now
            return
        }
        
        if let started = movementStartAt,
           now.timeIntervalSince(started) >= gpsT.movementNudgeConfirmSeconds {
            lastNudgeAt     = now
            movementStartAt = nil
            request(.drive, source: .movementNudge)
        }
    }
}


// MARK: - Motion Inference Helpers (private)

extension AppModel {
    
    private func checkDataQuality(speed: Double, time: Date, prevSpeed: Double?, prevTime: Date?) -> MotionState? {
        
        // Optional forgiveness: if we’ve been clean for a bit, drop strikes.
        if let lastStrike = motionLastQualityStrikeAt,
           time.timeIntervalSince(lastStrike) > motionTunables.qualityStrikeDecaySeconds {
            motionQualityStrikes = 0
        }
        
        var failed = false
        
        // 1) Speed jump gate
        if let ps = prevSpeed, let pt = prevTime {
            let dt = time.timeIntervalSince(pt)
            if dt > 0.05 {
                let speedDelta = abs(speed - ps)
                if speedDelta > motionTunables.maxSpeedJumpMps && dt < 2.0 {
                    DebugLog.motion("❌ Motion quality: speed jump \(String(format: "%.1f", speedDelta * 3.6)) km/h in \(String(format: "%.2f", dt))s")
                    failed = true
                }
            }
        }
        
        // 2) Flap gate
        let recentChanges = stateChangeHistory.filter { time.timeIntervalSince($0) < 5.0 }
        if recentChanges.count >= motionTunables.maxStateFlapsIn5s {
            DebugLog.motion("❌ Motion quality: flapping (\(recentChanges.count) changes/5s)")
            failed = true
        }
        
        // Strike logic
        if failed {
            motionQualityStrikes += 1
            motionLastQualityStrikeAt = time
            
            // Only go UNSURE after N strikes
            if motionQualityStrikes >= motionTunables.qualityStrikesToUnsure {
                refreshMotionUncertaintyReasons(now: time)
                return .unsure
            
            } else {
                DebugLog.motion("⚠️ Motion quality: strike \(motionQualityStrikes)/\(motionTunables.qualityStrikesToUnsure) (holding state)")
                return nil
            }
        } else {
            // Good sample: clear strikes
            motionQualityStrikes = 0
            if motionState != .unsure {
                clearMotionUncertaintyReasons()
            }
            return nil
        }
    }
    
    private func checkStopped(speed: Double, time: Date) -> Bool {
        guard speed < motionTunables.stoppedBelowMps else {
            stoppedAccumulatorStart = nil
            return false
        }
        if stoppedAccumulatorStart == nil {
            stoppedAccumulatorStart = time
            return false
        }
        guard let start = stoppedAccumulatorStart else { return false }
        return time.timeIntervalSince(start) >= motionTunables.stoppedDwell
    }
    
    private func checkCrawling(speed: Double, course: Double) -> Bool {
        guard speed >= motionTunables.crawlAboveMps,
              speed < motionTunables.crawlBelowMps else { return false }
        let hasSketchyHeading = course < 0 || courseIsChangingWildly(currentCourse: course)
        return hasSketchyHeading
    }
    
    private func isInPlausibleDecelTransition(
        speed: Double,
        prevSpeed: Double?,
        prevTime: Date?,
        now: Date
    ) -> Bool {
        
        guard let ps = prevSpeed, let pt = prevTime else { return false }
        
        let dt = now.timeIntervalSince(pt)
        
        guard dt > 0.05, dt < 3.0 else { return false }
        
        guard speed < ps else { return false }
        
        guard speed > motionTunables.stoppedBelowMps else { return false }
        
        return motionState == .decelerating
        || motionState == .cruising
        || motionState == .accelerating
    }
    
    private func courseIsChangingWildly(currentCourse: Double) -> Bool {
        if currentCourse >= 0 {
            courseSamples.append(currentCourse)
            if courseSamples.count > maxCourseHistory { courseSamples.removeFirst() }
        }
        guard courseSamples.count >= 3 else { return false }
        return calculateAngularVariance(courseSamples) > motionTunables.courseVarianceThreshold
    }
    
    private func calculateAngularVariance(_ courses: [Double]) -> Double {
        guard courses.count >= 2 else { return 0 }
        var deltas: [Double] = []
        for i in 1..<courses.count {
            var delta = abs(courses[i] - courses[i-1])
            if delta > 180 { delta = 360 - delta }  // handle 350°→10° wrap
            deltas.append(delta)
        }
        return deltas.reduce(0, +) / Double(deltas.count)
    }
    
    private func determineMotionTrend() -> MotionState {
        // Decel/accel: react faster
        let trendFast = calculateCurrentTrend(window: 3)
        if trendFast <= -motionTunables.decelMps2 { return .decelerating }
        if trendFast >=  motionTunables.accelMps2 { return .accelerating }
        
        // Cruise: require more evidence
        let trendStable = calculateCurrentTrend(window: 5)
        if trendStable >=  motionTunables.accelMps2  { return .accelerating }
        if trendStable <= -motionTunables.decelMps2 { return .decelerating }
        return .cruising
    }
    
    private func calculateCurrentTrend(window: Int) -> Double {
        guard speedSamples.count >= window else { return 0 }
        let recent = speedSamples.suffix(window)
        guard let first = recent.first, let last = recent.last else { return 0 }
        let dt = last.t.timeIntervalSince(first.t)
        guard dt > 0.15 else { return 0 }
        return (last.s - first.s) / dt
    }
    
    private func determineMotionFromSpeed(speed: Double, course: Double?, time: Date) -> MotionState {
        let c = course ?? -1
        
        if checkCrawling(speed: speed, course: c) { return .crawling }
        
        if speed >= motionTunables.movingAboveMps { return determineMotionTrend() }
        
        if speed >= motionTunables.crawlBelowMps {
            let trend = calculateCurrentTrend(window: 3)
            return trend <= -motionTunables.decelMps2 ? .decelerating : .crawling
        }
        return .crawling
    }
    
    private func recordStateChange(at time: Date) {
        stateChangeHistory.append(time)
        stateChangeHistory = stateChangeHistory.filter { time.timeIntervalSince($0) < 10.0 }
    }
}

// MARK: - Motion Uncertainty Reasons

extension AppModel {
    
    private func refreshMotionUncertaintyReasons(now: Date = Date()) {
        guard motionState == .unsure else {
            motionUncertaintyReasons = []
            return
        }
        
        var reasons: [String] = []
        
        // GPS freshness
        if let lastSample = lastSpeedSampleAt {
            let age = now.timeIntervalSince(lastSample)
            if age > motionTunables.gpsLostSeconds {
                reasons.append("GPS lost")
            } else if age > motionTunables.gpsStaleSeconds {
                reasons.append("GPS stale")
            }
        } else {
            reasons.append("No speed samples")
        }
        
        // Speed sample missing
        if lastKnownSpeedMps == nil {
            reasons.append("No speed")
        }
        
        // Quality strikes
        if motionQualityStrikes > 0 {
            reasons.append("Low quality")
        }
        
        // Flapping
        let recentChanges = stateChangeHistory.filter { now.timeIntervalSince($0) < 5.0 }
        if recentChanges.count >= motionTunables.maxStateFlapsIn5s {
            reasons.append("Flapping")
        }
        
        // Low-speed ambiguity
        if let s = lastKnownSpeedMps,
           s >= motionTunables.stoppedBelowMps,
           s < motionTunables.movingAboveMps {
            reasons.append("Low-speed ambiguity")
        }
        
        // Heading instability
        if courseSamples.count >= 3,
           calculateAngularVariance(courseSamples) > motionTunables.courseVarianceThreshold {
            reasons.append("Heading unstable")
        }
        
        motionUncertaintyReasons = Array(NSOrderedSet(array: reasons)) as? [String] ?? reasons
    }
    
    private func clearMotionUncertaintyReasons() {
        motionUncertaintyReasons = []
    }
}

// MARK: - Motion State Timer Tick & Reset

extension AppModel {
    
    // Called by the app ticker so STOP can be confirmed even when CoreLocation
    // stops sending samples while the vehicle is stationary.
    func tickMotionState(now: Date = Date()) {
        guard isOnDuty else {
            motionState = .stopped
            stoppedAccumulatorStart = nil
            return
        }
        
        guard let lastSample = lastSpeedSampleAt else {
            motionState = .stopped
            return
        }
        
        let age = now.timeIntervalSince(lastSample)
        
        if age > motionTunables.gpsLostSeconds {
            if motionState != .unsure {
                motionState = .unsure
                recordStateChange(at: now)
            }
            refreshMotionUncertaintyReasons(now: now)
            return
        }
        
        if age > motionTunables.gpsStaleSeconds {
            // Allow a pending STOP to lock in even if GPS has gone quiet.
            if let start = stoppedAccumulatorStart,
               let s = lastKnownSpeedMps, s >= 0, s < motionTunables.stoppedBelowMps,
               now.timeIntervalSince(start) >= motionTunables.stoppedDwell {
                if motionState != .stopped {
                    motionState = .stopped
                    recordStateChange(at: now)
                    clearMotionUncertaintyReasons()
                    speedSamples.removeAll(keepingCapacity: true)
                    courseSamples.removeAll(keepingCapacity: true)
                }
            }
        }
    }
    
    func resetMotionInference(reason: String = "Manual") {
        DebugLog.motion("🧽 Motion reset: \(reason) t=\(Date())")
        motionState             = .unsure
        stoppedAccumulatorStart = nil
        speedSamples.removeAll(keepingCapacity: true)
        courseSamples.removeAll(keepingCapacity: true)
        stateChangeHistory.removeAll(keepingCapacity: true)
        refreshMotionUncertaintyReasons(now: Date())
    }
}


// MARK: - Motion Certainty Scoring

extension AppModel {
    
    var motionPillCertaintyScore: Int {
        let now    = Date()
        let gps    = gpsCertaintyScore(now: now)
        let motion = motionCertaintyScore(now: now)
        return min(gps, motion)
    }
    
    var motionPillBucket: CertaintyBucket {
        switch motionPillCertaintyScore {
        case 80...100: return .high
        case 55...79:  return .medium
        case 30...54:  return .low
        default:       return .untrustworthy
        }
    }
    
    func overallCertaintyBandForUI(now: Date = Date()) -> CertaintyBucket {
        if motionState == .unsure { return .untrustworthy }
        switch overallCertaintyScore(now: now) {
        case 80...100: return .high
        case 55...79:  return .medium
        case 30...54:  return .low
        default:       return .untrustworthy
        }
    }
    
    func overallCertaintyScoreForUI(now: Date = Date()) -> Int {
        overallCertaintyScore(now: now)
    }
    
    private func gpsCertaintyScore(now: Date = Date()) -> Int {
        var score = 100
        if let acc = lastGpsAccuracyMeters {
            if      acc > 100 { score -= 40 }
            else if acc > 50  { score -= 20 }
            else if acc > 20  { score -= 10 }
        } else {
            score -= 25
        }
        if let t = lastGpsUpdateAt {
            let age = now.timeIntervalSince(t)
            if      age > 20 { score -= 60 }
            else if age > 10 { score -= 35 }
            else if age > 5  { score -= 15 }
        } else {
            score -= 40
        }
        return max(0, min(100, score))
    }
    
    private func motionCertaintyScore(now: Date = Date()) -> Int {
        if motionState == .unsure { return 25 }
        var score = 100
        if let t = lastSpeedSampleAt {
            let age = now.timeIntervalSince(t)
            if      age > 10  { score -= 70 }
            else if age > 5   { score -= 35 }
            else if age > 2.5 { score -= 15 }
        } else {
            score -= 70
        }
        if lastKnownSpeedMps == nil { score -= 40 }
        if let v = lastKnownSpeedMps, v >= gpsT.movementNudgeMinSpeedMps, speedSamples.count < 3 {
            score -= 15
        }
        return max(0, min(100, score))
    }
    
    private func overallCertaintyScore(now: Date = Date()) -> Int {
        let gps    = gpsCertaintyScore(now: now)
        let motion = motionCertaintyScore(now: now)
        let lower  = min(gps, motion)
        let higher = max(gps, motion)
        let raw: Double = {
            if lower < 20 { return Double(lower) }
            if lower < 35 { return Double(lower) * 0.8 + Double(higher) * 0.2 }
            return Double(lower) * 0.65 + Double(higher) * 0.35
        }()
        return max(0, min(100, Int(raw.rounded())))
    }
}


// MARK: - Motion Watchdog / Auto-Recovery

extension AppModel {
    
    @MainActor
    func autoRecoverMotionIfNeeded(reason: String) {
        resetMotionInference(reason: "AUTO: \(reason)")
        requestGpsKickFromUI?("AUTO: \(reason)")
        lastAutoRecoverReason  = reason
        lastAutoRecoverFiredAt = Date()
    }
    
    @MainActor
    func motionWatchdogTick() {
        let now    = Date()
        let gps    = gpsCertaintyScore(now: now)
        let motion = motionCertaintyScore(now: now)
        
        let gpsFresh: Bool = {
            guard let t = lastGpsUpdateAt else { return false }
            return now.timeIntervalSince(t) < gpsT.watchdogGpsFreshSeconds
        }()
        
        let gpsAccOK: Bool = {
            guard let acc = lastGpsAccuracyMeters else { return false }
            return acc > 0 && acc < gpsT.maxAccuracyMeters
        }()
        
        if motion <= gpsT.watchdogMinCertaintyScore {
            if lowMotionSince == nil { lowMotionSince = now }
        } else {
            lowMotionSince = nil
            return
        }
        
        guard let since = lowMotionSince,
              now.timeIntervalSince(since) >= gpsT.autoRecoverLowMotionHoldSeconds else { return }
        
        let validSpeed       = lastLmValidSpeedMps ?? lastKnownSpeedMps
        let movingEvidence   =
        (validSpeed ?? 0) > gpsT.minMotionSpeedMps ||
        lastLmDeltaMeters > gpsT.watchdogMovingEvidenceDeltaMeters ||
        speedSamples.isEmpty
        
        guard gpsFresh && gpsAccOK else { return }
        guard movingEvidence       else { return }
        
        if let last = lastAutoRecoverAt,
           now.timeIntervalSince(last) < gpsT.autoRecoverCooldownSeconds { return }
        
        lastAutoRecoverAt = now
        lowMotionSince    = nil
        autoRecoverMotionIfNeeded(reason: "motion≤\(gpsT.watchdogMinCertaintyScore) for \(Int(gpsT.autoRecoverLowMotionHoldSeconds))s while GPS good (gps=\(gps))")
    }
}

// MARK: backgrounded app data collection point 
extension AppModel { 
    struct BackgroundGapRecord: Identifiable, Codable {
        let id: UUID
        let startTime: Date
        let endTime: Date
        
        let startLat: Double
        let startLon: Double
        let endLat: Double
        let endLon: Double
        
        let elapsedSeconds: TimeInterval
        let straightLineKm: Double
        let estimatedRoadKm: Double?
        
        var isResolved: Bool
        var resolutionNote: String?
        
        init(
            id: UUID = UUID(),
            startTime: Date,
            endTime: Date,
            startLat: Double,
            startLon: Double,
            endLat: Double,
            endLon: Double,
            elapsedSeconds: TimeInterval,
            straightLineKm: Double,
            estimatedRoadKm: Double?,
            isResolved: Bool = false,
            resolutionNote: String? = nil
        ) {
            self.id = id
            self.startTime = startTime
            self.endTime = endTime
            self.startLat = startLat
            self.startLon = startLon
            self.endLat = endLat
            self.endLon = endLon
            self.elapsedSeconds = elapsedSeconds
            self.straightLineKm = straightLineKm
            self.estimatedRoadKm = estimatedRoadKm
            self.isResolved = isResolved
            self.resolutionNote = resolutionNote
        }
    }
}
