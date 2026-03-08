---

type: canonical-snapshot

snapshot_role: code

project: DriverAssistant

version: v0.2.6

snapshot_id: 2026308-1530

date: 08-Mar-2026

timezone: Australia/Brisbane

paired_resource_snapshot: Snapshot-Resources-v0.2.6

device_tested: iPad8,10 / iOS 26.2.1

build_status: Compiles / Runs

  

copyrighted: © 2026 Cory Russell Olsen. All rights reserved.

This snapshot and its contents are proprietary and confidential.

---

  

# Snapshot – Driver Assistant (CANONICAL CODE SNAPSHOT)

  

This file represents the **authoritative code state** of the Driver Assistant project at the time of capture.

  

It is **paired with a separate file**:

  

**Snapshot Resources – Driver Assistant**

  

The two files together form the complete canonical snapshot.

  

• **Snapshot (this file)** → executable source code  

• **Snapshot Resources** → architecture notes, registries, patchlogs, and reference material

  

If any discrepancy exists between documentation and code, **this snapshot takes precedence.**

  

---

  

# 0. Snapshot Scope

  

Includes:

  

• All `.swift` source files  

• Core model definitions  

• Extensions that affect runtime behaviour  

• Logic, services, and views required to compile and run the app

  

Excludes:

  

• Architecture notes  

• Patchlog history  

• Registry seed lists  

• JSON resource seeds  

• Assets and asset catalogs  

• Info.plist  

• Build settings  

• Derived data  

  

Excluded material is located in the **Snapshot Resources file**.

  

---

  

# 1. Canonical Rules

  

1. This snapshot is the **single source of truth for executable code**.

  

2. The paired **Snapshot Resources file** contains supporting documentation and registries but does not override code behaviour.

  

3. Any code not present in this snapshot is considered **obsolete or experimental**.

  

4. Working updates must paste **full file contents**, not partial diffs.

  

5. Folder names reflect **Xcode group structure**, not necessarily on-disk folders.

  

---

  

## 1.1 AI Safety Boundaries

  

The following subsystems are **safety-critical** and must not be refactored without explicit instruction:

  

• Fatigue engine calculations  

• Shift timeline and event sequencing  

• Odometer capture logic  

• Distance reconciliation between ODO and GPS  

• Legal compliance thresholds or timers

  

Authoritative rules:

  

• Driver-entered ODO values are the **source of truth for distance**  

• GPS distance is **supporting telemetry only**  

• Fatigue calculations must never depend on GPS distance alone  

• Journal events must remain **append-only and deterministic**

  

AI agents may refactor UI, registries, or internal structure, but must **preserve behavioural equivalence** for the above systems.

  

---

  

# 2. Build / Sanity Check

  

Compiles: YES  

Runs on device: YES  

  

Tested on:

iPad8,10 / iOS 26.2.1

  

Tabs verified:

  

• Today  

• Load  

• Map  

• Sim  

• Command

  

Known accepted niggles:

• GPS and Odometer tweaking is still in progress. Currently refining the capturing of trusted data and appropriate UI for confidence levels

  

Known broken bugs:

• …

  

---

  

# 3. Architecture Direction (Current Phase)

  

The project is evolving toward a modular architecture:

  

1. **Live State Engine**

   - authoritative runtime state

   - fatigue calculations

   - vehicle/load state

  

2. **Asset Registry**

   - static profiles

   - terminals

   - suppliers

   - load accounts

   - vehicles

  

3. **Event Journal**

   - append-only shift record

   - persistence foundation

  

Strategic layer in development:

  

**Command**

- Journal

- Truck

- Numbers

  

Navigation philosophy:

  

• Command accessible anytime  

• No automatic activity switching  

• Motion-aware interaction logging  

• “Coach, not nanny” UX principle  

  

---

  

# FILE TREE (for reference only. 111 files)

  

AppModels      (18+1 files)

GPS            (6+4 files)

Logic          (7 files)

Models         (1+10+6 files)

Modules        (1+0 files)

Persistence    (7 files)

Services       (8 files)

Transport      (0+0+2 files)

Views          (6+8+8+15+3 files)

  

---

  

# SOURCE FILES

  

---

  

## MyApp.swift

  

```swift

import SwiftUI

// © 2026 Cory Russell Olsen. All rights reserved.

// This application and its contents are proprietary and confidential.

  

//======================================

// MARK: - MyApp.swift

//======================================

  

// Drivers Assistant Entry point  

//  - wires AppModel + LocationManager into the view hierarchy

  

@main

struct MyApp: App {

  

    @StateObject private var model: AppModel = {

        let m = AppModel()

        DebugLog.myapp("Model created")

        return m

    }()

    @StateObject private var locationManager: LocationManager = {

        DebugLog.myapp("Creating LocationManager at \(Date())")

        let lm = LocationManager()  // calls the fixed init we corrected earlier

        DebugLog.myapp("LocationManager created and configured")

        return lm

    }()

    var body: some Scene {

        WindowGroup {

            ContentView()

                .environmentObject(model)

                .environmentObject(locationManager)

                .onAppear {

                    DebugLog.myapp("🟣 MyApp WindowGroup onAppear  t=\(Date()) modelID=\(ObjectIdentifier(model)) locID=\(ObjectIdentifier(locationManager))")

                }

        }

    }

}

```

  

---

  

# APPMODELS

  

---

  

## AppModels/AppModel+Assets.swift

  

```swift

import SwiftUI

  

extension AppModel {

    var products: [Product] { FuelProducts.all }

}

  

extension AppModel {

    func resolveLoadNumber(_ raw: String) {

        let canon = raw.replacingOccurrences(of: " ", with: "")

        let matches = loadAccounts.filter { $0.loadNumber.replacingOccurrences(of: " ", with: "") == canon }

        guard let first = matches.first else {

            // nothing found: don’t overwrite current selections

            return

        }

        // If multiple: pick a deterministic default (nominal first)

        let chosen = matches.first(where: { $0.billingRole == .nominal }) ?? first

        resolvedLoadAccountID = chosen.id

        resolvedTerminalID = chosen.terminalID

        loadCode = raw // if you still store/display this

    }

    var selectedLoadAccount: LoadAccount? {

        guard let id = resolvedLoadAccountID else { return nil }

        return loadAccounts.first(where: { $0.id == id })

    }

} 

extension AppModel {

    // New selection truth (Phase 2 UI wiring)

    // Registries (stubbed for now)

    /// Call this when loadCode changes.

    func resolveLoadCodeAutofill() {

        let canon = LoadAccountResolver.normalize(loadCode)

        guard canon.count >= 3 else { 

            resolvedLoadAccountID = nil

            loadAccountCandidates = []

            loadAccountResolveHint = nil

            return

        }

        let typed = loadCode 

        // Empty → clear *resolution UI* but don't nuke legacy fields

        guard !canon.isEmpty else {

            resolvedLoadAccountID = nil

            loadAccountCandidates = []

            loadAccountResolveHint = nil

            return

        }

        do {

            // If you don’t, pass nil and resolver will only succeed if unique.

            let resolved = try LoadAccountResolver.resolve(

                terminalID: nil,

                typed: typed,

                accounts: loadAccounts

            )

            resolvedLoadAccountID = resolved.id

            loadAccountCandidates = []

            loadAccountResolveHint = nil

            // Migration bridge (optional)

            resolvedTerminalID = resolved.terminalID

            terminalName = terminalNameDisplay

        } catch let err as LoadAccountResolver.ResolveError {

            switch err {

            case .emptyInput:

                resolvedLoadAccountID = nil

                loadAccountCandidates = []

                loadAccountResolveHint = nil

            case .noMatch:

                // Don’t overwrite existing selection, but show hint

                resolvedLoadAccountID = nil

                loadAccountCandidates = []

                loadAccountResolveHint = "No matching load account"

            case .ambiguous(let matches):

                resolvedLoadAccountID = nil

                loadAccountCandidates = matches

                loadAccountResolveHint = "Multiple matches — choose one"

            }

        } catch {

            resolvedLoadAccountID = nil

            loadAccountCandidates = []

            loadAccountResolveHint = "Resolve failed"

        }

    }

}

```

  

---

  

## AppModels/AppModel+BackgroundGap.swift

  

```swift

import Foundation

import CoreLocation

  

extension AppModel {

    /// Clears any in-flight background gap state + coordinator anchor.

    /// Safe to call from anywhere (odo capture, guard prompt actions, etc).

    @MainActor

    func clearBackgroundGapState(reason: String = "") {

        if !reason.isEmpty {

            DebugLog.lifecycle("🧹 Clear background gap state: \(reason)")

        }

        // Coordinator anchor (prevents re-trigger)

        backgroundGapCoordinator.clear()

        // Old markers (if still present)

        backgroundGapStartAt = nil

        backgroundGapStartCoord = nil

        backgroundGapEndAt = nil

        backgroundGapEndCoord = nil

        // Pending UI/apply state

        pendingGapEstimateMeters = nil

        pendingGapEstimateSegmentID = nil

        pendingGapReason = nil

        pendingGapSegmentID = nil

        backgroundGapResumePending = false

    }

}

```

  

---

  

## AppModels/AppModel+DGPlacard.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - DG PLACARD MAPPING (MODEL → DG LOGIC)

//======================================

  

extension CompartmentModel {

    /// Draft-only DG state derived from the current picker + litres text.

    /// - Note: Degassing is tracked separately via `isDegassed`.

    /// - Important (pre-persistence): Selecting a product with 0L does NOT imply residue/placarding.

    ///   Until litres exist (or persistence is implemented), treat 0L as `.unknown`.

    var dgStateForNow: DGCompartmentState {

        guard let product = selectedProduct else { return .unknown }

        let litres = Int(litresText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let family: DGProductFamily = (product.unNumber == 1203) ? .ulp : .diesel

        if litres > 0 {

            return .loaded(family: family, litres: litres)

        } else {

            return .unknown

        }

    }

}

  

extension AppModel {

    /// DG placard decision the UI should display.

    /// - Load plan mode: show LAST CONFIRMED state only (do not change while drafting).

    /// - Unload planning mode: show CURRENT ON-TRUCK state (changes as remaining litres change).

    var displayedDGPlacardDecision: DGPlacardDecision {

        isUnloadMode ? onTruckDGPlacardDecision : confirmedOnlyDGPlacardDecision

    }

    /// Placard based ONLY on the last confirmed load (ignores current picker/litres edits).

    private var confirmedOnlyDGPlacardDecision: DGPlacardDecision {

        // After a degas, keep placard blank while drafting the next load (until Confirm).

        if suppressPlacardUntilNextConfirm {

            return .blankTopHalf

        }

        // If everything is degassed, force blank top.

        if !compartments.isEmpty, compartments.allSatisfy({ $0.isDegassed }) {

            return .blankTopHalf

        }

        guard !confirmedLoads.isEmpty else {

            return .blankTopHalf

        }

        // Build states in current compartment order.

        let states: [DGCompartmentState] = compartments.map { comp in

            if comp.isDegassed { return .degassedEmpty }

            guard let fam = lastKnownFamilyForCompartment(compName: comp.name) else {

                return .unknown

            }

            // In “confirmed-only”, if we knew it was last in there, treat as residue/vapour.

            return .residueOrVapour(family: fam)

        }

        return DGPlacardLogic.decide(.init(compartments: states))

    }

    private var onTruckDGPlacardDecision: DGPlacardDecision {

        // UNLOAD MODE ONLY:

        // Placard represents what is currently on the truck, using remaining litres plus

        // confirmed history for product family (never the picker).

        let states = dgCompartmentsOnTruck

        return DGPlacardLogic.decide(.init(compartments: states))

    }

    private var dgCompartmentsOnTruck: [DGCompartmentState] {

        // 0) If EVERY compartment is degassed => true blank top.

        if !compartments.isEmpty, compartments.allSatisfy({ $0.isDegassed }) {

            return Array(repeating: .degassedEmpty, count: compartments.count)

        }

        // 1) No confirmed history yet => unknown everywhere (start-of-shift reality pre-persistence)

        guard !confirmedLoads.isEmpty else {

            return compartments.map { comp in

                comp.isDegassed ? .degassedEmpty : .unknown

            }

        }

        // 2) We have confirmed history this session: use LAST KNOWN FAMILY as the truth source.

        return compartments.map { comp in

            let litres = Int(comp.litresText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            // Degassed overrides everything

            if comp.isDegassed {

                return .degassedEmpty

            }

            let lastFam = lastKnownFamilyForCompartment(compName: comp.name)

            if litres > 0 {

                // When unloading, litres>0 means “product remains”.

                // Family must come from confirmed history (not the dropdown).

                if let fam = lastFam {

                    return .loaded(family: fam, litres: litres)

                }

                return .unknown

            }

            // litres == 0: if we have last known family => residue/vapour applies

            if let fam = lastFam {

                return .residueOrVapour(family: fam)

            }

            return .unknown

        }

    }

    private func lastKnownFamilyForCompartment(compName: String) -> DGProductFamily? {

        // Walk backwards through confirmed loads (session) to find the last known DG family

        // for this compartment. This is the single source of truth for unload placarding.

        for load in confirmedLoads.reversed() {

            if let fam = load.lastFamilyForCompartmentNamed(compName) {

                return fam

            }

        }

        return nil

    }

}

```

  

---

  

## AppModels/AppModel+GPS.swift

  

```swift

  

import Foundation

import CoreLocation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - AppModel + GPS / Motion

//======================================

  

// Purpose:

// - Isolate GPS-derived evidence and motion inference from core app state.

// - Keeps AppModel.swift focused on shift state, load planning, and UI-driven state.

  

// Owns:

// - Distance accumulation (GPS delta metres) and ODO reconciliation helpers.

// - Latest speed/course samples (evidence only).

// - MotionState inference (stopped/crawling/cruising/etc) using dwell + trend.

// - Movement nudge: "Are you driving?" feeds into the Guard pipeline.

// - Motion certainty scoring and watchdog auto-recovery.

  

// Notes:

// - GPS is NOT authoritative. It is evidence used for coaching and approximation.

// - Time + dwell confirm states (prevents flapping / jitter).

// - MotionState is diagnostic/informational pre-persistence.

// - @Published stored properties must live on the main AppModel type, not in extensions.

//======================================

  

  

// MARK: - Nested Types

  

extension AppModel {

    enum MotionState: String, Codable, CaseIterable {

        case stopped        // truly stationary (~0 km/h)

        case crawling       // slow maneuvering, 3–15 km/h, sketchy heading

        case accelerating   // >20 km/h, gaining speed

        case decelerating   // >20 km/h, losing speed

        case cruising       // >20 km/h, steady speed

        case unsure         // invalid/stale GPS or data quality issues

        var shortLabel: String {

            switch self {

            case .stopped:      return "STOP"

            case .crawling:     return "CRAWL"

            case .accelerating: return "ACCEL"

            case .decelerating: return "DECEL"

            case .cruising:     return "MOTION"

            case .unsure:       return "UNSURE"

            }

        }

    }

    struct MotionTunables: Codable {

        // Speed thresholds (m/s)

        var stoppedBelowMps: Double  = 0.9     // ~3 km/h

        var crawlAboveMps: Double    = 0.9     // ~3 km/h

        var crawlBelowMps: Double    = 4.1     // ~15 km/h

        var movingAboveMps: Double   = 4.8     // ~20 km/h

        // Dwell: seconds at low speed required to confirm stopped.

        var stoppedDwell: TimeInterval = 2.5

        // Acceleration thresholds (m/s²), applied only for speeds >20 km/h.

        var accelMps2: Double = 0.25

        var decelMps2: Double = 0.4

        // Data quality (strike-based unsure)

        var qualityStrikesToUnsure: Int = 3          // Option A: 3 consecutive bad samples

        var qualityStrikeDecaySeconds: TimeInterval = 3.0 // Optional: forgive strikes after some clean time

        // Data quality gates.

        var maxSpeedJumpMps: Double     = 13.9   // ~50 km/h impossible jump in <2s

        var maxStateFlapsIn5s: Int      = 3

        var gpsLostSeconds: TimeInterval = 10.0

        var gpsStaleSeconds: TimeInterval = 2.5

        // Heading variance threshold (degrees) above which heading is "sketchy".

        var courseVarianceThreshold: Double = 30.0

    }

    // Small rolling window of speed samples for trend calculation.

    struct SpeedSample {

        let t: Date

        let s: Double  // m/s

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

            self.id        = id

            self.at        = at

            self.segmentID = segmentID

            self.kind      = kind

            self.deltaKm   = deltaKm

            self.note      = note

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

        let sid      = segment.id

        let finalised = finalisedKmBySegment[sid] ?? 0

        let pending  = (gpsKmSinceLastOdoBySegment[sid] ?? 0) * effectiveKmCorrectionFactor

        return finalised + pending

    }

    // Segment km (AppModel ingest + correction factor + odo reconciliation). Journal/analysis number.

    var shiftKmBySegmentsApprox: Double {

        let finalised = finalisedKmBySegment.values.reduce(0, +)

        let pending   = gpsKmSinceLastOdoBySegment.values.reduce(0, +) * effectiveKmCorrectionFactor

        return finalised + pending

    }

    // Live GPS (LocationManager mirror). Driver-facing “trust” number.

    var shiftKmLiveGps: Double { gpsShiftMetersLive / 1000.0 }

    var currentSegmentKmApprox: Double {

        guard let sid = runningSegmentID else { return 0 }

        let finalised = finalisedKmBySegment[sid] ?? 0

        let pending   = (gpsKmSinceLastOdoBySegment[sid] ?? 0) * effectiveKmCorrectionFactor

        return finalised + pending

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

            if let t = lastGpsUpdateAt      { return max(0.01, now.timeIntervalSince(t)) }

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

        DebugLog.gps("📏 GPS INGEST #\(gpsIngestSeq)  meters=\(String(format: "%.3f", meters))  sid=\(runningSegmentID?.uuidString.prefix(6) ?? "nil")  t=\(now)")

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

        let prevSampleAt  = lastSpeedSampleAt

        let prevSpeedMps  = lastKnownSpeedMps

            let kmh = (speedMps ?? -1) * 3.6

            let c   = course ?? -1

            DebugLog.motion("🧭 Motion ingest: speed=\(String(format: "%.1f", kmh)) km/h  course=\(String(format: "%.0f", c))°  t=\(time)")

        guard let s = speedMps, s >= 0 else {

            // Don’t insta-UNSURE on a single nil/-1 tick.

            // Treat as “no evidence” and let tickMotionState decide stale/lost.

            return

        }

        lastSpeedSampleAt = time

        if let issue = checkDataQuality(speed: s, time: time, prevSpeed: prevSpeedMps, prevTime: prevSampleAt) {

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

        let newState = determineMotionFromSpeed(speed: s, course: course, time: time)

        if motionState != newState {

            motionState = newState

            recordStateChange(at: time)

        }

    }

}

  

  

// MARK: - Movement → "Are you driving?" Nudge

  

extension AppModel {

    func considerMovementPrompt(speedMps: Double?) {

        guard isOnDuty else { return }

        guard activeGuardPrompt == nil else { return }

        guard !isDriving else { movementStartAt = nil; return }

        guard !isOnBreak  else { movementStartAt = nil; return }

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

            lastNudgeAt     = now

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

                return .unsure

            } else {

                DebugLog.motion("⚠️ Motion quality: strike \(motionQualityStrikes)/\(motionTunables.qualityStrikesToUnsure) (holding state)")

                return nil

            }

        } else {

            // Good sample: clear strikes

            motionQualityStrikes = 0

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

            if delta > 180 { delta = 360 - delta }  // handle 350°→10° wrap

            deltas.append(delta)

        }

        return deltas.reduce(0, +) / Double(deltas.count)

    }

    private func determineMotionTrend() -> MotionState {

        // Decel/accel: react faster

        let trendFast = calculateCurrentTrend(window: 3)

        if trendFast <= -motionTunables.decelMps2 { return .decelerating }

        if trendFast >=  motionTunables.accelMps2 { return .accelerating }

        // Cruise: require more evidence

        let trendStable = calculateCurrentTrend(window: 5)

        if trendStable >=  motionTunables.accelMps2  { return .accelerating }

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

                    speedSamples.removeAll(keepingCapacity: true)

                    courseSamples.removeAll(keepingCapacity: true)

                }

            }

        }

    }

    func resetMotionInference(reason: String = "Manual") {

        DebugLog.motion("🧽 Motion reset: \(reason) t=\(Date())")

        motionState             = .unsure

        stoppedAccumulatorStart = nil

        speedSamples.removeAll(keepingCapacity: true)

        courseSamples.removeAll(keepingCapacity: true)

        stateChangeHistory.removeAll(keepingCapacity: true)

    }

}

  

  

// MARK: - Motion Certainty Scoring

  

extension AppModel {

    var motionPillCertaintyScore: Int {

        let now    = Date()

        let gps    = gpsCertaintyScore(now: now)

        let motion = motionCertaintyScore(now: now)

        return min(gps, motion)

    }

    var motionPillBucket: CertaintyBucket {

        switch motionPillCertaintyScore {

        case 80...100: return .high

        case 55...79:  return .medium

        case 30...54:  return .low

        default:       return .untrustworthy

        }

    }

    func overallCertaintyBandForUI(now: Date = Date()) -> CertaintyBucket {

        if motionState == .unsure { return .untrustworthy }

        switch overallCertaintyScore(now: now) {

        case 80...100: return .high

        case 55...79:  return .medium

        case 30...54:  return .low

        default:       return .untrustworthy

        }

    }

    func overallCertaintyScoreForUI(now: Date = Date()) -> Int {

        overallCertaintyScore(now: now)

    }

    private func gpsCertaintyScore(now: Date = Date()) -> Int {

        var score = 100

        if let acc = lastGpsAccuracyMeters {

            if      acc > 100 { score -= 40 }

            else if acc > 50  { score -= 20 }

            else if acc > 20  { score -= 10 }

        } else {

            score -= 25

        }

        if let t = lastGpsUpdateAt {

            let age = now.timeIntervalSince(t)

            if      age > 20 { score -= 60 }

            else if age > 10 { score -= 35 }

            else if age > 5  { score -= 15 }

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

            if      age > 10  { score -= 70 }

            else if age > 5   { score -= 35 }

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

        let gps    = gpsCertaintyScore(now: now)

        let motion = motionCertaintyScore(now: now)

        let lower  = min(gps, motion)

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

        lastAutoRecoverReason  = reason

        lastAutoRecoverFiredAt = Date()

    }

    @MainActor

    func motionWatchdogTick() {

        let now    = Date()

        let gps    = gpsCertaintyScore(now: now)

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

        let validSpeed       = lastLmValidSpeedMps ?? lastKnownSpeedMps

        let movingEvidence   =

        (validSpeed ?? 0) > gpsT.minMotionSpeedMps ||

        lastLmDeltaMeters > gpsT.watchdogMovingEvidenceDeltaMeters ||

        speedSamples.isEmpty

        guard gpsFresh && gpsAccOK else { return }

        guard movingEvidence       else { return }

        if let last = lastAutoRecoverAt,

           now.timeIntervalSince(last) < gpsT.autoRecoverCooldownSeconds { return }

        lastAutoRecoverAt = now

        lowMotionSince    = nil

        autoRecoverMotionIfNeeded(reason: "motion≤\(gpsT.watchdogMinCertaintyScore) for \(Int(gpsT.autoRecoverLowMotionHoldSeconds))s while GPS good (gps=\(gps))")

    }

}

```

  

---

  

## AppModels/AppModel+Guard.swift

  

```swift

  

import SwiftUI

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - AppModel + Guard

//======================================

  

// Purpose:

// - Intercept driver actions that don't match current state.

// - Coach (not block) when ambiguity is detected.

  

// Owns:

// - DriverIntent and DriverIntentSource enums.

// - GuardPrompt and GuardAction types.

// - The single request(_:source:) entry point for all intent-driven state changes.

  

// Design principles:

// - userTap:      driver explicitly pressed a button — trust them, execute immediately.

// - movementNudge: automatic detection — show coaching prompt if state mismatch.

// - contextAuto:  inferred from UI context — silent state correction, no prompt.

  

// Notes:

// - Prompts are advisory only; no enforcement or blocking.

// - Pre-persistence scope: helps prevent accidental timeline errors.

// - Post-persistence: may emit advisory events ("state mismatch detected"),

//   but will never auto-correct authoritative history.

//======================================

  

// MARK: - Intent Types

  

enum DriverIntent {

    case drive

    case breakTime

    case load

    case unload

    case incident

    case other(name: String, isWork: Bool)

}

  

// Where a request originated determines whether coaching prompts are shown.

enum DriverIntentSource {

    case userTap        // driver explicitly pressed a button — do not nag

    case movementNudge  // automatic movement detection — coach if state mismatch

    case contextAuto    // inferred from UI context — switch silently, no prompt

}

  

  

// MARK: - Guard Prompt Types

  

extension AppModel {

    struct GuardPrompt: Identifiable {

        let id = UUID()

        let title: String

        let message: String

        let actions: [GuardAction]

    }

    struct GuardAction {

        let title: String

        let role: ButtonRole?

        let handler: () -> Void

    }

}

  

  

// MARK: - Guard Engine

  

extension AppModel {

    /// Single entry point for all driver intent, whether from button taps or motion inference.

    /// Coaching prompts are only shown when source == .movementNudge.

    func request(_ intent: DriverIntent, source: DriverIntentSource = .userTap) {

        guard isOnDuty else { return }

        guard activeGuardPrompt == nil else { return }

        let shouldCoach = (source == .movementNudge)

        switch intent {

        case .drive:

            if shouldCoach, (isOnBreak || currentActivity == .workLoad || currentActivity == .workUnload) {

                presentGuard(

                    title: "You're not marked as driving",

                    message: "Movement suggests you're driving, but you're currently in \(humanActivityLabel()). Switch to Driving?",

                    primaryTitle: "Switch to Driving",

                    primary:      { [weak self] in self?.pressDrive() },

                    secondaryTitle: "Not driving",

                    secondary:    { [weak self] in self?.activeGuardPrompt = nil }

                )

                return

            }

            pressDrive()

        case .breakTime:

            pressBreak()

        case .load:

            if shouldCoach, isDriving {

                presentGuard(

                    title: "You appear to be driving",

                    message: "You tapped Load while marked Driving. Are you actually stopped and loading now?",

                    primaryTitle: "Switch to LOAD",

                    primary:      { [weak self] in self?.pressLoad() },

                    secondaryTitle: "Keep Driving",

                    secondary:    { [weak self] in self?.activeGuardPrompt = nil }

                )

                return

            }

            pressLoad()

        case .unload:

            if shouldCoach, isDriving {

                presentGuard(

                    title: "You appear to be driving",

                    message: "You tapped Unload while marked Driving. Are you actually stopped and unloading now?",

                    primaryTitle: "Switch to UNLOAD",

                    primary:      { [weak self] in self?.pressUnload() },

                    secondaryTitle: "Keep Driving",

                    secondary:    { [weak self] in self?.activeGuardPrompt = nil }

                )

                return

            }

            pressUnload()

        case .incident:

            // Incidents are event-only; allowed from any state.

            beginIncidentDraft()

            isShowingIncidentSheet = true

        case .other(let name, let isWork):

            let a = OtherActivity(id: UUID(), name: name, isWork: isWork)

            if shouldCoach, isDriving, isWork {

                presentGuard(

                    title: "You appear to be driving",

                    message: "Movement suggests you're driving. Switch out of Driving into '\(name)'?",

                    primaryTitle: "Switch to \(name)",

                    primary:      { [weak self] in self?.startOtherActivity(a) },

                    secondaryTitle: "Keep Driving",

                    secondary:    { [weak self] in self?.activeGuardPrompt = nil }

                )

                return

            }

            startOtherActivity(a)

        }

    }

}

  

  

// MARK: - Guard Helpers (private)

  

extension AppModel {

    private func presentGuard(

        title: String,

        message: String,

        primaryTitle: String,

        primary: @escaping () -> Void,

        secondaryTitle: String,

        secondary: @escaping () -> Void

    ) {

        activeGuardPrompt = GuardPrompt(

            title: title,

            message: message,

            actions: [

                GuardAction(title: primaryTitle, role: nil) { [weak self] in

                    self?.activeGuardPrompt = nil

                    primary()

                },

                GuardAction(title: secondaryTitle, role: .cancel) { [weak self] in

                    self?.activeGuardPrompt = nil

                    secondary()

                }

            ]

        )

    }

    private func humanActivityLabel() -> String {

        switch currentActivity {

        case .driving:       return "Driving"

        case .workLoad:      return "Load"

        case .workUnload:    return "Unload"

        case .workGeneral:   return "On duty"

        case .restBreak:     return "Break"

        case .restBreakdown: return "Breakdown"

        case .offDuty:       return "Off duty"

        }

    }

}

```

  

---

  

## AppModels/AppModel+Guardhelpers.swift

  

```swift

import SwiftUI

import Foundation

  

//======================================

// File: AppModel+GuardHelpers.swift

//======================================

//

// Purpose:

// - Guard prompt helpers for segment correction

// - Prevents events from being logged in wrong segments

// - Provides explicit (not silent) segment switching

//

// Three-tier system:

// 1. Entry guard (soft): prompt when entering LoadView in wrong segment

// 2. Edit guard (medium): prompt when focusing editable fields

// 3. Confirm guard (hard): block confirm if segment is wrong

//

// Design principle:

// - No silent segment changes

// - Driver always sees why/when segment changes

// - Explicit user choice required

//

//======================================

  

  

  

extension AppModel {

    //======================================

    // MARK: - Generic Guard Helpers

    //======================================

    func presentGuardPrompt(title: String, message: String, actions: [AppModel.GuardAction]) {

        DispatchQueue.main.async { [weak self] in

            self?.activeGuardPrompt = AppModel.GuardPrompt(title: title, message: message, actions: actions)

        }

    }

    func clearGuardPrompt() {

        DispatchQueue.main.async { [weak self] in

            self?.activeGuardPrompt = nil

        }

    }

    func promptToSwitchSegment(

        title: String,

        message: String,

        switchTitle: String,

        keepTitle: String = "Keep as-is",

        onSwitch: @escaping () -> Void,

        onKeep: @escaping () -> Void = {}

    ) {

        presentGuardPrompt(

            title: title,

            message: message,

            actions: [

                AppModel.GuardAction(title: switchTitle, role: nil) { [weak self] in

                    self?.activeGuardPrompt = nil   // ✅ dismiss prompt first

                    onSwitch()

                },

                AppModel.GuardAction(title: keepTitle, role: .cancel) { [weak self] in

                    self?.activeGuardPrompt = nil   // ✅ dismiss prompt first

                    onKeep()

                }

            ]

        )

    }

    //======================================

    // MARK: - Tier 1: Entry Guards (Soft)

    //======================================

    /// Soft prompt when entering LoadView in wrong segment (Load mode)

    func promptToSwitchToLoad() {

        let currentLabel = currentActivity.displayName

        promptToSwitchSegment(

            title: "Switch to Loading?",

            message: "You're currently marked as \(currentLabel). Switch to Loading mode to edit the load plan?",

            switchTitle: "Switch to Loading",

            keepTitle: "Stay in \(currentLabel)",

            onSwitch: {

                self.request(.load, source: .userTap)

            }

        )

    }

    /// Soft prompt when entering LoadView in wrong segment (Unload mode)

    func promptToSwitchToUnload() {

        let currentLabel = currentActivity.displayName

        promptToSwitchSegment(

            title: "Switch to Unloading?",

            message: "You're currently marked as \(currentLabel). Switch to Unloading mode to edit the unload plan?",

            switchTitle: "Switch to Unloading",

            keepTitle: "Stay in \(currentLabel)",

            onSwitch: {

                self.request(.unload, source: .userTap)

            }

        )

    }

    //======================================

    // MARK: - Tier 2: Edit Guards (Medium)

    //======================================

    /// Medium guard when focusing on editable fields

    func promptToSwitchSegmentForEditing(to expectedSegment: ActivityType) {

        let currentLabel = currentActivity.displayName

        let expectedLabel = expectedSegment.displayName

        promptToSwitchSegment(

            title: "Switch to \(expectedLabel) to edit?",

            message: "You're currently marked as: \(currentLabel)\nEditing the load plan requires \(expectedLabel) mode.",

            switchTitle: "Switch to \(expectedLabel)",

            keepTitle: "Cancel",

            onSwitch: {

                if expectedSegment == .workLoad {

                    self.request(.load, source: .userTap)

                } else if expectedSegment == .workUnload {

                    self.request(.unload, source: .userTap)

                }

            },

            onKeep: {

                // Field blur handled by caller via @FocusState

            }

        )

    }

    //======================================

    // MARK: - Tier 3: Confirm Guards (Hard)

    //======================================

    /// Hard blocker when confirming in wrong segment

    func presentSegmentMismatchBlocker(expected: ActivityType) {

        let currentLabel = currentActivity.displayName

        let expectedLabel = expected.displayName

        promptToSwitchSegment(

            title: "Cannot confirm — Wrong segment",

            message: "You're currently marked as: \(currentLabel)\n\nYou cannot confirm a \(expectedLabel.lowercased()) operation while \(currentLabel.lowercased()).\n\nSwitch to \(expectedLabel) first, then confirm.",

            switchTitle: "Switch to \(expectedLabel)",

            keepTitle: "Cancel",

            onSwitch: {

                if expected == .workLoad {

                    self.request(.load, source: .userTap)

                } else if expected == .workUnload {

                    self.request(.unload, source: .userTap)

                }

                // Note: User must press Confirm again after switching

            }

        )

    }

}

```

  

---

  

## AppModels/AppModel+Incident.swift

  

```swift

import Foundation

//======================================

// MARK: - AppModel+Incident

//======================================

//

// INCIDENT FLOW CONTRACT

// - AppModel owns incident lifecycle and presentation state

// - Views may mutate incidentDraft *only while sheet is visible*

// - Views must never clear incidentDraft directly

// - Clearing happens after dismissal on next runloop tick

  

extension AppModel {

    func beginIncidentDraft() {

        // Pull best-known context without being creepy.

        let suburb = locationManagerSuburbGuessOrNil()

        let (lat, lon) = locationManagerLatLonOrNil()

        incidentDraft = IncidentReport(

            suburb: suburb,

            latitude: lat,

            longitude: lon,

            type: .accident,

            severity: .minor

        )

        recomputeIncidentAdvice()

    }

    func recomputeIncidentAdvice() {

        guard let draft = incidentDraft else {

            lastIncidentAdvicePlan = nil

            return

        }

        lastIncidentAdvicePlan = IncidentAdviceEngine.buildPlan(report: draft, settings: settings)

    }

    func commitIncidentDraft() {

        guard let draft = incidentDraft else { return }

        // Phase 1: minimal timeline logging.

        // Later: persistence + attachments + export bundles.

        logEvent(.other, note: "Incident – \(draft.type.rawValue.capitalized) / \(draft.severity.rawValue.capitalized)", at: draft.timestamp)

    }

    // MARK: - Context helpers (Phase 1 placeholders)

    private func locationManagerSuburbGuessOrNil() -> String? {

        // You already have suburb suggestion plumbing elsewhere.

        // If you have a “currentSuburb” string in your model, use that instead.

        // For now, use the last recorded suburb if available.

        return odoLocationRecords.last?.suburb.trimmingCharacters(in: .whitespacesAndNewlines)

    }

    private func locationManagerLatLonOrNil() -> (Double?, Double?) {

        // If you have lat/lon available from LocationManager, wire it here later.

        return (nil, nil)

    }

}

```

  

---

  

## AppModels/AppModel+Journal.swift

  

```swift

import SwiftUI

  

// future planning

```

  

---

  

## AppModels/AppModel+Lifecycle.swift

  

```swift

import Foundation

import CoreLocation

  

extension AppModel {

    // MARK: - Lifecycle hooks

    @MainActor

    func onAppBackgrounded(locationManager lm: LocationManager) {

        guard isOnDuty else { return }

        let now = Date()

        // Prefer a "good" fix (accuracy-gated) rather than just "lastLocation"

        guard let loc = lm.lastGoodLocation ?? lm.lastLocation else { return }

        // Avoid anchoring on stale samples

        guard now.timeIntervalSince(loc.timestamp) < 60 else { return }

        backgroundGapCoordinator.markBackgroundStart(at: now, coord: loc.coordinate)

        backgroundGapResumePending = true

        DebugLog.lifecycle("🌙 BG anchor set at=\(now) acc=\(Int(loc.horizontalAccuracy))m")

    }

    @MainActor

    func onAppBecameActive(locationManager lm: LocationManager) {

        guard isOnDuty else {

            backgroundGapResumePending = false

            return

        }

        // We’ll complete once we have a fresh good fix (see connect() sink).

        backgroundGapResumePending = true

        DebugLog.lifecycle("🌞 Foregrounded — waiting for fresh GPS to estimate BG gap")

    }

    // Optional helper if you want a manual “clear” button in debug.

    @MainActor

    func clearBackgroundGapAdvisory(reason: String = "") {

        if !reason.isEmpty {

            DebugLog.lifecycle("🧹 Clear BG advisory: \(reason)")

        }

        backgroundGapCoordinator.clear()

        backgroundGapResumePending = false

        lastBackgroundGapEstimate = nil

        // keep history unless you explicitly want to wipe it too

    }

}

```

  

---

  

## AppModels/AppModel+LoadAccount.swift

  

```swift

// File: AppModel+LoadAccount.swift

import Foundation

  

extension AppModel {

    func resolveLoadAccount() {

        loadAccountResolveError = nil

        loadAccountAmbiguousMatches = []

        resolvedLoadAccountID = nil

        do {

            let acct = try LoadAccountResolver.resolve(

                terminalID: resolvedTerminalID,

                typed: typedLoadNumber,

                accounts: LoadAccountRegistry.all

            )

            resolvedLoadAccountID = acct.id

        } catch let err as LoadAccountResolver.ResolveError {

            switch err {

            case .ambiguous(let matches):

                loadAccountAmbiguousMatches = matches

                loadAccountResolveError = err.description

            default:

                loadAccountResolveError = err.description

            }

        } catch {

            loadAccountResolveError = error.localizedDescription

        }

    }

}

```

  

---

  

## AppModels/AppModel+LoadAccountUI.swift

  

```swift

import Foundation

  

extension AppModel {

    // Registries (Phase 1: in-memory)

    var terminals: [Terminal] { TerminalRegistry.all }

    var loadAccounts: [LoadAccount] { LoadAccountRegistry.all }

    var suppliers: [Supplier] { SupplierRegistry.all }

    // Your selected/resolved account (rename these two vars if your model uses different names)

    var resolvedLoadAccount: LoadAccount? {

        guard let id = resolvedLoadAccountID else { return nil }

        return loadAccounts.first(where: { $0.id == id })

    }

    var terminalNameDisplay: String {

        guard let tid = resolvedLoadAccount?.terminalID,

              let t = terminals.first(where: { $0.id == tid }) else { return "—" }

        return t.name

    }

    var supplierNameDisplay: String {

        guard let sid = resolvedLoadAccount?.supplierID,

              let s = suppliers.first(where: { $0.id == sid }) else { return "—" }

        return s.name

    }

    var billingRoleDisplay: String {

        resolvedLoadAccount?.billingRole.rawValue.capitalized ?? "—"

    }

}

```

  

---

  

  

## AppModels/AppModel+LoadPlan.swift

  

```swift

import SwiftUI

//======================================

// MARK: - AppModel+LoadPlan

//======================================

// functioning for how trucmis loaded

  

  

extension AppModel {

    //======================================

    // MARK: - SG helpers

    //======================================

    func sg(for product: Product) -> Double {

        if let override = sgOverrides[product.id] {

            return override

        }

        return product.defaultSg

    }

    func setSg(_ value: Double, for product: Product) {

        let clamped = min(max(value, product.sgMin), product.sgMax)

        var copy = sgOverrides

        copy[product.id] = clamped

        sgOverrides = copy          // <- reassign triggers @Published properly

    }

    func massKg(for comp: CompartmentModel) -> Double? {

        guard let product = comp.selectedProduct,

              let litres = Double(comp.litresText),

              litres > 0 else {

            return nil

        }

        let sgValue = sg(for: product)

        return litres * sgValue

    }

    var totalMassKg: Double {

        compartments.compactMap { massKg(for: $0) }.reduce(0, +)

    }

    //======================================

    // MARK: - Confirm gating (Phase 1)

    //======================================

    //

    // Goal:

    // - Prevent accidental double-confirm of an identical draft.

    // - "Confirm this load" is enabled only if the current draft differs

    //   from the most recent confirmed load of the same mode (Load vs Unload).

    var canConfirmCurrentLoad: Bool {

        // If there is literally nothing to confirm, block it.

        let hasAnyLitres = compartments.contains { (Double($0.litresText) ?? 0) > 0 }

        let hasAnyProduct = compartments.contains { $0.selectedProduct != nil }

        // LOAD mode: must have litres

        // UNLOAD mode: allow “confirm to zero” as long as products are defined

        if isUnloadMode {

            guard hasAnyProduct else { return false }

        } else {

            guard hasAnyLitres else { return false }

        }

        // Compare only against last confirm of the SAME mode (load vs unload planning).

        let sameModeLoads = confirmedLoads.reversed().first { $0.mode == currentConfirmMode }

        guard let lastSameMode = sameModeLoads else { return true }

        return draftSignature() != confirmedSignature(for: lastSameMode)

    }

    private var currentConfirmMode: ConfirmedLoadMode {

        isUnloadMode ? .unloadSnapshot : .loadConfirmed

    }

    private func draftSignature() -> String {

        // Stable signature: mode + per-compartment (name|product|litres)

        // Normalise litres to whole litres (int) to avoid float noise.

        let lines = compartments.map { comp -> String in

            let litresInt = Int((Double(comp.litresText) ?? 0).rounded())

            let prod = comp.selectedProduct?.shortName ?? ""

            return "\(comp.name)|\(prod)|\(litresInt)"

        }

        return "\(currentConfirmMode.rawValue)#" + lines.joined(separator: ";")

    }

    private func confirmedSignature(for load: ConfirmedLoad) -> String {

        let lines = load.compartments.map { line -> String in

            let litresInt = Int(line.litres.rounded())

            return "\(line.name)|\(line.productShort)|\(litresInt)"

        }

        return "\(load.mode.rawValue)#" + lines.joined(separator: ";")

    }

    //======================================

    // MARK: - Confirm current load

    //======================================

    /// Commits the current Load/Unload state into `confirmedLoads` (session history).

    /// - Load mode: records only compartments with product + litres (>0).

    /// - Unload mode: records a snapshot of remaining on-truck state (includes 0L lines if product is still selected).

    /// This is the ONLY place where totals, axle loads, and DG "last known family" history become authoritative.

    func confirmCurrentLoad() {

        // Capture ONE timestamp used for:

        // - segment switch (so timeline stays physically possible)

        // - confirmed load record

        // - event log

        let confirmTime = Date()

        if isUnloadMode {

            // Unload mode:

            // Allow confirming snapshots even when litres are 0,

            // as long as there is still product context selected (placarding/history),

            // OR the driver explicitly declared empty via Full Unload / Degas.

            let hasAnyProduct = compartments.contains { $0.selectedProduct != nil }

            guard totalLitres > 0 || hasAnyProduct || unloadFinalised else { return }

        } else {

            // Load mode:

            // Require at least one compartment with positive litres AND a product.

            let hasAnyProduct = compartments.contains { comp in

                (Double(comp.litresText) ?? 0) > 0 && comp.selectedProduct != nil

            }

            guard hasAnyProduct else { return }

        }

        // --- Segment reconciliation ---

        // Confirming LOAD/UNLOAD means the driver is doing WORK.

        // If they forgot to change segment (e.g., still on Break or Driving),

        // we fix the state at the moment of confirm.

        if isOnDuty {

            // Make UI flags match reality (always do this)

            isDriving = false

            isOnBreak = false

            let newType: ActivityType = isUnloadMode ? .workUnload : .workLoad

            // Only switch segment if not already in the right mode

            if currentActivity != newType {

                startActivity(newType, at: confirmTime)

            } else {

                // Optional: update timestamp on existing open segment if needed

                // currentSegmentStart = confirmTime  // rare case

            }

        }

        // If we are confirming a LOAD, any compartment with product+litres is definitely not degassed.

        for i in compartments.indices {

            let litres = Double(compartments[i].litresText) ?? 0

            if litres > 0, compartments[i].selectedProduct != nil {

                compartments[i].isDegassed = false

            }

        }

        // Build compartment snapshots

        var compSnapshots: [ConfirmedCompartment] = []

        for comp in compartments {

            let litres = Double(comp.litresText) ?? 0

            if isUnloadMode {

                // In unload mode, include compartments that still have a product selected

                // (placarding context), even if litres are 0.

                guard let product = comp.selectedProduct else { continue }

                let sgValue = sg(for: product)

                let mass = litres * sgValue

                let snap = ConfirmedCompartment(

                    name: comp.name,

                    sfl: comp.capacityLitres,

                    productShort: product.shortName,

                    sg: sgValue,

                    litres: litres,

                    massKg: mass

                )

                compSnapshots.append(snap)

            } else {

                // Load mode: only include compartments with positive litres + product.

                guard litres > 0, let product = comp.selectedProduct else { continue }

                let sgValue = sg(for: product)

                let mass = litres * sgValue

                let snap = ConfirmedCompartment(

                    name: comp.name,

                    sfl: comp.capacityLitres,

                    productShort: product.shortName,

                    sg: sgValue,

                    litres: litres,

                    massKg: mass

                )

                compSnapshots.append(snap)

            }

        }

        let load = ConfirmedLoad(

            timestamp: confirmTime,

            mode: isUnloadMode ? .unloadSnapshot : .loadConfirmed,

            terminalName: terminalNameDisplay,

            loadCode: loadCode,

            vehicleId: vehicleId,

            driverName: settings.driverName,

            compartments: compSnapshots,

            totalLitres: totalLitres,

            totalMassKg: totalMassKg,

            steerKg: steerLoadedKg,

            driveKg: driveLoadedKg,

            gvmKg: gvmLoadedKg

        )

        confirmedLoads.append(load)

        // ✅ Log the event ONCE per load (not per compartment)

        logEvent(isUnloadMode ? .unload : .load, at: confirmTime)

        // Reset empty-finalisation after we successfully confirm.

        // (If driver is unloading and then starts loading again, this prevents accidental "empty confirms".)

        unloadFinalised = false

        suppressPlacardUntilNextConfirm = false

        autosave?.requestAutosave(reason: "Confirmed load/unload", immediate: true)

    }

  

    // MARK: - Typical load templates (pre-persistence)

    // NOTE: Used by the "Apply typical load" UI.

    // Do not delete until `typicalLoadTemplates` and `applyTypicalLoad(_:)`

    // are migrated to the unified `LoadTemplate` system.

    struct TypicalLoadTemplate: Identifiable {

        let id = UUID()

        let name: String

        /// Keyed by compartment name, e.g. "C1" → ("DSL", 5000)

        let perCompartment: [String: (productShortName: String, litres: Int)]

    }

    //======================================

    // MARK: - Axle load helpers

    //======================================

    private var runningTankMissingKg: Double {

        let f = min(max(fuelFraction, 0), 1)

        return truckConfig.runTankFullKg * (1.0 - f)

    }

    private var tareSteerAdjustedKg: Double {

        max(truckConfig.tareSteerKg - runningTankMissingKg * 0.15, 0)

    }

    private var tareDriveAdjustedKg: Double {

        max(truckConfig.tareDriveKg - runningTankMissingKg * 0.85, 0)

    }

    var steerLoadedKg: Double {

        var total = tareSteerAdjustedKg

        for comp in compartments {

            guard let mass = massKg(for: comp),

                  let split = truckConfig.axleSplitByCompartment[comp.name] else { continue }

            total += mass * split.steerFraction

        }

        // Lazy axle up => shift some load off steer (heuristic)

        if truckConfig.hasLazyAxle, lazyAxleIsUp {

            total = max(total - truckConfig.lazyLiftTransferKg, 0)

        }

        return total

    }

    var driveLoadedKg: Double {

        var total = tareDriveAdjustedKg

        for comp in compartments {

            guard let mass = massKg(for: comp),

                  let split = truckConfig.axleSplitByCompartment[comp.name] else { continue }

            total += mass * split.driveFraction

        }

        // Lazy axle up => shift that load onto drives (heuristic)

        if truckConfig.hasLazyAxle, lazyAxleIsUp {

            total += truckConfig.lazyLiftTransferKg

        }

        return total

    }

    var gvmLoadedKg: Double {

        steerLoadedKg + driveLoadedKg

    }

    //======================================

    // MARK: - Load plan helpers

    //======================================

    var totalLitres: Int {

        compartments.compactMap { Int($0.litresText) }.reduce(0, +)

    }

    var loadPlanProducts: [Product] {

        var result: [Product] = []

        for comp in compartments {

            if let product = comp.selectedProduct,

               let litres = Int(comp.litresText),

               litres > 0 {

                result.append(product)

            }

        }

        return result

    }

    // PHASE 1 STUB (kept intentionally).

    // Not used by DG placarding (placarding is compartment-state driven).

    // Retained as a reference point for future multi-product Hazchem logic post-persistence.

    var combinedHazchemForLoad: String {

        let products = loadPlanProducts

        guard !products.isEmpty else { return "—" }

        let hasE = products.contains { $0.hazchem.uppercased().contains("E") }

        let eChar = hasE ? "E" : ""

        return "3Y" + eChar // PHASE1_STUB: real multi-load Hazchem logic deferred until DG history exists

    }

    var copyToPaperSummaryLines: [String] {

        compartments.compactMap { comp in

            guard let product = comp.selectedProduct,

                  let litres = Int(comp.litresText),

                  litres > 0 else {

                return nil

            }

            return "\(comp.name): \(product.shortName)  \(litres) L"

        }

    }

    /// Applies a load template as a DRAFT ONLY.

    /// - Does not append to `confirmedLoads`.

    /// - DG placard in Load Plan mode should continue showing last confirmed state until `confirmCurrentLoad()`.

    func applyTemplateToLoadPlan(_ template: LoadTemplate) {

        // 1) Clear first: blank the plan (NOT "0")

        for i in compartments.indices {

            compartments[i].litresText = ""

            compartments[i].selectedProduct = nil

            compartments[i].isDegassed = false

        }

        // 2) Apply each item

        for item in template.items {

            guard let idx = compartments.firstIndex(where: { $0.name == item.compartmentName }) else { continue }

            // Product is optional: only set if it matches

            if let prod = product(shortName: item.productShortName) {

                compartments[idx].selectedProduct = prod

                // litres: show blank if 0, otherwise the number

                let litres = max(item.litres, 0)

                compartments[idx].litresText = litres == 0 ? "" : "\(litres)"

                // SG override: store per product if provided

                if let sg = item.sgOverride {

                    setSg(sg, for: prod)

                }

            } else {

                // If product shortName doesn't match, leave blank

                compartments[idx].selectedProduct = nil

                compartments[idx].litresText = ""

            }

        }

    }

    // MARK: - Unload helpers

    /// Applies a delivery in UNLOAD mode.

    /// Subtracts delivered litres from the current "remaining" litres (clamped at 0).

    /// Intended to be called by DeliverySheetView to avoid manual maths in the main grid.

    func applyDelivery(compName: String, litresDelivered: Int) {

        guard litresDelivered > 0 else { return }

        guard let idx = compartments.firstIndex(where: { $0.name == compName }) else { return }

        let currentRemaining = Int(compartments[idx].litresText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let newRemaining = max(currentRemaining - litresDelivered, 0)

        compartments[idx].litresText = String(newRemaining)

        // If anything remains, it definitely isn't degassed.

        if newRemaining > 0 {

            compartments[idx].isDegassed = false

        }

        // A delivery implies the truck is not in "final empty" state.

        // (Driver can still press Full Unload to explicitly declare empty.)

        unloadFinalised = false

    }

    /// Clear litres only — keep product type for placarding.

    func fullUnload() {

        for i in compartments.indices {

            compartments[i].litresText = "0"

        }

        // Driver has explicitly declared: truck is empty (on board inventory)

        unloadFinalised = true

    }

    /// Degassed — clear litres AND product types.

    func degasTruck() {

        for i in compartments.indices {

            compartments[i].isDegassed = true

            compartments[i].litresText = "0"

            compartments[i].selectedProduct = nil

        }

        suppressPlacardUntilNextConfirm = true

    }

}

```

  

---

  

## AppModels/AppModel+OdoCapture.swift

  

```swift

  

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - AppModel + OdoCapture

//======================================

  

// Purpose:

// - Centralise odo capture helpers and in-load coaching nudges.

// - Keeps AppModel.swift free of sheet/capture workflow methods.

  

// Owns:

// - "You appear stopped" coaching nudge for the Load view.

// - Odo prompt lifecycle (request/commit) + validation.

// - ODO ↔ GPS reconciliation to finalise per-segment kilometres.

// - Load/unload mode toggle handler.

  

// Notes:

// - All @Published stored properties remain in AppModel.swift.

// - Thresholds are sourced from GPSConstants/OdoConstants to avoid magic numbers.

// - ODO capture is authoritative; GPS is evidence used for approximation.

//======================================

  

//======================================

// MARK: - "Stopped while driving" Nudge (in-load view)

//======================================

  

extension AppModel {

    /// Called on every GPS speed update while the Load view is open.

    func considerStoppedNudgeInLoad(speedMps: Double?) {

        guard isOnDuty else { cancelStoppedNudge(); return }

        guard isDriving else { cancelStoppedNudge(); return }

        guard !isOnBreak else { cancelStoppedNudge(); return }

        let now = Date()

        if let last = lastStoppedNudgeAt,

           now.timeIntervalSince(last) < GPSConstants.stoppedNudgeCooldownSeconds {

            return

        }

        guard let s = speedMps, s >= 0 else { return }

        // Moving → reset stop accumulator.

        if s > GPSConstants.minMotionSpeedMps {

            stoppedStartAt = nil

            pendingStoppedNudge?.cancel()

            pendingStoppedNudge = nil

            return

        }

        // First time we detect stopped → start dwell timer.

        if stoppedStartAt == nil {

            stoppedStartAt = now

            scheduleStoppedNudgeCheck()

        }

    }

    /// Called when entering the Load view — primes the nudge if already stopped.

    func primeStoppedNudgeInLoadEntry() {

        guard isOnDuty, isDriving, !isOnBreak else { return }

        guard let s = lastKnownSpeedMps, s >= 0 else { return }

        let now = Date()

        if let last = lastStoppedNudgeAt,

           now.timeIntervalSince(last) < GPSConstants.stoppedNudgeCooldownSeconds {

            return

        }

        if s <= GPSConstants.minMotionSpeedMps, stoppedStartAt == nil {

            stoppedStartAt = now

            scheduleStoppedNudgeCheck()

        }

    }

    func snoozeStoppedNudgeInLoad() {

        lastStoppedNudgeAt = Date()

        stoppedStartAt     = nil

    }

    func scheduleStoppedNudgeCheck() {

        pendingStoppedNudge?.cancel()

        let workItem = DispatchWorkItem { [weak self] in

            guard let self else { return }

            let now = Date()

            if let start = self.stoppedStartAt,

               now.timeIntervalSince(start) >= GPSConstants.stoppedNudgeConfirmSeconds,

               let lastS = self.lastKnownSpeedMps,

               lastS <= GPSConstants.minMotionSpeedMps {

                self.showStoppedNudgeInLoad = true

                self.lastStoppedNudgeAt     = now

                self.stoppedStartAt         = nil

            }

            self.pendingStoppedNudge = nil

        }

        pendingStoppedNudge = workItem

        DispatchQueue.main.asyncAfter(

            deadline: .now() + GPSConstants.stoppedNudgeConfirmSeconds,

            execute: workItem

        )

    }

    private func cancelStoppedNudge() {

        stoppedStartAt = nil

        pendingStoppedNudge?.cancel()

        pendingStoppedNudge = nil

    }

}

  

  

//======================================

// MARK: - Load / Unload Mode

//======================================

  

extension AppModel {

    func handleModeToggleAttempt(newIsUnloadMode: Bool) {

        // Phase 1: allow unconditionally (coaching deferred to a later phase).

        isUnloadMode = newIsUnloadMode

    }

}

  

  

//======================================

// MARK: - Odo Prompt Setup

//======================================

  

extension AppModel {

    /// Prepares the odometer capture prompt for a specific context

    /// (e.g. shift start, break end, shift end).

    /// This only sets transient UI state — nothing is persisted until `commitOdoCapture()`.

    func requestOdoCapture(_ context: OdoPromptContext, afterSave: (() -> Void)? = nil) {

        pendingActionAfterOdo = afterSave

        odoPromptContext      = context

        odoPromptOdoText      = odoText // prefill with last known odo

        odoPromptSuburbText   = ""      // driver must enter suburb where required

    }

    var isMissingShiftStartOdo: Bool {

        isOnDuty && !odoLocationRecords.contains(where: { $0.context == .shiftStart })

    }

}

  

  

//======================================

// MARK: - ODO ↔ GPS Reconciliation (private)

//======================================

  

extension AppModel {

    private func reconcileDistanceIfPossible(

        afterNewOdoKm newOdoKm: Int,

        at time: Date,

        context: OdoPromptContext

    ) {

        // 0) First ever anchor

        guard let lastKm = lastOdoAnchorKm else {

            lastOdoAnchorKm = newOdoKm

            kmCorrectionFactor = 1.0

            gpsKmSinceLastOdoBySegment.removeAll()

            lastOdoCaptureTime = time

            return

        }

        // 1) Shift start is a boundary marker, not a measurement window

        if context == .shiftStart {

            lastOdoAnchorKm = newOdoKm

            kmCorrectionFactor = 1.0

            gpsKmSinceLastOdoBySegment.removeAll()

            lastOdoCaptureTime = time

            return

        }

        // 2) Odo delta sanity

        let odoDelta = newOdoKm - lastKm

        guard odoDelta >= 0 else {

            DebugLog.odo("⚠️ ODO reconcile ignored (negative delta): new=\(newOdoKm) last=\(lastKm)")

            return

        }

        guard odoDelta > 0 else {

            // No movement since last anchor → just reset window cleanly

            gpsKmSinceLastOdoBySegment.removeAll()

            kmCorrectionFactor = 1.0

            lastOdoAnchorKm = newOdoKm

            lastOdoCaptureTime = time

            return

        }

        // 3) Gather GPS window

        let gpsWindowKm = gpsKmSinceLastOdoBySegment.values.reduce(0, +)

        // 4) Decide whether GPS is usable for calibration

        let minGpsWindowKm: Double = 1.0   // <-- key guard: prevents tiny denominator

        let maxGpsWindowKm: Double = 200.0 // defensive (won't hit in real life)

        let gpsUsable: Bool = (gpsWindowKm >= minGpsWindowKm && gpsWindowKm <= maxGpsWindowKm)

        // 5) If GPS isn't usable, allocate odoDelta to current segment (or buffer if nil)

        guard gpsUsable else {

            kmCorrectionFactor = 1.0

            if let sid = runningSegmentID {

                finalisedKmBySegment[sid, default: 0] += Double(odoDelta)

                DebugLog.odo("ODO reconcile (GPS unusable): allocated odoΔ=\(odoDelta)km to sid=\(sid.uuidString.prefix(6)) gpsWindow=\(String(format: "%.2f", gpsWindowKm))km")

            } else {

                DebugLog.odo("⚠️ Odo capture with no running segment - odoΔ=\(odoDelta)km gpsWindow=\(String(format: "%.2f", gpsWindowKm))km")

            }

            gpsKmSinceLastOdoBySegment.removeAll()

            lastOdoAnchorKm = newOdoKm

            lastOdoCaptureTime = time

            return

        }

        // 6) Compute factor and clamp to sane bounds

        let rawFactor = Double(odoDelta) / gpsWindowKm

        let clampedFactor =

        min(max(rawFactor, GPSConstants.kmCorrectionClampMin),

            GPSConstants.kmCorrectionClampMax)

        // If we had to clamp hard, log it (this is the smoking gun for later debugging)

        if abs(clampedFactor - rawFactor) > 0.0001 {

            DebugLog.odo("⚠️ kmCorrectionFactor CLAMPED raw=\(String(format: "%.2f", rawFactor)) → \(String(format: "%.2f", clampedFactor)) (odoΔ=\(odoDelta) gpsWindow=\(String(format: "%.2f", gpsWindowKm)))")

        }

        kmCorrectionFactor = clampedFactor

        // 7) Finalise per segment using CLAMPED factor

        for (sid, gpsKm) in gpsKmSinceLastOdoBySegment {

            finalisedKmBySegment[sid, default: 0] += gpsKm * kmCorrectionFactor

        }

        let finalisedKm = gpsWindowKm * kmCorrectionFactor

        let note =

        "ODO reconcile: odoΔ=\(odoDelta)km, gpsWindow=\(String(format: "%.2f", gpsWindowKm))km, " +

        "rawFactor=\(String(format: "%.2f", rawFactor)), factor=\(String(format: "%.2f", kmCorrectionFactor)), " +

        "finalised≈\(String(format: "%.2f", finalisedKm))km"

        logEvent(.other, note: note, at: time)

        // 8) Reset window + anchor

        gpsKmSinceLastOdoBySegment.removeAll()

        lastOdoAnchorKm = newOdoKm

        lastOdoCaptureTime = time

    }

}

  

//======================================

// MARK: - Commit Odo Capture (authoritative write-point)

//======================================

  

extension AppModel {

    /// Validates and commits an odometer capture into `odoLocationRecords`.

    /// - Enforces numeric-only odometer values.

    /// - Requires suburb for mandatory contexts (as defined in OdoConstants).

    /// - Acts as the single authoritative write-point for odo history.

    func commitOdoCapture() {

        guard let ctx = odoPromptContext else { return }

        let capturedContext = ctx // keep stable copy (we nil UI state later)

        let rawOdo = odoPromptOdoText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawOdo.isEmpty, rawOdo.allSatisfy({ $0.isNumber }) else { return }

        let cleanedOdo = rawOdo

        let cleanedSuburb = odoPromptSuburbText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Suburb mandatory/optional rules live in constants.

        let suburbRequired = OdoConstants.mandatorySuburbContexts.contains(capturedContext)

        if suburbRequired {

            guard !cleanedSuburb.isEmpty else { return }

        }

        // Store a single space when suburb is optional and left blank (preserves "intentionally blank").

        let suburbToStore = cleanedSuburb.isEmpty ? " " : cleanedSuburb

        let saveTime = Date()

        // Shift-start may be backdated (override), but never after the save moment.

        let recordTime: Date = {

            if capturedContext == .shiftStart, let override = odoPromptTimestampOverride {

                return min(override, saveTime)

            }

            return saveTime

        }()

        // Update current odo display immediately.

        odoText = cleanedOdo

        // SHIFT START: create the first segment BEFORE recording/reconciling.

        if pendingStartShiftCapture && capturedContext == .shiftStart {

            pendingStartShiftCapture = false

            isOnDuty  = true

            isDriving = false

            isOnBreak = false

            // Create the first segment now.

            startActivity(.workGeneral, at: saveTime)

            // Log event at the backdated time.

            logEvent(.shiftStart, at: recordTime)

        }

        // Associate odo record to the current running segment (should exist by now).

        let associatedSegmentID: UUID? = runningSegmentID

        // Create and store the record.

        let record = OdoLocationRecord(

            id: UUID(),

            timestamp: recordTime,

            context: capturedContext,

            odoText: cleanedOdo,

            suburb: suburbToStore,

            segmentID: associatedSegmentID

        )

        odoLocationRecords.append(record)

        // If this odo capture closes a segment that had a background gap,

        // apply the estimated meters as finalised km.

        if let gapSeg = pendingGapSegmentID,

           let estimateMeters = pendingGapEstimateMeters,

           gapSeg == associatedSegmentID {

            let km = estimateMeters / 1000.0

            finalisedKmBySegment[gapSeg, default: 0] += km

            distanceEvents.append(

                DistanceEvent(

                    at: Date(),

                    segmentID: gapSeg,

                    kind: .backgroundGapApplied,

                    deltaKm: km,

                    note: pendingGapReason ?? "Background gap applied"

                )

            )

            DebugLog.gps("🟣 Background gap applied: \(String(format: "%.2f", km)) km")

            clearBackgroundGapState(reason: "Gap applied via odo capture")

        }

        // Reconcile distance AFTER segment exists.

        if let odoKm = Int(cleanedOdo) {

            reconcileDistanceIfPossible(afterNewOdoKm: odoKm, at: recordTime, context: capturedContext)

            lastOdoCaptureTime = recordTime

        }

        // Clear timestamp override.

        odoPromptTimestampOverride = nil

        // Clear prompt UI state.

        odoPromptContext    = nil

        odoPromptOdoText    = ""

        odoPromptSuburbText = ""

        // Release shift-start gate here.

        // (DO NOT clear pendingEndShiftCapture here — we act on context below)

        if capturedContext == .shiftStart {

            pendingStartShiftCapture = false

        }

        // Run queued action (e.g. legal break end -> switch activity).

        let action = pendingActionAfterOdo

        pendingActionAfterOdo = nil

        action?()

        // Always autosave after a committed capture.

        autosave?.requestAutosave(reason: "Odo/location captured", immediate: true)

        // SHIFT END: finalize immediately and deterministically.

        if capturedContext == .shiftEnd {

            pendingEndShiftCapture = false

            finalizeEndShift()

            autosave?.requestAutosave(reason: "Shift ended", immediate: true)

            return

        }

        // If some other pathway set this flag, honour it (belt + suspenders).

        if pendingEndShiftCapture {

            pendingEndShiftCapture = false

            finalizeEndShift()

            autosave?.requestAutosave(reason: "Shift ended (pending)", immediate: true)

        }

    }

    /// Lightweight helper used during breaks to update the current odometer display.

    /// Does NOT write to `odoLocationRecords`.

    /// Phase 1 only — future versions may link this to shift history.

    func updateOdometer(fromBreak newOdo: String) {

        odoText = newOdo.trimmingCharacters(in: .whitespaces)

    }

}
```

  

---

  

## AppModels/AppModel+RestLogic.swift

  

```swift

import Foundation

//======================================

// MARK: - AppModel+RestLogic

//======================================

//

//======================================

// MARK: - Phase 1 Start Planning (pre-persistence, single-day only)

//======================================

// Phase 1 goal: provide a simple "earliest next start" + "latest finish" planner

// without rolling 24h / multi-day rules (those require persistence).

// Assumptions:

// - "Legal rest today" = sum of rest segments ≥ 15 minutes (see FatigueRules.swift).

// - Post-shift rest requirement is approximated as:

//   max(7h continuous rest, (12h total rest target - legal rest already taken today)).

// This is a planning heuristic and will be refined in Phase 3+.

  

extension AppModel {

    /// Phase 1 definition of "legal rest today":

    /// sum of rest segments ≥ 15 minutes (see `totalLegalRestToday` in FatigueRules.swift).

    var phase1_restToday: TimeInterval {

        totalLegalRestToday

    }

    /// Phase 1 post-shift rest requirement (planning heuristic).

    /// Returns the minimum rest needed after finishing, based on:

    /// - 7h continuous rest minimum, and

    /// - a 12h "total rest target" where today's already-taken legal rest counts toward the 12h.

    /// Note: This does NOT implement rolling 24h windows or multi-day NHVR logic (Phase 3+).

    func phase1_requiredRestAfterShift(restToday: TimeInterval) -> TimeInterval {

        let needForTotal = max(FatigueConstants.targetTotalRest24h - restToday, 0)

        let needForContinuous = FatigueConstants.minContinuousRest

        return max(needForContinuous, needForTotal)

    }

  

    /// Phase 1: can the driver legally start work *immediately* (same day proxy)?

    ///

    /// Intent:

    /// - If the driver ends a short "test/admin" shift, the app should not imply

    ///   they must take 7h continuous rest before doing anything else.

    /// - This answers: "Can I start again now under today's proxy limits?"

    ///

    /// Notes:

    /// - Still NOT a rolling 24h engine (Phase 3+).

    /// - Uses today's proxies:

    ///   • 12h daily cap

    ///   • 5h15 spacing between ≥15m legal rests

    ///   • 7h30/10h thresholds requiring 30m/60m legal rest (today proxy)

    func phase1_canStartAgainNow() -> Bool {

        let workToday = workSecondsToday

        let legalRest = totalLegalRestToday

        let workSinceLegal15 = workSecondsSinceLastLegalRest(minBreak: FatigueConstants.legalBreak15)

        // 12h cap proxy

        if workToday >= FatigueConstants.nhvrDailyCap { return false }

        // 5h15 spacing proxy

        if workSinceLegal15 >= FatigueConstants.nhvrSpacingLimit { return false }

        // Threshold proxies

        if workToday >= FatigueConstants.nhvrSevenPointFiveHours && 

            legalRest < FatigueConstants.requiredRestAt7h30 { 

            return false 

        }

        if workToday >= FatigueConstants.nhvrTenHours && 

            legalRest < FatigueConstants.requiredRestAt10h { 

            return false 

        }

        return true

    }

  

    /// Earliest next start time if you finish at `end`, using Phase 1 rest requirement.

    func phase1_earliestNextStart(from end: Date) -> Date {

        // If today's proxy limits still allow work, you can start again immediately.

        // (Ending a short "shift" shouldn't force a 7h rest block in Phase 1.)

        if phase1_canStartAgainNow() {

            return end

        }

        // Otherwise, fall back to the post-shift rest heuristic.

        let required = phase1_requiredRestAfterShift(restToday: phase1_restToday)

        return end.addingTimeInterval(required)

    }

    /// Reverse planner:

    /// Given a desired next start time, calculates the latest finish time

    /// that would still allow enough post-shift rest (Phase 1 heuristic).

    func phase1_backCalculateFinish(desiredStart: Date) -> Phase1StartPlanning {

        let restToday = phase1_restToday

        let requiredAfterShift = phase1_requiredRestAfterShift(restToday: restToday)

        let latestFinish = desiredStart.addingTimeInterval(-requiredAfterShift)

        return Phase1StartPlanning(

            restToday: restToday,

            requiredRestAfterShift: requiredAfterShift,

            latestFinishToStartAtDesired: latestFinish

        )

    }

}

  

extension AppModel {

    /// NHVR "legal rest" today = sum of rest segments >= 15 minutes.

    var legalRestSecondsToday: TimeInterval {

        // If you already have totalLegalRestToday, use that instead.

        totalLegalRestToday

    }

    /// Short rest today = rest segments < 15 minutes (these count as WORK for NHVR rolling windows).

    var shortRestSecondsToday: TimeInterval {

        max(restSecondsToday - legalRestSecondsToday, 0)

    }

    /// NHVR work today = work + short rest (because <15m rest counts as work).

    var nhvrWorkSecondsToday: TimeInterval {

        workSecondsToday + shortRestSecondsToday

    }

    /// NHVR rest today = legal rest only (>=15m).

    var nhvrRestSecondsToday: TimeInterval {

        legalRestSecondsToday

    }

}

  

//======================================

// MARK: - Rest-in-progress (Limbo) helpers

//======================================

//

// Purpose (Phase 1):

// - While the driver is currently resting, but the break has not yet reached

//   the ≥15m "legal rest" threshold, the UI should not scream ❌.

// - This does NOT change NHVR maths. It only gives the UI a “provisional” state.

//

// Post-persistence:

// - This can become rule-aware (e.g. 30m / 60m targets) and location-aware.

//

  

extension AppModel {

    /// True if the current activity is a REST-type activity (not work, not off duty filter here).

    var isCurrentlyResting: Bool {

        currentSegmentStart != nil && !currentActivity.isWork

    }

    /// Duration (seconds) of the current in-progress rest segment. 0 if not currently resting.

    var currentRestDurationSeconds: TimeInterval {

        guard isCurrentlyResting, let start = currentSegmentStart else { return 0 }

        return max(time.now().timeIntervalSince(start), 0)

    }

    /// Limbo state: currently resting, but not yet qualified as ≥15m legal rest.

    var isInRestLimbo15: Bool {

        guard isCurrentlyResting else { return false }

        let d = currentRestDurationSeconds

        return d > 0 && d < FatigueConstants.legalBreak15

    }

    /// Seconds remaining until the current rest becomes ≥15m legal rest.

    /// Returns 0 if not resting or already qualified.

    var secondsUntilLegal15: TimeInterval {

        guard isCurrentlyResting else { return 0 }

        return max(FatigueConstants.legalBreak15 - currentRestDurationSeconds, 0)

    }

    /// Convenience text hook if you want it later.

    /// (UI can format secondsUntilLegal15 using formatTimeHM.)

    var currentRestIsQualifiedLegal15: Bool {

        guard isCurrentlyResting else { return false }

        return currentRestDurationSeconds >= FatigueConstants.legalBreak15

    }

}

  

extension AppModel {

    private var todayActivitySegmentsIncludingCurrent: [ActivitySegment] {

        let cal = complianceCalendar

        let now = time.now()

        // You already keep today's completed segments here:

        var segs = segmentsToday.filter { cal.isDate($0.start, inSameDayAs: now) }

        // If there's an in-progress activity, synthesize a "current" segment

        if let start = currentSegmentStart,

           cal.isDate(start, inSameDayAs: now),

           currentActivity != .offDuty {

            let current = ActivitySegment(

                type: currentActivity,

                start: start,

                end: nil

            )

            segs.append(current)

        }

        segs.sort { $0.start < $1.start }

        return segs

    }

    /// NHVR work since last ≥minBreak rest.

    /// NHVR work = work + short rest (<15m) because short rest counts as work for NHVR.

    /// Resets only when a rest segment ≥minBreak occurs.

    func nhvrWorkSecondsSinceLastLegalRest(minBreak: TimeInterval) -> TimeInterval {

        let segments = todayActivitySegmentsIncludingCurrent

        var acc: TimeInterval = 0

        let now = time.now()

        for seg in segments.reversed() {

            let end = seg.end ?? now

            let dur = max(end.timeIntervalSince(seg.start), 0)

            if seg.type.isWork {

                acc += dur

            } else {

                if dur >= minBreak {

                    break

                } else {

                    // short rest counts as work for NHVR

                    acc += dur

                }

            }

        }

        return acc

    }

}

  

//======================================

// MARK: - UI payload for Phase 1 start planning

//======================================

  

struct Phase1StartPlanning {

    let restToday: TimeInterval

    let requiredRestAfterShift: TimeInterval

    let latestFinishToStartAtDesired: Date

}

```

  

---

  

## AppModels/AppModel+ShiftActions.swift

  

```swift

import SwiftUI

import Foundation

//======================================

// MARK: - AppModel+ShiftActions

//======================================

  

extension AppModel {

    // MARK: - Activity button gates (Part C)

    /// True when it is safe to change activity.

    /// This prevents "buttons dead", half-started shift states, and switching during prompts.

    var canChangeActivityNow: Bool {

        // Must be on a shift

        guard isOnDuty else { return false }

        // Must not be in an ODO capture prompt

        guard odoPromptContext == nil else { return false }

        // Must not be in a Guard prompt flow (drive nudge / stopped nudge / etc)

        guard activeGuardPrompt == nil else { return false }

        // Must not be mid-gate for start/end shift

        guard !pendingStartShiftCapture else { return false }

        guard !pendingEndShiftCapture else { return false }

        // Must have completed the shift-start odo capture (your helper)

        guard !isMissingShiftStartOdo else { return false }

        // Must have an active segment to attach evidence + km accumulation

        guard runningSegmentID != nil else { return false }

        return true

    }

    var canPressDrive: Bool {

        canChangeActivityNow && currentActivity != .driving

    }

    var canPressBreak: Bool {

        canChangeActivityNow && currentActivity != .restBreak

    }

    var canPressLoad: Bool {

        canChangeActivityNow && currentActivity != .workLoad

    }

    var canPressUnload: Bool {

        canChangeActivityNow && currentActivity != .workUnload

    }

    var canPressEndShift: Bool {

        // End shift allowed even if you're in work/rest,

        // but not allowed during prompts or while already ending.

        isOnDuty

        && odoPromptContext == nil

        && activeGuardPrompt == nil

        && !pendingEndShiftCapture

        && !pendingStartShiftCapture

        && !isMissingShiftStartOdo

    }

  

    //======================================

    // MARK: - Event logging

    //======================================

    func logEvent(_ kind: EventKind, note: String? = nil, at time: Date = Date()) {

        let event = ShiftEvent(time: time, kind: kind, note: note)

        events.append(event)

        autosave?.requestAutosave(reason: "Event log")

    }

    //======================================

    // MARK: - Tick (for driving time)

    //======================================

    /// Called every second from TodayView's timer.

    /// Only accumulates driving time while `isDriving == true`.

    func tick(now: Date = Date()) {

        // Only accumulate driving time while actually driving

        guard isDriving else {

            lastTick = nil

            return

        }

        if isOnDuty && isGpsConnected {

            motionWatchdogTick()

        }

        if let last = lastTick {

            let delta = now.timeIntervalSince(last)

            // Accept any sane positive delta; reject huge jumps (clock change / app suspended / timer hiccup).

            if delta > 0 && delta < 6 * 3600 {

                driveSecondsToday += delta

            }

        }

        // Always move lastTick forward

        lastTick = now

    }

    //======================================

    // MARK: - Activity engine

    //======================================

    // NOTE ON STATE:

    // - `currentActivity/currentSegmentStart/segmentsToday` is the authoritative source for fatigue maths.

    // - `isOnDuty/isDriving/isOnBreak` are UI convenience flags + drive `tick()` behaviour.

    // If they ever disagree, treat the activity engine as truth and adjust flags accordingly.

    /// Close current segment (if any) and start a new one.

    func startActivity(_ newType: ActivityType) {

        startActivity(newType, at: Date())

    }

    func startActivity(_ newType: ActivityType, at time: Date) {

        // Close existing segment

        if let start = currentSegmentStart, let sid = runningSegmentID {

            let finished = ActivitySegment(id: sid, type: currentActivity, start: start, end: time)

            segmentsToday.append(finished)

            considerGapEstimatePromptIfNeeded(endingSegmentID: sid)

  

            autosave?.requestAutosave(reason: "Activity switch")

        }

        // Switch to new activity

        currentActivity = newType

        if newType == .offDuty {

            currentSegmentStart = nil

            runningSegmentID = nil

        } else {

            currentSegmentStart = time

            runningSegmentID = UUID()            // ✅ NEW segment identity every time

        }

    }

    /// Total WORK seconds today (any work activity).

    /// Includes the current in-progress work segment (if any).

    var workSecondsToday: TimeInterval {

        var total: TimeInterval = 0

        let now = Date()

        for seg in segmentsToday {

            guard seg.type.isWork else { continue }

            let end = seg.end ?? now

            total += end.timeIntervalSince(seg.start)

        }

        if let start = currentSegmentStart, currentActivity.isWork {

            total += now.timeIntervalSince(start)

        }

        return max(total, 0)

    }

    /// Total REST seconds today (everything that isn't work).

    /// Includes the current in-progress rest segment (if any).

    var restSecondsToday: TimeInterval {

        var total: TimeInterval = 0

        let now = Date()

        for seg in segmentsToday {

            guard !seg.type.isWork else { continue }

            let end = seg.end ?? now

            total += end.timeIntervalSince(seg.start)

        }

        if let start = currentSegmentStart, !currentActivity.isWork {

            total += now.timeIntervalSince(start)

        }

        return max(total, 0)

    }

    // Close the current segment and start a new one.

        // If leaving a legal break (>=15m), require odo+suburb BEFORE switching.

        private func switchActivityWithLegalBreakGate(

            to newType: ActivityType,

            log kind: EventKind?,

            note: String? = nil

        ) {

            guard isOnDuty else { return }

            // ✅ Shift-start ODO gate: if we haven't captured shift-start yet,

            // queue this activity change and prompt for ODO.

            if pendingStartShiftCapture || isMissingShiftStartOdo {

                // Queue the switch to run AFTER the ODO capture commits

                pendingActionAfterOdo = { [weak self] in

                    guard let self = self else { return }

                    // Do the actual switch now (no further gating needed here)

                    self.isDriving = (newType == .driving)

                    self.isOnBreak = (!newType.isWork && newType != .offDuty)

                    self.lastTick = self.isDriving ? Date() : nil

                    self.startActivity(newType)

                    if let kind {

                        self.logEvent(kind, note: note)

                    }

                }

                // Only show the prompt if it's not already on screen

                if odoPromptContext == nil {

                    requestOdoCapture(.shiftStart)

                }

                return

            }

            let now = Date()

            // Detect: are we currently on a rest break, and is it legal?

            // Detect: are we currently in a restBreak segment?

            let leavingRestBreak = (currentActivity == .restBreak)

            let breakStart = currentSegmentStart ?? now

            let breakSeconds = leavingRestBreak ? now.timeIntervalSince(breakStart) : 0

            let isLegalBreak = leavingRestBreak && breakSeconds >= FatigueConstants.legalBreak15

            // The actual switch work (what we want to happen AFTER any odo gate)

            let performSwitch: () -> Void = { [weak self] in

                guard let self = self else { return }

                // Update UI flags based on newType

                self.isDriving = (newType == .driving)

                self.isOnBreak = (!newType.isWork && newType != .offDuty)

                if self.isDriving { self.lastTick = Date() } else { self.lastTick = nil }

                self.startActivity(newType)

                // Only log an event if caller asked for one

                if let kind {

                    self.logEvent(kind, note: note)

                }

            }

            // If leaving a legal break, odo capture is mandatory before switching

            if isLegalBreak {

                requestOdoCapture(.legalBreakEnd, afterSave: performSwitch)

                return

            }

            // Otherwise switch immediately

            performSwitch()

        }

    //======================================

    // MARK: - Shift / drive / break actions

    //======================================

    /// Starts a new shift and resets "today/shift" tracking.

    /// - Parameter previousMinutes: Manual backfill to account for work done before opening the app.

    ///   This creates a synthetic earlier WORK segment so fatigue calculations reflect the full shift.

    ///   (Phase 1 only — persistence will replace this with real history.)

    func startShift(previousMinutes: Int, backfillKind: BackfillKind = .onDutyNotDriving) {

          let now = time.now()

        // ✅ Compliance TZ (Mode B): freeze at shift start for NHVR counting

        // Capture the timezone in effect at the moment the shift begins (not after backfill).

        sessionBaseTimeZoneID = TimeZone.current.identifier  // if you have this persisted field

        DebugLog.lifecycle("🕒 Compliance TZ locked: \(sessionBaseTimeZoneID)")

      let clampedMinutes = min(max(previousMinutes, 0), 240) // Phase 1 cap: 4 hours

        let previousSeconds = TimeInterval(clampedMinutes * 60)

        events.removeAll()

        segmentsToday.removeAll()

        isOnDuty = true

        isDriving = false

        isOnBreak = false

        let backdatedStart = now.addingTimeInterval(-previousSeconds)

        shiftStartTime = backdatedStart

        if clampedMinutes > 0 {

            let backfillType: ActivityType = {

                switch backfillKind {

                case .onDutyNotDriving: return .workGeneral

                case .driving:         return .driving

                case .rest:            return .restBreak

                case .other(let a):    return a.isWork ? .workGeneral : .restBreak

                }

            }()

            segmentsToday.append(ActivitySegment(type: backfillType, start: backdatedStart, end: now))

            driveSecondsToday = (backfillKind == .driving) ? previousSeconds : 0

        } else {

            driveSecondsToday = 0

        }

        lastTick = nil

        // Don’t start live segment until odo is committed

        currentActivity = .offDuty

        currentSegmentStart = nil

        // Optional backfill note event

        if clampedMinutes > 0 {

            switch backfillKind {

            case .other(let act):   logEvent(.other, note: "Backfill — \(act.name)", at: backdatedStart)

            case .driving:          logEvent(.other, note: "Backfill — Driving", at: backdatedStart)

            case .rest:             logEvent(.other, note: "Backfill — Rest", at: backdatedStart)

            case .onDutyNotDriving: logEvent(.other, note: "Backfill — On duty (Paperwork)", at: backdatedStart)

            }

        }

        pendingStartShiftCapture = true

        odoPromptTimestampOverride = shiftStartTime

        requestOdoCapture(.shiftStart)

        autosave?.markResumableNow(reason: "Shift started")

        autosave?.requestAutosave(reason: "Shift started", immediate: true)

    }

  

        var activityDisabledReason: String? {

            if !isOnDuty { return "Start shift to enable activities." }

            if odoPromptContext != nil { return "Finish odometer capture first." }

            if activeGuardPrompt != nil { return "Respond to the prompt first." }

            if pendingStartShiftCapture { return "Confirm shift-start odometer first." }

            if pendingEndShiftCapture { return "Finalising shift — please wait." }

            if isMissingShiftStartOdo { return "Shift-start odometer is required." }

            if runningSegmentID == nil { return "Activity engine not ready (no segment)." }

            return nil

        }

    func pressDrive() {

        guard canPressDrive else { return }

        switchActivityWithLegalBreakGate(to: .driving, log: .driveStart)

    }

    func pressBreak() {

        guard canPressBreak else { return }

        switchActivityWithLegalBreakGate(to: .restBreak, log: .breakStart)

    }

    func pressLoad() {

        if !canPressLoad {

            DebugLog.lifecycle("❌ pressLoad blocked:  \(activityDisabledReason ?? "unknown")")

            return

        }

        DebugLog.lifecycle("✅ pressLoad allowed")

        isUnloadMode = false

        switchActivityWithLegalBreakGate(to: .workLoad, log: nil)

    }

    func pressUnload() {

        guard canPressUnload else { return }

        isUnloadMode = true

        switchActivityWithLegalBreakGate(to: .workUnload, log: nil)

    }

    func pressIncidentQuick() {

        // Pre-persistence: treat it as an EVENT only, do NOT change segments automatically.

        // (Later: incident types can optionally become segments.)

        logEvent(.incident)

    }

    func endShift() {

        guard isOnDuty else { return }

        let now = Date()

        let leavingRest = !currentActivity.isWork

        let breakStart = currentSegmentStart ?? now

        let breakSeconds = leavingRest ? now.timeIntervalSince(breakStart) : 0

        let isLegalBreak = leavingRest && breakSeconds >= FatigueConstants.legalBreak15

        // If we’re leaving a legal break, do THAT capture first, then shift end capture.

        if isLegalBreak {

            requestOdoCapture(.legalBreakEnd, afterSave: { [weak self] in

                guard let self = self else { return }

                self.pendingEndShiftCapture = true

                self.requestOdoCapture(.shiftEnd)

            })

            return

        }

        pendingEndShiftCapture = true

        requestOdoCapture(.shiftEnd)

    }

    func finalizeEndShift() {

        let now = Date()

        // Close any running segment

        startActivity(.offDuty)

        // Build summary (keep)

        let shiftStart = shiftStartTime ?? .distantPast

        let loads = confirmedLoads.filter { $0.timestamp >= shiftStart && $0.mode == .loadConfirmed }.count

        let unloads = confirmedLoads.filter { $0.timestamp >= shiftStart && $0.mode == .unloadSnapshot }.count

        gpsShiftMetersLive = 0

        requestLmResetShiftMetersFromUI?("Shift ended (finalizeEndShift)")

        lastShiftSummary = ShiftSummary(

            date: now,

            start: shiftStartTime,

            end: now,

            workSeconds: workSecondsToday,

            restSeconds: restSecondsToday,

            driveSeconds: driveSecondsToday,

            loadCount: loads,

            unloadCount: unloads

        )

        // Turn shift OFF

        isOnDuty = false

        isDriving = false

        isOnBreak = false

        shiftStartTime = nil

        driveSecondsToday = 0

        lastTick = nil

        // Clear "within-shift only" state (your policy)

        events.removeAll()

        segmentsToday.removeAll()

        confirmedLoads.removeAll()

        unloadFinalised = false

        isUnloadMode = false

        suppressPlacardUntilNextConfirm = false

        // Optional: clear current load plan UI (draft)

        for i in compartments.indices {

            compartments[i].litresText = ""

            compartments[i].selectedProduct = nil

            compartments[i].isDegassed = false

        }

        // Clear prompts/timers etc

        resetTransientWorkflows()

        // ✅ This is the key: kill resumability + remove the files

        autosave?.markNotResumableNow(reason: "Shift ended", clearFiles: true)

        saveStore.clearAutosaves()

    }

    //======================================

    // MARK: - Other activities

    //======================================

    func openIncidentSheet() {

        // If a prompt is stuck on screen, kill it first

        activeGuardPrompt = nil

        beginIncidentDraft()

        isShowingIncidentSheet = true

    }

    /// Start a user-defined "Other" activity (work or rest).

    func startOtherActivity(_ activity: OtherActivity, note: String? = nil) {

        guard isOnDuty else { return }

        isDriving = false

        if activity.isWork {

            isOnBreak = false

            startActivity(.workGeneral)

        } else {

            isOnBreak = true

            startActivity(.restBreak)

        }

        // If driver adds a note, append it after the label

        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let combinedNote = trimmed.isEmpty ? activity.name : "\(activity.name) — \(trimmed)"

        logEvent(.other, note: combinedNote)

    }

}

  

extension AppModel {

    /// Pre-persistence: the canonical segment list for display (finished + current running).

    var timelineSegmentsIncludingCurrent: [ActivitySegment] {

        var segs = segmentsToday

        if let start = currentSegmentStart,

           currentActivity != .offDuty,

           let sid = runningSegmentID {

            segs.append(ActivitySegment(id: sid, type: currentActivity, start: start, end: nil))

        }

        return segs.sorted { $0.start < $1.start }

    } 

    /// Find the most relevant odo record for a segment:

    /// Prefer one that falls within the segment window; otherwise nil.

    func odoRecord(for segment: ActivitySegment) -> OdoLocationRecord? {

        odoLocationRecords.last(where: { $0.segmentID == segment.id })

    }

    /// Events that happened during a segment (pre-persistence)

    func events(during segment: ActivitySegment) -> [ShiftEvent] {

        let segEnd = segment.end ?? Date()

        return events.filter { $0.time >= segment.start && $0.time <= segEnd }

    }

    /// Confirmed loads during a segment (pre-persistence)

    func confirmedLoadsDuring(_ segment: ActivitySegment) -> [ConfirmedLoad] {

        let segEnd = segment.end ?? Date()

        return confirmedLoads.filter { $0.timestamp >= segment.start && $0.timestamp <= segEnd }

    }

    func considerGapEstimatePromptIfNeeded(endingSegmentID sid: UUID) {

        guard let pendingSid = pendingGapSegmentID,

              pendingSid == sid

        else { return }

        guard let meters = pendingGapEstimateMeters else {

            // We detected a gap but have no estimate; still can prompt for odo capture if you want.

            pendingGapSegmentID = nil

            pendingGapReason = nil

            return

        }

        let km = meters / 1000.0

        // ✅ Use your existing GuardPrompt pipe (shown globally in ContentView)

        activeGuardPrompt = GuardPrompt(

            title: "Distance gap detected",

            message: """

        The app was inactive and likely missed GPS updates.

        Estimated road distance: \(String(format: "%.1f", km)) km.

        \(pendingGapReason ?? "")

        Confirm with odometer?

        """,

            actions: [

                GuardAction(title: "Apply estimate", role: nil) { [weak self] in

                    guard let self else { return }

                    self.finalisedKmBySegment[sid, default: 0] += km

                    Task { @MainActor in

                        self.clearBackgroundGapState(reason: "User applied estimate")

                    }

                },

                GuardAction(title: "Capture odo now", role: nil) { [weak self] in

                    guard let self else { return }

                    Task { @MainActor in

                        self.clearBackgroundGapState(reason: "User chose capture odo")

                        self.requestOdoCapture(.odoUpdate)

                    }

                },

                GuardAction(title: "Ignore", role: .cancel) { [weak self] in

                    Task { @MainActor in

                        self?.clearBackgroundGapState(reason: "User ignored gap")

                    }

                }

            ]

        )

    }

    private func clearPendingGap() {

        pendingGapEstimateMeters = nil

        pendingGapSegmentID = nil

        pendingGapReason = nil

    }

}

```

  

---

  

## AppModels/AppModel+TemplatesAndSimulation.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Templates + Simulation helpers (Phase 1, pre-persistence)

//======================================

// Purpose:

// - Lookup products by short code (e.g. "DSL", "P91").

// - Apply "Typical load" patterns to the live Load Plan.

// - Provide draft mass simulation results for SimulationView.

// - Save the current draft as a reusable template (session-only for now).

//

// Notes (pre-persistence):

// - `savedTemplates` are in-memory only unless/ until persistence is added.

// - "Typical loads" are built-in helpers and will later migrate to the unified LoadTemplate system.

//======================================

  

extension AppModel {

    //======================================

    // MARK: - Product lookup + template application

    //======================================

    /// Finds a product by short name (case-insensitive), e.g. "DSL", "P91", "P95".

    /// Single source of truth for mapping template strings → Product models.

    func product(shortName: String) -> Product? {

        products.first { $0.shortName.uppercased() == shortName.uppercased() }

    }

    /// Computed draft simulation result for the current `draftTemplate`.

    /// Pure calculation: should NOT mutate model state.

    var draftSimulationResult: MassSimulationResult {

        MassSimulationLogic.simulate(template: draftTemplate, products: products, truck: truckConfig)

    }

    /// Applies a built-in "Typical load" pattern as a DRAFT ONLY.

    /// - Compartments mentioned in the template: set product + litres.

    /// - Compartments not mentioned: clear litres (leave product picker untouched).

    /// Note: Placarding should not change in Load Plan mode until `confirmCurrentLoad()`.

    func applyTypicalLoad(_ template: TypicalLoadTemplate) {

        for index in compartments.indices {

            let name = compartments[index].name

            if let config = template.perCompartment[name],

               let prod = product(shortName: config.productShortName) {

                compartments[index].selectedProduct = prod

                compartments[index].litresText = "\(config.litres)"

            } else {

                // Not in this template: clear litres only.

                // Leaving the product picker alone avoids accidental type changes when comparing templates.

                compartments[index].litresText = ""

            }

        }

    }

    /// Forces SwiftUI to refresh views that depend on `draftSimulationResult`.

    /// Used when the draft template mutates in a way that doesn't naturally trigger an @Published change.

    func recalcDraftSimulation() {

        objectWillChange.send()

    }

    /// Saves the current `draftTemplate` as a NEW `LoadTemplate` entry.

    /// - Creates a new UUID + createdAt timestamp.

    /// - Copies items/notes as-is (no validation here).

    /// Phase 1: stored in-memory only until persistence is implemented.

    func saveDraftAsNewTemplate() {

        let newTemplate = LoadTemplate(

            id: UUID(),

            name: draftTemplate.name,

            createdAt: Date(),

            items: draftTemplate.items,

            notes: draftTemplate.notes

        )

        savedTemplates.append(newTemplate)

    }

}

```

  

---

  

## AppModels/AppModel+Timeline.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Timeline Projection (UI View Models)

//======================================

//

// Purpose:

// - Convert raw events/segments into UI-friendly timeline rows

// - Provides stable IDs for SwiftUI List rendering

// - Formats timestamps consistently

//

// Scope:

// - Read-only transformations only

// - No business logic (that belongs in AppModel core or Logic/)

// - Pure view-model layer

//

// Pre-persistence:

// - Operates on in-memory events array

// - Lost on app restart

//

// Post-persistence:

// - Will query from SQLite instead

// - Same UI contract, different data source

//

//======================================

  

extension AppModel {

  

    /// UI-friendly projection of `events` for Timeline display.

    /// - Reuses `ShiftEvent.id` so SwiftUI diffing stays stable across refreshes.

    /// - Formats timestamps to short time strings for compact display.

    var timelineEvents: [TimelineEvent] {

        events.map { event in

            let label: String

            switch event.kind {

            case .other:

                if let note = event.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                    label = "Other – \(note)"

                } else {

                    label = event.kind.rawValue   // "Other"

                }

            case .incident:

                if let note = event.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                    label = "Incident – \(note)"

                } else {

                    label = event.kind.rawValue

                }

            default:

                // For all standard events, use the canonical EventKind string.

                // This keeps the timeline in sync if you rename EventKind labels later.

                label = event.kind.rawValue

            }

            return TimelineEvent(

                id: event.id,

                timeString: formatTimeShort(event.time),

                label: label

            )

        }

    }

}

```

  

---

  

## AppModels/AppModel.swift

  

```swift

  

import SwiftUI

import Combine

import CoreLocation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - AppModel

//======================================

  

// Purpose:

// - Central state container and coordinator for the driver assistant app.

// - Owns all @Published stored properties (Swift extensions cannot store them).

// - Delegates GPS inference to AppModel+GPS, guard coaching to AppModel+Guard,

//   and odo/load nudges to AppModel+OdoCapture.

  

// Owns:

// - All @Published stored properties across every domain.

// - App lifecycle: init, ticker, autosave setup, GPS connection.

// - Other-activity persistence (UserDefaults; pre-persistence exception).

// - Shift/session workflow reset.

  

// Notes:

// - Keep this file free of domain logic. Domain logic lives in the + files.

// - Computed properties and methods that span domains may live here if they

//   don't cleanly belong to a single extension.

//======================================

  

@MainActor

final class AppModel: ObservableObject {

    @Published var selectedTruckLabel: String = "Truck 92" // temporary Phase 1

    // later: @Published var selectedTruckID: UUID?

    // MARK: - Service Objects

    let time = TimeService()

    let saveStore = SaveStore()

    var autosave: AutoSaveController?

    private var initComplete  = false

    private var timer: Timer?

    private var tickerTask: Task<Void, Never>?

    private var gpsCancellables = Set<AnyCancellable>()

    var isGpsConnected = false

    private static let otherActivitiesKey = "OtherActivities_v1"

    // MARK: - Driver Settings (Identity / Config)

    @Published var settings: DriverSettings = DriverSettings()

    // MARK: - Banner / Global UI (stubs)

    @Published var isShowingSettingsSheet: Bool = false

    var integrityIssueCount: Int { 0 }  // later: computed from validations

    func presentIntegritySheet() { }     // later: open “Adjust / Review” sheet

    var currentSuburbForBanner: String {

        // Best available right now: last odo suburb if any

        odoLocationRecords.last?.suburb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        ? (odoLocationRecords.last?.suburb ?? "—")

        : "—"

    }

    var futureProjectionLine1: String { "—" }

    var futureProjectionLine2: String { "" }

    // MARK: - Command (global sheet routing)

    enum CommandSheet: String, Identifiable {

        case journal, truck, numbers

        var id: String { rawValue }

    }

    @Published var activeCommandSheet: CommandSheet? = nil

    func openCommand(_ sheet: CommandSheet) {

        activeCommandSheet = sheet

    }

    // MARK: - Splash

    @Published var didFinishSplash    = false

    @Published var splashSetupStarted = false

    // MARK: - Shift State

    @Published var isOnDuty:   Bool = false

    @Published var isDriving:  Bool = false

    @Published var isOnBreak:  Bool = false

    @Published var shiftStartTime:   Date?          = nil

    @Published var lastShiftSummary: ShiftSummary?  = nil

    @Published var driveSecondsToday: TimeInterval = 0

    @Published var lastTick: Date?                  = nil

    @Published var events: [ShiftEvent] = []

    @Published var sessionBaseTimeZoneID: String = TimeZone.current.identifier

    var complianceTimeZone: TimeZone {

        TimeZone(identifier: sessionBaseTimeZoneID) ?? TimeZone.current

    }

    var complianceCalendar: Calendar {

        var cal = Calendar.current

        cal.timeZone = complianceTimeZone

        return cal

    }

    // MARK: - GPS / Motion Stored State

    @Published var gpsKmSinceLastOdoBySegment: [UUID: Double] = [:]

    @Published var finalisedKmBySegment:        [UUID: Double] = [:]

    @Published var runningSegmentID:            UUID?          = nil

    @Published var lastOdoAnchorRecordID: UUID? = nil

    @Published var lastOdoAnchorKm:       Int?  = nil

    @Published var kmCorrectionFactor:    Double = 1.0

    @Published var lastOdoCaptureTime:    Date? = nil

    @Published var lastKnownCourseDegrees: Double? = nil

    @Published var lastKnownSpeedMps:      Double? = nil

    @Published var lastSpeedSampleAt:      Date?   = nil

    @Published var motionState:    MotionState    = .unsure

    @Published var showMotionDebug: Bool          = true

    var motionTunables = MotionTunables()

    var speedSamples:       [SpeedSample] = []

    let maxSpeedSamples:    Int           = 8

    var courseSamples:      [Double]      = []

    let maxCourseHistory:   Int           = 5

    var stateChangeHistory: [Date]        = []

    var stoppedAccumulatorStart: Date? = nil

    var pendingStoppedAt:        Date? = nil

    var pendingMovingAt:         Date? = nil

    var lastNudgeAt:             Date? = nil

    @Published var gpsKmPendingUntilFirstSegment: Double = 0

    @Published var gpsIngestSeq: Int = 0

    @Published var lastGpsUpdateAt:      Date?   = nil

    @Published var lastGpsAccuracyMeters: Double? = nil

    @Published var lastGpsWasStalled:    Bool     = false

    @Published var lastLmDeltaMeters:   Double  = 0

    @Published var lastLmValidSpeedMps: Double? = nil

    @Published var gpsShiftMetersLive: Double = 0

    var requestGpsKickFromUI: ((String) -> Void)? = nil

    var requestLmResetShiftMetersFromUI: ((String) -> Void)? = nil

    // GPS advisory (does NOT affect factor learning)

    let backgroundGapCoordinator = BackgroundGapCoordinator()

    @Published var lastBackgroundGapEstimate: BackgroundGapEstimate?

    @Published var backgroundGapHistory: [BackgroundGapEstimate] = []

    // MARK: - Distance Guard (internal)

    var lastDistanceIngestAt: Date? = nil

    var distanceSpikeCount: Int = 0

    @Published var liveCostPerKmText: String = "Cost/km —"

    enum BannerContext {

        case motion

        case heading

        case odo

        case cost

    }

    func bannerContext(for tab: MainTab) -> BannerContext {

        switch tab {

        case .today:

            return .motion

        case .map:

            return .heading

        case .load:

            return .odo

        case .sim:

            return .motion   // or leave as motion for now

        case .command:

            return .cost

        }

    }

    // MARK: - Motion Auto-Recovery

    @Published var lastAutoRecoverFiredAt: Date?   = nil

    @Published var lastAutoRecoverReason:  String? = nil

    @Published var motionCertaintyReasons: [String] = []

    @Published var driverProfile = DriverProfilePayloadV1()

    @Published var settingsProfile = SettingsPayloadV1()

    @Published var appConfig: AppConfigV1 = AppConfigV1()

    @Published var lastConfigLoadedAt: Date? = nil

    // MARK: - Motion Quality (internal)

    var motionQualityStrikes: Int = 0

    var motionLastQualityStrikeAt: Date? = nil

    // Backing state for the motion watchdog (not @Published — internal only).

    var lastAutoRecoverAt: Date? = nil

    var lowMotionSince:    Date? = nil

    // MARK: - Background Gap Recovery

    @Published var backgroundGapStartAt:     Date?                    = nil

    @Published var backgroundGapStartCoord:  CLLocationCoordinate2D? = nil

    @Published var backgroundGapEndAt:       Date?                    = nil

    @Published var backgroundGapEndCoord:    CLLocationCoordinate2D? = nil

    @Published var pendingGapEstimateMeters: Double?                  = nil

    @Published var pendingGapEstimateSegmentID: UUID?                 = nil

    @Published var pendingGapReason:         String?                  = nil

    @Published var pendingGapSegmentID:      UUID?                    = nil

    @Published var backgroundGapResumePending: Bool                   = false

    @Published var distanceEvents: [DistanceEvent] = []

    // MARK: - Fatigue Activity Tracking

    @Published var currentActivity:     ActivityType    = .offDuty

    @Published var currentSegmentStart: Date?           = nil

    @Published var segmentsToday:       [ActivitySegment] = []

    // MARK: - Odometer & Load Nudge State

    @Published var odoText:     String = ""

    @Published var prestartDone: Bool  = false

    @Published var odoLocationRecords:        [OdoLocationRecord] = []

    @Published var odoPromptTimestampOverride: Date?              = nil

    @Published var odoPromptContext:          OdoPromptContext?   = nil

    @Published var odoPromptOdoText:          String             = ""

    @Published var odoPromptSuburbText:       String             = ""

    @Published var pendingStartShiftCapture: Bool                = false

    @Published var pendingEndShiftCapture:   Bool                = false

    @Published var pendingActionAfterOdo:    (() -> Void)?       = nil

    @Published var showStoppedNudgeInLoad: Bool = false

    @Published var stoppedStartAt:         Date? = nil

    @Published var pendingStoppedNudge:    DispatchWorkItem? = nil

    var lastStoppedNudgeAt: Date? = nil

    var movementStartAt:    Date? = nil

    // MARK: - Guard Prompt State

    @Published var activeGuardPrompt: GuardPrompt? = nil

    @Published var isShowingIncidentSheet: Bool    = false

    @Published var incidentDraft:          IncidentReport?    = nil

    @Published var lastIncidentAdvicePlan: IncidentAdvicePlan? = nil

    // MARK: - Load Plan

    @Published var compartments:  [CompartmentModel] = []

    @Published var lazyAxleIsUp: Bool                = false

    @Published var fuelStepIndex: Int                = 6  // default = FULL

    @Published var confirmedLoads: [ConfirmedLoad]   = []

    @Published var isUnloadMode:   Bool              = false

    @Published var unloadFinalised: Bool             = false

    @Published var suppressPlacardUntilNextConfirm: Bool = false

    @Published var sgOverrides: [UUID: Double]       = [:]

    @Published var terminalName: String = "BP"

    @Published var loadCode:    String  = "6750"

    @Published var vehicleId:   String  = "277 WQH"

    @Published var selectedSupplierID: UUID? = nil

    @Published var resolvedSupplierName: String = "" 

    @Published var resolvedTerminalName: String = ""

    @Published var loadAccountCandidates: [LoadAccount] = []

  

    @Published var loadAccountResolveHint: String? = nil

    var loadCodeCanonical: String {

        loadCode.replacingOccurrences(of: " ", with: "")

    }

    // Phase 1 selection state (wire these to your Terminals screen)

    @Published var resolvedTerminalID: UUID? = nil

    @Published var resolvedLoadAccountID: UUID? = nil

    @Published var typedLoadNumber: String = ""

    @Published var loadAccountResolveError: String? = nil

    @Published var loadAccountAmbiguousMatches: [LoadAccount] = []

    var fuelStepFractions: [Double] { [0.0, 0.25, 1.0/3.0, 0.5, 2.0/3.0, 0.75, 1.0] }

    var fuelFraction: Double {

        let idx = min(max(fuelStepIndex, 0), fuelStepFractions.count - 1)

        return fuelStepFractions[idx]

    }

    var fuelStepLabel: String {

        switch fuelStepIndex {

        case 0: return "0"

        case 1: return "1/4"

        case 2: return "1/3"

        case 3: return "1/2"

        case 4: return "2/3"

        case 5: return "3/4"

        default: return "FULL"

        }

    }

    // MARK: - Templates & Simulation

    @Published var savedTemplates: [LoadTemplate] = []

    @Published var draftTemplate: LoadTemplate = LoadTemplate(

        name: "New template",

        items: [

            .init(compartmentName: "C1", productShortName: "DSL", litres: 0),

            .init(compartmentName: "C2", productShortName: "P91", litres: 0),

            .init(compartmentName: "C3", productShortName: "DSL", litres: 0),

            .init(compartmentName: "C4", productShortName: "DSL", litres: 0),

            .init(compartmentName: "C5", productShortName: "DSL", litres: 0)

        ]

    )

    let typicalLoadTemplates: [TypicalLoadTemplate] = [

        TypicalLoadTemplate(

            name: "Metro mix – ULP + Diesel",

            perCompartment: [

                "C1": ("DSL", 4500),

                "C2": ("P91", 2000),

                "C3": ("DSL", 3500),

                "C4": ("DSL", 3000),

                "C5": ("DSL", 7000)

            ]

        ),

        TypicalLoadTemplate(

            name: "All Diesel (high volume)",

            perCompartment: [

                "C1": ("DSL", 5000),

                "C2": ("DSL",    0),

                "C3": ("DSL", 4500),

                "C4": ("DSL", 3000),

                "C5": ("DSL", 7000)

            ]

        )

    ]

  

    // MARK: - Truck Config

    // Phase 1: hard-coded for Truck 92.

    // Axle split fractions are rough tuning values, not certified calculations.

    let truckConfig = TruckConfig(

        name: "Truck 92",

        tareSteerKg: 8400,

        tareDriveKg: 6200,

        runTankFullKg: 340,

        lazyLiftTransferKg: 660,

        maxSteerKg: 11000,

        maxDriveKg: 20000,

        maxGvmKg: 31000,

        axleSplitByCompartment: [

            "C1": AxleSplit(steerFraction:  0.70, driveFraction: 0.30),

            "C2": AxleSplit(steerFraction:  0.45, driveFraction: 0.55),

            "C3": AxleSplit(steerFraction:  0.15, driveFraction: 0.85),

            "C4": AxleSplit(steerFraction:  0.05, driveFraction: 0.95),

            "C5": AxleSplit(steerFraction: -0.23, driveFraction: 1.23)

        ]

    )

    // MARK: - Other Activities (UserDefaults persistence)

    // Pre-persistence exception: saved so drivers don't lose custom buttons between runs.

    @Published var otherActivities: [OtherActivity] = [

        OtherActivity(id: UUID(), name: "Training",   isWork: true),

        OtherActivity(id: UUID(), name: "Induction",  isWork: true),

        OtherActivity(id: UUID(), name: "Truck wash",  isWork: true)

    ] {

        didSet {

            guard initComplete else {

                DebugLog.lifecycle("⚠️ otherActivities didSet blocked during init")

                return

            }

            saveOtherActivities()

        }

    }

    // MARK: - AppConfig

    var gpsT: AppConfigV1.GpsTunables { appConfig.gps }

    func applyHotConfig(reason: String) {

        // MotionTunables is already used everywhere; just replace the bag.

        motionTunables = appConfig.motion

        DebugLog.autosave("🧩 Applied AppConfig (hot) reason=\(reason) savedAt=\(appConfig.savedAt)")

    }

    func reloadAppConfig(reason: String = "Manual reload") {

        if let cfg = saveStore.loadAppConfig() {

            appConfig = cfg

            applyHotConfig(reason: reason)

            DebugLog.autosave("✅ AppConfig reloaded")

        } else {

            DebugLog.autosave("⚠️ AppConfig not found at JSON/AppConfig/appconfig.json")

        }

    }

    func saveAppConfig(reason: String = "Manual save") {

        do {

            appConfig.savedAt = Date()

            try saveStore.writeAppConfig(appConfig)

            DebugLog.autosave("✅ AppConfig saved reason=\(reason)")

        } catch {

            DebugLog.autosave("❌ AppConfig save failed: \(error)")

        }

    }

    // MARK: - Init

    init() {

        guard !initComplete else {

            DebugLog.lifecycle("⚠️ AppModel init called multiple times – ignoring duplicate")

            return

        }

        DebugLog.lifecycle("🔧 AppModel init START \(Date())")

        compartments = [

            CompartmentModel(name: "C1", capacityLitres: 5360),

            CompartmentModel(name: "C2", capacityLitres: 3240),

            CompartmentModel(name: "C3", capacityLitres: 4900),

            CompartmentModel(name: "C4", capacityLitres: 3250),

            CompartmentModel(name: "C5", capacityLitres: 7240)

        ]

        loadOtherActivitiesIfAvailable()

        loadProfilesFromJSONIfAvailable()

        initComplete = true

        sessionBaseTimeZoneID = TimeZone.current.identifier

        DebugLog.lifecycle("🕒 TimeService base TZ seeded: \(sessionBaseTimeZoneID)")

        DebugLog.lifecycle("🔧 AppModel init COMPLETE \(Date())")

    }

    // MARK: - Ticker

    func startTickerIfNeeded() {

        guard tickerTask == nil else { return }

        tickerTask = Task { [weak self] in

            while !Task.isCancelled {

                try? await Task.sleep(nanoseconds: 1_000_000_000)

                await MainActor.run { self?.tick() }

            }

        }

    }

    func stopTicker() {

        tickerTask?.cancel()

        tickerTask = nil

    }

    // MARK: - Autosave

    func ensureAutosaveSetup() {

        guard autosave == nil else { return }

        autosave = AutoSaveController(model: self)

        saveStore.debugPrintSaveFolder()

        autosave?.restoreIfAvailable()

    }

    func clearAutosaveFiles() {

        autosave?.clearAutosaves()

        DebugLog.autosave("🧹 Cleared autosave files")

    }

    // MARK: - JSON Profiles (Driver + Settings)

    func loadProfilesFromJSONIfAvailable() {

        if let s = saveStore.loadSettings() {

            // map SettingsV1 -> DriverSettings

            settings.nhvrBaseName    = s.nhvrBaseName

            settings.nhvrBaseAddress = s.nhvrBaseAddress

            settings.nhvrRadiusKm    = s.nhvrRadiusKm

        }

        if let cfg = saveStore.loadAppConfig() {

            appConfig = cfg

            applyHotConfig(reason: "Init load")

        } else {

            // Optional: write defaults once so the file exists for editing

            // (comment out if you don't want the app to create files automatically)

            // try? saveStore.writeAppConfig(appConfig)

        }

        if let d = saveStore.loadDriverProfile() {

            // map DriverProfileV1 -> DriverSettings (and/or future driverProfile)

            settings.driverName = d.driverName

            // Only if these exist on DriverSettings:

            // settings.licenceType = d.licenceType.rawValue

            // settings.licenceHoursMode = d.licenceHoursMode.rawValue

            // settings.crewMode = d.crewMode.rawValue

            // settings.isOwnerDriver = d.isOwnerDriver

        }

        DebugLog.autosave("✅ Profiles loaded from JSON (if present)")

    }

    func saveProfilesToJSON() {

        do {

            try saveStore.writeSettings(settingsProfile)

            try saveStore.writeDriverProfile(driverProfile)

            DebugLog.autosave("✅ Profiles saved to JSON")

        } catch {

            DebugLog.autosave("❌ saveProfilesToJSON failed: \(error)")

        }

    }

    // MARK: - GPS Connection

    func connect(locationManager lm: LocationManager) {

        if isGpsConnected && !gpsCancellables.isEmpty { return }

        isGpsConnected = true

        startTickerIfNeeded()

        gpsCancellables.removeAll()

        // ✅ Seed LM with restored shift meters so LIVE GPS survives autosave restore

        Task { @MainActor in

            lm.setShiftMeters(self.gpsShiftMetersLive)

        }

        lm.$lastDeltaMeters

            .receive(on: DispatchQueue.main)

            .sink { [weak self] delta in

                guard let self else { return }

                self.lastLmDeltaMeters = delta

                guard delta > 0 else { return }

                self.ingestGpsDeltaMeters(delta)

            }

            .store(in: &gpsCancellables)

        Publishers.CombineLatest(lm.$rawSpeedMps, lm.$courseDegrees)

            .receive(on: DispatchQueue.main)

            .sink { [weak self] mps, course in

                guard let self else { return }

                self.lastLmValidSpeedMps = mps

                self.ingestSpeedSample(mps, course: course)

                self.considerMovementPrompt(speedMps: mps)

                self.considerStoppedNudgeInLoad(speedMps: mps)

            }

            .store(in: &gpsCancellables)

        lm.$gpsShiftMeters

            .receive(on: DispatchQueue.main)

            .sink { [weak self] meters in

                self?.gpsShiftMetersLive = meters

            }

            .store(in: &gpsCancellables)

        lm.$lastGoodLocation

            .receive(on: DispatchQueue.main)

            .sink { [weak self] loc in

                guard let self else { return }

                self.lastGpsUpdateAt       = loc?.timestamp

                self.lastGpsAccuracyMeters = loc?.horizontalAccuracy

                guard self.backgroundGapResumePending,

                      self.isOnDuty,

                      let loc else { return }

                let now = Date()

                guard now.timeIntervalSince(loc.timestamp) < 3 else { return }

                self.backgroundGapResumePending = false

                self.backgroundGapCoordinator.estimateOnForegroundReturn(

                    at: now,

                    coord: loc.coordinate

                ) { [weak self] estimate in

                    guard let self else { return }

                    guard let estimate else { return }

                    self.lastBackgroundGapEstimate = estimate

                    self.backgroundGapHistory.append(estimate)

                    DebugLog.gps("🟧 BG estimate: \(estimate.note)")

                }

            }

            .store(in: &gpsCancellables)

    }

    func disconnectLocationManager() {

        gpsCancellables.removeAll()

        isGpsConnected = false

        stopTicker()

    }

    // MARK: - Workflow Reset

    func resetTransientWorkflows() {

        odoPromptContext           = nil

        odoPromptOdoText           = ""

        odoPromptSuburbText        = ""

        pendingActionAfterOdo      = nil

        pendingStartShiftCapture   = false

        pendingEndShiftCapture     = false

        odoPromptTimestampOverride = nil

        activeGuardPrompt = nil

        movementStartAt = nil

        lastNudgeAt     = nil

        stoppedStartAt  = nil

        pendingStoppedNudge?.cancel()

        pendingStoppedNudge = nil

        gpsKmPendingUntilFirstSegment = 0

        gpsKmSinceLastOdoBySegment.removeAll()

        finalisedKmBySegment.removeAll()

        kmCorrectionFactor = 1.0

        lastOdoAnchorKm    = nil

        lastOdoCaptureTime = nil

    }

    // MARK: - Other Activity Persistence

    private func saveOtherActivities() {

        do {

            let data = try JSONEncoder().encode(otherActivities)

            UserDefaults.standard.set(data, forKey: Self.otherActivitiesKey)

        } catch {

            DebugLog.autosave("Failed to save otherActivities: \(error)")

        }

    }

    private func loadOtherActivitiesIfAvailable() {

        guard let data = UserDefaults.standard.data(forKey: Self.otherActivitiesKey) else { return }

        do {

            let decoded = try JSONDecoder().decode([OtherActivity].self, from: data)

            if !decoded.isEmpty { otherActivities = decoded }

        } catch {

            DebugLog.autosave("Failed to load otherActivities: \(error)")

        }

    }

}

```

  

---

# GPS

  

---

  

## GPS/Engine/BackgroundGapCoordinator.swift

  

```swift

import Foundation

import CoreLocation

  

//======================================

// MARK: - BackgroundGapCoordinator

//======================================

//

// Purpose:

// - Glue layer around BackgroundGapEstimator.

// - Stores a "background start anchor" (time + coord).

// - On return to foreground, produces a BackgroundGapEstimate? for UI/debug.

// - Advisory only: NEVER feeds correction factor learning.

//======================================

  

final class BackgroundGapCoordinator {

    struct Anchor: Codable {

        var at: Date

        var coord: CodableCoordinate

    }

    private let estimator: BackgroundGapEstimator

    private var anchor: Anchor?

    init(estimator: BackgroundGapEstimator = BackgroundGapEstimator()) {

        self.estimator = estimator

    }

    // MARK: - Public API

    /// Call when app is *about to* background, using your last known good GPS fix.

    func markBackgroundStart(at: Date, coord: CLLocationCoordinate2D) {

        anchor = Anchor(at: at, coord: CodableCoordinate(coord))

    }

    /// Call once you have a fresh fix after returning to foreground.

    /// Completion returns nil if it doesn't qualify (short gap / tiny displacement).

    func estimateOnForegroundReturn(

        at endAt: Date,

        coord endCoord: CLLocationCoordinate2D,

        completion: @escaping (BackgroundGapEstimate?) -> Void

    ) {

        guard let anchor else {

            completion(nil)

            return

        }

        // Clear anchor immediately so we don't double-run.

        self.anchor = nil

        estimator.estimateIfQualifies(

            startAt: anchor.at,

            startCoord: anchor.coord.cl,

            endAt: endAt,

            endCoord: endCoord,

            completion: completion

        )

    }

    /// Optional: allow caller to drop the anchor (eg. manual reset).

    func clear() {

        anchor = nil

    }

}

```

  

---

  

## GPS/Engine/BackgroundGapEstimator.swift

  

```swift

import Foundation

import CoreLocation

import MapKit

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - BackgroundGapEstimator

//======================================

//

// Purpose:

// - Estimate distance traveled during an app background gap.

// - Advisory only: NEVER feeds correction factor learning.

// - Used to populate the "amber triangle" card / suggestion UI.

//

// Inputs:

// - start/end coordinate + timestamps (captured on background/foreground transitions)

// - optional quality flags (accuracy, stale, etc) can be layered later

//

// Outputs:

// - BackgroundGapEstimate (distance, method, confidence, suggestedOdoDeltaKm)

//

// Notes:

// - If routing fails/unavailable, falls back to straight-line * multiplier.

// - Caller decides whether to apply, prompt, or ignore.

//======================================

  

enum GapEstimateMethod: String, Codable {

    case route

    case straightLineFallback

    case none

}

  

enum GapConfidence: String, Codable {

    case high

    case medium

    case low

    case none

}

  

struct BackgroundGapEstimate: Codable, Identifiable {

    let id: UUID

    let createdAt: Date

    let startAt: Date

    let endAt: Date

    let gapSeconds: TimeInterval

    let startCoord: CodableCoordinate 

    let endCoord: CodableCoordinate

    let straightLineMeters: Double

    let estimatedMeters: Double

    let method: GapEstimateMethod

    let confidence: GapConfidence

    /// Rounded km suggestion for UI (odo delta suggestion), derived from estimatedMeters.

    let suggestedOdoDeltaKm: Int

    /// Human-readable audit note for debug/log UI.

    let note: String

    init(

        id: UUID = UUID(),

        createdAt: Date = Date(),

        startAt: Date,

        endAt: Date,

        startCoord: CodableCoordinate,

        endCoord: CodableCoordinate,

        straightLineMeters: Double,

        estimatedMeters: Double,

        method: GapEstimateMethod,

        confidence: GapConfidence,

        note: String

    ) {

        self.id = id

        self.createdAt = createdAt

        self.startAt = startAt

        self.endAt = endAt

        self.gapSeconds = max(0, endAt.timeIntervalSince(startAt))

        self.startCoord = startCoord

        self.endCoord = endCoord

        self.straightLineMeters = max(0, straightLineMeters)

        self.estimatedMeters = max(0, estimatedMeters)

        self.method = method

        self.confidence = confidence

        self.suggestedOdoDeltaKm = Int((self.estimatedMeters / 1000.0).rounded())

        self.note = note

    }

}

  

final class BackgroundGapEstimator {

    struct Tunables: Codable {

        /// Only consider a "gap event" if background duration exceeds this.

        var minGapSeconds: TimeInterval = 45

        /// Only consider a "gap event" if the straight-line displacement exceeds this.

        var minStraightLineMeters: Double = 800

        /// If routing fails, multiply straight-line by this as a crude road-factor.

        var fallbackMultiplier: Double = 1.2

        /// If straight-line is huge, flag as manual review recommended.

        var manualReviewThresholdKm: Double = 50

        /// Timeout for routing attempts.

        var routeTimeoutSeconds: TimeInterval = 6

    }

    private let t: Tunables

    init(tunables: Tunables = Tunables()) {

        self.t = tunables

    }

    // MARK: - Public API

    /// Main entrypoint.

    /// Calls completion on main queue.

    func estimateIfQualifies(

        startAt: Date,

        startCoord: CLLocationCoordinate2D,

        endAt: Date,

        endCoord: CLLocationCoordinate2D,

        completion: @escaping (BackgroundGapEstimate?) -> Void

    ) {

        let gapSeconds = max(0, endAt.timeIntervalSince(startAt))

        guard gapSeconds >= t.minGapSeconds else {

            DispatchQueue.main.async { completion(nil) }

            return

        }

        let startLoc = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)

        let endLoc   = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)

        let straightLine = endLoc.distance(from: startLoc)

        guard straightLine >= t.minStraightLineMeters else {

            DispatchQueue.main.async { completion(nil) }

            return

        }

        // Try route first (preferred, when available).

        estimateByRouting(

            startCoord: startCoord,

            endCoord: endCoord,

            timeoutSeconds: t.routeTimeoutSeconds

        ) { [weak self] routeMeters in

            guard let self else {

                DispatchQueue.main.async { completion(nil) }

                return

            }

            if let routeMeters, routeMeters.isFinite, routeMeters > 0 {

                let confidence: GapConfidence = .high

                let note = self.makeNote(

                    gapSeconds: gapSeconds,

                    straightLineMeters: straightLine,

                    estimatedMeters: routeMeters,

                    method: .route

                )

                let estimate = BackgroundGapEstimate(

                    startAt: startAt,

                    endAt: endAt,

                    startCoord: CodableCoordinate(startCoord),

                    endCoord: CodableCoordinate(endCoord),

                    straightLineMeters: straightLine,

                    estimatedMeters: routeMeters,

                    method: .route,

                    confidence: confidence,

                    note: note

                )

                DispatchQueue.main.async { completion(estimate) }

            } else {

                // Fallback: straight-line × multiplier

                let est = straightLine * self.t.fallbackMultiplier

                let confidence: GapConfidence = .low

                let note = self.makeNote(

                    gapSeconds: gapSeconds,

                    straightLineMeters: straightLine,

                    estimatedMeters: est,

                    method: .straightLineFallback

                )

                let estimate = BackgroundGapEstimate(

                    startAt: startAt,

                    endAt: endAt,

                    startCoord: CodableCoordinate(startCoord),

                    endCoord: CodableCoordinate(endCoord),

                    straightLineMeters: straightLine,

                    estimatedMeters: est,

                    method: .straightLineFallback,

                    confidence: confidence,

                    note: note

                )

                DispatchQueue.main.async { completion(estimate) }

            }

        }

    }

    // MARK: - Routing

    private func estimateByRouting(

        startCoord: CLLocationCoordinate2D,

        endCoord: CLLocationCoordinate2D,

        timeoutSeconds: TimeInterval,

        completion: @escaping (Double?) -> Void

    ) {

        let req = MKDirections.Request()

        req.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoord))

        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoord))

        req.transportType = .automobile

        req.requestsAlternateRoutes = false

        let directions = MKDirections(request: req)

        var finished = false

        // Timeout guard

        let timeout = DispatchWorkItem {

            guard !finished else { return }

            finished = true

            directions.cancel()

            completion(nil)

        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)

        directions.calculate { response, error in

            guard !finished else { return }

            finished = true

            timeout.cancel()

            if let route = response?.routes.first {

                completion(route.distance)

            } else {

                completion(nil)

            }

        }

    }

    // MARK: - Note builder

    private func makeNote(

        gapSeconds: TimeInterval,

        straightLineMeters: Double,

        estimatedMeters: Double,

        method: GapEstimateMethod

    ) -> String {

        let gapMins = Int((gapSeconds / 60.0).rounded())

        let slKm = straightLineMeters / 1000.0

        let estKm = estimatedMeters / 1000.0

        let big = estKm >= t.manualReviewThresholdKm

        let review = big ? " • manual review recommended (>\(Int(t.manualReviewThresholdKm))km)" : ""

        return "gap≈\(gapMins)m • straight≈\(String(format: "%.1f", slKm))km • est≈\(String(format: "%.1f", estKm))km • method=\(method.rawValue)\(review)"

    }

}

```

  

---

  

## GPS/Engine/GPSDistanceEngine.swift

  

```swift

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

```

  

---

  

## GPS/Engine/GPSFilter.swift

  

```swift

import Foundation

import CoreLocation

  

//======================================

// MARK: - GPSFilter

//======================================

//

// Evaluates incoming GPS samples and

// determines whether they should be

// accepted for span accumulation.

//

// Responsibilities:

//

// • Reject poor accuracy samples

// • Reject stale samples

// • Reject impossible jumps

// • Produce a filtered delta distance

//

// Does NOT:

// • Accumulate span distance

// • Update correction factor

//

  

struct GPSFilter {

    //======================================

    // MARK: - Evaluation Result

    //======================================

    enum Result {

        case accept(deltaMeters: Double)

        case rejectAccuracy

        case rejectJump

        case rejectSpeed

    }

    //======================================

    // MARK: - Evaluate sample

    //======================================

    static func evaluate(

        newLocation: CLLocation,

        previousLocation: CLLocation?

    ) -> Result {

        // No previous sample → accept first fix

        guard let previous = previousLocation else {

            return .accept(deltaMeters: 0)

        }

        // Accuracy check

        if newLocation.horizontalAccuracy > GPSTuning.maxHorizontalAccuracy {

            return .rejectAccuracy

        }

        // Sample age check

        let age = Date().timeIntervalSince(newLocation.timestamp)

        if age > GPSTuning.maxSampleAge {

            return .rejectAccuracy

        }

        // Distance delta

        let distance = newLocation.distance(from: previous)

        // Jump rejection

        if distance > GPSTuning.maxDistanceJumpMeters {

            return .rejectJump

        }

        // Speed sanity check

        let time = newLocation.timestamp.timeIntervalSince(previous.timestamp)

        if time > 0 {

            let speedMps = distance / time

            let speedKph = speedMps * 3.6

            if speedKph > GPSTuning.maxSpeedJumpKph {

                return .rejectSpeed

            }

        }

        return .accept(deltaMeters: distance)

    }

}

```

  

---

  

## GPS/Engine/GPSTuning.swift

  

```swift

import Foundation

import CoreLocation

  

//======================================

// MARK: - GPSTuning

//======================================

//

// Centralised configuration for all

// GPS engine tunable parameters.

//

// These values can be surfaced in the

// DebugDashboard for live tweaking

// during real-world testing.

//

  

struct GPSTuning {

    //======================================

    // MARK: - Sample acceptance

    //======================================

    /// Maximum allowed horizontal accuracy (meters)

    static var maxHorizontalAccuracy: Double = 30

    /// Maximum age of location sample (seconds)

    static var maxSampleAge: TimeInterval = 15

    /// Maximum allowed speed spike (km/h)

    static var maxSpeedJumpKph: Double = 160

    /// Maximum allowed distance jump between samples (meters)

    static var maxDistanceJumpMeters: Double = 250

    //======================================

    // MARK: - Gap detection

    //======================================

    /// Gap threshold before counting as GPS dropout

    static var gapDetectionSeconds: TimeInterval = 15

    /// Background gap trigger time

    static var backgroundGapSeconds: TimeInterval = 45

    /// Minimum distance before background gap UI triggers (meters)

    static var backgroundGapMinDistance: Double = 800

    //======================================

    // MARK: - Correction factor

    //======================================

    /// Hard lower bound of correction factor

    static var factorMin: Double = 0.70

    /// Hard upper bound of correction factor

    static var factorMax: Double = 1.30

    //======================================

    // MARK: - Learning rates

    //======================================

    /// Aggressive learning (new truck / new driver)

    static var alphaEmbryonic: Double = 0.35

    /// Moderate learning

    static var alphaStabilising: Double = 0.18

    /// Light correction once stable

    static var alphaMature: Double = 0.06

    /// When drift increases again

    static var alphaDrifting: Double = 0.25

    //======================================

    // MARK: - Maturity thresholds

    //======================================

    /// Span closures required before leaving embryonic

    static var embryonicSpanCount: Int = 3

    /// Span closures required before reaching mature

    static var matureSpanCount: Int = 10

    /// Allowed variance before drift detection

    static var driftVarianceThreshold: Double = 0.08

}

```

  

---

  

## GPS/Engine/SpanAccumulator.swift

  

```swift

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

```

  

---

  

## GPS/Models/CodaleCoordinate.swift

  

```swift

import Foundation

import CoreLocation

  

/// CLLocationCoordinate2D is NOT Codable. This is the tiny wrapper we persist instead.

struct CodableCoordinate: Codable, Hashable {

    var latitude: Double

    var longitude: Double

    init(latitude: Double, longitude: Double) {

        self.latitude = latitude

        self.longitude = longitude

    }

    init(_ coord: CLLocationCoordinate2D) {

        self.latitude = coord.latitude

        self.longitude = coord.longitude

    }

    var cl: CLLocationCoordinate2D {

        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

    }

}

```

  

---

  

## GPS/Models/DistanceSource.swift

  

```swift

import Foundation

  

//======================================

// MARK: - DistanceSource

//======================================

//

// Identifies which GPS evidence stream

// was selected at span closure.

//

// The engine tracks both raw and filtered

// distance during an open span. When the

// driver performs an OdoCapture the engine

// evaluates which source best matches the

// odometer truth anchor.

//

// This enum records the winning source.

//

  

enum DistanceSource: String, Codable, CaseIterable {

    case raw

    case filtered

}

```

  

---

  

## GPS/Models/MaturityState.swift

  

```swift

import Foundation

  

//======================================

// MARK: - MaturityState

//======================================

//

// Represents the confidence level of the

// GPS correction factor learning system.

//

// The state influences:

//

// • how aggressively the factor updates

// • how frequently the app suggests

//   optional OdoCapture anchors

//

// States progress as the engine gathers

// more span closures with stable results.

//

  

enum MaturityState: String, Codable, CaseIterable {

    case embryonic      // new truck / driver / calibration reset

    case stabilising    // learning but starting to settle

    case mature         // very stable correction factor

    case drifting       // variance increasing again

}

```

  

---

  

## GPS/Models/SpanClosureLog.swift

  

```swift

import Foundation

  

//======================================

// MARK: - SpanClosureLog

//======================================

//

// Diagnostic record captured whenever a

// GPS span closes due to an OdoCapture.

//

// This acts as a "black box" for the

// correction-factor learning system,

// allowing inspection of:

//

// • odometer delta

// • raw vs filtered GPS evidence

// • chosen source

// • factor update behaviour

// • maturity state at time of learning

//

// These logs are extremely valuable when

// reviewing real-world runs and tuning

// GPS behaviour.

  

  

struct SpanClosureLog: Codable, Identifiable {

    // MARK: - Identity

    let id: UUID

    let timestamp: Date

    // MARK: - Odometer truth

    let odoDeltaKm: Double

    // MARK: - GPS evidence

    let gpsRawKm: Double

    let gpsFilteredKm: Double?

    let chosenSource: DistanceSource  // e.g. .raw / .filtered

    // MARK: - Factor learning

    let priorFactor: Double

    let updatedFactor: Double

    let maturityState: MaturityState

    // MARK: - Errors (absolute)

    let errorRawKm: Double

    let errorFilteredKm: Double?

    init(

        id: UUID = UUID(),

        timestamp: Date,

        odoDeltaKm: Double,

        gpsRawKm: Double,

        gpsFilteredKm: Double?,

        chosenSource: DistanceSource,

        priorFactor: Double,

        updatedFactor: Double,

        maturityState: MaturityState,

        errorRawKm: Double,

        errorFilteredKm: Double?

    ) {

        self.id = id

        self.timestamp = timestamp

        self.odoDeltaKm = odoDeltaKm

        self.gpsRawKm = gpsRawKm

        self.gpsFilteredKm = gpsFilteredKm

        self.chosenSource = chosenSource

        self.priorFactor = priorFactor

        self.updatedFactor = updatedFactor

        self.maturityState = maturityState

        self.errorRawKm = errorRawKm

        self.errorFilteredKm = errorFilteredKm

    }

}

```

  

---

# LOGIC

  

---

  

## Logic/DGPlacardLogic.swift

  

```swift

import Foundation

// © 2026 Cory Russell Olsen. All rights reserved.

// This application and its contents are proprietary and confidential.

//======================================

// MARK: - DGPlacardLogic

//======================================

//

// MARK: - DG Placard Decision (v0.2 groundwork)

//

// Intent:

// - Decide what placard the truck should display based on compartment states.

// - "0 litres" may still count as product (vapour/residue) IF prior DG history exists.

// - Absence of history is represented as `.unknown` (do not invent residue).

// - Diesel-only => Combustible Liquid (no UN 1202 shown in AU road transport practice).

// - ULP-only (91/95/98) => UN 1203 PETROL

// - Any mix of ULP + Diesel anywhere in comps (including vapour/residue) => UN 1270 PETROLEUM FUEL

// - Degassed empty => top half blank (rare event)

  

enum DGProductFamily: String, Codable, CaseIterable {

    case ulp       // petrol family: 91/95/98 etc

    case diesel    // diesel family

    case other     // future: avgas, ethanol blends, etc

}

  

/// How a compartment should be treated for DG purposes.

/// This is intentionally not "litres only".

enum DGCompartmentState: Codable, Equatable {

    /// Comp has product in it (non-zero load).

    case loaded(family: DGProductFamily, litres: Int)

    /// Comp is "0 litres" but not degassed, and the last known product matters.

    /// This is where vapour/residue counts as product for placarding.

    case residueOrVapour(family: DGProductFamily)

    /// Comp has been degassed/cleared for maintenance/repairs (true blank).

    case degassedEmpty

    /// Nothing known (avoid inventing history). Treat as unknown, not as a product.

    case unknown

}

  

/// What the app will render.

enum DGPlacardDecision: Codable, Equatable {

    case petrol1203(hazchem: String)          // PETROL / UN 1203 / 3YE

    case petroleumFuel1270(hazchem: String)   // PETROLEUM FUEL / UN 1270 / 3YE

    case combustibleLiquid                    // COMBUSTIBLE LIQUID (no UN shown)

    case blankTopHalf                         // degassed truck (all compartments degassed)

    case blankUnknown                         // unknown or insufficient evidence (render as blank, no placard)

}

  

/// The classifier. Keep pure + deterministic.

struct DGPlacardLogic {

    struct Inputs {

        var compartments: [DGCompartmentState]

        /// Default hazchem for Class 3 petrol/petroleum fuel in your fleet.

        /// Keep it injectable for future products.

        var defaultHazchem: String = "3YE"

    }

    static func decide(_ input: Inputs) -> DGPlacardDecision {

        let comps = input.compartments

        // 1) Degassed check: ONLY if *every* compartment is degassedEmpty.

        // (If any comp is not degassed, we do not show blank top.)

        if !comps.isEmpty, comps.allSatisfy({ $0 == .degassedEmpty }) {

            return .blankTopHalf

        }

        // 2) Determine if ULP and/or Diesel exist anywhere (including residue/vapour).

        var hasULP = false

        var hasDiesel = false

        for c in comps {

            switch c {

            case .loaded(let family, _),

                    .residueOrVapour(let family):

                if family == .ulp { hasULP = true }

                if family == .diesel { hasDiesel = true }

            case .degassedEmpty, .unknown:

                continue

            }

        }

        // 3) Decision rules (your Brisbane tunnel reality):

        // - Mix => 1270

        // - ULP only => 1203

        // - Diesel only => Combustible Liquid (no UN 1202 on placard for AU road transport)

        // - Nothing known => blank / unknown.

        //   We deliberately avoid inventing a DG state when history is missing or corrupted.

        if hasULP && hasDiesel {

            return .petroleumFuel1270(hazchem: input.defaultHazchem)

        } else if hasULP {

            return .petrol1203(hazchem: input.defaultHazchem)

        } else if hasDiesel {

            return .combustibleLiquid

        } else {

            return .blankUnknown

        }

    }

}

```

  

---

  

## Logic/FatigueCountdownLogic.swift

  

```swift

import Foundation

// © 2026 Cory Russell Olsen. All rights reserved.

// This application and its contents are proprietary and confidential.

//======================================

// MARK: - Fatigue Countdown Logic (Rule Picker)

//======================================

//

// Purpose:

// - Determine which rule is "on the radar" (due soonest or already breached)

// - Shared between TodayView (live) and SimulationView (what-if)

// - Single source of truth for countdown bar logic

//

// Scope (Phase 1 / Pre-persistence):

// - Today-only proxies (not true rolling 24h windows)

// - Uses work/rest totals from current session only

// - No multi-day accumulation yet

//

// Post-persistence evolution:

// - Will operate on queried windows (last 7/14/28 days)

// - True rolling 24h / 7-day / 14-day calculations

// - Same function signature, smarter inputs

//

// Design principles:

// - Deterministic (same inputs → same output)

// - Explainable (UI can show *why* a rule is next)

// - Severity-aware (countdown thresholds inform UI color/urgency)

//

//======================================

  

//======================================

// MARK: - Rule window identifiers (for UI + severity thresholds)

//======================================

  

/// Which logical window/threshold the countdown belongs to (used only for UI severity rules).

enum RuleWindow {

    case work5h15_in5h30

    case work7h30_in8h

    case work10h_in11h

    case work12h_in24h

}

  

/// How urgent the countdown is for UI treatment.

/// - `breached` means remaining < 0.

enum CountdownSeverity {

    case normal

    case caution

    case warning

    case critical

    case breached

}

  

/// Convert remaining time into a severity bucket.

/// `remaining` is seconds until due; can be negative after breach.

func countdownSeverity(

    forRemaining remaining: TimeInterval,

    window: RuleWindow

) -> CountdownSeverity {

    let mins = remaining / 60.0

    switch window {

    case .work5h15_in5h30, .work7h30_in8h, .work10h_in11h:

        if mins > 60 { return .normal }    // > 60 min

        if mins > 30 { return .caution }   // 60–30

        if mins > 15 { return .warning }   // 30–15

        if mins >= 0 { return .critical }  // 15–0

        return .breached                   // < 0

    case .work12h_in24h:

        if mins > 60 { return .normal }    // > 60 min

        if mins >= 0 { return .warning }   // 60–0

        return .breached                   // < 0

    }

}

  

//======================================

// MARK: - Output payload

//======================================

  

/// Payload describing whichever rule is currently “on the radar”.

struct CountdownRuleInfo {

    /// Stable key for UI/debug (not shown to driver).

    let key: String              // e.g. "5.25h", "7.5h", "10h", "12h"

    /// UI title line.

    let title: String            // e.g. "Next rule: 5.25h rule"

    /// Text prefix used by the UI to build the subtitle sentence.

    let descriptionPrefix: String

    /// Seconds remaining; may be negative once breached.

    let remaining: TimeInterval

    /// The limit/threshold in seconds this rule is counting toward.

    let limit: TimeInterval

    /// Which window bucket it belongs to (controls severity thresholds).

    let window: RuleWindow

}

  

//======================================

// MARK: - Rule picker used by Today (+ later Sim)

//======================================

  

/// Determine the “next” rule to show in the countdown panel.

/// Selection logic:

/// 1) If ANY rule is already breached (remaining < 0), return the one closest to zero

///    (most recently broken).

/// 2) Otherwise return the rule with the smallest positive remaining (due soonest).

func determineNextRule(

    workSinceRest: TimeInterval,

    workToday: TimeInterval,

    legalRest: TimeInterval

) -> CountdownRuleInfo {

    struct Candidate {

        let remaining: TimeInterval   // < 0 = breached, >= 0 = future

        let info: CountdownRuleInfo

    }

    // Phase 1 thresholds (seconds)

    // - 5.25h spacing threshold is based on WORK since last legal rest

    // - 7.5h / 10h thresholds are based on WORK today + required legal rest today

    // - 12h is a simple daily cap in Phase 1 (not rolling 24h)

    let workLimit_5h15 = FatigueConstants.nhvrSpacingLimit

    let workLimit_7h30 = FatigueConstants.nhvrSevenPointFiveHours

    let workLimit_10h = FatigueConstants.nhvrTenHours

    let workLimit_12h = FatigueConstants.nhvrDailyCap

    var candidates: [Candidate] = []

    // 1) 5h15 spacing rule — always track it, even when breached

    // NOTE (Phase 1 UX semantics):

    // The 5h15 spacing rule currently shows as "OK" (green) while work is below the threshold.

    // This is legally correct (not breached), but semantically premature for drivers,

    // who interpret green as "requirement satisfied" rather than "not yet due".

    // This will be reworked post-persistence to distinguish:

    //   - not yet due

    //   - approaching threshold

    //   - breached

    // without marking the rule as satisfied before a qualifying legal rest resets it.

    do {

        let remaining = workLimit_5h15 - workSinceRest

        let info = CountdownRuleInfo(

            key: "5.25h",

            title: "Next rule: 5.25h rule",

            descriptionPrefix: "If you keep working without extra legal rest, you'll hit the 5.25h rule",

            remaining: remaining,

            limit: workLimit_5h15,

            window: .work5h15_in5h30

        )

        candidates.append(Candidate(remaining: remaining, info: info))

    }

    // Helper for “daily threshold + required rest” rules (7.5h, 10h)

    func addDailyRule(

        key: String,

        title: String,

        description: String,

        limit: TimeInterval,

        requiredRest: TimeInterval,

        window: RuleWindow

    ) {

        let workOverLimit = workToday - limit

        let restShortfall = requiredRest - legalRest

        // Case A: threshold reached AND rest requirement already met → ignore

        if workToday >= limit && restShortfall <= 0 {

            return

        }

        // Case B: not yet at threshold

        if workToday < limit {

            // If you’ve already banked enough legal rest, you cannot fail this rule.

            guard restShortfall > 0 else { return }

            let remaining = limit - workToday

            let info = CountdownRuleInfo(

                key: key,

                title: title,

                descriptionPrefix: description,

                remaining: remaining,

                limit: limit,

                window: window

            )

            candidates.append(Candidate(remaining: remaining, info: info))

            return

        }

        // Case C: past threshold and still short on rest → breached

        if restShortfall > 0 {

            let remaining = -workOverLimit   // negative seconds past the threshold

            let info = CountdownRuleInfo(

                key: key,

                title: title,

                descriptionPrefix: description,

                remaining: remaining,

                limit: limit,

                window: window

            )

            candidates.append(Candidate(remaining: remaining, info: info))

        }

    }

    // 2) 7.5h rule (needs ≥ 30 min legal rest today)

    addDailyRule(

        key: "7.5h",

        title: "Next rule: 7.5h rule",

        description: "If you keep working without extra legal rest, you'll hit the 7.5h rule",

        limit: workLimit_7h30,

        requiredRest: FatigueConstants.requiredRestAt7h30,

        window: .work7h30_in8h

    )

    // 3) 10h rule (needs ≥ 60 min legal rest today)

    addDailyRule(

        key: "10h",

        title: "Next rule: 10h rule",

        description: "If you keep working without extra legal rest, you'll hit the 10h rule",

        limit: workLimit_10h,

        requiredRest: FatigueConstants.requiredRestAt10h,

        window: .work10h_in11h

    )

  

    // 4) 12h daily cap — always track it

    do {

        let remaining = workLimit_12h - workToday

        let info = CountdownRuleInfo(

            key: "12h",

            title: "Next rule: 12h daily cap",

            descriptionPrefix: "If you keep working without extra legal rest, you'll hit the 12h daily cap",

            remaining: remaining,

            limit: workLimit_12h,

            window: .work12h_in24h

        )

        candidates.append(Candidate(remaining: remaining, info: info))

    }

    // Safety fallback: should never happen, but keep UI stable.

    guard !candidates.isEmpty else {

        let remaining = workLimit_12h - workToday

        return CountdownRuleInfo(

            key: "12h",

            title: "Next rule: 12h daily cap",

            descriptionPrefix: "If you keep working without extra legal rest, you'll hit the 12h daily cap",

            remaining: remaining,

            limit: workLimit_12h,

            window: .work12h_in24h

        )

    }

    // Split into breached vs future

    let breached = candidates.filter { $0.remaining < 0 }

    let future   = candidates.filter { $0.remaining >= 0 }

    // If anything is breached, report the one closest to zero (most recently broken).

    if let mostRecentBreach = breached.sorted(by: { $0.remaining > $1.remaining }).first {

        return mostRecentBreach.info

    }

    // Otherwise, pick the one due soonest.

    let next = future.min(by: { $0.remaining < $1.remaining })!

    return next.info

}

```

  

---

  

  

## Logic/FatigueEngine.swift

  

```swift

import Foundation

  

//==================================================

// MARK: - Fatigue Scheme (Phase 1: Standard + BFM)

//==================================================

  

enum FatigueScheme: String, CaseIterable, Identifiable {

    case standardHV = "Standard (HV)"

    case bfmHV = "BFM (HV)"

    case busCoachStandard = "Bus/Coach Standard (coming)"

    case busCoachBFM = "Bus/Coach BFM (coming)"

    case afmCustom = "AFM (coming)"

    var id: String { rawValue }

    var isAvailableNow: Bool {

        switch self {

        case .standardHV, .bfmHV: return true

        default: return false

        }

    }

}

  

//==================================================

// MARK: - Timeline primitives (Journal truth shape)

//==================================================

  

enum SegmentKind: String, Codable {

    case work

    case rest

}

  

struct WorkRestSegment: Identifiable, Codable, Hashable {

    let id: UUID

    var kind: SegmentKind

    var start: Date

    var end: Date?               // nil = in-progress segment

    var stationaryRest: Bool     // required for “stationary rest” rules

    init(

        id: UUID = UUID(),

        kind: SegmentKind,

        start: Date,

        end: Date? = nil,

        stationaryRest: Bool = true

    ) {

        self.id = id

        self.kind = kind

        self.start = start

        self.end = end

        self.stationaryRest = stationaryRest

    }

    func clipped(to window: DateInterval, now: Date) -> DateInterval? {

        let effectiveEnd = end ?? now

        let seg = DateInterval(start: start, end: effectiveEnd)

        let intersection = seg.intersection(with: window)

        return intersection

    }

}

  

//==================================================

// MARK: - Fatigue Output model (What Today/Sim renders)

//==================================================

  

enum FatigueSeverity: String {

    case ok

    case warn

    case over

    case unavailable

}

  

struct FatigueMetric {

    var title: String

    var value: String

    var severity: FatigueSeverity

    var detail: String? = nil

}

  

struct FatigueStatus {

    var scheme: FatigueScheme

    var asOf: Date

    // Core rolling windows

    var work24: TimeInterval

    var rest24StationaryContinuousMax: TimeInterval

    var work7d: TimeInterval

    var work14d: TimeInterval

    // Standard/BFM structural requirements

    var has24hContinuousRestIn7d: Bool

    var nightRestCount14d: Int

    var hasConsecutiveNightRestPair14d: Bool

    // BFM extras (Phase 1: placeholders you can wire later)

    var longNightWork7d: TimeInterval?          // BFM: “long/night work” rolling 7d (cap often 36h)

    var has24hRestAfter84hWork14d: Bool?        // BFM: reset condition

    // Render-ready cards (keep UI dumb)

    var cards: [FatigueMetric]

}

  

//==================================================

// MARK: - Engine

//==================================================

  

enum FatigueEngine {

    // Public entry point

    static func evaluate(

        scheme: FatigueScheme,

        segments: [WorkRestSegment],

        now: Date,

        tz: TimeZone = .current

    ) -> FatigueStatus {

        guard scheme.isAvailableNow else {

            return FatigueStatus(

                scheme: scheme,

                asOf: now,

                work24: 0,

                rest24StationaryContinuousMax: 0,

                work7d: 0,

                work14d: 0,

                has24hContinuousRestIn7d: false,

                nightRestCount14d: 0,

                hasConsecutiveNightRestPair14d: false,

                longNightWork7d: nil,

                has24hRestAfter84hWork14d: nil,

                cards: [

                    FatigueMetric(title: scheme.rawValue, value: "Coming", severity: .unavailable, detail: "Not enabled yet.")

                ]

            )

        }

        let win24  = DateInterval(start: now.addingTimeInterval(-24*3600), end: now)

        let win7d  = DateInterval(start: now.addingTimeInterval(-7*24*3600), end: now)

        let win14d = DateInterval(start: now.addingTimeInterval(-14*24*3600), end: now)

        let work24 = sum(kind: .work, segments: segments, in: win24, now: now)

        let work7d = sum(kind: .work, segments: segments, in: win7d, now: now)

        let work14 = sum(kind: .work, segments: segments, in: win14d, now: now)

        let maxContinuousStationaryRest24 = maxContinuousStationaryRest(segments: segments, in: win24, now: now)

        let has24hContRest7d = hasContinuousStationaryRest(segments: segments, minSeconds: 24*3600, in: win7d, now: now)

        // Night rest break detection: >=7h stationary rest with overlap inside 22:00–08:00 window

        let nightLabels14 = nightRestLabels(in: win14d, segments: segments, now: now, tz: tz)

        let nightCount = nightLabels14.count

        let streak = maxConsecutiveNightStreak(nightLabels14, tz: tz)

        let hasConsecPair = streak >= 2

        // Scheme-specific limits

        let (work24Limit, minRest24, work7Limit, work14Limit) = limits(for: scheme)

        // Create render cards (dense, decision-grade)

        var cards: [FatigueMetric] = []

        // Card 1 — Rolling 24h

        cards.append(

            metricRolling24h(

                work24: work24,

                work24Limit: work24Limit,

                maxStationaryRest24: maxContinuousStationaryRest24,

                minStationaryRest24: minRest24

            )

        )

        // Card 2 — 7d totals + 24h continuous rest requirement

        cards.append(

            metricRolling7d(

                work7d: work7d,

                work7Limit: work7Limit,

                has24hContinuousRest: has24hContRest7d

            )

        )

        // Card 3 — 14d totals + night rests structure

        cards.append(

            metricRolling14d(

                work14d: work14,

                work14Limit: work14Limit,

                nightRestCount: nightCount,

                nightRestRequiredTotal: 4,

                consecutiveStreak: streak

            )

        )

        // BFM placeholders

        var longNightWork7d: TimeInterval? = nil

        var has24After84: Bool? = nil

        if scheme == .bfmHV {

            // Wire these properly later once we encode “long/night work” classification.

            // For now leave as nil so UI can show “not yet”.

            longNightWork7d = nil

            has24After84 = nil

        }

        return FatigueStatus(

            scheme: scheme,

            asOf: now,

            work24: work24,

            rest24StationaryContinuousMax: maxContinuousStationaryRest24,

            work7d: work7d,

            work14d: work14,

            has24hContinuousRestIn7d: has24hContRest7d,

            nightRestCount14d: nightCount,

            hasConsecutiveNightRestPair14d: hasConsecPair,

            longNightWork7d: longNightWork7d,

            has24hRestAfter84hWork14d: has24After84,

            cards: cards

        )

    }

    private static func maxConsecutiveNightStreak(_ labels: [Date], tz: TimeZone) -> Int {

        guard !labels.isEmpty else { return 0 }

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        let sorted = labels.sorted()

        var best = 1

        var cur = 1

        for i in 1..<sorted.count {

            let prev = sorted[i-1]

            let expected = calendar.date(byAdding: .day, value: 1, to: prev)!

            if calendar.isDate(sorted[i], inSameDayAs: expected) {

                cur += 1

                best = max(best, cur)

            } else {

                cur = 1

            }

        }

        return best

    }

    // MARK: - Limits

    private static func limits(for scheme: FatigueScheme) -> (work24: TimeInterval, minRest24: TimeInterval, work7: TimeInterval, work14: TimeInterval) {

        switch scheme {

        case .standardHV:

            return (12*3600, 7*3600, 72*3600, 144*3600)

        case .bfmHV:

            // Core caps (from your screenshots): 14h/24h and 144h/14d.

            // 7d work cap differs by scheme/table; keep 72h as “base” and rely on BFM extras later.

            return (14*3600, 7*3600, 72*3600, 144*3600)

        default:

            return (0, 0, 0, 0)

        }

    }

    // MARK: - Aggregation helpers

    private static func sum(kind: SegmentKind, segments: [WorkRestSegment], in window: DateInterval, now: Date) -> TimeInterval {

        var total: TimeInterval = 0

        for s in segments where s.kind == kind {

            if let clipped = s.clipped(to: window, now: now) {

                total += clipped.duration

            }

        }

        return total

    }

    private static func maxContinuousStationaryRest(segments: [WorkRestSegment], in window: DateInterval, now: Date) -> TimeInterval {

        // Find max continuous REST where stationaryRest == true inside window.

        // Note: assumes segments are non-overlapping and in order; if not, you can sort by start.

        let sorted = segments.sorted { $0.start < $1.start }

        var best: TimeInterval = 0

        for s in sorted where s.kind == .rest && s.stationaryRest {

            guard let clipped = s.clipped(to: window, now: now) else { continue }

            best = max(best, clipped.duration)

        }

        return best

    }

    private static func hasContinuousStationaryRest(segments: [WorkRestSegment], minSeconds: TimeInterval, in window: DateInterval, now: Date) -> Bool {

        let sorted = segments.sorted { $0.start < $1.start }

        for s in sorted where s.kind == .rest && s.stationaryRest {

            guard let clipped = s.clipped(to: window, now: now) else { continue }

            if clipped.duration >= minSeconds { return true }

        }

        return false

    }

    // MARK: - Night rest breaks (Standard/BFM 14d structure)

    /// Returns qualifying night rest breaks in a rolling window:

    /// - stationary REST

    /// - continuous >= 7h

    /// - AND overlaps a “night rest window” (22:00–08:00)

    /// NOTE: This is a conservative approximation that works well for SimView tests.

    /// Later, you can refine with exact regulatory definitions and “night label” bucketing.

    // Returns unique "night labels" (22:00 start dates) that qualify in the window.

    private static func nightRestLabels(

        in window: DateInterval,

        segments: [WorkRestSegment],

        now: Date,

        tz: TimeZone

    ) -> [Date] {

        let sorted = segments.sorted { $0.start < $1.start }

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        var labels: [Date] = []

        for s in sorted where s.kind == .rest && s.stationaryRest {

            guard let clipped = s.clipped(to: window, now: now) else { continue }

            // This keeps your "rest must be at least 7h overall" guard

            // (doesn't block long rests; just ignores short ones).

            if clipped.duration < 7 * 3600 { continue }

            labels.append(contentsOf: qualifyingNightLabels(for: clipped, tz: tz))

        }

        // De-dupe by the day of the night label.

        let unique = Set(labels.map { calendar.startOfDay(for: $0) })

        return unique.sorted()

    }

    private static func nightRestBreaks(in window: DateInterval, segments: [WorkRestSegment], now: Date, tz: TimeZone) -> [DateInterval] {

        let sorted = segments.sorted { $0.start < $1.start }

        var results: [DateInterval] = []

        for s in sorted where s.kind == .rest && s.stationaryRest {

            guard let clipped = s.clipped(to: window, now: now) else { continue }

            if clipped.duration < 7*3600 { continue }

            // Must overlap some 22:00–08:00 window.

            if qualifiesAsNightRestStrict(rest: clipped, tz: tz) {

                results.append(clipped)

            }

        }

        return results

    }

    /// Detect if there exists at least one pair of night rests on consecutive “night labels”.

    /// “Night label” here = the date of the 22:00 start that the rest overlaps.

    private static func firstNightWindowStartOverlapped(by rest: DateInterval, calendar: Calendar) -> Date? {

        let anchorDays = [

            rest.start.addingTimeInterval(-24*3600),

            rest.start,

            rest.start.addingTimeInterval(24*3600)

        ]

        var candidates: [Date] = []

        for d in anchorDays {

            let dayStart = calendar.startOfDay(for: d)

            let winStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart)!

            let winEnd = calendar.date(byAdding: .hour, value: 10, to: winStart)! // 08:00 next day

            let nightWin = DateInterval(start: winStart, end: winEnd)

            if rest.intersection(with: nightWin) != nil {

                candidates.append(winStart)

            }

        }

        return candidates.sorted().first

    }

    private static func qualifiesAsNightRestStrict(rest: DateInterval, tz: TimeZone) -> Bool {

        // Rule: a night rest break is either:

        // 1) 24h continuous stationary rest, OR

        // 2) at least 7h continuous stationary rest that occurs within a single 22:00–08:00 window.

        if rest.duration >= 24 * 3600 { return true }

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        // Check nearby night windows so we don’t miss the correct one.

        let anchorDays = [

            rest.start.addingTimeInterval(-24*3600),

            rest.start,

            rest.start.addingTimeInterval(24*3600)

        ]

        for d in anchorDays {

            let dayStart = calendar.startOfDay(for: d)

            let winStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart)!

            let winEnd   = calendar.date(byAdding: .hour, value: 10, to: winStart)! // 08:00 next day

            let nightWin = DateInterval(start: winStart, end: winEnd)

            // Strict: rest must contain >=7h that lies inside the night window

            if let intersection = rest.intersection(with: nightWin),

               intersection.duration >= 7 * 3600 {

                return true

            }

        }

        return false

    }

    private static func maxConsecutiveNightRestStreak(_ rests: [DateInterval], tz: TimeZone) -> Int {

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        // Convert each qualifying rest to a “night label” (the day of the 22:00 start it belongs to)

        var labels: Set<Date> = []

        for r in rests {

            if let label = firstNightWindowStartOverlapped(by: r, calendar: calendar) {

                labels.insert(calendar.startOfDay(for: label))

            }

        }

        let sorted = labels.sorted()

        guard !sorted.isEmpty else { return 0 }

        var best = 1

        var current = 1

        for i in 1..<sorted.count {

            let prev = sorted[i - 1]

            let cur  = sorted[i]

            if let nextDay = calendar.date(byAdding: .day, value: 1, to: prev),

               calendar.isDate(cur, inSameDayAs: nextDay) {

                current += 1

                best = max(best, current)

            } else {

                current = 1

            }

        }

        return best

    }

    // MARK: - Render Metrics

    private static func metricRolling24h(

        work24: TimeInterval,

        work24Limit: TimeInterval,

        maxStationaryRest24: TimeInterval,

        minStationaryRest24: TimeInterval

    ) -> FatigueMetric {

        let workStr = "\(fmt(work24)) / \(fmt(work24Limit))"

        let remaining = max(work24Limit - work24, 0)

        let restOk = maxStationaryRest24 >= minStationaryRest24

        let sev: FatigueSeverity

        if work24 >= work24Limit { sev = .over }

        else if work24 >= work24Limit * 0.8 { sev = .warn }

        else { sev = restOk ? .ok : .warn }

        let detail = "Remain \(fmt(remaining)) • Max stationary rest \(fmt(maxStationaryRest24))"

        return FatigueMetric(

            title: "Rolling 24h",

            value: "Work \(workStr)",

            severity: sev,

            detail: detail

        )

    }

    private static func metricRolling7d(work7d: TimeInterval, work7Limit: TimeInterval, has24hContinuousRest: Bool) -> FatigueMetric {

        let sev: FatigueSeverity

        if work7d >= work7Limit { sev = .over }

        else if work7d >= work7Limit * 0.8 { sev = .warn }

        else { sev = has24hContinuousRest ? .ok : .warn }

        let detail = has24hContinuousRest ? "24h continuous rest ✅" : "Needs 24h continuous rest ⚠️"

        return FatigueMetric(

            title: "Rolling 7d",

            value: "Work \(fmt(work7d)) / \(fmt(work7Limit))",

            severity: sev,

            detail: detail

        )

    }

    // Returns all night-window starts (labels) that this REST qualifies for.

    // Qualification: overlap with the 22:00–08:00 window is >= 7h.

    private static func qualifyingNightLabels(for rest: DateInterval, tz: TimeZone) -> [Date] {

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        // We scan a range of days that cover the rest.

        // Start 1 day before to catch windows that begin before rest.start.

        let scanStart = calendar.startOfDay(for: rest.start.addingTimeInterval(-24*3600))

        let scanEnd   = calendar.startOfDay(for: rest.end.addingTimeInterval(24*3600))

        var labels: [Date] = []

        var day = scanStart

        while day <= scanEnd {

            let winStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)!

            let winEnd   = calendar.date(byAdding: .hour, value: 10, to: winStart)! // → 08:00 next day

            let nightWin = DateInterval(start: winStart, end: winEnd)

            if let overlap = rest.intersection(with: nightWin) {

                if overlap.duration >= 7*3600 {

                    labels.append(winStart) // label is the 22:00 start for that night

                }

            }

            day = calendar.date(byAdding: .day, value: 1, to: day)!

        }

        return labels

    }

    private static func metricRolling14d(

        work14d: TimeInterval,

        work14Limit: TimeInterval,

        nightRestCount: Int,

        nightRestRequiredTotal: Int,

        consecutiveStreak: Int

    ) -> FatigueMetric {

        // Severity considers both work cap and night-rest structure.

        var sev: FatigueSeverity = .ok

        if work14d >= work14Limit { sev = .over }

        else if work14d >= work14Limit * 0.8 { sev = .warn }

        // Night rest structure is “must have 4 total, including a consecutive pair”

        let hasConsecutivePair = consecutiveStreak >= 2

        if nightRestCount < nightRestRequiredTotal || !hasConsecutivePair {

            if sev == .ok { sev = .warn }

        }

        // Night rest UI: show as "X (min 4)" once compliant, so large numbers don’t look wrong.

        let nightText: String

        if nightRestCount >= nightRestRequiredTotal {

            let surplus = nightRestCount - nightRestRequiredTotal

            nightText = "Night rests \(nightRestCount) (min \(nightRestRequiredTotal), +\(surplus))"

        } else {

            nightText = "Night rests \(nightRestCount)/\(nightRestRequiredTotal)"

        }

        // Consecutive UI: show streak number (not just a tick)

        let streakText = hasConsecutivePair ? "Streak \(consecutiveStreak) ✅" : "Streak \(consecutiveStreak) ⚠️"

        let detail = "\(nightText) • \(streakText)"

        return FatigueMetric(

            title: "Rolling 14d",

            value: "Work \(fmt(work14d)) / \(fmt(work14Limit))",

            severity: sev,

            detail: detail

        )

    }

    static func build14DaySummary(

        segments: [WorkRestSegment],

        now: Date,

        tz: TimeZone = .current

    ) -> [DailyDriverSummary] {

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        let startOfToday = calendar.startOfDay(for: now)

        let windowStart = calendar.date(byAdding: .day, value: -13, to: startOfToday)!

        // Reuse existing night label logic

        let win14 = DateInterval(start: windowStart, end: now)

        let nightLabels = nightRestLabels(in: win14, segments: segments, now: now, tz: tz)

        var days: [DailyDriverSummary] = []

        for offset in 0..<14 {

            let dayStart = calendar.date(byAdding: .day, value: offset, to: windowStart)!

            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let dayWindow = DateInterval(start: dayStart, end: dayEnd)

            var totalWork: TimeInterval = 0

            var firstStart: Date?

            var lastEnd: Date?

            for s in segments where s.kind == .work {

                guard let clipped = s.clipped(to: dayWindow, now: now) else { continue }

                totalWork += clipped.duration

                if firstStart == nil || clipped.start < firstStart! {

                    firstStart = clipped.start

                }

                if lastEnd == nil || clipped.end > lastEnd! {

                    lastEnd = clipped.end

                }

            }

            // Night rest label matches this calendar day?

            let hasNight = nightLabels.contains {

                calendar.isDate($0, inSameDayAs: dayStart)

            }

            days.append(

                DailyDriverSummary(

                    dayStart: calendar.startOfDay(for: dayStart),

                    firstWorkStart: firstStart,

                    lastWorkEnd: lastEnd,

                    totalWork: totalWork,

                    hasNightRest: hasNight

                )

            )

        }

        return days

    }

    private static func fmt(_ seconds: TimeInterval) -> String {

        let s = max(Int(seconds.rounded()), 0)

        let h = s / 3600

        let m = (s % 3600) / 60

        return "\(h)h \(m)m"

    }

}

  

struct DailyDriverSummary: Identifiable {

    let dayStart: Date   // startOfDay for that row

    var id: Date { dayStart }

    let firstWorkStart: Date?

    let lastWorkEnd: Date?

    let totalWork: TimeInterval

    let hasNightRest: Bool

    }

```

  

---

  

## Logic/FatigueRules.swift

  

```swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

// This application and its contents are proprietary and confidential.

//======================================

// MARK: - Fatigue Rule Models + Today Helpers (Phase 1)

//======================================

//

// Purpose:

// 1. Define `FatigueRuleState` (UI row model for Today fatigue section)

// 2. Provide Phase 1 helper methods on AppModel:

//    - workSecondsSinceLastLegalRest()

//    - totalLegalRestToday

//    - dailyFatigueRules() → builds rule rows for UI

//

// Important (Phase 1 scope):

// - "Today-only" proxies (not true rolling windows)

// - Legal rest = sum of >=15m blocks (today session)

// - Work since last rest = work after the most recent >=15m rest

//

// Post-persistence evolution:

// - These helpers will query SQLite for multi-day windows

// - Rolling 24h / 7-day / 14-day calculations replace today-only

// - Same function signatures, smarter implementations

//

// Separation of concerns:

// - This file: UI models + helper methods

// - FatigueCountdownLogic.swift: countdown rule picker (pure logic)

// - AppModel+RestLogic.swift: planning helpers (earliest start, etc)

//

//======================================

  

enum FatigueRuleStatus {

    case ok

    case warning

    case over

}

  

  

/// One row shown in Today → Fatigue.

/// `worked` and `limit` are in seconds (TimeInterval).

struct FatigueRuleState: Identifiable {

    let id = UUID()

    let title: String

    let detail: String

    let worked: TimeInterval

    let limit: TimeInterval

    /// Remaining time until limit (clamped at 0 for display).

    var remaining: TimeInterval {

        max(limit - worked, 0)

    }

    /// 0.0 = none used, 1.0 = at limit, >1.0 = over.

    var ratio: Double {

        guard limit > 0 else { return 0 }

        return worked / limit

    }

    /// Simple traffic-light for the progress bar.

    /// Note: "over" means you've reached/exceeded the limit (ratio >= 1.0),

    /// not that you have breached a specific NHVR offence in Phase 1.

    var status: FatigueRuleStatus {

        guard limit > 0 else { return .ok }

        let r = ratio

        if r >= 1.0 { return .over }

        if r >= 0.8 { return .warning }

        return .ok

    }

}

  

//======================================

// MARK: - APPMODEL FATIGUE HELPERS (PHASE 1)

//======================================

  

extension AppModel {

    /// Work time (WORK seconds, not clock time) since the last *legal* rest segment

    /// of at least `minBreak`.

    ///

    /// Definitions (Phase 1):

    /// - "WORK" is any `ActivityType` where `isWork == true`.

    /// - "REST" is any `ActivityType` where `isWork == false`.

    /// - A "legal rest segment" for this helper is a REST segment whose duration >= minBreak.

    ///

    /// Implementation notes:

    /// - We include the current in-progress segment (if any) by appending a synthetic segment with end=nil.

    /// - We scan for the *last* qualifying rest segment and anchor from its end time.

    /// - Then we sum WORK time after that anchor.

    ///

    /// Phase 1 limitation:

    /// - This does not do rolling-window logic; it is “today/session” based.

    func workSecondsSinceLastLegalRest(

        minBreak: TimeInterval = FatigueConstants.legalBreak15,

        now: Date? = nil

    ) -> TimeInterval {

        let now = now ?? time.now()

        // Collect all segments, including the current in-progress one.

        var allSegments = segmentsToday

        if let start = currentSegmentStart {

            let current = ActivitySegment(

                type: currentActivity,

                start: start,

                end: nil

            )

            allSegments.append(current)

        }

        guard !allSegments.isEmpty else { return 0 }

        // Sort by start time to ensure we evaluate in chronological order.

        allSegments.sort { $0.start < $1.start }

        // Find the end time of the last "legal" rest segment (REST duration >= minBreak).

        var lastLegalRestEnd: Date? = nil

        for seg in allSegments {

            let segEnd = seg.end ?? now

            guard !seg.type.isWork else { continue } // REST only

            let duration = segEnd.timeIntervalSince(seg.start)

            if duration >= minBreak {

                lastLegalRestEnd = segEnd

            }

        }

        // If we've never had a legal rest, anchor at the very first segment start.

        let anchor = lastLegalRestEnd ?? allSegments.first!.start

        // Sum all WORK time that occurs after `anchor`.

        var totalWork: TimeInterval = 0

        for seg in allSegments {

            let segEnd = seg.end ?? now

            if segEnd <= anchor { continue }          // ends before anchor

            guard seg.type.isWork else { continue }    // WORK only

            let effectiveStart = max(seg.start, anchor)

            totalWork += segEnd.timeIntervalSince(effectiveStart)

        }

        return max(totalWork, 0)

    }

    /// Total "legal" rest today (sum of REST segments that are >= 15 minutes).

    ///

    /// Purpose:

    /// - Used by Phase 1 “threshold” rows (7.5 / 10) and the countdown helper as a proxy.

    ///

    /// Phase 1 limitation:

    /// - This is not a rolling-window calculation; it is “today/session” only.

    var totalLegalRestToday: TimeInterval {

        let now = time.now()

        var total: TimeInterval = 0

        // Completed segments

        for seg in segmentsToday {

            guard !seg.type.isWork else { continue }

            let end = seg.end ?? now

            let duration = end.timeIntervalSince(seg.start)

            if duration >= FatigueConstants.legalBreak15 {

                total += duration

            }

        }

        // Current in-progress REST segment (only counts once it reaches 15 minutes)

        if let start = currentSegmentStart, !currentActivity.isWork {

            let duration = now.timeIntervalSince(start)

            if duration >= FatigueConstants.legalBreak15 {

                total += duration

            }

        }

        return max(total, 0)

    }

    /// Builds a Phase 1 list of “today” fatigue rules for the UI.

    ///

    /// IMPORTANT: Separation of concerns (Phase 1):

    /// - Company policy lives here (e.g. “5h target between preferred breaks”).

    /// - NHVR “fine-risk” rules / rolling windows are handled separately by:

    ///   - countdown logic (determineNextRule)

    ///   - TodayView threshold rows (labelled as NHVR/proxy)

    func dailyFatigueRules(now _: Date = Date()) -> [FatigueRuleState] {

        var rules: [FatigueRuleState] = []

        // 1) COMPANY POLICY (example):

        // removed for phase 1. return phase 3

        // 2–4) Phase 1 “today-only” thresholds (proxy).

        // These are UI cues that become meaningful once the work threshold is reached.

        // The actual rolling-window NHVR implementation arrives post-persistence.

        rules.append(

            FatigueRuleState(

                title: "Work today (7.5h threshold)",

                detail: "At ≥7.5h work (today proxy), aim for ≥30m legal breaks",

                worked: workSecondsToday,

                limit: FatigueConstants.nhvrSevenPointFiveHours

            )

        )

        rules.append(

            FatigueRuleState(

                title: "Work today (10h threshold)",

                detail: "At ≥10h work (today proxy), aim for ≥60m legal breaks",

                worked: workSecondsToday,

                limit: FatigueConstants.nhvrTenHours

            )

        )

        rules.append(

            FatigueRuleState(

                title: "Work today (12h cap)",

                detail: "Simple cap – 12h work max in a day (Phase 1 proxy)",

                worked: workSecondsToday,

                limit: FatigueConstants.nhvrDailyCap

            )

        )

        return rules

    }

}

```

  

---

  

## Logic/IncidentAdviceEngine.swift

  

```swift

import Foundation

  

//======================================

// MARK: - INCIDENT ADVICE ENGINE (PRE-PERSISTENCE)

//======================================

//

// Purpose:

// - Convert an IncidentReport into a calm, structured action plan.

// - Uses triage answers + app settings (phones) + known context.

//

// Scope (Phase 1):

// - Pure functions only (no UI, no alerts, no side-effects).

// - Returns an IncidentAdvicePlan: headline + ordered actions.

//

// Design principles:

// - Safety first.

// - Prefer minimal, high-value actions.

// - Don’t assume — ask (TernaryAnswer).

//

//======================================

  

  

enum IncidentAdviceEngine {

    static func buildPlan(report: IncidentReport, settings: DriverSettings) -> IncidentAdvicePlan {

        var actions: [IncidentAdviceAction] = []

        // 0) Always start with “safe stop” if not confirmed

        // If unknown, we still prompt early because driver might be mid-chaos.

        if report.isSafeStopped != .yes {

            // We don’t have a dedicated “pull over safely” action yet,

            // so we front-load 000 for emergencies and evidence steps later.

            // (UI will ask this as the first triage question.)

        }

        // 1) Determine whether this is an emergency (000)

        let emergencyBySeverity = (report.severity == .emergency)

        let emergencyByFireSpill = (report.fireOrSpill == .yes)

        let emergencyByInjury = (report.injuriesPresent == .yes)

        let shouldCall000 = emergencyBySeverity || emergencyByFireSpill || emergencyByInjury

        if shouldCall000 {

            actions.append(.call000)

        }

        // 2) Specialist advice (EIP / hazchem) when relevant:

        // - Any spill/fire OR accident with unknowns OR serious/emergency.

        let hasSpecialist = !settings.specialistAdvicePhone.trimmed().isEmpty

        let shouldCallSpecialist =

        report.fireOrSpill != .no ||

        report.severity == .serious ||

        report.severity == .emergency ||

        report.type == .spill ||

        report.type == .fire

        if shouldCallSpecialist, hasSpecialist {

            actions.append(.callSpecialistAdvice(phone: settings.specialistAdvicePhone.cleanedPhone()))

        }

        // 3) Supervisor is useful for basically everything except “info-only near miss”

        let hasSupervisor = !settings.supervisorPhone.trimmed().isEmpty

        let shouldCallSupervisor =

        report.severity != .informationOnly ||

        report.type != .nearMiss

        if shouldCallSupervisor, hasSupervisor {

            actions.append(.callSupervisor(phone: settings.supervisorPhone.cleanedPhone()))

        }

        // 4) Mechanic mainly for breakdowns / non-drivable vehicle (or serious accident)

        let hasMechanic = !settings.mechanicPhone.trimmed().isEmpty

        let shouldCallMechanic =

        report.type == .breakdown ||

        report.severity == .serious ||

        report.severity == .emergency

        if shouldCallMechanic, hasMechanic {

            actions.append(.callMechanic(phone: settings.mechanicPhone.cleanedPhone()))

        }

        // 5) Hit & run / non-urgent police reporting

        // If it’s NOT an emergency call, and hit&run is yes → Policelink advice

        if !shouldCall000, report.hitAndRun == .yes {

            actions.append(.reportToPolicelink)

        }

        // 6) Evidence + note (only if safe stopped is yes OR unknown)

        // If they said "no" (not safely stopped), UI should push "stop safely" first.

        if report.isSafeStopped != .no {

            // Suggest photos if they haven't already taken enough.

            if report.photosTakenCount < 4 {

                actions.append(.takePhotos(count: 4))

            }

            if (report.shortNote?.trimmed().isEmpty ?? true) {

                actions.append(.writeShortNote)

            }

            // Camera prompt is handled in UI later; for now we nudge rest/hydration always.

            actions.append(.hydrateAndRest)

        }

        // Headline

        let headline = headlineFor(report: report, shouldCall000: shouldCall000)

        // De-dupe while preserving order (important for repeated rules)

        actions = actions.uniquedById()

        return IncidentAdvicePlan(headline: headline, actions: actions)

    }

    private static func headlineFor(report: IncidentReport, shouldCall000: Bool) -> String {

        if shouldCall000 {

            return "Emergency actions first"

        }

        switch report.type {

        case .accident:  return "Accident — stay calm, capture details"

        case .breakdown: return "Breakdown — secure the scene, get help moving"

        case .nearMiss:  return "Near miss — quick record while it’s fresh"

        case .spill:     return "Spill — treat as hazchem until confirmed safe"

        case .fire:      return "Fire — treat as emergency risk"

        case .medical:   return "Medical — safety and support first"

        }

    }

}

  

// MARK: - Small helpers (local to this file)

  

private extension String {

    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Keep digits and a leading + only (good enough for Phase 1)

    func cleanedPhone() -> String {

        let t = trimmed()

        guard !t.isEmpty else { return "" }

        var out = ""

        for (i, ch) in t.enumerated() {

            if ch.isNumber { out.append(ch) }

            else if ch == "+", i == 0 { out.append(ch) }

        }

        return out

    }

}

  

private extension Array where Element == IncidentAdviceAction {

    func uniquedById() -> [IncidentAdviceAction] {

        var seen = Set<String>()

        var out: [IncidentAdviceAction] = []

        for a in self {

            if seen.contains(a.id) { continue }

            seen.insert(a.id)

            out.append(a)

        }

        return out

    }

}

```

  

---

  

## Logic/MassSimulationLogic.swift

  

```swift

import Foundation

  

//======================================

// MARK: - Mass Simulation (draft / what-if)

//======================================

//

// Intent (Phase 1 / pre-persistence):

// - Run a deterministic "what-if" mass + axle load estimate for a LoadTemplate.

// - Uses SG override per template item if provided, otherwise product.defaultSg.

// - Starts from truck tare weights, then adds each compartment's mass via axle split.

// - Ignores template lines with unknown products (fails safe).

//

// Notes for reviewers:

// - This is a PURE calculation (no AppModel state, no side effects).

// - Axle split fractions may be negative or > 1.0 (rear-heavy comps can unload steer).

// - Litres are clamped at >= 0 (negative inputs are treated as 0).

  

enum MassSimulationLogic {

    static func simulate(

        template: LoadTemplate,

        products: [Product],

        truck: TruckConfig

    ) -> MassSimulationResult {

        // Local lookup helper (case-insensitive short name).

        func product(for short: String) -> Product? {

            products.first { $0.shortName.uppercased() == short.uppercased() }

        }

        var totalLitres = 0

        var totalMass: Double = 0

        // Start with tare (empty truck).

        var steer = truck.tareSteerKg

        var drive = truck.tareDriveKg

        // Apply each template item as a draft load.

        for item in template.items {

            guard let prod = product(for: item.productShortName) else { continue }

            let litres = max(item.litres, 0)

            let sg = item.sgOverride ?? prod.defaultSg

            let mass = Double(litres) * sg

            totalLitres += litres

            totalMass += mass

            // If we have a known axle split for this compartment, apply it.

            if let split = truck.axleSplitByCompartment[item.compartmentName] {

                steer += mass * split.steerFraction

                drive += mass * split.driveFraction

            }

        }

        let gvm = steer + drive

        // Human-readable over-limit message (nil if within limits).

        let warning: String? = {

            var msgs: [String] = []

            if steer > truck.maxSteerKg {

                msgs.append("Steer axle is OVER by \(Int(steer - truck.maxSteerKg)) kg")

            }

            if drive > truck.maxDriveKg {

                msgs.append("Drive axle is OVER by \(Int(drive - truck.maxDriveKg)) kg")

            }

            if gvm > truck.maxGvmKg {

                msgs.append("GVM is OVER by \(Int(gvm - truck.maxGvmKg)) kg")

            }

            return msgs.isEmpty ? nil : msgs.joined(separator: " • ")

        }()

        return MassSimulationResult(

            totalLitres: totalLitres,

            totalMassKg: totalMass,

            steerKg: steer,

            driveKg: drive,

            gvmKg: gvm,

            maxSteerKg: truck.maxSteerKg,

            maxDriveKg: truck.maxDriveKg,

            maxGvmKg: truck.maxGvmKg,

            steerHeadroom: truck.maxSteerKg - steer,

            driveHeadroom: truck.maxDriveKg - drive,

            gvmHeadroom: truck.maxGvmKg - gvm,

            warning: warning

        )

    }

}

```

  

---

  

## Logic/TelemetryPolicy.swift

  

```swift

import Foundation

import CoreLocation

  

//======================================

// MARK: - Telemetry Policy (v0.2)

//======================================

//

// Single source of truth for telemetry policy + constants.

// This file intentionally contains:

// - thresholds (time/distance/heading/speed)

// - retention horizons

// - UI lockout rules (policy only)

// - suggestion thresholds (arrival radius etc)

//

// This file intentionally does NOT contain:

// - persistence implementation (CoreData/SwiftData)

// - business rules (shift logic, fatigue, DG etc)

// - location manager wiring

//

// NOTE: Some policy items are declared for Phase 2+ but are not yet enforced

// by the helper functions at the bottom of this file (explicitly tagged below).

//======================================

  

struct TelemetryPolicy {

    //==================================

    // MARK: - Capture Modes

    //==================================

    enum CaptureMode: String, CaseIterable, Codable {

        case off

        case minimal

        case standard

        case diagnostic

    }

    /// Default for new installs (conservative: fewer breadcrumbs).

    static let defaultMode: CaptureMode = .minimal

    //==================================

    // MARK: - Speed Thresholds

    //==================================

    /// Above this speed, UI safety lockout may apply (ENFORCED by `shouldLockoutUI`).

    static let drivingSpeedKPH: Double = 20        // TODO: calibrate

    /// Considered stationary below this speed (DECLARED ONLY; not enforced here yet).

    static let stationarySpeedKPH: Double = 2      // TODO: calibrate

    //==================================

    // MARK: - Time Triggers

    //==================================

    /// Minimum seconds between breadcrumb captures (ENFORCED by `shouldCapture`).

    static func minTimeInterval(for mode: CaptureMode) -> TimeInterval {

        switch mode {

        case .off:        return .infinity

        case .minimal:    return 300      // 5 min (TODO: calibrate)

        case .standard:   return 60       // 1 min (TODO: calibrate)

        case .diagnostic: return 10       // TODO: calibrate

        }

    }

    /// Stationary dwell before logging a stop (DECLARED ONLY; not enforced here yet).

    static let stopDwellSeconds: TimeInterval = 180   // 3 min (TODO: calibrate)

    //==================================

    // MARK: - Distance Triggers

    //==================================

    /// Minimum distance moved before capture (ENFORCED by `shouldCapture`).

    static func minDistanceMeters(for mode: CaptureMode) -> CLLocationDistance {

        switch mode {

        case .off:        return .infinity

        case .minimal:    return 500      // TODO: calibrate

        case .standard:   return 100      // TODO: calibrate

        case .diagnostic: return 20       // TODO: calibrate

        }

    }

    //==================================

    // MARK: - Heading Triggers

    //==================================

    /// Heading change required to force a capture (DECLARED ONLY; not enforced here yet).

    static func headingDeltaDegrees(for mode: CaptureMode) -> Double {

        switch mode {

        case .off:        return .infinity

        case .minimal:    return 60        // TODO: calibrate

        case .standard:   return 45        // TODO: calibrate

        case .diagnostic: return 15        // TODO: calibrate

        }

    }

    //==================================

    // MARK: - Retention Windows

    //==================================

    // DECLARED ONLY: retention is enforced by persistence layer (Phase 2+).

    static let hotRetentionHours: Int = 24     // raw points

    static let warmRetentionDays: Int = 14     // simplified path

    static let coldRetentionDays: Int = 120    // compressed/purged horizon

    //==================================

    // MARK: - UI Safety Lockout

    //==================================

    /// Whether speed-based UI lockout is allowed at all (ENFORCED by `shouldLockoutUI`).

    static let lockoutAvailable: Bool = true

    /// Policy toggle: restrict critical actions while moving (ENFORCED by caller, not here).

    static let lockoutAppliesToCriticalActions = true

    /// Always-allowed actions (even while moving). Caller decides how to apply.

    static let alwaysAllowedActions: [ActionKind] = [

        .undo,

        .startBreak,

        .openSettings

    ]

    //==================================

    // MARK: - Telemetry → Suggestion Rules

    //==================================

    // DECLARED ONLY: suggestion engine comes later (Phase 2+).

    static let arrivalRadiusMeters: CLLocationDistance = 150   // TODO: calibrate

    static let arrivalMaxSpeedKPH: Double = 15                  // TODO: calibrate

    //==================================

    // MARK: - Breadcrumb Thinning

    //==================================

    // DECLARED ONLY: replay/thinning comes later (Phase 2+).

    static let playbackSpeedMultiplier: Double = 10.0

    static let replaySpacingSeconds: TimeInterval = 30         // TODO: calibrate

}

  

//======================================

// MARK: - Telemetry Data Model (Minimal)

//======================================

//

// Minimal breadcrumb representation, suitable for persistence later.

// Intentionally stores derived scalar fields (speed/heading/accuracy) so the

// replay/analysis layer doesn't depend on CLLocation serialization.

//

  

struct TelemetryPoint: Identifiable, Codable {

    let id: UUID

    let timestamp: Date

    let latitude: Double

    let longitude: Double

    let speedKPH: Double?

    let headingDegrees: Double?

    let horizontalAccuracy: Double?

    let captureMode: TelemetryPolicy.CaptureMode

    let source: Source

    enum Source: String, Codable {

        case gps

        case derived

    }

}

  

//======================================

// MARK: - Telemetry Evaluation Helpers (Phase 1)

//======================================

//

// These helpers enforce ONLY the Phase 1 rules currently wired:

// - speed lockout threshold

// - min time + min distance capture triggers

//

// Heading trigger + dwell logic are intentionally not implemented yet.

//

  

extension TelemetryPolicy {

    /// Determines whether UI lockout should apply (speed threshold only).

    static func shouldLockoutUI(

        speedKPH: Double,

        modeEnabled: Bool

    ) -> Bool {

        guard lockoutAvailable, modeEnabled else { return false }

        return speedKPH >= drivingSpeedKPH

    }

    /// Determines whether a breadcrumb capture should occur (time OR distance).

    static func shouldCapture(

        lastPoint: TelemetryPoint?,

        newLocation: CLLocation,

        mode: CaptureMode

    ) -> Bool {

        guard mode != .off else { return false }

        if let last = lastPoint {

            let timeDelta = newLocation.timestamp.timeIntervalSince(last.timestamp)

            if timeDelta >= minTimeInterval(for: mode) {

                return true

            }

            let distance = newLocation.distance(

                from: CLLocation(latitude: last.latitude, longitude: last.longitude)

            )

            if distance >= minDistanceMeters(for: mode) {

                return true

            }

            // Phase 2+ idea (not implemented):

            // - compare heading delta against headingDeltaDegrees(for: mode)

            // - force capture if the route changes meaningfully

        }

        // First point in a session should usually be captured by the caller

        // (or handled here later if needed).

        return false

    }

}

  

//======================================

// MARK: - Action Kind (for lockout policy)

//======================================

  

enum ActionKind {

    case startShift

    case endShift

    case confirmLoad

    case confirmUnload

    case editTimeline

    case undo

    case startBreak

    case openSettings

}

```

  

---

  

# MODELS

  

---

  

## Models/Assets/Terminals/AccessCredentials.swift

  

```swift

//

//  AccessCredential.swift

//  DriverAssistant

//

//  Asset model (Phase 1):

//  - Represents “load numbers / PINs” a driver can use at a terminal.

//  - Supports multiple suppliers per terminal.

//  - Supports nominal vs cartage roles.

//  - No JSON persistence assumed yet (iPad-safe).

//

  

import Foundation

  

// MARK: - AccessRole

  

enum AccessRole: String, Codable, CaseIterable {

    case nominal      // carrier house fuel

    case cartage      // supplier/customer fuel

}

  

// MARK: - AccessCredential

  

struct AccessCredential: Codable, Identifiable, Hashable {

    let id: UUID

    /// Linkages (by ID) so we don’t need heavy objects here.

    var terminalID: UUID

    var supplierID: UUID

    /// Nominal vs cartage

    var role: AccessRole

    /// The PIN / load number the driver enters/uses.

    var code: String

    /// Some codes rotate/change.

    var isRotating: Bool

    /// Optional: when you last verified it still works.

    var lastVerifiedAt: Date?

    /// Cartage-only (optional). Keep it lightweight until Customers exist.

    var customerLabel: String?

    /// Free-text notes (e.g. “United jumps terminals”, quirks, etc.)

    var notes: String?

    init(

        id: UUID = UUID(),

        terminalID: UUID,

        supplierID: UUID,

        role: AccessRole,

        code: String,

        isRotating: Bool = false,

        lastVerifiedAt: Date? = nil,

        customerLabel: String? = nil,

        notes: String? = nil

    ) {

        self.id = id

        self.terminalID = terminalID

        self.supplierID = supplierID

        self.role = role

        self.code = code

        self.isRotating = isRotating

        self.lastVerifiedAt = lastVerifiedAt

        self.customerLabel = customerLabel

        self.notes = notes

    }

}

```

  

---

  

## Models/Assets/FuelProducts.swift

  

```swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - FuelProducts

//======================================

  

enum FuelProducts {

    // Petrol (UN 1203, Hazchem 3YE)

    static let p91 = Product(

        code: "P91",

        name: "ULP 91",

        unNumber: 1203,

        hazchemCode: "3YE",

        sgMinValue: 0.710,

        sgMaxValue: 0.750,

        defaultSgValue: 0.724

    )

    static let p95 = Product(

        code: "P95",

        name: "ULP 95",

        unNumber: 1203,

        hazchemCode: "3YE",

        sgMinValue: 0.710,

        sgMaxValue: 0.750,

        defaultSgValue: 0.724

    )

    static let p98 = Product(

        code: "P98",

        name: "ULP 98",

        unNumber: 1203,

        hazchemCode: "3YE",

        sgMinValue: 0.710,

        sgMaxValue: 0.750,

        defaultSgValue: 0.724

    )

    static let e10 = Product(

        code: "E10",

        name: "E10",

        unNumber: 1203,

        hazchemCode: "3YE",

        sgMinValue: 0.710,

        sgMaxValue: 0.750,

        defaultSgValue: 0.724

    )

    // Diesel (treat as combustible/non-placarded for Phase 1)

    static let diesel = Product(

        code: "DSL",

        name: "Diesel",

        unNumber: nil,

        hazchemCode: "— —",

        sgMinValue: 0.810,

        sgMaxValue: 0.855,

        defaultSgValue: 0.835

    )

    static let b100 = Product(

        code: "B100",

        name: "Biodiesel B100",

        unNumber: nil,

        hazchemCode: "— —",

        sgMinValue: 0.860,

        sgMaxValue: 0.900,

        defaultSgValue: 0.880

    )

    static var all: [Product] {

        [p91, p95, p98, e10, diesel, b100]

    }

}

```

  

---

  

## Models/Assets/LoadAccount.swift

  

```swift

// File: Models/Assets/LoadAccount.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - LoadAccount (Commercial reference)

//======================================

//

// Purpose:

// - Represents a terminal/supplier “load number” you can select at load time.

// - This is NOT a security credential (not a PIN).

// - It’s an account/authorisation reference used for billing / allocation.

//

// Key UX goal:

// - Driver types/selects: (Terminal + LoadNumber)

// - App resolves: Supplier + BillingRole + Products allowed + notes.

//======================================

  

struct LoadAccount: Codable, Identifiable, Hashable {

    let id: UUID

    /// The number you type at the gantry / kiosk.

    /// Stored as String to preserve leading zeros and formatting.

    var loadNumber: String

    /// Human label (eg "United - Nominal", "United - Cartage", "BP - Backup").

    var label: String

    /// Nominal vs Cartage (your real-world split).

    var billingRole: BillingRole

    /// The supplier “brand bucket” this number belongs to.

    var supplierID: UUID

    /// Where it works (some numbers only exist at certain terminals).

    var terminalID: UUID?

    /// Optional: which products this load account can access at that terminal.

    /// If empty, treat as “unknown / assume terminal decides”.

    var allowedProductCodes: [String]   // e.g. ["P91","P95","P98","DSL","B100"]

    /// Some numbers stay stable, some rotate/change.

    var stability: AccountStability

    var orderKind: LoadOrderKind = .openOrder

    var notes: String?

    init(

        id: UUID = UUID(),

        loadNumber: String,

        label: String,

        billingRole: BillingRole,

        supplierID: UUID,

        terminalID: UUID? = nil,

        allowedProductCodes: [String] = [],

        stability: AccountStability = .staticNumber,

        orderKind: LoadOrderKind = .openOrder,

        notes: String? = nil

    ) {

        self.id = id

        self.loadNumber = loadNumber

        self.label = label

        self.billingRole = billingRole

        self.supplierID = supplierID

        self.terminalID = terminalID

        self.allowedProductCodes = allowedProductCodes

        self.stability = stability

        self.orderKind = orderKind

        self.notes = notes

    }

}

  

enum BillingRole: String, Codable, CaseIterable {

    case nominal

    case cartage

    case other

}

  

enum AccountStability: String, Codable, CaseIterable {

    case staticNumber

    case rotates

}

  

enum LoadOrderKind: String, Codable, CaseIterable {

    case openOrder   // static, driver-typable

    case rackOrder   // created by schedulers, driver recalls a specific order

}

  

extension LoadAccount {

    var normalizedLoadNumber: String {

        loadNumber.filter { $0.isNumber }

    }

}

```

  

---

  

## Models/Assets/LoadAccountRegistry.swift

  

```swift

// File: Models/Assets/LoadAccountRegistry.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - LoadAccountRegistry

//======================================

//

// Phase 0/1 seed list.

// Replace with JSON later (same shape).

//======================================

  

enum LoadAccountRegistry {

    static let bpNominal_whinstanes = LoadAccount(

        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,

        loadNumber: "6750",

        label: "BP Nominal",

        billingRole: .nominal,

        supplierID: SupplierRegistry.bp.id,

        terminalID: TerminalRegistry.atomWhinstanes.id,

        orderKind: .openOrder

    )

    static let unitedNominal_whinstanes = LoadAccount(

        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,

        loadNumber: "9014",

        label: "United Nominal",

        billingRole: .nominal,

        supplierID: SupplierRegistry.united.id,

        terminalID: TerminalRegistry.atomWhinstanes.id

    )

    static let unitedCartage_whinstanes = LoadAccount(

        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,

        loadNumber: "9023",

        label: "United Cartage",

        billingRole: .cartage,

        supplierID: SupplierRegistry.united.id,

        terminalID: TerminalRegistry.atomWhinstanes.id

    )

    static let chevronNominal_chevron = LoadAccount(

        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,

        loadNumber: "130647",

        label: "Chevron Nominal",

        billingRole: .nominal,

        supplierID: SupplierRegistry.chevron.id,

        terminalID: TerminalRegistry.chevron.id

    )

    static let unitedNominal_chevron = LoadAccount(

        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,

        loadNumber: "13105 1",

        label: "United Nominal (Chevron)",

        billingRole: .nominal,

        supplierID: SupplierRegistry.united.id,

        terminalID: TerminalRegistry.chevron.id

    )

    static let unitedCartage_chevron = LoadAccount(

        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,

        loadNumber: "13103 1",

        label: "United Cartage (Chevron)",

        billingRole: .cartage,

        supplierID: SupplierRegistry.united.id,

        terminalID: TerminalRegistry.chevron.id

    )

    static let ior_ior = LoadAccount(

        id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,

        loadNumber: "530589",

        label: "iOR",

        billingRole: .nominal,

        supplierID: SupplierRegistry.ior.id,

        terminalID: TerminalRegistry.ior.id

    )

    static let all: [LoadAccount] = [

        bpNominal_whinstanes,

        unitedNominal_whinstanes,

        unitedCartage_whinstanes,

        chevronNominal_chevron,

        unitedNominal_chevron,

        unitedCartage_chevron,

        ior_ior

    ]

}

```

  

---

  

## Models/Assets/LoadAccountResolver.swift

  

```swift

// File: Models/Assets/LoadAccountResolver.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - LoadAccountResolver

//======================================

//

// Purpose:

// - Given (terminalID + typed loadNumber), resolve the best matching LoadAccount.

// - Normalizes user input (keeps digits only).

// - Prefers terminal-specific matches over “any terminal” matches.

// - Pure logic: no JSON required yet.

//======================================

  

struct LoadAccountResolver {

    enum ResolveError: Error, CustomStringConvertible {

        case emptyInput

        case noMatch

        case ambiguous([LoadAccount])

        var description: String {

            switch self {

            case .emptyInput: return "Empty load number"

            case .noMatch: return "No matching load account"

            case .ambiguous(let matches): return "Ambiguous: \(matches.count) matches"

            }

        }

    }

    /// Main entrypoint.

    /// - Parameters:

    ///   - terminalID: The terminal you’re at (or the one selected in UI).

    ///   - typed: What the driver typed (can include spaces, commas, etc).

    ///   - accounts: Your known LoadAccounts (Phase 1: in-memory).

    /// - Returns: A single best match, or throws if none/ambiguous.

    static func resolve(

        terminalID: UUID?,

        typed: String,

        accounts: [LoadAccount]

    ) throws -> LoadAccount {

        let normalized = normalize(typed)

        guard !normalized.isEmpty else { throw ResolveError.emptyInput }

        // 1) Exact matches on number (normalized)

        let numberMatches = accounts.filter { $0.normalizedLoadNumber == normalized }

        guard !numberMatches.isEmpty else { throw ResolveError.noMatch }

        // 2) If terminal is known, prefer exact terminal match.

        if let tid = terminalID {

            let terminalExact = numberMatches.filter { $0.terminalID == tid }

            if terminalExact.count == 1 { return terminalExact[0] }

            if terminalExact.count > 1 {

                // still ambiguous: eg same number used for nominal+cartage

                throw ResolveError.ambiguous(terminalExact)

            }

            // 3) Otherwise allow “terminal-agnostic” accounts (terminalID == nil)

            let terminalAgnostic = numberMatches.filter { $0.terminalID == nil }

            if terminalAgnostic.count == 1 { return terminalAgnostic[0] }

            if terminalAgnostic.count > 1 { throw ResolveError.ambiguous(terminalAgnostic) }

            // 4) Fallback: if all matches are for *other* terminals, treat as no match

            throw ResolveError.noMatch

        }

        // No terminal known → only safe if single match

        if numberMatches.count == 1, let only = numberMatches.first { return only }

        throw ResolveError.ambiguous(numberMatches)

    }

    /// Digits only. (“12 34-56” -> “123456”)

    static func normalize(_ s: String) -> String {

        s.filter { $0.isNumber }

    }

}

```

  

---

  

## Models/Assets/Product.swift

  

```swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - Product (Unified)

//======================================

//

// Goal:

// - One Product model across disciplines.

// - Fuel fields supported (UN / Hazchem / SG range).

// - Other disciplines can ignore fuel fields safely.

// - Persist `code` as the stable foreign key.

// - `id` is runtime-only (do NOT persist across runs later).

//

// Back-compat:

// - Provides `shortName`, `defaultSg`, `sgMin`, `sgMax`, `un`, `hazchem`

//   so existing code keeps compiling.

//

//======================================

  

struct Product: Codable, Identifiable, Hashable {

    let id: UUID

    // Stable foreign key (persist this)

    var code: String          // e.g. "P91", "DSL"

    var name: String          // e.g. "ULP 91", "Diesel"

    // Optional general fields (multi-discipline friendly)

    var description: String? = nil

    var densityKgPerLitre: Double? = nil

    var dgClass: String? = nil

    // ==============================

    // Fuel / DG fields (optional)

    // ==============================

    /// UN number (fuel: e.g. 1203 for petrol). nil if unknown / not relevant.

    var unNumber: Int? = nil

    /// Hazchem (fuel: e.g. "3YE"). nil if unknown / not relevant.

    var hazchemCode: String? = nil

    /// Specific gravity range + default. nil if unknown / not relevant.

    var sgMinValue: Double? = nil

    var sgMaxValue: Double? = nil

    var defaultSgValue: Double? = nil

    init(

        id: UUID = UUID(),

        code: String,

        name: String,

        description: String? = nil,

        densityKgPerLitre: Double? = nil,

        dgClass: String? = nil,

        unNumber: Int? = nil,

        hazchemCode: String? = nil,

        sgMinValue: Double? = nil,

        sgMaxValue: Double? = nil,

        defaultSgValue: Double? = nil

    ) {

        self.id = id

        self.code = code

        self.name = name

        self.description = description

        self.densityKgPerLitre = densityKgPerLitre

        self.dgClass = dgClass

        self.unNumber = unNumber

        self.hazchemCode = hazchemCode

        self.sgMinValue = sgMinValue

        self.sgMaxValue = sgMaxValue

        self.defaultSgValue = defaultSgValue

    }

}

  

//======================================

// MARK: - Back-compat shims

//======================================

//

// These keep your existing app compiling while you migrate views/logic.

// Eventually you can delete these and update call sites to use the new names.

//======================================

  

extension Product {

    /// Old name used by LoadPlan UI etc.

    var shortName: String { code }

    /// Old names used by SG sliders / mass sim

    var sgMin: Double { sgMinValue ?? 0.0 }

    var sgMax: Double { sgMaxValue ?? 1.0 }

    var defaultSg: Double { defaultSgValue ?? (densityKgPerLitre ?? 0.0) } // fallback if you ever set density

    /// Old names used by DG logic

    var un: Int { unNumber ?? 0 }

    var hazchem: String { hazchemCode ?? "— —" }

    /// Convenience: do we have a real SG range?

    var hasSgRange: Bool {

        guard let a = sgMinValue, let b = sgMaxValue else { return false }

        return a > 0 && b > 0 && a <= b

    }

}

```

  

---

  

## Models/Assets/ProductsRegistry.swift

  

```swift

// File: Models/Assets/ProductRegistry.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - ProductRegistry

//======================================

//

// Purpose:

// - Aggregates products across multiple disciplines.

// - Provides:

//     • stable canonical list (for pickers)

//     • lookups by code/name

//

// Notes:

// - Phase 0/1: in-memory lists.

// - Phase 2+: swap in JSON-backed packs, but keep this API.

//======================================

  

enum ProductRegistry {

    /// All known products across all disciplines (merged).

    static var all: [Product] {

        FuelProducts.all

        // + RefrigeratedProducts.all

        // + LivestockProducts.all

        // + ContainersProducts.all

    }

    /// Convenience: by code (case-insensitive).

    static func byCode(_ code: String) -> Product? {

        let needle = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        return all.first { $0.code.uppercased() == needle }

    }

    /// Convenience: by name (loose match).

    static func byName(_ name: String) -> Product? {

        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return all.first { $0.name.lowercased() == needle }

    }

}

```

  

---

  

## Models/Assets/Supplier.swift

  

```swift

// File: Models/Assets/Supplier.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

  

struct Supplier: Identifiable, Codable, Hashable {

    let id: UUID

    var name: String

    init(id: UUID = UUID(), name: String) {

        self.id = id

        self.name = name

    }

}

```

  

---

  

## Models/Assets/SupplierRegistry.swift

  

```swift

// File: Models/Assets/SupplierRegistry.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

  

enum SupplierRegistry {

    static let bp = Supplier(

        id: UUID(uuidString: "2C9F7D27-3F80-4A0D-9E1D-2B7B4EAFB0A1")!,

        name: "BP"

    )

    static let mobil = Supplier(

        id: UUID(uuidString: "A6D8D8A0-2A7B-4F9E-9C64-65D83B5A8A11")!,

        name: "Mobil"

    )

    static let united = Supplier(

        id: UUID(uuidString: "4B9F4C6D-8F63-4F2E-8A0C-8B6C44D2A2D0")!,

        name: "United"

    )

    static let chevron = Supplier(

        id: UUID(uuidString: "F1A28C3B-6A3E-4A1C-9E0A-39B1F5B7A2E7")!,

        name: "Chevron"

    )

    static let ior = Supplier(

        id: UUID(uuidString: "7A3E8D31-8B2B-4C7A-9B2E-9A0D3B2C1F88")!,

        name: "iOR"

    )

    static var all: [Supplier] { [bp, mobil, united, chevron, ior] }

}

```

  

---

  

## Models/Assets/Terminal.swift

  

```swift

import SwiftUI

  

// File: Models/Assets/Terminal.swift

import Foundation

import CoreLocation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - Terminal (Core asset)

//======================================

//

// Purpose:

// - Represents a physical loading location (fuel terminal, depot, etc).

// - Used for:

//     • Load planning (SimView)

//     • Map pins

//     • LoadAccount resolution

//

// Philosophy:

// - Driver-oriented model.

// - We do NOT model bays, gantries, or internal terminal layout.

// - Only what a driver actually needs.

//

// Future:

// - Works for other industries (e.g. reefer depots).

//======================================

  

struct Terminal: Codable, Identifiable, Hashable {

    let id: UUID

    /// Display name shown in UI

    var name: String

    /// Optional nickname drivers often use

    /// e.g. "Whinstanes", "Lytton", "Pinkenba"

    var shortName: String?

    /// Physical location (for map + proximity detection)

    var coordinate: CodableCoordinate?

    /// Known suppliers operating at this terminal

    /// (BP, Mobil, Chevron etc)

    var supplierIDs: [UUID]

    /// Notes the driver may want

    /// e.g. gate quirks, queue patterns, bay preferences

    var notes: String?

    init(

        id: UUID = UUID(),

        name: String,

        shortName: String? = nil,

        coordinate: CodableCoordinate? = nil,

        supplierIDs: [UUID] = [],

        notes: String? = nil

    ) {

        self.id = id

        self.name = name

        self.shortName = shortName

        self.coordinate = coordinate

        self.supplierIDs = supplierIDs

        self.notes = notes

    }

}

```

  

---

  

## Models/Assets/TerminalRegistry.swift

  

```swift

// File: Models/Assets/TerminalRegistry.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

  

enum TerminalRegistry {

    // Use stable UUIDs so your debug/test data doesn't reshuffle each run.

    // (Pick any UUIDs you like; just keep them constant once chosen.)

    static let atomWhinstanes = Terminal(

        id: UUID(uuidString: "8E2A4D3F-5C2D-4B8F-8C6D-0A5E1F9B6B01")!,

        name: "ATOM Whinstanes"

    )

    static let chevron = Terminal(

        id: UUID(uuidString: "0D9B08C9-1C5E-4F6A-8E9A-7F01B93E4B22")!,

        name: "Chevron Terminal"

    )

    static let ior = Terminal(

        id: UUID(uuidString: "B2D3A7C0-2B7C-4F0A-9D02-0E2E8A93C1F0")!,

        name: "iOR"

    )

    static var all: [Terminal] { [atomWhinstanes, chevron, ior] }

}

```

  

---

  

## Models/FatigueRuleModels.swift

  

```swift

import Foundation

  

  

// =========================

// FatigueRuleModels.swift

// =========================

//

//  Shared model types for fatigue rules, countdowns, and future multi-day status.

//  NOTE: This file is intentionally "types only" (no business logic).

//  Safe to extend without affecting current Phase 1 behaviour.

//

//  Phase 1 scope:

//  - FatigueRuleID enum defines canonical rule identifiers

//  - RuleStatusLevel provides traffic-light states (ok/warning/breached)

//  - FatigueRuleStatusV2 is a future-ready status payload

//

//  Post-persistence scope:

//  - Multi-day support types (WorkDaySummary, MultiDayFatigueStatus)

//  - Night rest tracking

//  - Rolling window summaries

//

//  Design principle:

//  - These are data structures, not calculations

//  - Calculations live in Logic/ folder

//  - UI uses these as view models

//

  

  

//======================================

// MARK: - Rule Identifiers

//======================================

  

  

/// Canonical identifiers for fatigue rules.

/// These IDs let UI + logic refer to the same rule without string keys.

///

/// Notes on intent:

/// - Some IDs mirror Phase 1 UI (pre-persistence “today proxies”).

/// - Some IDs represent true NHVR rolling-window rules (Phase 3+).

/// - A few IDs may sound similar; keep them distinct on purpose so the UI

///   can label “policy coaching” vs “legal breach” clearly.

enum FatigueRuleID: String, Hashable, CaseIterable, Codable {

    // MARK: Phase 1 “today” / shift-facing rules (pre-persistence)

    /// Company coaching rule: aim to take a preferred 30m break around 5h work.

    /// (Not an NHVR infringement rule — used for early warning.)

    case fiveHourCompanySoft

    /// NHVR spacing rule proxy: max 5h15 work between qualifying rests.

    /// (Pre-persistence proxy: does not yet model the full 5h30 window mechanics.)

    case fiveHourFifteenLegal

    /// Today proxy: when ≥7h30 work (8h window proxy), require ≥30m legal rest (today).

    case sevenPointFive

    /// Today proxy: when ≥10h work (11h window proxy), require ≥60m legal rest (today).

    case tenHour

    /// Today proxy hard cap: 12h max work (pre-persistence simplification).

    /// (True NHVR is “12h work in any rolling 24h” — handled later.)

    case workTodayTotal

    // MARK: Phase 3+ rolling window rules (true multi-day / rolling)

    /// True rule: 12h max work in any rolling 24h window (post-persistence).

    case twelveHourCap

    /// Placeholder: ≤6 consecutive work days before a qualifying 24h continuous rest.

    case sixConsecutiveDays

    /// Placeholder: ≤72h work in any rolling 7 days.

    case weekly72Hours

    /// Placeholder: ≤144h work in any rolling 14 days.

    case fortnight144Hours

    // MARK: Night rest rules (post-persistence)

    /// Placeholder: at least 4 night rests in 14 days (definition implemented later).

    case nightRestFourInFourteen

    /// Placeholder: at least 2 consecutive night rests (definition implemented later).

    case nightRestTwoConsecutive

    // MARK: Optional / legacy mapping (kept for backwards UI phrasing)

    /// Legacy-friendly alias: “work since last break” (typically driven by the spacing rule).

    /// Keep until the UI is fully migrated to the ID set above.

    case workSinceLastBreak

}

  

//======================================

// MARK: - Generic Status Types

//======================================

  

/// High-level traffic-light status for any rule.

/// Kept view-agnostic so multiple panels can reuse it.

enum RuleStatusLevel: String, Codable {

    case ok        // compliant / comfortably within limits

    case warning   // approaching limit, attention needed

    case breached  // non-compliant or exceeded

}

  

/// Generic status payload for any fatigue rule.

/// Designed to support:

/// - Phase 1 tick-box rows (7.5h, 10h, 12h)

/// - “next rule” countdown card

/// - Phase 3+ multi-day panels (72h/7 days, night rests, etc.)

struct FatigueRuleStatusV2: Identifiable, Codable {

    /// Which rule this status refers to.

    let id: FatigueRuleID

    /// Short title for UI (e.g. "7h30 threshold", "Night rests").

    var title: String

    /// Optional one-liner explanation / hint.

    var message: String?

    /// Traffic-light status.

    var level: RuleStatusLevel

    /// Optional progress 0.0 ... 1.0 for bars / rings.

    /// Example: workSoFar / limit, workedDays / 6, etc.

    var progress: Double?

    /// Optional minutes remaining until breach (work-time based for Phase 1).

    /// For rolling-window rules, this may become “minutes remaining in window” later.

    var minutesUntilBreach: Int?

    /// Optional legal rest minutes accumulated (useful for 7h30/10h thresholds and night rests).

    var legalRestMinutes: Int?

    var isBreached: Bool { level == .breached }

    var isWarning: Bool { level == .warning }

}

  

//======================================

// MARK: - Multi-day Support Types (Phase 3+)

//======================================

  

/// Summary of one calendar day used for multi-day rules.

/// Persistence will populate this from stored segments / events.

struct WorkDaySummary: Codable {

    /// Midnight-anchored date (local calendar day).

    var date: Date

    /// Total *work* minutes logged that day (driving + other work).

    var workMinutes: Int

    /// Total minutes counted as “legal rest” (e.g. ≥15m blocks).

    var legalRestMinutes: Int

    /// Placeholder: whether this day contained a qualifying night rest.

    /// Exact definition (time window + continuous duration) is implemented later.

    var hadNightRest: Bool

}

  

/// Aggregate status for multi-day rules.

/// The UI can render this as a separate “Multi-day” panel post-persistence.

struct MultiDayFatigueStatus: Codable {

    /// Last N days considered (e.g. last 14).

    var days: [WorkDaySummary]

    /// Computed status for each multi-day rule.

    var ruleStatuses: [FatigueRuleStatusV2]

}

```

  

---

  

## Models/IncidentModels.swift

  

```swift

import Foundation

  

//======================================

// MARK: - INCIDENT MODELS (PRE-PERSISTENCE)

//======================================

//

// Purpose:

// - Define the core data structures for incident handling.

// - Support calm, structured driver guidance during stressful events

//   (accidents, breakdowns, spills, medical, near-misses).

//

// Scope (Phase 1):

// - Model-only definitions (NO UI, NO side-effects).

// - Incidents are event-based (not activity segments).

// - Advice is computed dynamically, not hard-coded.

//

// Design principles:

// - Favour clarity over completeness.

// - Use triage-style questions (yes / no / unknown).

// - Avoid "big brother" behaviour — only use data the driver

//   explicitly provides or the app already holds.

//

// Future evolution:

// - Phase 2+: persistence to SQLite.

// - Phase 3+: richer branching logic, photo metadata, exports.

// - Phase 4+: incident history review and editing.

//

//======================================

  

  

enum IncidentType: String, Codable, CaseIterable {

    case accident

    case breakdown

    case nearMiss

    case spill

    case fire

    case medical

}

  

enum IncidentSeverity: String, Codable {

    case informationOnly   // near miss, no damage

    case minor             // damage, no danger

    case serious           // vehicle disabled, injury possible

    case emergency         // immediate danger

}

  

enum TernaryAnswer: String, Codable {

    case yes

    case no

    case unknown

}

  

struct IncidentReport: Identifiable, Codable {

    let id: UUID

    let timestamp: Date

    // Context (auto-filled)

    let suburb: String?

    let latitude: Double?

    let longitude: Double?

    // Driver input

    var type: IncidentType

    var severity: IncidentSeverity

    // Key triage answers

    var isSafeStopped: TernaryAnswer

    var injuriesPresent: TernaryAnswer

    var fireOrSpill: TernaryAnswer

    var hitAndRun: TernaryAnswer

    // Evidence

    var photosTakenCount: Int

    var shortNote: String?

    init(

        timestamp: Date = Date(),

        suburb: String? = nil,

        latitude: Double? = nil,

        longitude: Double? = nil,

        type: IncidentType,

        severity: IncidentSeverity

    ) {

        self.id = UUID()

        self.timestamp = timestamp

        self.suburb = suburb

        self.latitude = latitude

        self.longitude = longitude

        self.type = type

        self.severity = severity

        self.isSafeStopped = .unknown

        self.injuriesPresent = .unknown

        self.fireOrSpill = .unknown

        self.hitAndRun = .unknown

        self.photosTakenCount = 0

        self.shortNote = nil

    }

}

  

enum IncidentAdviceAction: Identifiable, Codable {

    case call000

    case callSpecialistAdvice(phone: String)

    case callSupervisor(phone: String)

    case callMechanic(phone: String)

    case reportToPolicelink

    case takePhotos(count: Int)

    case writeShortNote

    case hydrateAndRest

    var id: String {

        switch self {

        case .call000: return "call000"

        case .callSpecialistAdvice(let phone): return "callSpecialist-\(phone)"

        case .callSupervisor(let phone): return "callSupervisor-\(phone)"

        case .callMechanic(let phone): return "callMechanic-\(phone)"

        case .reportToPolicelink: return "policelink"

        case .takePhotos(let count): return "photos-\(count)"

        case .writeShortNote: return "note"

        case .hydrateAndRest: return "rest"

        }

    }

}

  

struct IncidentAdvicePlan: Codable {

    let headline: String

    let actions: [IncidentAdviceAction]

}

```

  

---

  

## Models/LoadTemplateModels.swift

  

```swift

import Foundation

  

//======================================

// MARK: - Load Template Models

//======================================

//

// Intent:

// - A LoadTemplate is a reusable preset you can apply to the live Load Plan.

// - Pre-persistence: templates live in memory (and can be stored later).

// - Post-persistence: templates become user data and may need migration.

//

// Design note:

// - `items` is an Array (not a Dictionary) to allow future extensions like:

//   - multi-drop sequencing

//   - multiple products per compartment over time

//   - metadata per row (e.g. priority, delivery order, notes)

// - In Phase 1/2 UI we treat it as "one row per compartment" (C1...C5).

//

// Template vs Load Plan distinction:

// - Template = reusable pattern (saved, shareable, non-authoritative)

// - Load Plan (in AppModel) = current draft (volatile until confirmed)

// - Confirmed Load (in confirmedLoads) = authoritative snapshot

//

//======================================

  

/// A reusable preset you can apply to the live Load Plan.

struct LoadTemplate: Identifiable, Codable, Hashable {

    let id: UUID

    var name: String

    var createdAt: Date

    /// Template rows.

    /// Phase 1/2 expectation: one row per compartment name ("C1"..."C5").

    /// Future: may contain multiple rows per compartment for sequencing.

    var items: [LoadTemplateItem]

    /// Optional notes / tags for later (e.g. "Metro", "Heavy steer", etc.)

    var notes: String?

    init(

        id: UUID = UUID(),

        name: String,

        createdAt: Date = Date(),

        items: [LoadTemplateItem],

        notes: String? = nil

    ) {

        self.id = id

        self.name = name

        self.createdAt = createdAt

        self.items = items

        self.notes = notes

    }

}

  

/// One “row” in a template.

/// In Phase 1/2 this represents a single compartment fill.

/// Future: could represent a step in a sequence (partial unload/reload patterns).

struct LoadTemplateItem: Identifiable, Codable, Hashable {

    let id: UUID

    /// Compartment identifier, e.g. "C1".

    var compartmentName: String

    /// Product identifier using the fleet short code, e.g. "P91", "DSL".

    /// (Resolution into a full Product happens in model logic.)

    var productShortName: String

    /// Litres for this row. Phase 1/2: intended to be >= 0.

    var litres: Int

    /// Optional per-template SG override (overrides product.defaultSg for simulation).

    var sgOverride: Double?

    init(

        id: UUID = UUID(),

        compartmentName: String,

        productShortName: String,

        litres: Int,

        sgOverride: Double? = nil

    ) {

        self.id = id

        self.compartmentName = compartmentName

        self.productShortName = productShortName

        self.litres = litres

        self.sgOverride = sgOverride

    }

}

```

  

---

  

## Models/MassSimulationResult.swift

  

```swift

import Foundation

  

//======================================

// MARK: - Mass Simulation Result

//======================================

//

// Intent:

// - Output payload from MassSimulationLogic.

// - View layer uses this to render totals, axle loads, headroom, and warnings.

// - All weights are kilograms (kg). Volumes are litres (L).

// - Headroom: positive = under limit, negative = over limit.

//

// Usage:

// - Simulation screen: shows what-if results for draft templates

// - Load screen (future): may show live axle estimates as driver edits

//

// Important:

// - This is a DERIVED result, never authoritative truth

// - Confirmed loads store their OWN mass snapshot (from confirmation time)

// - This struct is for planning/preview only

//

//======================================

  

struct MassSimulationResult: Hashable {

  

    // Totals

    var totalLitres: Int          // L

    var totalMassKg: Double       // kg (product mass only, excludes tare)

    // Loaded axle / vehicle weights (tare + product mass allocation)

    var steerKg: Double           // kg

    var driveKg: Double           // kg

    var gvmKg: Double             // kg (steer + drive)

    // Legal/target limits (so the view can show "current / max")

    var maxSteerKg: Double        // kg

    var maxDriveKg: Double        // kg

    var maxGvmKg: Double          // kg

    // Headroom (positive = under limit, negative = over)

    var steerHeadroom: Double     // kg

    var driveHeadroom: Double     // kg

    var gvmHeadroom: Double       // kg

    /// Human-readable summary when any limit is exceeded.

    /// Nil means "no issues detected".

    var warning: String?

}

```

  

---

  

## Models/SharedModels.swift

  

```swift

import SwiftUI

import MapKit

  

//======================================

// MARK: - SharedModels

//======================================

//

//======================================

// MARK: - SETTINGS / DRIVER PROFILE

//======================================

  

/// Simple settings bag for driver + base info.

/// This will grow later (e.g. SG presets, favourite terminals, fatigue mode selection, etc.).

  

  

  

struct DriverSettings: Codable {

    var driverName: String = "Cory"

    var truckIdentifier: String = "Truck 92"

    // NHVR/base-radius features (Phase 3+)

    // Placeholder only: NOT enforcing NHVR rules yet.

    var nhvrBaseName: String = ""      // e.g. "BP 6750 depot"

    var nhvrBaseAddress: String = ""   // free-text for now

    var nhvrRadiusKm: Double = 100.0 // placeholder for base-radius/geofence logic

    // Emergency / specialist contacts

    var specialistAdvicePhone: String = ""   // e.g. EIP / Hazchem advice

    var supervisorPhone: String = ""

    var mechanicPhone: String = ""

    // Non-urgent police (AU wide)

    var policelinkPhone: String = "131 444"

    // Optional: does the vehicle have a dashcam / inward cam?

    var hasVehicleCamera: Bool = false

}

  

//======================================

// MARK: - OTHER ACTIVITIES / ODO CAPTURE

//======================================

  

/// User-defined activity shortcuts (Phase 1: used to log events quickly).

struct OtherActivity: Identifiable, Codable, Hashable {

    let id: UUID

    var name: String       // e.g. "Training"

    var isWork: Bool       // true = counts as work, false = rest

}

  

/// Why the odo/suburb prompt is being shown.

enum OdoPromptContext: String, Codable {

    case shiftStart

    case legalBreakEnd

    case shiftEnd

    case odoUpdate

}

  

/// Logbook-style capture of odometer + a simple location label.

/// Pre-persistence: suburb is stored as free-text.

struct OdoLocationRecord: Identifiable, Codable {

    let id: UUID

    let timestamp: Date

    let context: OdoPromptContext

    let odoText: String

    let suburb: String

    let segmentID: UUID?    

}

  

//======================================

// MARK: - LOCATION / MAP MODELS

//======================================

  

enum LocationCategory: String, CaseIterable, Identifiable, Codable {

    case terminal = "Terminal"

    case customer = "Customer"

    case breakSpot = "Break Spot"

    case other = "Other"

    var id: String { rawValue }

    /// UI-only color hint (no business logic).

    var color: Color {

        switch self {

        case .terminal:  return .red

        case .customer:  return .blue

        case .breakSpot: return .green

        case .other:     return .gray

        }

    }

}

  

/// Map pin stored in a Codable-friendly way (lat/long instead of CLLocationCoordinate2D).

/// Persistence-friendly as-is.

struct LocationPin: Identifiable, Codable {

    var id: UUID

    var name: String

    var latitude: Double

    var longitude: Double

    var category: LocationCategory

    // Alias so you can use pin.title OR pin.name

    var title: String {

        get { name }

        set { name = newValue }

    }

    var coordinate: CLLocationCoordinate2D {

        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

    }

    // Full init (your original intent)

    init(id: UUID = UUID(),

         name: String,

         coordinate: CLLocationCoordinate2D,

         category: LocationCategory) {

        self.id = id

        self.name = name

        self.latitude = coordinate.latitude

        self.longitude = coordinate.longitude

        self.category = category

    }

    // Convenience init: allows you to omit name (defaults to category label)

    init(id: UUID = UUID(),

         coordinate: CLLocationCoordinate2D,

         category: LocationCategory) {

        self.id = id

        self.name = category.rawValue

        self.latitude = coordinate.latitude

        self.longitude = coordinate.longitude

        self.category = category

    }

}

  

//======================================

// MARK: - LOAD / TRUCK MODELS

//======================================

  

/// Fuel/product definition used for load planning, mass simulation and (later) DG rules.

/// Note: `id` is currently a random UUID (runtime identity).

/// Persistence will eventually require a STABLE ID (e.g. based on shortName or a fixed UUID).

  

/// Placeholder for future Hazchem parsing/display logic.

/// Safe to keep even if unused until Hazchem UI exists.

struct HazchemCode: Codable {

    var prefixDot: Bool

    var digit: Int

    var letter: String

    var hasE: Bool

}

  

/// Live compartment state for Load/Unload views (draft state, not authoritative).

struct CompartmentModel: Identifiable, Codable {

    var id = UUID()

    let name: String

    let capacityLitres: Int

    var selectedProduct: Product?

    var litresText: String = ""

    var isDegassed: Bool = false

}

  

struct AxleSplit: Codable {

    var steerFraction: Double  // can exceed 0...1 in edge cases (e.g. rear overhang)

    var driveFraction: Double

}

  

struct TruckConfig: Codable {

    var name: String

    // Tare weights (empty truck) — NOTE: your tare currently includes FULL fuel tank.

    var tareSteerKg: Double

    var tareDriveKg: Double

    // Full tank fuel mass that is INCLUDED in the tare above.

    // Used for “fuel slider” to reduce tare as tank empties.

    var runTankFullKg: Double = 0

    var lazyLiftTransferKg: Double 

    var hasLazyAxle: Bool = true   // or false by default, set per truck

    // Configured limits (UI warnings use these; not legal advice)

    var maxSteerKg: Double

    var maxDriveKg: Double

    var maxGvmKg: Double

    // How each compartment's mass is shared between axles

    // keyed by compartment name, e.g. "C1", "C2"...

    var axleSplitByCompartment: [String: AxleSplit]

}

  

/// A confirmed snapshot line for a compartment.

/// Confirmed loads become the "authoritative" session history used by DG placarding.

struct ConfirmedCompartment: Identifiable, Codable {

    var id = UUID()

    let name: String

    let sfl: Int

    let productShort: String

    let sg: Double?       // optional for future flexibility (paper-only / unknown SG)

    let litres: Double

    let massKg: Double

}

  

enum ConfirmedLoadMode: String, Codable {

    case loadConfirmed = "LOAD"

    case unloadSnapshot = "UNLOAD"

}

  

extension ConfirmedLoadMode {

    var displayName: String {

        switch self {

        case .loadConfirmed:  return "Load"

        case .unloadSnapshot: return "Unload"

        }

    }

}

  

/// Confirmed load/unload snapshot.

/// This is the history source used for placarding + later persistence.

struct ConfirmedLoad: Identifiable, Codable {

    var id = UUID()

    let timestamp: Date

    let mode: ConfirmedLoadMode

    let terminalName: String

    let loadCode: String

    let vehicleId: String

    let driverName: String

    let compartments: [ConfirmedCompartment]

    let totalLitres: Int

    let totalMassKg: Double

    let steerKg: Double

    let driveKg: Double

    let gvmKg: Double

}

  

/// Delivery sheet model (future-ready for multiple products + multiple compartments).

struct DeliveryLine: Identifiable, Codable {

    var id = UUID()

    let compName: String        // "C1"

    let productShort: String    // "DSL", "P91", etc

    let litresDelivered: Int

}

  

struct DeliveryRecord: Identifiable, Codable {

    var id = UUID()

    let timestamp: Date

    let customerName: String?        // later: from pins

    let lines: [DeliveryLine]        // multiple compartments, multiple products

    let note: String?

}

  

// MARK: - Product Catalogue (Fuel for now; modular later)

var products: [Product] { FuelProducts.all }

  

//======================================

// MARK: - DG helpers (ConfirmedLoad → last-known family)

//======================================

  

extension ConfirmedLoad {

    /// Returns the last known DG family for a compartment based on a confirmed load record.

    /// Phase 1: heuristic mapping from productShort. Keep it simple and aligned to product naming.

    func lastFamilyForCompartmentNamed(_ compName: String) -> DGProductFamily? {

        guard let c = compartments.first(where: { $0.name == compName }) else { return nil }

        guard c.litres > 0 else { return nil }   // only trust it if it actually had product

        let s = c.productShort.lowercased()

        if s.contains("ulp") || s.contains("petrol") || s.contains("p91") || s.contains("p95") || s.contains("p98") {

            return .ulp

        }

        if s.contains("diesel") || s.contains("dsl") || s.contains("adf") {

            return .diesel

        }

        return .other

    }

}

  

//======================================

// MARK: - EVENTS / ACTIVITY / FATIGUE

//======================================

  

enum EventKind: String, Codable {

    case shiftStart = "Shift started"

    case shiftEnd   = "Shift ended"

    case driveStart = "Driving"

    case breakStart = "Break started"

    case load       = "Load event"

    case unload     = "Unload event"

    case incident   = "Incident"

    case other      = "Other"

}

  

struct ShiftEvent: Identifiable, Codable {

    var id = UUID()

    let time: Date

    let kind: EventKind

    let note: String?

}

  

/// Detailed activity types.

/// Phase 1: NHVR work/rest is derived ONLY via `isWork`.

/// Later phases can add activity-specific constraints and better categorisation.

enum ActivityType: String, Codable {

    case offDuty

    // WORK activities

    case driving

    case workGeneral

    case workLoad

    case workUnload

    // REST activities

    case restBreak

    case restBreakdown

}

  

extension ActivityType {

    /// NHVR view: is this WORK time?

    var isWork: Bool {

        switch self {

        case .driving,

                .workGeneral,

                .workLoad,

                .workUnload:

            return true

        case .offDuty,

                .restBreak,

                .restBreakdown:

            return false

        }

    }

    /// Human-friendly label (handy for UI + debugging).

    var displayName: String {

        switch self {

        case .offDuty: return "Off duty"

        case .driving: return "Driving"

        case .workGeneral: return "On Duty "

        case .workLoad: return "Loading"

        case .workUnload: return "Unloading"

        case .restBreak: return "Break"

        case .restBreakdown: return "Breakdown"

        }

    }

}

  

/// A continuous chunk of time spent in a single activity.

struct ActivitySegment: Identifiable, Codable {

    var id = UUID()

    let type: ActivityType

    let start: Date

    var end: Date?   // nil == still going

    // Future hooks (Phase 3+)

    var odoAtStart: Int?

    var locationName: String?

}

  

struct ShiftSummary: Identifiable, Codable {

    var id = UUID()

    let date: Date

    let start: Date?

    let end: Date

    let workSeconds: TimeInterval

    let restSeconds: TimeInterval

    let driveSeconds: TimeInterval

    let loadCount: Int

    let unloadCount: Int

}

  

//======================================

// MARK: - HELPERS

//======================================

  

/// Shared formatter to avoid repeated DateFormatter creation cost.

private let shortTimeFormatter: DateFormatter = {

    let df = DateFormatter()

    df.dateStyle = .none

    df.timeStyle = .short

    return df

}()

  

func formatTimeHM(_ seconds: TimeInterval) -> String {

    let clamped = max(seconds, 0)

    let totalMinutes = Int(clamped / 60)

    let hours = totalMinutes / 60

    let minutes = totalMinutes % 60

    return String(format: "%dh %02dm", hours, minutes)

}

  

func formatTimeShort(_ date: Date) -> String {

    shortTimeFormatter.string(from: date)

}

  

/// UI-friendly shape for displaying the timeline list.

struct TimelineEvent: Identifiable {

    let id: UUID

    let timeString: String

    let label: String

}

```

  

---

  

## Models/SimulationModel.swift

  

```swift

import Foundation

  

//======================================

// MARK: - Simulation Model (Fatigue Simulator Only)

//======================================

//

// Purpose:

// - Lightweight sandbox for testing fatigue rules WITHOUT touching live shift data

// - Used ONLY by FatigueSimulationView (in SimulationView.swift)

//

// Critical separation:

// - This model is COMPLETELY ISOLATED from AppModel

// - No shared state, no side effects

// - Changes here do NOT affect the driver's real shift

//

// Why this exists:

// - Pre-persistence testing aid (validate countdown logic)

// - Driver education tool ("what if I work 2 more hours?")

// - Future: may become a planning/forecast engine

//

// Design principles:

// - Simple, deterministic math

// - Mirrors real fatigue rules (uses same FatigueConstants)

// - Always clearly labelled as "simulation" in UI

//

//======================================

  

enum SimActivityType {

  

    case work

    case rest

}

  

struct SimSegment: Identifiable {

    let id = UUID()

    let type: SimActivityType

    let start: TimeInterval

    let end: TimeInterval

    var duration: TimeInterval { end - start }

}

  

/// Represents the next fatigue rule we’re counting down to (simulator UI only).

enum SimFatigueTarget {

    case fiveHoursFifteen(remaining: TimeInterval)

    case sevenPointFive(remainingWork: TimeInterval, remainingRest: TimeInterval)

    case tenHours(remainingWork: TimeInterval, remainingRest: TimeInterval)

    case twelveHours(remaining: TimeInterval)

    case breached(rule: String)   // knows which rule broke

}

  

//======================================

// MARK: - Simulation Model (Fatigue Simulator Only)

//======================================

  

/// A lightweight model used only for the fatigue simulator.

/// This does NOT touch AppModel or real shift data.

///

/// Important: Keep simulator rule maths aligned with the real fatigue engine.

/// If the real rules change, update this file too (or call into shared logic later).

final class SimulationModel: ObservableObject {

    // Legal break threshold (seconds). Simulator mirrors Phase 1 rule: ≥ 15m.

    private let legalBreakSeconds: TimeInterval = FatigueConstants.legalBreak15

    /// A sequence of alternating Work / Rest segments in simulated time.

    @Published var segments: [SimSegment] = []

    /// The last time position chosen by the slider (seconds from "start of scenario").

    @Published var lastSimulatedTime: TimeInterval = 0

    //======================================

    // MARK: - Recording segments

    //======================================

    func addWork(to newTime: TimeInterval) {

        addSegment(type: .work, newTime: newTime)

    }

    func addRest(to newTime: TimeInterval) {

        addSegment(type: .rest, newTime: newTime)

    }

    private func addSegment(type: SimActivityType, newTime: TimeInterval) {

        guard newTime > lastSimulatedTime else { return }

        let seg = SimSegment(

            type: type,

            start: lastSimulatedTime,

            end: newTime

        )

        segments.append(seg)

        lastSimulatedTime = newTime

    }

    //======================================

    // MARK: - Derived totals (simulated "today")

    //======================================

    var workSecondsToday: TimeInterval {

        segments

            .filter { $0.type == .work }

            .map { $0.duration }

            .reduce(0, +)

    }

    /// Total legal rest today (sum of rest segments ≥ 15 minutes).

    var legalRestToday: TimeInterval {

        segments

            .filter { $0.type == .rest && $0.duration >= legalBreakSeconds }

            .map { $0.duration }

            .reduce(0, +)

    }

    /// Same concept as the real engine: work since the *last legal* break.

    func workSinceLastRest() -> TimeInterval {

        var total: TimeInterval = 0

        for seg in segments.reversed() {

            if seg.type == .rest && seg.duration >= legalBreakSeconds {

                break

            }

            if seg.type == .work {

                total += seg.duration

            }

        }

        return total

    }

    //======================================

    // MARK: - Rule picker (simulator-only)

    //======================================

    /// Determine the next rule countdown (simulator approximation).

    /// This is work-time based, not wall-clock based.

    func nextFatigueTarget() -> SimFatigueTarget {

        let work = workSecondsToday

        let rest = legalRestToday

        let sevenFiveLimit: TimeInterval = FatigueConstants.nhvrSevenPointFiveHours

        let tenLimit: TimeInterval      = FatigueConstants.nhvrTenHours

        let twelveLimit: TimeInterval   = FatigueConstants.nhvrDailyCap

        // 0) Check for breaches first (most serious wins)

        if work >= twelveLimit {

            return .breached(rule: "12h daily cap")

        }

        if work >= tenLimit && rest < FatigueConstants.requiredRestAt10h {

            return .breached(rule: "10h rule (60m rest)")

        }

        if work >= sevenFiveLimit && rest < FatigueConstants.requiredRestAt7h30 {

            return .breached(rule: "7.5h rule (30m rest)")

        }

        // 1) No breaches yet – pick the rule with the least remaining work time

        var candidates: [(remaining: TimeInterval, target: SimFatigueTarget)] = []

        // 5.25h since last legal break

        let sinceLast = workSinceLastRest()

        if sinceLast < FatigueConstants.nhvrSpacingLimit {

            let remaining = FatigueConstants.nhvrSpacingLimit - sinceLast

            candidates.append((remaining, .fiveHoursFifteen(remaining: remaining)))

        }

        // 7.5h rule

        if work < sevenFiveLimit {

            let remainingW = sevenFiveLimit - work

            let remainingR = max(FatigueConstants.requiredRestAt7h30 - rest, 0)

            candidates.append((remainingW, .sevenPointFive(remainingWork: remainingW, remainingRest: remainingR)))

        }

        // 10h rule

        if work < tenLimit {

            let remainingW = tenLimit - work

            let remainingR = max(FatigueConstants.requiredRestAt10h - rest, 0)

            candidates.append((remainingW, .tenHours(remainingWork: remainingW, remainingRest: remainingR)))

        }

        // 12h cap

        if work < twelveLimit {

            let remaining = twelveLimit - work

            candidates.append((remaining, .twelveHours(remaining: remaining)))

        }

        // Choose the smallest remaining work time

        if let best = candidates.min(by: { $0.remaining < $1.remaining }) {

            return best.target

        } else {

            // Edge case: no candidates – treat as sitting right on the 12h cap

            return .twelveHours(remaining: 0)

        }

    }

    //======================================

    // MARK: - Reset

    //======================================

    func reset() {

        segments = []

        lastSimulatedTime = 0

    }

}

```

  

---

  

# MODULES

  

---

  

## Modules/Fuel/FuelModuleAndVocabNotesTemp.swift

  

```swift

// ============================================================

// FuelModuleNotes.swift

// Temporary architectural placeholder

// Purpose: describe the Fuel transport module and how it

// maps generic transport concepts into fuel delivery logic.

// ============================================================

  

  

// ------------------------------------------------------------

// WHY THIS FILE EXISTS

// ------------------------------------------------------------

//

// The current application began as a fuel delivery assistant.

// Many systems therefore assume fuel-specific terminology.

//

// As the architecture evolves, fuel becomes only ONE module

// within a larger transport platform.

//

// This file records the vocabulary mapping and design intent

// for the fuel module.

  

  

// ------------------------------------------------------------

// ROLE OF THE FUEL MODULE

// ------------------------------------------------------------

//

// The Fuel module provides:

//

// • fuel product definitions

// • terminal registries

// • supplier registries

// • load accounts

// • compartment-based truck loading

// • DG placarding logic

//

// These features sit on top of generic transport behaviour.

  

  

// ------------------------------------------------------------

// VOCABULARY TRANSLATION

// ------------------------------------------------------------

//

// Transport Layer Term → Fuel Term

//

// CargoUnit            → Compartment

// SiteAsset            → Underground Tank

// TransportOrder       → Delivery / Load / Transfer

//

// This translation allows the same transport engine to

// support other freight types later.

  

  

// ------------------------------------------------------------

// EXAMPLE OF MODULE SKINNING

// ------------------------------------------------------------

//

// Transport concept:

//

// CargoUnit

//

// Fuel module interpretation:

//

// Compartment

// A tank compartment within a fuel tanker.

//

// Properties may include:

//

// • capacity

// • product type

// • fill level

// • weight contribution

// • axle mass effect

  

  

// ------------------------------------------------------------

// FUEL-SPECIFIC DOMAIN OBJECTS

// ------------------------------------------------------------

//

// Examples currently implemented:

//

// Product

// ProductRegistry

// Supplier

// SupplierRegistry

// Terminal

// TerminalRegistry

// LoadAccount

// LoadAccountRegistry

//

// These objects will eventually live fully inside the

// Fuel module rather than inside the generic Models folder.

  

  

// ------------------------------------------------------------

// DELIVERY SITE STRUCTURE

// ------------------------------------------------------------

//

// A delivery site may contain multiple tanks.

//

// Current company workflow:

//

// • dip tanks before delivery

// • deliver fuel to selected tanks

// • record volumes in external company system

//

// The Driver Assistant app does NOT attempt to replicate

// full inventory management systems like SmartFill.

//

// Instead the app focuses on:

//

// • planning

// • verification

// • driver assistance

// • mass simulation

// • operational awareness

  

  

// ------------------------------------------------------------

// IMPORTANT DESIGN LIMIT

// ------------------------------------------------------------

//

// The app intentionally avoids becoming a full fuel

// inventory management platform.

//

// Systems such as SmartFill already perform that role.

//

// The driver assistant only captures data that directly

// assists the driver during a shift.

  

  

// ------------------------------------------------------------

// FUTURE MODULE STRUCTURE

// ------------------------------------------------------------

//

// Modules

//   └ Fuel

//       ├ Models

//       ├ Logic

//       ├ Assets

//       └ UI

//

// Fuel-specific code should migrate here over time.

  

  

// ------------------------------------------------------------

// POSSIBLE FUTURE TRANSPORT MODULES

// ------------------------------------------------------------

//

// Livestock

// Refrigerated Freight

// Palletised Freight

// Container Transport

//

// Each module will translate transport concepts into its

// own domain vocabulary.

  

  

// ------------------------------------------------------------

// CURRENT STATUS

// ------------------------------------------------------------

//

// The system is mid-transition.

//

// Fuel logic still exists in multiple areas of the codebase:

//

// • Models

// • AppModel extensions

// • UI layers

//

// These will gradually consolidate into the Fuel module

// once the Transport layer stabilises.

  

  

// ------------------------------------------------------------

// TEMPORARY FILE NOTICE

// ------------------------------------------------------------

//

// This file exists only to guide architecture during

// refactoring.

//

// Once the module structure is fully implemented this file

// can be:

//

// • moved to Resources

// • replaced with formal documentation

// • or removed.

  

  

// ============================================================

// END OF FILE

// ============================================================

```

  

---

  

# PERSISTENCE

  

---

  

## Persistence/AppConfigV1.swift

  

```swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - AppConfigV1

//======================================

//

// Purpose:

// - Hot-tweak tunables mid-shift without recompiling.

// - Stored as JSON in Documents/DriverAssistant/JSON/AppConfig/appconfig.json

//

// Safety:

// - Only include values that are safe to change at runtime.

// - Avoid anything that changes meaning of already-recorded history.

//

  

struct AppConfigV1: Codable {

    static let schemaVersion: Int = 1

    var schemaVersion: Int = AppConfigV1.schemaVersion

    var savedAt: Date = Date()

    // Tunables you can safely change mid-shift

    var motion: AppModel.MotionTunables = AppModel.MotionTunables()

    var gps: GpsTunables = GpsTunables()

    // Optional notes for humans (ignored by logic)

    var notes: String? = nil

    static var `default`: AppConfigV1 {

        AppConfigV1(

            schemaVersion: AppConfigV1.schemaVersion,

            savedAt: Date(),

            motion: AppModel.MotionTunables(),

            gps: GpsTunables(),

            notes: "Default config"

        )

    }

    //======================================

    // MARK: - GPS Tunables (hot-tweakable subset)

    //======================================

    struct GpsTunables: Codable {

        // Speed gate: below this, treat as stationary evidence.

        // Used by AppModel distance ingestion guard.

        var minMotionSpeedMps: Double = 1.0              // ~3.6 km/h

        // GPS accuracy gate

        var maxAccuracyMeters: Double = 50

        // Distance gate (anti-teleport)

        var maxSingleUpdateJumpMeters: Double = 250

        // After odo capture, suppress GPS-derived estimates briefly

        var postCaptureGraceSeconds: TimeInterval = 5

        // UI: speed readout stales to 0 after this

        var speedDisplayStaleSeconds: TimeInterval = 2

        // "Are you driving?" nudge

        var movementNudgeMinSpeedMps: Double = 5.5       // ~20 km/h sustained

        var movementNudgeConfirmSeconds: TimeInterval = 12

        var movementNudgeCooldownSeconds: TimeInterval = 600

        // "You appear stopped" nudge (Load tab)

        var stoppedNudgeConfirmSeconds: TimeInterval = 90

        var stoppedNudgeCooldownSeconds: TimeInterval = 300

        // Motion watchdog / auto-recovery

        var autoRecoverCooldownSeconds: TimeInterval = 25

        var autoRecoverLowMotionHoldSeconds: TimeInterval = 8

        var watchdogGpsFreshSeconds: TimeInterval = 5

        var watchdogMovingEvidenceDeltaMeters: Double = 2.0

        var watchdogMinCertaintyScore: Int = 30

        // Plausibility guard for distance ingestion (AppModel side)

        // You can safely drop this from 55 -> 35 m/s mid-shift.

        var maxPlausibleSpeedMpsForDistance: Double = 55.0

        // Slack for jitter/batching

        var distanceGuardSlackMeters: Double = 35.0

    }

}

```

  

---

  

## Persistence/AppSaveV1.swift

  

```swift

import Foundation

  

//======================================

// MARK: - AppSaveV1 (Session Autosave Payload)

//======================================

//

// Purpose:

// - Capture the minimum "session state" needed to survive a crash.

// - Restore timeline + confirmed loads + odometer anchors consistently.

//

// Notes:

// - This is NOT long-term history storage yet.

// - Keep it boring and reliable.

  

struct AppSaveV1: Codable {

    // Schema

    let schemaVersion: Int

    let savedAt: Date

    //=========================

    // Timeline / shift engine

    //=========================

    var isOnDuty: Bool

    var isDriving: Bool

    var isOnBreak: Bool

    var currentActivity: ActivityType

    var currentSegmentStart: Date?

    var runningSegmentID: UUID?

    var segmentsToday: [ActivitySegment]

    var gpsShiftMetersLive: Double 

    //=========================

    // Timeline events

    //=========================

    var events: [ShiftEvent]

    //=========================

    // Loads (authoritative session history)

    //=========================

    var confirmedLoads: [ConfirmedLoad]

    //=========================

    // Odo + location snapshots

    //=========================

    var odoText: String

    var odoLocationRecords: [OdoLocationRecord]

    var lastOdoCaptureTime: Date?

    //=========================

    // GPS/ODO distance engine anchors

    //=========================

    var gpsKmSinceLastOdoBySegment: [UUID: Double]

    var finalisedKmBySegment: [UUID: Double]

    var lastOdoAnchorRecordID: UUID?

    var lastOdoAnchorKm: Int?

    var lastOdoAnchorKmCorrectionFactor: Double

    //=========================

    // Load tab draft state (practical recovery)

    //=========================

    var isUnloadMode: Bool

    var compartments: [CompartmentModel]

    var lazyAxleIsUp: Bool

    var fuelStepIndex: Int

    // Optional: keep settings if DriverSettings is Codable (it should be).

    var settings: DriverSettings

}

  

//======================================

// MARK: - Build / Apply

//======================================

  

@MainActor

extension AppSaveV1 {

    static let currentSchemaVersion = 1

    static func build(from model: AppModel) -> AppSaveV1 {

        AppSaveV1(

            schemaVersion: currentSchemaVersion,

            savedAt: Date(),

            isOnDuty: model.isOnDuty,

            isDriving: model.isDriving,

            isOnBreak: model.isOnBreak,

            currentActivity: model.currentActivity,

            currentSegmentStart: model.currentSegmentStart,

            runningSegmentID: model.runningSegmentID,

            segmentsToday: model.segmentsToday,

            gpsShiftMetersLive: model.gpsShiftMetersLive, 

            events: model.events,

            confirmedLoads: model.confirmedLoads,

            odoText: model.odoText,

            odoLocationRecords: model.odoLocationRecords,

            lastOdoCaptureTime: model.lastOdoCaptureTime,

            gpsKmSinceLastOdoBySegment: model.gpsKmSinceLastOdoBySegment,

            finalisedKmBySegment: model.finalisedKmBySegment,

            lastOdoAnchorRecordID: model.lastOdoAnchorRecordID,

            lastOdoAnchorKm: model.lastOdoAnchorKm,

            lastOdoAnchorKmCorrectionFactor: model.kmCorrectionFactor,

            isUnloadMode: model.isUnloadMode,

            compartments: model.compartments,

            lazyAxleIsUp: model.lazyAxleIsUp,

            fuelStepIndex: model.fuelStepIndex,

            settings: model.settings

        )

    }

    func apply(to model: AppModel) {

        // Do NOT restore any transient UI sheet state (prompts, pending closures, etc.)

        // Restore only "real" session state.

        model.isOnDuty = isOnDuty

        model.isDriving = isDriving

        model.isOnBreak = isOnBreak

        model.currentActivity = currentActivity

        model.currentSegmentStart = currentSegmentStart

        model.runningSegmentID = runningSegmentID

        model.segmentsToday = segmentsToday

        model.gpsShiftMetersLive = gpsShiftMetersLive

        model.events = events

        model.confirmedLoads = confirmedLoads

        model.odoText = odoText

        model.odoLocationRecords = odoLocationRecords

        model.lastOdoCaptureTime = lastOdoCaptureTime

        model.gpsKmSinceLastOdoBySegment = gpsKmSinceLastOdoBySegment

        model.finalisedKmBySegment = finalisedKmBySegment

  

        model.lastOdoAnchorRecordID = lastOdoAnchorRecordID

        model.lastOdoAnchorKm = lastOdoAnchorKm

        model.kmCorrectionFactor = lastOdoAnchorKmCorrectionFactor

        model.isUnloadMode = isUnloadMode

        model.compartments = compartments

        model.lazyAxleIsUp = lazyAxleIsUp

        model.fuelStepIndex = fuelStepIndex

        model.settings = settings

        // Safety: after restore, ensure lastTick doesn’t create weird deltas.

        model.lastTick = Date()

    }

}

```

  

---

  

## Persistence/AutoSaveController.swift

  

```swift

import Foundation

import SwiftUI

  

//======================================

// MARK: - AutoSaveController (debounced autosave)

//======================================

//

// Strategy:

// - Debounce frequent changes (avoid writing every second).

// - Force-save on high-value events (confirm load, activity switch, odo capture).

// - Optional: call `flushNow()` when app is backgrounding.

  

@MainActor

final class AutoSaveController: ObservableObject{

    weak var model: AppModel?

    init(model: AppModel) { self.model = model }

    private let store = SaveStore()

    private var pendingWorkItem: DispatchWorkItem?

    private let debounceSeconds: TimeInterval = 1.25

    private var shouldWriteResumable: Bool = true

    // Debug / UI hook (optional)

    @Published var lastAutosaveAt: Date? = nil

    @Published var lastAutosaveReason: String? = nil

    @Published var lastAutosaveFailed: Bool = false

    // MARK: - Restore

    func restoreIfAvailable() {

        guard let model else { return }

        guard let save = store.loadBestResumableAutosave() else { return }

        let age = Date().timeIntervalSince(save.savedAt)

        if age > 14400 {  // 4 hours

            DebugLog.autosave("💾 Stale autosave skipped: \(age/3600) hours old")

            store.clearAutosaves()  // Auto-nuke

            return

        }

        // Then prompt (e.g., set model.activeGuardPrompt for a "Resume crashed shift?" dialog)

        let pretty = model.time.formatDateTimeShort(save.savedAt, context: .ui)

        model.presentGuardPrompt(

            title: "Resume previous session?",

            message: "Found mid-shift data from \(pretty). Resume or start fresh?",

            actions: [

                AppModel.GuardAction(title: "Resume", role: nil) {

                    save.apply(to: model)

                },

                AppModel.GuardAction(title: "Start Fresh", role: .destructive) {

                    self.clearAutosaves()

                },

                AppModel.GuardAction(title: "Cancel", role: .cancel) {

                    // do nothing

                }

            ]

        )

    }

    // MARK: - Autosave requests

    func requestAutosave(reason: String, immediate: Bool = false) {

        pendingWorkItem?.cancel()

        if immediate {

            flushNow(reason: reason)

            return

        }

        let task = DispatchWorkItem { [weak self] in

            self?.flushNow(reason: reason)

        }

        pendingWorkItem = task

        DispatchQueue.main.asyncAfter(deadline: .now() + debounceSeconds, execute: task)

    }

    func clearAutosaves() {

        store.clearAutosaves()

    }

    func flushNow(reason: String) {

        guard let model else { return }

        do {

            let payload = AppSaveV1.build(from: model)

            try store.writeAutosave(payload: payload, resumable: shouldWriteResumable)

            lastAutosaveAt = Date()

            lastAutosaveReason = reason

            lastAutosaveFailed = false

            DebugLog.autosave("💾 Autosaved(\(shouldWriteResumable ? "resumable" : "not-resumable")): \(reason)")

        } catch {

            lastAutosaveFailed = true

            DebugLog.autosave("❌ Autosave failed: \(error)")

        }

    }

    func markResumableNow(reason: String = "Shift active") {

        shouldWriteResumable = true

        DebugLog.autosave("💾 Autosave marked resumable: \(reason)")

    }

    func markNotResumableNow(reason: String = "Shift ended", clearFiles: Bool = false) {

        pendingWorkItem?.cancel()

        pendingWorkItem = nil

        shouldWriteResumable = false

        guard let model else { return }

        do {

            let payload = AppSaveV1.build(from: model)

            try store.writeAutosave(payload: payload, resumable: false)

            DebugLog.autosave("💾 Autosave marked NOT resumable: \(reason)")

            if clearFiles {

                store.clearAutosaves()

                DebugLog.autosave("🧹 Autosave files cleared")

            }

            if store.hasAutosaveFiles() { DebugLog.autosave("⚠️ Autosave clear incomplete—retrying"); store.clearAutosaves() }

        } catch {

            DebugLog.autosave("❌ Failed to mark not resumable: \(error)")

        }

    }

}

```

  

---

  

## Persistence/DriverProfilePayloadV1.swift

  

```swift

// DriverProfilePayloadV1.swift

import Foundation

  

struct DriverProfilePayloadV1: Codable {

    var driverName: String = "Cory Olsen"

    enum LicenceType: String, Codable, CaseIterable {

        case mr = "MR"

        case hr = "HR"

        case hc = "HC"

        case mc = "MC"

    }

    enum LicenceHoursMode: String, Codable, CaseIterable {

        case standard = "Standard"

        case bfm = "BFM"

        case afm = "AFM"

    }

    enum CrewMode: String, Codable, CaseIterable {

        case solo = "solo"

        case twoUp = "two_up"

    }

    var licenceType: LicenceType = .hc

    var licenceHoursMode: LicenceHoursMode = .standard

    var crewMode: CrewMode = .solo

    var isOwnerDriver: Bool = false

}

```

  

---

  

## Persistence/ProfileEnvelope.swift

  

```swift

// ProfileEnvelopeV1.swift

import Foundation

  

struct ProfileEnvelopeV1<Payload: Codable>: Codable {

    // Keep this as a literal; no static storage.

    var schemaVersion: Int = 1

    var savedAt: Date = Date()

    var payload: Payload

    init(schemaVersion: Int = 1, savedAt: Date = Date(), payload: Payload) {

        self.schemaVersion = schemaVersion

        self.savedAt = savedAt

        self.payload = payload

    }

}

```

  

---

  

## Persistence/SaveStore.swift

  

```swift

import Foundation

import CryptoKit

  

//======================================

// MARK: - SaveStore (Atomic write + rotation + validation)

//======================================

//

// Files:

// - autosave_tmp.json       (written first)

// - autosave_current.json   (last good save)

// - autosave_previous.json  (fallback)

//

// Validation:

// - SHA256 of payload bytes stored in envelope.

// - If current fails validation -> try previous.

  

final class SaveStore {

    struct Envelope<T: Codable>: Codable {

        let schemaVersion: Int

        let savedAt: Date

        let resumable: Bool         

        let byteCount: Int

        let sha256: String

        let payload: T

    }

    enum SaveError: Error {

        case cannotResolveDocuments

        case cannotCreateFolder

        case encodeFailed

        case decodeFailed

        case checksumMismatch

        case fileMissing

    }

    // Folder: Documents/DriverAssistant/Saves

    private let folderName = "DriverAssistant/Saves"

    private let currentName = "autosave_current.json"

    private let previousName = "autosave_previous.json"

    private let tmpName = "autosave_tmp.json"

    // MARK: - AppConfig

    private let appConfigFolder = "AppConfig"

    private let appConfigFile   = "appconfig.json"

    // MARK: - JSON Assets (Driver / Settings)

    private let jsonRoot = "DriverAssistant/JSON"

    private let driverFolder = "Driver"

    private let settingsFolder = "Settings"

    private let driverFile = "driver.json"

    private let settingsFile = "settings.json"

    private let encoder: JSONEncoder = {

        let e = JSONEncoder()

        e.outputFormatting = [.prettyPrinted, .sortedKeys]

        e.dateEncodingStrategy = .iso8601

        return e

    }()

    private let decoder: JSONDecoder = {

        let d = JSONDecoder()

        d.dateDecodingStrategy = .iso8601

        return d

    }()

    // MARK: - Public API

    private func writeJSON<T: Codable>(_ value: T, to url: URL) throws {

        let bytes = try encoder.encode(value)

        try bytes.write(to: url, options: [.atomic])

    }

    private func readJSON<T: Codable>(_ type: T.Type, from url: URL) throws -> T {

        let bytes = try Data(contentsOf: url)

        return try decoder.decode(T.self, from: bytes)

    }

    private func ensureFolder() throws -> URL {

        try ensureFolder(path: folderName)

    }

    func writeAutosave(payload: AppSaveV1, resumable: Bool) throws {

        let folderURL = try ensureFolder(path: folderName)

        let currentURL = folderURL.appendingPathComponent(currentName)

        let previousURL = folderURL.appendingPathComponent(previousName)

        let tmpURL = folderURL.appendingPathComponent(tmpName)

        // 1) Encode payload first (bytes)

        let payloadBytes = try encoder.encode(payload)

        // 2) Wrap in envelope with checksum

        let digest = SHA256.hash(data: payloadBytes)

        let sha = digest.map { String(format: "%02x", $0) }.joined()

        let env = Envelope<AppSaveV1>(

            schemaVersion: payload.schemaVersion,

            savedAt: payload.savedAt,

            resumable: resumable,     

            byteCount: payloadBytes.count,

            sha256: sha,

            payload: payload

        )

        let envBytes = try encoder.encode(env)

        // 3) Atomic-ish write:

        //    - write tmp

        //    - rotate current -> previous

        //    - replace current with tmp

        try envBytes.write(to: tmpURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: currentURL.path) {

            // Replace previous with current

            _ = try? FileManager.default.removeItem(at: previousURL)

            try FileManager.default.copyItem(at: currentURL, to: previousURL)

        }

        // Replace current with tmp

        _ = try? FileManager.default.removeItem(at: currentURL)

        try FileManager.default.copyItem(at: tmpURL, to: currentURL)

        // Clean up tmp (optional)

        _ = try? FileManager.default.removeItem(at: tmpURL)

    }

    func loadBestResumableAutosave() -> AppSaveV1? {

        do {

            let folderURL = try ensureFolder(path: folderName)

            let currentURL = folderURL.appendingPathComponent(currentName)

            let previousURL = folderURL.appendingPathComponent(previousName)

            if let s = try? readValidatedResumable(from: currentURL) { return s }

            if let s = try? readValidatedResumable(from: previousURL) { return s }

            return nil

        } catch {

            return nil

        }

    }

    private func readValidatedResumable(from url: URL) throws -> AppSaveV1 {

        let bytes = try Data(contentsOf: url)

        let env = try decoder.decode(Envelope<AppSaveV1>.self, from: bytes)

        // checksum validation (same as you already do)

        let payloadBytes = try encoder.encode(env.payload)

        let digest = SHA256.hash(data: payloadBytes)

        let sha = digest.map { String(format: "%02x", $0) }.joined()

        guard sha == env.sha256, payloadBytes.count == env.byteCount else {

            throw SaveError.checksumMismatch

        }

        // ✅ resumable gate

        guard env.resumable else {

            throw SaveError.fileMissing // or a new error like .notResumable

        }

        return env.payload

    }

    func clearAutosaves() {

        do {

            let folderURL = try ensureFolder()

            let currentURL = folderURL.appendingPathComponent(currentName)

            let previousURL = folderURL.appendingPathComponent(previousName)

            let tmpURL = folderURL.appendingPathComponent(tmpName)

            _ = try? FileManager.default.removeItem(at: currentURL)

            _ = try? FileManager.default.removeItem(at: previousURL)

            _ = try? FileManager.default.removeItem(at: tmpURL)

        } catch {

            // ignore

        }

    }

    // MARK: - Driver Profile

    func writeDriverProfile(_ payload: DriverProfilePayloadV1) throws {

        let folder = try ensureFolder(path: "\(jsonRoot)/\(driverFolder)")

        let url = folder.appendingPathComponent(driverFile)

        try writeProfileEnvelope(payload, to: url)

    }

    func loadDriverProfile() -> DriverProfilePayloadV1? {

        do {

            let folder = try ensureFolder(path: "\(jsonRoot)/\(driverFolder)")

            let url = folder.appendingPathComponent(driverFile)

            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            let payload = try loadProfilePayload(DriverProfilePayloadV1.self, from: url)

            // Optional auto-upgrade: re-save in envelope format if it was legacy plain JSON

            // (We can’t easily detect which path succeeded without extra logic; simplest: just write it back.)

            try? writeDriverProfile(payload)

            return payload

        } catch {

            return nil

        }

    }

    //Mark: - Settings profiles.

    func writeSettings(_ payload: SettingsPayloadV1) throws {

        let folder = try ensureFolder(path: "\(jsonRoot)/\(settingsFolder)")

        let url = folder.appendingPathComponent(settingsFile)

        try writeProfileEnvelope(payload, to: url)

    }

    func loadSettings() -> SettingsPayloadV1? {

        do {

            let folder = try ensureFolder(path: "\(jsonRoot)/\(settingsFolder)")

            let url = folder.appendingPathComponent(settingsFile)

            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            let payload = try loadProfilePayload(SettingsPayloadV1.self, from: url)

            try? writeSettings(payload) // optional auto-upgrade

            return payload

        } catch {

            return nil

        }

    }

    // MARK: - AppConfig

    func writeAppConfig(_ payload: AppConfigV1) throws {

        let folder = try ensureFolder(path: "\(jsonRoot)/\(appConfigFolder)")

        let url = folder.appendingPathComponent(appConfigFile)

        try writeProfileEnvelope(payload, to: url)

    }

    func loadAppConfig() -> AppConfigV1? {

        do {

            let folder = try ensureFolder(path: "\(jsonRoot)/\(appConfigFolder)")

            let url = folder.appendingPathComponent(appConfigFile)

            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            let payload = try loadProfilePayload(AppConfigV1.self, from: url)

            try? writeAppConfig(payload) // optional auto-upgrade

            return payload

        } catch {

            return nil

        }

    }

    func debugPrintSaveFolder() {

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

            DebugLog.autosave("💾 Saves folder = \(docs.appendingPathComponent(folderName, isDirectory: true))")

        }

    }

    func debugPrintJSONFolders() {

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        DebugLog.autosave("📁 JSON root = \(docs.appendingPathComponent(jsonRoot, isDirectory: true))")

        DebugLog.autosave("📁 Driver = \(docs.appendingPathComponent("\(jsonRoot)/\(driverFolder)", isDirectory: true))")

        DebugLog.autosave("📁 Settings = \(docs.appendingPathComponent("\(jsonRoot)/\(settingsFolder)", isDirectory: true))")

        DebugLog.autosave("📁 AppConfig = \(docs.appendingPathComponent("\(jsonRoot)/\(appConfigFolder)", isDirectory: true))")

    }

    // MARK: - Internals

     private func ensureFolder(path: String) throws -> URL {

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {

            throw SaveError.cannotResolveDocuments

        }

        let folderURL = docs.appendingPathComponent(path, isDirectory: true)

        if !FileManager.default.fileExists(atPath: folderURL.path) {

            do {

                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            } catch {

                throw SaveError.cannotCreateFolder

            }

        }

        return folderURL

    }

    private func readValidated(from url: URL) throws -> AppSaveV1 {

        guard FileManager.default.fileExists(atPath: url.path) else {

            throw SaveError.fileMissing

        }

        let bytes = try Data(contentsOf: url)

        let env = try decoder.decode(Envelope<AppSaveV1>.self, from: bytes)

        // Re-encode payload exactly as we did when writing (same encoder settings)

        let payloadBytes = try encoder.encode(env.payload)

        let digest = SHA256.hash(data: payloadBytes)

        let sha = digest.map { String(format: "%02x", $0) }.joined()

        guard sha == env.sha256 else { throw SaveError.checksumMismatch }

        guard payloadBytes.count == env.byteCount else { throw SaveError.checksumMismatch }

        return env.payload

    }

}

  

extension SaveStore {

    func hasAutosaveFiles() -> Bool {

        do {

            let folderURL = try ensureFolder()

            let currentURL = folderURL.appendingPathComponent(currentName)

            let previousURL = folderURL.appendingPathComponent(previousName)

            let fm = FileManager.default

            return fm.fileExists(atPath: currentURL.path) ||

            fm.fileExists(atPath: previousURL.path)

        } catch {

            return false

        }

    }

}

  

extension SaveStore {

    /// Debug-only helper: returns the URLs of known autosave files if the folder exists.

    func debugAutosaveFileURLs() -> [URL] {

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {

            return []

        }

        let folderURL = docs.appendingPathComponent(folderName, isDirectory: true)

        // Only the real autosaves (you can include tmp if you want)

        let names = [currentName, previousName]

        return names

            .map { folderURL.appendingPathComponent($0) }

            .filter { FileManager.default.fileExists(atPath: $0.path) }

    }

}

  

extension SaveStore {

    // inside SaveStore)

    private func writeProfileEnvelope<T: Codable>(_ payload: T, to url: URL) throws {

        let env = ProfileEnvelopeV1(payload: payload)

        try writeJSON(env, to: url)

    }

    private func loadProfilePayload<T: Codable>(_ type: T.Type, from url: URL) throws -> T {

        let bytes = try Data(contentsOf: url)

        // 1) Try envelope first (new format)

        if let env = try? decoder.decode(ProfileEnvelopeV1<T>.self, from: bytes) {

            return env.payload

        }

        // 2) Fallback: old “plain payload” (legacy format)

        //    If this succeeds, caller can re-save and “upgrade” the file.

        return try decoder.decode(T.self, from: bytes)

    }

}

```

  

---

  

## Persistence/SettingsPayloadV1.swift

  

```swift

// SettingsPayloadV1.swift

import Foundation

  

struct SettingsPayloadV1: Codable {

    var nhvrBaseName: String = "Liquip"

    var nhvrBaseAddress: String = "730 Macarthur Avenue Central, Pinkenba, Qld."

    var nhvrRadiusKm: Double = 100.0

}

```

  

---

  

# SERVICES

  

---

  

## Services/AppBuildInfo.swift

  

```swift

import Foundation

  

//======================================

// MARK: - AppBuildInfo

//======================================

//

/// Reads PATCHLOG.md from the app bundle and exposes

/// the current version + build date based on the *topmost* entry.

///

/// Expected PATCHLOG header example:

/// ## [0.1.42] 20251231

struct AppBuildInfo {

    static let shared = AppBuildInfo()

    /// e.g. "0.1.42"

    let version: String

    /// e.g. "20251231" (raw yyyymmdd from the header)

    let buildDateRaw: String

    /// e.g. "31-12-2025" (AU-friendly)

    let buildDatePretty: String

    /// The full header line we parsed (useful for debugging).

    let headerLine: String

    private init() {

        let (line, v, d) = AppBuildInfo.loadFromPatchlog()

        self.headerLine      = line ?? ""

        self.version         = v ?? "0.0.0"

        self.buildDateRaw    = d ?? "unknown"

        self.buildDatePretty = AppBuildInfo.prettyDate(from: d)

    }

}

  

//======================================

// MARK: - Internal helpers

//======================================

  

private extension AppBuildInfo {

    /// Load PATCHLOG.md, find the first header line, and parse version + date.

    static func loadFromPatchlog() -> (String?, String?, String?) {

        guard let url = Bundle.main.url(forResource: "PATCHLOG", withExtension: "md"),

              let contents = try? String(contentsOf: url, encoding: .utf8)

        else {

            return (nil, nil, nil)

        }

        // Split into lines and grab the first that starts with "##"

        let lines = contents

            .split(whereSeparator: \.isNewline)

            .map { String($0) }

        guard let header = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("##") })

        else {

            return (nil, nil, nil)

        }

        let version = parseVersion(from: header)

        let date    = parseDate(from: header)

        return (header, version, date)

    }

    /// Extracts text between "[" and "]", e.g. "[0.1.42]" → "0.1.42".

    static func parseVersion(from line: String) -> String? {

        guard let open = line.firstIndex(of: "["),

              let close = line[open...].firstIndex(of: "]")

        else { return nil }

        let inner = line[line.index(after: open)..<close]

        let trimmed = inner.trimmingCharacters(in: .whitespaces)

        return trimmed.isEmpty ? nil : String(trimmed)

    }

    /// Assumes the last whitespace-separated token in the line is yyyymmdd.

    static func parseDate(from line: String) -> String? {

        let parts = line

            .split(separator: " ")

            .map { String($0) }

        guard let last = parts.last,

              last.count == 8,

              last.allSatisfy({ $0.isNumber })

        else {

            return nil

        }

        return last

    }

    /// Turn "20251231" into "31-12-2025", otherwise "unknown".

    static func prettyDate(from raw: String?) -> String {

        guard let raw = raw, raw.count == 8 else { return "unknown" }

        let year  = raw.prefix(4)

        let month = raw.dropFirst(4).prefix(2)

        let day   = raw.suffix(2)

        return "\(day)-\(month)-\(year)"

    }

}

```

  

---

  

## Services/Constants.swift

  

```swift

  

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

```

  

---

  

## Services/Debug.swift

  

```swift

import Foundation

  

//======================================

// MARK: - Debug Infrastructure

//======================================

  

enum DebugFlags {

    // Master override (turns everything on)

    static let all = false

    // App lifecycle

    static let myapp     = true

    static let lifecycle = true

    // Motion / GPS

    static let gps    = false

    static let motion = false

    // Persistence (general)

    static let persistence = true

    // Persistence (autosave subcategory)

    // Keep this so you can toggle autosave noise separately if you want.

    static let autosave = true

    // Odometer

    static let odo = true

    // Guard / Incident engine

    static let guardEngine = true

    // Debug UI

    static let debugMenu = true

    static let ui = true

    static let trianglePlaceholder = true

    static let sim = true

}

  

  

//======================================

// MARK: - Debug Logging

//======================================

  

enum DebugLog {

    private static func enabled(_ flag: Bool) -> Bool {

        DebugFlags.all || flag

    }

    // MARK: - App / Lifecycle

    static func myapp(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.myapp) else { return }

        print("🟣 " + msg())

    }

    static func lifecycle(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.lifecycle) else { return }

        print("🧬 " + msg())

    }

    // MARK: - GPS / Motion

    static func gps(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.gps) else { return }

        print("🛰️ " + msg())

    }

    static func motion(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.motion) else { return }

        print("🏃 " + msg())

    }

    // MARK: - Persistence

    /// General persistence logging (file IO, encoding/decoding, migrations, export, etc.)

    static func persistence(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.persistence) else { return }

        print("🗄️ " + msg())

    }

    /// Autosave-specific logging (debounce, flushes, restore, clear).

    static func autosave(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.autosave) else { return }

        print("💾 " + msg())

    }

    // MARK: - Odo

    static func odo(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.odo) else { return }

        print("🧭 " + msg())

    }

    // MARK: - Guard

    static func guardEngine(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.guardEngine) else { return }

        print("🛡️ " + msg())

    }

    // MARK: - UI

    /// UI events that aren't "app lifecycle" (sheets, banners, prompts, debug panels).

    static func ui(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.ui) else { return }

        print("🪟 " + msg())

    }

    // Mark:- Sim

    static func sim(_ msg: @autoclosure () -> String) {

            guard enabled(DebugFlags.sim) else { return } // ✅ your existing dev-only gate

            print("🧪SIM: " + msg())

    }

  

}

```

  

---

  

## Services/Haptics.swift

  

```swift

import UIKit
// This is here as a just in case
// iPad for testing doesn’t use haptics 

enum Haptics {

    static func heavyImpact() {

        let gen = UIImpactFeedbackGenerator(style: .heavy)

        gen.prepare()

        gen.impactOccurred()

    }

}

```

  

---

  

## Services/Hysteresis.swift

  

```swift

import Foundation

  

/// Simple 2-threshold hysteresis gate.

/// Example: upper=101, lower=99

/// - When inactive: activates at >= upper

/// - When active:   deactivates at <= lower

struct HysteresisGate {

    let upper: Int

    let lower: Int

    init(upper: Int, lower: Int) {

        precondition(lower < upper, "HysteresisGate: lower must be < upper")

        self.upper = upper

        self.lower = lower

    }

    func nextState(current: Int, isActive: Bool) -> Bool {

        if isActive {

            // stay active unless we're safely below

            return current > lower

        } else {

            // stay inactive unless we're clearly above

            return current >= upper

        }

    }

}

```

  

---

  

## Services/LocationManager.swift

  

```swift

  

import CoreLocation

import Combine

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - LocationManager

//======================================

  

// Purpose:

// - Wrap CLLocationManager and publish validated GPS data to the rest of the app.

// - Produce clean speed, course, accuracy, and delta-distance signals.

  

// Owns:

// - CLLocationManager lifecycle (permission, start, stop, recover).

// - Speed smoothing (rolling trim-average) and accuracy gating.

// - Distance accumulation per location update (raw GPS estimate).

// - Stall detection when updates stop while the vehicle is moving.

// - Context-aware precision switching (driving / loading / rest).

  

// Notes:

// - Published signals are consumed by AppModel via Combine in connect(locationManager:).

// - Thresholds shared with AppModel+GPS reference GPSConstants to stay in sync.

//======================================

  

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - System Manager

    private var manager: CLLocationManager

    private var hasStarted   = false

    private var delegateSet  = false

    // MARK: - Distance Accumulation

    @Published var gpsShiftMeters: Double  = 0

    @Published var lastDeltaMeters: Double = 0

    private var lastGoodLocationForDistance: CLLocation? = nil

    // Distance filter thresholds (LocationManager-internal; not shared with AppModel).

    private let minDeltaMetersToCount: Double = 4.0

    private let maxDeltaMetersToCount: Double = 180.0  // catches teleports before AppModel's 250m gate

    // MARK: - Published Telemetry

    @Published var lastLocation:     CLLocation? = nil

    @Published var lastGoodLocation: CLLocation? = nil   

    @Published var rawSpeedMps:      Double?      = nil

    @Published var speedMps:         Double?      = nil

    @Published var lastValidSpeedMps: Double?     = nil

    @Published var courseDegrees:    Double?      = nil

    // MARK: - Speed Smoothing

    private var recentValidSpeeds: [Double] = []

    private let maxSamples = 5

    // Hard ceiling: above this the reading is treated as a sensor glitch.

    private let maxReasonableSpeedMps: Double = 36.0   // ~130 km/h

    // MARK: - Service State

    enum ServiceState: Equatable {

        case idle

        case requestingPermission

        case running

        case pausedOrStalled

        case denied

        case restricted

        case reducedAccuracy

        case error(String)

    }

    @Published var serviceState:      ServiceState = .idle

    @Published var lastStatusMessage: String?       = nil

    @Published var showStatusBanner:  Bool          = false

    private var bannerHideTask: DispatchWorkItem?   = nil

    // MARK: - Stall Detection

    @Published var lastUpdateAt: Date? = nil

    private var stallTimer: Timer?     = nil

    private let stallThresholdSeconds: TimeInterval = 20

    // MARK: - Banner Kinds

    enum BannerKind { case info, success, warning, error }

    // MARK: - Debug Helpers

    var authDebug: String {

        switch manager.authorizationStatus {

        case .notDetermined:     return "notDetermined"

        case .authorizedWhenInUse: return "whenInUse"

        case .authorizedAlways:  return "always"

        case .denied:            return "denied"

        case .restricted:        return "restricted"

        @unknown default:        return "unknown"

        }

    }

    var stateDebug: String {

        switch serviceState {

        case .idle:                return "idle"

        case .requestingPermission: return "requesting"

        case .running:             return "running"

        case .pausedOrStalled:     return "stalled"

        case .denied:              return "denied"

        case .restricted:          return "restricted"

        case .reducedAccuracy:     return "reduced"

        case .error(let m):        return "err:\(m)"

        }

    }

  

  

    @Published var liveSuburb: String = "—"

    private let geocoder = CLGeocoder()

    private var lastGeocodeAt: Date? = nil

    private var lastGeocodeLocation: CLLocation? = nil

    private var geocodeInFlight = false

    private let geocodeMinInterval: TimeInterval = 120        // 2 min

    private let geocodeMinDistanceMeters: Double = 1000        // only when actually moved 1 klm

    private var wasMovingLastTick: Bool = false

    private func maybeUpdateLiveSuburb(for loc: CLLocation, isMoving: Bool, force: Bool = false) {

        // Gate: don't geocode garbage

        guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 1000 else { return }

        guard !geocodeInFlight else { return }

        let now = Date()

        // Choose interval by motion

        let minInterval: TimeInterval = isMoving ? geocodeMinInterval : 600   // 2 min moving, 10 min stopped

        let minDistance: CLLocationDistance = geocodeMinDistanceMeters        // 1 km

        if !force {

            if let last = lastGeocodeAt, now.timeIntervalSince(last) < minInterval {

                // too soon

                return

            }

            if let lastLoc = lastGeocodeLocation, loc.distance(from: lastLoc) < minDistance {

                // not far enough

                return

            }

        }

        geocodeInFlight = true

        lastGeocodeAt = now

        lastGeocodeLocation = loc

        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in

            guard let self else { return }

            self.geocodeInFlight = false

            if let pm = placemarks?.first {

                let suburb =

                pm.locality

                ?? pm.subLocality

                ?? pm.administrativeArea

                ?? "—"

                DispatchQueue.main.async {

                    self.liveSuburb = suburb

                }

            }

        }

    }

    @MainActor

    func setShiftMeters(_ meters: Double) {

        gpsShiftMeters = max(0, meters)

        lastDeltaMeters = 0

        // Prevent a giant “first delta” after restore:

        if let loc = lastLocation {

            lastGoodLocationForDistance = loc

        } else {

            lastGoodLocationForDistance = nil

        }

    }

    @MainActor

    func resetShiftMeters(reason: String) {

        DebugLog.gps("🧹 LM shift meters reset: \(reason)")

        setShiftMeters(0)

    }

    // MARK: - Init

    override init() {

        self.manager = CLLocationManager()

        super.init()

        DebugLog.gps("📍 LocationManager init PAST super — safe zone")

        DebugLog.gps("📍 LocationManager init COMPLETE - auth: \(authDebug)")

    }

    // MARK: - Public Controls

    func start() {

        guard !hasStarted else {

            DebugLog.gps("start() - already started, skipping")

            return

        }

        hasStarted   = true

        serviceState = derivedAuthState()

        DebugLog.gps("📍 start() called – applying config immediately")

        manager.activityType                     = .automotiveNavigation

        manager.desiredAccuracy                  = kCLLocationAccuracyBestForNavigation

        manager.distanceFilter                   = kCLDistanceFilterNone

        manager.pausesLocationUpdatesAutomatically = false

        // Defer delegate assignment slightly so init is fully off the call stack.

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in

            guard let self else { return }

            if !self.delegateSet {

                self.manager.delegate = self

                self.delegateSet = true

                DebugLog.gps("📍 Delegate set lazily (deferred)")

            }

            DebugLog.gps("📍 Pre-start auth: \(self.authDebug), state: \(self.serviceState)")

            self.manager.startUpdatingLocation()

            DebugLog.gps("📍 Location updates started successfully") 

            self.startStallWatch()

        }

        // Watchdog: warn if no fix arrives within 8 seconds.

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in

            guard let self, self.lastUpdateAt == nil else { return }

            DebugLog.gps("No location after 8s – degraded")

            self.serviceState = .pausedOrStalled

            self.notify("Location slow to start - check GPS/signal", kind: .warning)

        }

    }

    func stop() {

        DebugLog.gps("📍 stop() called")

        manager.stopUpdatingLocation()

        stallTimer?.invalidate()

        stallTimer = nil

        hasStarted   = false

        serviceState = .idle

    }

    func kickUpdates(reason: String = "Manual kick") {

        let auth = manager.authorizationStatus

        guard auth != .denied, auth != .restricted else {

            notify("GPS kick blocked: permission \(authDebug).", kind: .error)

            return

        }

        DebugLog.gps("📍 kickUpdates() – \(reason) t=\(Date())")

        notify("Kicking GPS…", kind: .info)

        manager.stopUpdatingLocation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in

            guard let self else { return }

            self.manager.startUpdatingLocation()

            self.lastUpdateAt = Date()

            self.serviceState = self.derivedAuthState()

            self.notify("GPS kick complete.", kind: .success)

        }

    }

    func requestPermissionIfNeeded() {

        if manager.authorizationStatus == .notDetermined {

            serviceState = .requestingPermission

            manager.requestWhenInUseAuthorization()

            notify("Requesting location permission…", kind: .info)

        }

    }

    func recover(reason: String = "Manual restart") {

        DebugLog.gps("📍 recover() called - reason: \(reason)")

        notify("Location recover: \(reason)", kind: .warning)

        let newManager = CLLocationManager()

        manager.delegate = nil

        manager = newManager

        requestPermissionIfNeeded()

        start()

    }

    // MARK: - Context-Aware Precision

    func setContext(_ context: ActivityContext) {

        switch context {

        case .driving:

            manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation

            manager.distanceFilter  = kCLDistanceFilterNone

            DebugLog.gps("📍 Context: DRIVING (high precision)")

        case .loading, .unloading:

            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

            manager.distanceFilter  = 50

            DebugLog.gps("📍 Context: LOADING/UNLOADING (reduced precision)")

        case .rest, .offDuty:

            manager.desiredAccuracy = kCLLocationAccuracyKilometer

            manager.distanceFilter  = 500

            DebugLog.gps("📍 Context: REST/OFF-DUTY (minimal updates)")

        }

    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {

        DebugLog.gps("📍 Authorization changed - auth: \(authDebug), precise: \(manager.accuracyAuthorization == .fullAccuracy)")

        serviceState = derivedAuthState()

        switch serviceState {

        case .reducedAccuracy:

            notify("Location ON but Precise Location OFF (reduced accuracy).", kind: .warning)

        case .running:

            notify("Location authorized.", kind: .success)

            if hasStarted { manager.startUpdatingLocation() }

        case .denied:

            notify("Location denied. Enable in Settings → Privacy & Security → Location Services.", kind: .error)

        case .restricted:

            notify("Location restricted (device policy).", kind: .error)

        case .error(let msg):

            notify("Location: \(msg)", kind: .error)

        default:

            break

        }

    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {

        DebugLog.gps("📍 Location error: \(error.localizedDescription)")

        let message: String

        if let clErr = error as? CLError {

            switch clErr.code {

            case .locationUnknown:

                message = "Location unknown (waiting for GPS fix)…"

                serviceState = .pausedOrStalled

                notify(message, kind: .warning)

            case .denied:

                message = "Location denied."

                serviceState = .denied

                notify(message, kind: .error)

            case .network:

                message = "Location error: network issue."

                serviceState = .error(message)

                notify(message, kind: .warning)

            default:

                message = "Location error: \(clErr.code.rawValue)"

                serviceState = .error(message)

                notify(message, kind: .error)

            }

        } else {

            message = "Location error: \(error.localizedDescription)"

            serviceState = .error(message)

            notify(message, kind: .error)

        }

    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        guard let loc = locations.last else { return }

        lastLocation = loc

        let now = Date()

        let prev = lastUpdateAt

        lastUpdateAt = now

        if let prev {

            DebugLog.gps("LM cadence dt=\(String(format: "%.2f", now.timeIntervalSince(prev)))s  acc=\(Int(loc.horizontalAccuracy))m")

        }

        // Gate 1: Reject poor-accuracy fixes.

        let acc = loc.horizontalAccuracy

        guard acc >= 0, acc <= GPSConstants.maxAccuracyMeters else {

            lastGoodLocation = nil   // ✅ prevent stale “good” from masquerading as current

            rawSpeedMps   = (loc.speed >= 0) ? loc.speed : nil

            courseDegrees = (loc.course >= 0) ? loc.course : nil

            lastDeltaMeters = 0

            return

        }

        // ✅ Post-gate good fix

        lastGoodLocation = loc

        // Gate 2: Validate speed and reject sensor spikes.

        let raw = (loc.speed >= 0) ? loc.speed : nil

        rawSpeedMps   = raw

        courseDegrees = (loc.course >= 0) ? loc.course : nil

        var candidate: Double? = raw

        if let s = candidate, s > maxReasonableSpeedMps { candidate = nil }

        // Gate 3: Smooth with a trim-average (needs ≥ 3 samples).

        if let s = candidate {

            recentValidSpeeds.append(s)

            if recentValidSpeeds.count > maxSamples {

                recentValidSpeeds.removeFirst(recentValidSpeeds.count - maxSamples)

            }

            if recentValidSpeeds.count >= 3 {

                let sorted  = recentValidSpeeds.sorted()

                let trimmed = Array(sorted.dropFirst().dropLast())

                let avg = trimmed.reduce(0, +) / Double(trimmed.count)

                let fastDown = trimmed.min() ?? avg   // your idea, but on trimmed only

                let prev = lastValidSpeedMps ?? avg

                // Detect falling trend with a small deadband to ignore tiny jitter

                let isFalling = avg < (prev - 0.3)    // 0.3 m/s ≈ 1.1 km/h

                let chosen = isFalling ? fastDown : avg

                speedMps = chosen

                lastValidSpeedMps = chosen

                // Optional: if falling, purge high history so it doesn't keep "holding you up"

                if isFalling {

                    recentValidSpeeds = recentValidSpeeds.filter { $0 <= chosen + 0.5 } // keep only near/under current

                }

            }

        }

        // Gate 3.5: Don't accumulate distance while stationary — update anchor to prevent drift.

        let movingSpeed = speedMps ?? lastValidSpeedMps ?? 0

        let isMoving = movingSpeed >= GPSConstants.minMotionSpeedMps

        let justStopped = (wasMovingLastTick == true && isMoving == false)

        wasMovingLastTick = isMoving

        // ✅ Run suburb update even if stopped (it will throttle itself)

        maybeUpdateLiveSuburb(for: loc, isMoving: isMoving, force: justStopped)

        if !isMoving {

            lastDeltaMeters = 0

            lastGoodLocationForDistance = loc

            return

        }

        // Gate 4: Accumulate distance, rejecting jitter and teleports.

        if let prev = lastGoodLocationForDistance {

            let delta = loc.distance(from: prev)

            if delta >= minDeltaMetersToCount, delta.isFinite, delta < maxDeltaMetersToCount {

                lastDeltaMeters   = delta

                gpsShiftMeters   += delta

                lastGoodLocationForDistance = loc

            } else {

                lastDeltaMeters = 0

                // Re-anchor on large jumps so the next valid delta isn't also discarded.

                if delta.isFinite, delta >= maxDeltaMetersToCount {

                    lastGoodLocationForDistance = loc

                }

            }

        } else {

            lastGoodLocationForDistance = loc

            lastDeltaMeters = 0

        }

    }

    // MARK: - Stall Detection

    private func startStallWatch() {

        stallTimer?.invalidate()

        stallTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in

            self?.checkForStall()

        }

    }

    private func checkForStall() {

        guard case .running = serviceState else { return }

        guard let last = lastUpdateAt       else { return }

        let dt = Date().timeIntervalSince(last)

        guard dt >= stallThresholdSeconds   else { return }

        // Stationary vehicles naturally stop producing updates — not a stall.

        if let s = lastValidSpeedMps, s < GPSConstants.minMotionSpeedMps {

            DebugLog.gps("📍 No updates for \(Int(dt))s but vehicle stopped - OK")

            return

        }

        serviceState = .pausedOrStalled

        notify("Location stalled while moving (>\(Int(stallThresholdSeconds))s). Tap Recover.", kind: .warning)

    }

    // MARK: - Private Helpers

    private func derivedAuthState() -> ServiceState {

        switch manager.authorizationStatus {

        case .denied:                  return .denied

        case .restricted:              return .restricted

        case .authorizedAlways, .authorizedWhenInUse:

            return manager.accuracyAuthorization == .reducedAccuracy ? .reducedAccuracy : .running

        case .notDetermined:           return .requestingPermission

        @unknown default:              return .error("Unknown authorization status")

        }

    }

    private func notify(_ text: String, kind: BannerKind, autoHideSeconds: TimeInterval = 6) {

        lastStatusMessage = text

        showStatusBanner  = true

        bannerHideTask?.cancel()

        let task = DispatchWorkItem { [weak self] in self?.showStatusBanner = false }

        bannerHideTask = task

        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideSeconds, execute: task)

        let emoji: String = {

            switch kind {

            case .info:    return "ℹ️"

            case .success: return "✅"

            case .warning: return "⚠️"

            case .error:   return "❌"

            }

        }()

        DebugLog.ui("\(emoji) Location: \(text)")

    }

}

  

  

// MARK: - Activity Context

  

enum ActivityContext {

    case driving

    case loading

    case unloading

    case rest

    case offDuty

}

```

  

---

  

## Services/SuburbSuggestionManager.swift

  

```swift

import CoreLocation

  

//======================================

// MARK: - SuburbSuggestionManager.swift

//======================================

// 

// utilising gps location to suggest a suburb for odocapture

  

  

final class SuburbSuggestionManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    private let geocoder = CLGeocoder()

    @Published var suggestedSuburb: String? = nil

    @Published var isFetching: Bool = false

    @Published var authorization: CLAuthorizationStatus = .notDetermined

    override init() {

        super.init()

        manager.delegate = self

        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

    }

    func requestPermissionIfNeeded() {

        if manager.authorizationStatus == .notDetermined {

            manager.requestWhenInUseAuthorization()

        }

    }

    func refresh() {

        requestPermissionIfNeeded()

        let auth = manager.authorizationStatus

        guard auth == .authorizedAlways || auth == .authorizedWhenInUse else {

            DispatchQueue.main.async {

                self.suggestedSuburb = nil

                self.isFetching = false

            }

            return

        }

        isFetching = true

        manager.requestLocation() // one-shot

    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {

        DispatchQueue.main.async {

            self.authorization = manager.authorizationStatus

        }

    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        guard let loc = locations.last else {

            DispatchQueue.main.async { self.isFetching = false }

            return

        }

        geocoder.cancelGeocode()

        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in

            let suburb =

            placemarks?.first?.locality

            ?? placemarks?.first?.subLocality

            ?? placemarks?.first?.administrativeArea

            DispatchQueue.main.async {

                self.suggestedSuburb = suburb

                self.isFetching = false

            }

        }

    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {

        DispatchQueue.main.async {

            self.suggestedSuburb = nil

            self.isFetching = false

        }

    }

}

```

  

---

  

## Services/TimeService.swift

  

```swift

import Foundation

  

//======================================

// MARK: - TimeService (single source of truth)

//======================================

//

// Goals:

// - Store absolute times as Date (always).

// - Present UI using the device's current timezone (autoupdating).

// - Compute compliance windows using a stable session timezone (Mode B).

//

// Phase 1:

// - Compliance timezone is "locked" when a shift starts (or at app init).

// - Later: optionally update complianceTZ from location/geocoder if you choose.

//

final class TimeService: ObservableObject {

    enum Context {

        case ui          // device-local, can change as you travel

        case compliance  // session-locked timezone for NHVR Mode B maths

    }

    /// Stable timezone used for compliance calculations this session/shift.

    @Published private(set) var complianceTimeZoneID: String

    init(baseTimeZoneID: String = TimeZone.current.identifier) {

        self.complianceTimeZoneID = baseTimeZoneID

    }

    // MARK: - Absolute time

    /// "Now" as an absolute timestamp.

    func now() -> Date { Date() }

    // MARK: - Time zones

    var uiTimeZone: TimeZone { .autoupdatingCurrent }

    var complianceTimeZone: TimeZone {

        TimeZone(identifier: complianceTimeZoneID) ?? .current

    }

    /// Lock compliance timezone (call at shift start).

    func lockComplianceTimeZoneToCurrentDevice(reason: String = "Shift start") {

        complianceTimeZoneID = TimeZone.current.identifier

        DebugLog.lifecycle("🕒 Compliance TZ locked to device: \(complianceTimeZoneID) (\(reason))")

    }

    /// Lock compliance timezone explicitly (future: derived from GPS/state rules).

    func lockComplianceTimeZone(id: String, reason: String = "Manual") {

        complianceTimeZoneID = id

        DebugLog.lifecycle("🕒 Compliance TZ locked: \(complianceTimeZoneID) (\(reason))")

    }

    // MARK: - Calendars (the big source of bugs if uncontrolled)

    func calendar(_ context: Context) -> Calendar {

        var cal = Calendar(identifier: .gregorian)

        cal.locale = Locale.current

        cal.timeZone = (context == .ui) ? uiTimeZone : complianceTimeZone

        return cal

    }

    // MARK: - Formatting helpers

    func formatTimeShort(_ date: Date, context: Context) -> String {

        let f = DateFormatter()

        f.locale = Locale.current

        f.timeZone = (context == .ui) ? uiTimeZone : complianceTimeZone

        f.dateStyle = .none

        f.timeStyle = .short

        return f.string(from: date)

    }

    func formatDateTimeShort(_ date: Date, context: Context) -> String {

        let f = DateFormatter()

        f.locale = Locale.current

        f.timeZone = (context == .ui) ? uiTimeZone : complianceTimeZone

        f.dateStyle = .medium

        f.timeStyle = .short

        return f.string(from: date)

    }

    // MARK: - "Day" boundaries (critical for 'today' proxy logic)

    func isSameDay(_ a: Date, _ b: Date, context: Context) -> Bool {

        let cal = calendar(context)

        return cal.isDate(a, inSameDayAs: b)

    }

    func startOfDay(_ date: Date, context: Context) -> Date {

        calendar(context).startOfDay(for: date)

    }

}

```

  

---

  

# TRANSPORT

  

---

  

  

## Transport/Assets/

  

---

  

## Transport/Logic/

  

---

  

## Transport/Models/CargoUnits.swift

  

```swift

// Placeholder transport abstraction

// Will later represent:

// - fuel compartments

// - pallet slots

// - livestock pens

// - container positions

```

  

---

  

## Transport/Models/TransportDomainNotesTemp.swift

  

```swift

// ============================================================

// TransportDomainNotes.swift

// Temporary architectural placeholder

// Purpose: describe the emerging transport layer that will sit

// between core app systems and specific freight modules.

// ============================================================

  

  

// ------------------------------------------------------------

// WHY THIS FILE EXISTS

// ------------------------------------------------------------

//

// The app originally grew around a fuel delivery workflow.

// Many domain nouns (compartment, product, terminal, etc)

// were therefore baked directly into the core app structure.

//

// As the architecture evolves, the system must support

// multiple transport types:

//

// • Fuel tankers

// • Livestock carriers

// • Palletised freight

// • Refrigerated freight

// • Container haulage

//

// To achieve this, a generic TRANSPORT layer will sit between:

//

// Core App Systems

// ↓

// Transport Domain

// ↓

// Specific Modules (Fuel, Livestock, etc)

//

// This file marks the conceptual boundary for that layer.

  

  

// ------------------------------------------------------------

// CORE APP RESPONSIBILITIES (Remain outside Transport)

// ------------------------------------------------------------

//

// Core contains systems that are NOT transport-specific:

//

// • AppModel lifecycle

// • persistence

// • timeline / journal

// • fatigue engine

// • GPS telemetry

// • distance reconciliation

// • UI navigation

// • debugging / telemetry policy

//

// These systems should never contain fuel-specific logic.

  

  

// ------------------------------------------------------------

// TRANSPORT LAYER RESPONSIBILITIES

// ------------------------------------------------------------

//

// The transport layer introduces neutral transport concepts

// that can apply to many types of freight.

//

// Examples:

//

// CargoUnit

// A physical location on a vehicle that can hold cargo.

//

// TransportOrder

// A movement of goods from one place to another.

//

// SiteAsset

// A storage unit or infrastructure element at a site.

//

// CargoMath

// Shared calculations involving:

//

// • quantity

// • mass

// • fill percentage

// • capacity

//

// These concepts allow modules to translate their own

// vocabulary into shared transport behaviour.

  

  

// ------------------------------------------------------------

// EXAMPLE VOCABULARY MAPPING

// ------------------------------------------------------------

//

// Transport concept → Fuel module translation

//

// CargoUnit       → Compartment

// SiteAsset       → Tank

// TransportOrder  → Delivery / Load / Transfer

//

// Other modules will translate differently:

//

// CargoUnit       → Pallet Slot

// CargoUnit       → Livestock Pen

// CargoUnit       → Container Position

  

  

// ------------------------------------------------------------

// DESIGN PRINCIPLE

// ------------------------------------------------------------

//

// Core must never "know about fuel".

//

// Instead:

//

// Core

//   ↕

// Transport concepts

//   ↕

// Module vocabulary

  

  

// ------------------------------------------------------------

// CURRENT STATUS

// ------------------------------------------------------------

//

// The current codebase still contains fuel-specific models

// in the main Models area.

//

// This is expected during transition.

//

// Over time:

//

// • generic concepts move into Transport

// • fuel-specific models move into Modules/Fuel

  

  

// ------------------------------------------------------------

// FUTURE TRANSPORT MODELS (PLACEHOLDERS)

// ------------------------------------------------------------

//

// CargoUnit.swift

// TransportOrder.swift

// SiteAsset.swift

//

// These may start as simple structs or protocols and grow

// as additional transport modules appear.

  

  

// ------------------------------------------------------------

// FUTURE TRANSPORT LOGIC (PLACEHOLDERS)

// ------------------------------------------------------------

//

// CargoMath.swift

// TransportWorkflow.swift

//

// These hold shared behaviours independent of cargo type.

  

  

// ------------------------------------------------------------

// IMPORTANT NOTE

// ------------------------------------------------------------

//

// This file is temporary and exists only to document

// architectural intent while the system transitions.

//

// Once the Transport layer stabilises this file may be:

//

// • moved to Resources

// • replaced with formal documentation

// • or removed entirely.

  

  

// ============================================================

// END OF FILE

// ============================================================

```

  

---

  

# VIEWS

  

---

  

## Views/Components/BlendWidget.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Blend Calculator Widget

//======================================

//

// Purpose:

// - Quick helper for common fuel blend calculations

// - B5 (95% ADF + 5% B100)

// - PULP 95 (75% P98 + 25% P91)

//

// Workflow:

// - Driver enters base litres OR target total

// - Widget calculates required additive litres

//

// Design:

// - Self-contained (no AppModel dependency)

// - Embedded in LoadView left panel

// - Pure calculation (no persistence)

//

// Notes:

// - Accepts "18,000" or "18 000" (strips separators)

// - Rounds to whole litres for clarity

//

//======================================

  

struct BlendWidget: View {

    enum BlendMode: String, CaseIterable, Identifiable {

        case b5 = "B5 (ADF + B100)"

        case pulp95 = "PULP 95 (98 + 91)"

        var id: String { rawValue }

    }

    @State private var mode: BlendMode = .b5

    // Inputs support two workflows:

    // 1) "I have base litres"  → calculate additive litres to hit the blend ratio.

    // 2) "I want target total" → calculate both components of the final blend.

    @State private var baseLitresText: String = ""     // Meaning depends on mode: ADF (B5) or P98 (PULP95)

    @State private var targetTotalText: String = ""    // Optional: desired final total litres

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Blend calculator")

                .font(.headline)

            Picker("Blend", selection: $mode) {

                ForEach(BlendMode.allCases) { m in

                    Text(m.rawValue).tag(m)

                }

            }

            .pickerStyle(.segmented)

            Group {

                if mode == .b5 {

                    // B5 = 95% ADF + 5% B100 (by volume)

                    LabeledTextField(

                        title: "ADF litres you have",

                        placeholder: "e.g. 18000",

                        text: $baseLitresText

                    )

                    LabeledTextField(

                        title: "OR target total litres (optional)",

                        placeholder: "e.g. 19000",

                        text: $targetTotalText

                    )

                    ResultBox(lines: b5Lines())

                } else {

                    // PULP 95 = 75% P98 + 25% P91 (by volume)

                    LabeledTextField(

                        title: "P98 litres you have",

                        placeholder: "e.g. 3000",

                        text: $baseLitresText

                    )

                    LabeledTextField(

                        title: "OR target total litres of P95 (optional)",

                        placeholder: "e.g. 8000",

                        text: $targetTotalText

                    )

                    ResultBox(lines: pulp95Lines())

                }

            }

        }

        .padding()

        .background(Color.gray.opacity(0.06))

        .cornerRadius(12)

        .onChange(of: mode) { _, _ in

            // Reset inputs when switching modes to avoid “wrong meaning” confusion.

            baseLitresText = ""

            targetTotalText = ""

        }

    }

    // MARK: - Maths

    private func b5Lines() -> [String] {

        let adf = parseLitres(baseLitresText)

        let targetTotal = parseLitres(targetTotalText)

        // Option 1: user has ADF litres, compute B100 to add so final is B5.

        // If final blend must be 95% ADF and 5% B100:

        // B100 = ADF * (0.05 / 0.95)

        if adf > 0 && targetTotal <= 0 {

            let b100 = adf * (0.05 / 0.95)

            let total = adf + b100

            return [

                "Add B100: \(fmt0(b100)) L",

                "Final total: \(fmt0(total)) L",

                "Check: B100 fraction ≈ 5%"

            ]

        }

        // Option 2: user wants a target total, compute both parts.

        // If target total is provided, it takes precedence over "base litres".

        // ADF = 95% of total, B100 = 5% of total

        if targetTotal > 0 {

            let adfNeed = targetTotal * 0.95

            let b100Need = targetTotal * 0.05

            return [

                "ADF in final: \(fmt0(adfNeed)) L",

                "B100 in final: \(fmt0(b100Need)) L"

            ]

        }

        return ["Enter ADF litres OR a target total."]

    }

    private func pulp95Lines() -> [String] {

        let p98 = parseLitres(baseLitresText)

        let targetTotal = parseLitres(targetTotalText)

        // PULP95 recipe: 75% P98 + 25% P91

        // If user has P98, compute required P91:

        // P98 / Total = 0.75 => Total = P98 / 0.75; P91 = Total - P98

        if p98 > 0 && targetTotal <= 0 {

            let total = p98 / 0.75

            let p91 = total - p98

            return [

                "Add P91: \(fmt0(p91)) L",

                "Final P95 total: \(fmt0(total)) L",

                "Ratio: 98 ≈ 75% / 91 ≈ 25%"

            ]

        }

        // If target total is provided, it takes precedence over "base litres".

        // If target total is provided, compute both components:

        if targetTotal > 0 {

            let p98Need = targetTotal * 0.75

            let p91Need = targetTotal * 0.25

            return [

                "P98 required: \(fmt0(p98Need)) L",

                "P91 required: \(fmt0(p91Need)) L"

            ]

        }

        return ["Enter P98 litres OR a target total."]

    }

    // MARK: - Parsing / formatting

    /// Accepts common driver inputs like "18,000" or "18 000".

    private func parseLitres(_ s: String) -> Double {

        let cleaned = s

            .replacingOccurrences(of: ",", with: "")

            .replacingOccurrences(of: " ", with: "")

            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(cleaned) ?? 0

    }

    private func fmt0(_ v: Double) -> String {

        String(Int(round(v)))

    }

}

  

  

// MARK: - Small helpers (keeps widget self-contained)

  

private struct LabeledTextField: View {

    let title: String

    let placeholder: String

    @Binding var text: String

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(title).font(.subheadline)

            TextField(placeholder, text: $text)

                .keyboardType(.decimalPad)

                .textFieldStyle(.roundedBorder)

        }

    }

}

  

private struct ResultBox: View {

    let lines: [String]

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            ForEach(lines, id: \.self) { line in

                Text("• \(line)")

                    .font(.caption)

                    .foregroundColor(.secondary)

            }

        }

        .padding(.top, 4)

    }

}

```

  

---

  

## Views/Components/Bundle+Version.swift

  

```swift

import Foundation

  

//======================================

// MARK: - Bundle+Version.swift

//======================================

// 

// potentially redundant file . meant to provide version number when patchlog unavailable.

  

  

extension Bundle {

    /// CFBundleShortVersionString (e.g. "0.2.1")

    var releaseVersionNumber: String {

        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"

    }

    /// CFBundleVersion (e.g. "103")

    var buildVersionNumber: String {

        infoDictionary?["CFBundleVersion"] as? String ?? "—"

    }

}

```

  

---

  

## Views/Components/DGPlacardView.swift

  

```swift

import SwiftUI

//======================================

// MARK: - DGPlacardView.swift

//======================================

// 

// NOTE:

// Placard layout intentionally prioritises correctness & legibility over

// perfect typographic balance.

// Fine-grain spacing / tightening is deferred to Phase 4 cosmetics.

// Do NOT reintroduce nested borders or fixed heights without revisiting aspect math.

  

struct DGPlacardView: View {

    @EnvironmentObject var model: AppModel

    private var decision: DGPlacardDecision { model.displayedDGPlacardDecision }

    // Single source of truth for layout constants

    private let border: CGFloat = 3

    private let aspect: CGFloat = 700.0 / 410.0

    private let diamondWidth: CGFloat = 200

    var body: some View {

        GeometryReader { geo in

            let w = geo.size.width

            let h = w / aspect

            let topH = h * (250.0 / 410.0)

            let bottomH = h * (160.0 / 410.0)

            ZStack(alignment: .topLeading) {

                Color.white

                VStack(spacing: 0) {

                    topHalf

                        .frame(height: topH)

                    // Single horizontal divider between top + bottom

                    Rectangle()

                        .fill(Color.black)

                        .frame(height: border)

                    bottomHalf

                        .frame(height: bottomH)

                }

                .frame(width: w, height: h, alignment: .topLeading)

                .clipped()

            }

            // One outer border only

            .overlay(

                Rectangle().stroke(Color.black, lineWidth: border)

            )

            .frame(width: w, height: h, alignment: .topLeading)

        }

        .aspectRatio(aspect, contentMode: .fit)

        .accessibilityLabel(accessibilityText)

    }

    //======================================

    // MARK: - TOP HALF

    //======================================

    @ViewBuilder

    private var topHalf: some View {

        switch decision {

        case .combustibleLiquid:

            // Full width, no diamond column (diesel-only case in AU practice).

            VStack(spacing: 6) {

                Text("COMBUSTIBLE")

                Text("LIQUID")

            }

            .font(.system(size: 52, weight: .bold))

            .fitText(minScale: 0.6, lines: 1)

            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .blankTopHalf, .blankUnknown:

            // `blankUnknown` is used when we don't have enough evidence (pre-persistence or corrupt history).

            // `blankTopHalf` is the explicit "degassed" / suppressed state.

            Color.white

                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .petrol1203(let hazchem):

            topWithDiamond(

                left: unLeftBlock(title: "PETROL", un: "1203", hazchem: hazchem)

            )

        case .petroleumFuel1270(let hazchem):

            topWithDiamond(

                left: unLeftBlock(title: "PETROLEUM FUEL", un: "1270", hazchem: hazchem)

            )

        }

    }

    /// Standard "UN block + Class 3 diamond" layout.

    private func topWithDiamond(left: some View) -> some View {

        HStack(spacing: 0) {

            left

                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Single vertical divider

            Rectangle()

                .fill(Color.black)

                .frame(width: border)

            FlammableLiquidDiamond()

                .frame(width: diamondWidth)

                .frame(maxHeight: .infinity)

        }

    }

    //======================================

    // MARK: - LEFT UN BLOCK

    //======================================

    private func unLeftBlock(title: String, un: String, hazchem: String) -> some View {

        GeometryReader { g in

            let h = g.size.height

            // Row proportions (tweak these 3 numbers if needed)

            let titleH  = h * 0.22

            let unH     = h * 0.39

            let hazH    = h * 0.39

            VStack(spacing: 0) {

                // TITLE ROW (shorter, avoids wasted air)

                Text(title)

                    .font(.system(size: 30, weight: .bold))

                    .fitText(minScale: 0.5, lines: 1)

                    .frame(height: titleH)

                    .frame(maxWidth: .infinity)

                    .padding(.horizontal, 10)

                Rectangle().fill(Color.black).frame(height: border)

                // UN ROW (label + number)

                VStack(spacing: 4) {

                    HStack {

                        Text("UN No.")

                            .font(.system(size: 16))

                        Spacer()

                    }

                    .padding(.horizontal, 12)

                    .padding(.top, 4)

                    Text(un)

                        .font(.system(size: 70, weight: .semibold))

                        .fitText(minScale: 0.6, lines: 1)

                        .padding(.bottom, 2)

                }

                .frame(height: unH)

                Rectangle().fill(Color.black).frame(height: border)

                // HAZCHEM ROW (label + code)

                VStack(spacing: 4) {

                    HStack {

                        Text("HAZCHEM")

                            .font(.system(size: 16))

                        Spacer()

                    }

                    .padding(.horizontal, 12)

                    .padding(.top, 4)

                    Text(hazchem)

                        .font(.system(size: 70, weight: .semibold))

                        .fitText(minScale: 0.6, lines: 1)

                        .padding(.bottom, 2)

                }

                .frame(height: hazH)

            }

        }

    }

    //======================================

    // MARK: - BOTTOM HALF

    //======================================

    private var bottomHalf: some View {

        HStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 6) {

                Text("IN EMERGENCY DIAL")

                    .font(.system(size: 16, weight: .semibold))

                Text("000-POLICE OR\nFIRE BRIGADE")

                    .font(.system(size: 20, weight: .semibold))

                    .fitText(minScale: 0.75, lines: 2)

            }

            .padding(12)

            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()

                .fill(Color.black)

                .frame(width: border)

            VStack(alignment: .leading, spacing: 8) {

                Text("SPECIALIST ADVICE")

                    .font(.system(size: 16, weight: .semibold))

                Text("ISS FIRST RESPONSE")

                    .font(.system(size: 26, weight: .semibold))

                    .fitText(minScale: 0.65, lines: 1)

                Text("   1300 131 001")

                    .font(.system(size: 30, weight: .bold))

                    .fitText(minScale: 0.6, lines: 1)

            }

            .padding(12)

            .frame(minWidth: 260, maxWidth: 320)

            .frame(maxHeight: .infinity, alignment: .leading)

        }

    }

    private var accessibilityText: String {

        switch decision {

        case .petrol1203(let h):         return "Placard PETROL UN 1203 Hazchem \(h)"

        case .petroleumFuel1270(let h):  return "Placard PETROLEUM FUEL UN 1270 Hazchem \(h)"

        case .combustibleLiquid:         return "Placard COMBUSTIBLE LIQUID"

        case .blankTopHalf:              return "Placard blank top half"

        case .blankUnknown:              return "Placard blank top half"

        }

    }

}

  

//======================================

// MARK: - FLAMMABLE DIAMOND

//======================================

  

struct FlammableLiquidDiamond: View {

    var body: some View {

        ZStack {

            DiamondShape()

                .fill(Color.red)

            DiamondShape()

                .stroke(Color.black, lineWidth: 5)

            VStack(spacing: 6) {

                // System flame is good enough for Phase 1/2.

                // If you later want an ADR-perfect flame, swap to `FlameIcon()` (below).

                Image(systemName: "flame.fill")

                    .resizable()

                    .scaledToFit()

                    .foregroundStyle(.black)

                    .frame(width: 46, height: 46)

                    .padding(.top, 4)

                Text("FLAMMABLE\nLIQUID")

                    .font(.system(size: 15, weight: .bold))

                    .multilineTextAlignment(.center)

                    .foregroundColor(.black)

                Text("3")

                    .font(.system(size: 20, weight: .bold))

                    .foregroundColor(.black)

                    .padding(.bottom, 3)

            }

        }

        // IMPORTANT: let the parent size it (don’t hardcode here)

        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .padding(6)

    }

}

  

struct DiamondShape: Shape {

    func path(in rect: CGRect) -> Path {

        var p = Path()

        let midX = rect.midX

        let midY = rect.midY

        p.move(to: CGPoint(x: midX, y: rect.minY))

        p.addLine(to: CGPoint(x: rect.maxX, y: midY))

        p.addLine(to: CGPoint(x: midX, y: rect.maxY))

        p.addLine(to: CGPoint(x: rect.minX, y: midY))

        p.closeSubpath()

        return p

    }

}

  

// DEAD CODE (for now):

// Not referenced anywhere in the UI. Kept as a ready-made “custom flame”

// if you ever decide the SF Symbol isn’t good enough for placard fidelity.

// Safe to delete later.

struct FlameIcon: View {

    var body: some View {

        GeometryReader { geo in

            let w = geo.size.width

            let h = geo.size.height

            Path { p in

                p.move(to: CGPoint(x: 0.5*w, y: 1.0*h))

                p.addCurve(to: CGPoint(x: 0.1*w, y: 0.6*h),

                           control1: CGPoint(x: 0.35*w, y: 0.9*h),

                           control2: CGPoint(x: 0.15*w, y: 0.8*h))

                p.addCurve(to: CGPoint(x: 0.4*w, y: 0.1*h),

                           control1: CGPoint(x: 0.0*w, y: 0.35*h),

                           control2: CGPoint(x: 0.25*w, y: 0.2*h))

                p.addCurve(to: CGPoint(x: 0.6*w, y: 0.0*h),

                           control1: CGPoint(x: 0.45*w, y: 0.05*h),

                           control2: CGPoint(x: 0.55*w, y: 0.0*h))

                p.addCurve(to: CGPoint(x: 0.9*w, y: 0.45*h),

                           control1: CGPoint(x: 0.85*w, y: 0.05*h),

                           control2: CGPoint(x: 0.95*w, y: 0.25*h))

                p.addCurve(to: CGPoint(x: 0.5*w, y: 1.0*h),

                           control1: CGPoint(x: 0.85*w, y: 0.75*h),

                           control2: CGPoint(x: 0.7*w, y: 0.92*h))

                p.closeSubpath()

            }

            .fill(Color.black)

        }

    }

}

```

  

---

  

## Views/Components/FatigueEnginePanel.swift

  

```swift

import SwiftUI

  

struct FatigueEnginePanel: View {

    @Binding var scheme: FatigueScheme

    var segments: [WorkRestSegment]

    var now: Date

    var tz: TimeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

    var body: some View {

        let status = FatigueEngine.evaluate(

            scheme: scheme,

            segments: segments,

            now: now,

            tz: tz

        )

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("Fatigue Engine (Sim Harness)")

                    .font(.headline)

                Spacer()

                // Optional; delete if you don't want it yet

                Picker("", selection: $scheme) {

                    ForEach(FatigueScheme.allCases) { s in

                        Text(s.isAvailableNow ? s.rawValue : "\(s.rawValue) 🔒").tag(s)

                    }

                }

                .pickerStyle(.menu)

            }

            Text("As of: \(now.formatted(date: .abbreviated, time: .shortened))")

                .font(.caption)

                .foregroundStyle(.secondary)

            ForEach(Array(status.cards.enumerated()), id: \.offset) { _, card in

                HStack(alignment: .top, spacing: 12) {

                    Circle()

                        .frame(width: 10, height: 10)

                        .foregroundStyle(color(for: card.severity))

                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 2) {

                        Text(card.title).font(.subheadline).fontWeight(.semibold)

                        Text(card.value).font(.body)

                        if let d = card.detail {

                            Text(d).font(.footnote).foregroundStyle(.secondary)

                        }

                    }

                    Spacer()

                }

            }

            if scheme == .bfmHV {

                Text("BFM extras (long/night 7d + 84h reset) are stubbed for now.")

                    .font(.footnote)

                    .foregroundStyle(.secondary)

            }

        }

        .padding()

        .background(.thinMaterial)

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private func color(for sev: FatigueSeverity) -> Color {

        switch sev {

        case .ok: return .green

        case .warn: return .orange

        case .over: return .red

        case .unavailable: return .gray

        }

    }

}

```

  

---

  

## Views/Components/OdoLocationSheet.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Odometer + Location Capture Sheet

//======================================

//

// Purpose:

// - Single unified sheet for odometer + suburb/location capture

// - Replaces legacy BreakOdometerSheet (deleted)

//

// Contexts (driven by model.odoPromptContext):

// - .shiftStart: mandatory odo + suburb

// - .legalBreakEnd: mandatory odo + suburb

// - .shiftEnd: mandatory odo + suburb

// - .odoUpdate: mandatory odo, suburb optional

//

// Features:

// - GPS suburb suggestion (via SuburbSuggestionManager)

// - Tap suggested suburb to apply

// - Manual refresh button

// - Numeric-only odo validation

// - Auto-focus odo field on appear

// - Next/Done keyboard toolbar (numberPad safe)

// - Auto-jump to suburb after odo entered (1.4s delay)

//

//======================================

  

struct OdoLocationSheet: View {

    @EnvironmentObject var model: AppModel

    @StateObject private var suburbSuggester = SuburbSuggestionManager()

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case odo, suburb }

    private var ctx: OdoPromptContext? { model.odoPromptContext }

    private var isLocationRequired: Bool { ctx != .odoUpdate }

    @State private var odoJumpTask: Task<Void, Never>?

    private var title: String {

        switch ctx {

        case .shiftStart:     return "Start shift – Odo & Suburb"

        case .legalBreakEnd:  return "Break end – Odo & Suburb"

        case .shiftEnd:       return "End shift – Odo & Suburb"

        case .odoUpdate:      return "Update odo – Odo & Location"

        case nil:             return "Odo & Suburb"

        }

    }

    private var odoTrimmed: String {

        model.odoPromptOdoText.trimmingCharacters(in: .whitespacesAndNewlines)

    }

    private var odoIsNumeric: Bool {

        !odoTrimmed.isEmpty && odoTrimmed.allSatisfy { $0.isNumber }

    }

    private var suburbTrimmed: String {

        model.odoPromptSuburbText.trimmingCharacters(in: .whitespacesAndNewlines)

    }

    private var canSave: Bool {

        guard odoIsNumeric else { return false }

        return isLocationRequired ? !suburbTrimmed.isEmpty : true

    }

    private var locationHeaderText: String {

        isLocationRequired ? "Location" : "Location (optional)"

    }

    private var locationPlaceholder: String {

        isLocationRequired ? "Suburb" : "Suburb (optional)"

    }

    var body: some View {

        NavigationView {

            Form {

                Section(header: Text("Odometer")) {

                    TextField("Odo (km)", text: $model.odoPromptOdoText)

                        .keyboardType(.numberPad)

                        .textInputAutocapitalization(.never)

                        .autocorrectionDisabled()

                        .focused($focusedField, equals: .odo)

                        .foregroundStyle((!odoTrimmed.isEmpty && !odoIsNumeric) ? .red : .primary)

                    if let suggested = model.suggestedOdoFromGps {

                        let entered = Int(odoTrimmed)

                        let diff: Int? = entered.map { $0 - suggested }

                        HStack {

                            Text("Suggested:")

                                .foregroundStyle(.secondary)

                            Text("\(suggested)")

                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {

                                model.odoPromptOdoText = "\(suggested)"

                                focusedField = isLocationRequired ? .suburb : nil

                            } label: {

                                Label("Apply", systemImage: "arrow.down.circle")

                                    .labelStyle(.titleAndIcon)

                                    .foregroundStyle(.secondary)

                            }

                            .buttonStyle(.borderless)

                        }

                        if let diff {

                            Text("Difference: \(diff >= 0 ? "+" : "")\(diff) km")

                                .font(.caption2)

                                .foregroundStyle(.secondary)

                        }

                    }

                    if !odoTrimmed.isEmpty && !odoIsNumeric {

                        Text("Odometer must be numbers only.")

                            .font(.caption)

                            .foregroundStyle(.red)

                    }

                }

                Section(header: Text(locationHeaderText)) {

                    // Suggested suburb (grey), tap-to-apply

                    if let suggestion = suburbSuggester.suggestedSuburb, !suggestion.isEmpty {

                        HStack {

                            Text("Suggested:")

                                .foregroundStyle(.secondary)

                            Text(suggestion)

                                .foregroundStyle(.secondary)

                            Spacer()

                            Image(systemName: "arrow.down.circle")

                                .foregroundStyle(.secondary)

                        }

                        .contentShape(Rectangle())

                        .onTapGesture {

                            model.odoPromptSuburbText = suggestion

                            focusedField = nil

                        }

                    } else if suburbSuggester.isFetching {

                        HStack {

                            ProgressView()

                            Text("Finding suburb…")

                                .foregroundStyle(.secondary)

                        }

                    } else if isLocationRequired {

                        Text("No GPS suburb suggestion available.")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                    TextField(locationPlaceholder, text: $model.odoPromptSuburbText)

                        .textInputAutocapitalization(.words)

                        .autocorrectionDisabled()

                        .focused($focusedField, equals: .suburb)

                    Button {

                        suburbSuggester.refresh()

                    } label: {

                        Label("Refresh GPS suggestion", systemImage: "location.circle")

                            .foregroundStyle(.secondary)

                    }

                    .buttonStyle(.borderless)

                }

            }

            .navigationTitle(title)

            .toolbar {

                ToolbarItem(placement: .confirmationAction) {

                    Button("Save") { model.commitOdoCapture() }

                        .disabled(!canSave)

                }

                // ✅ Keyboard accessory: works even with .numberPad (no Return key)

                ToolbarItemGroup(placement: .keyboard) {

                    Spacer()

                    if focusedField == .odo {

                        Button("Next") {

                            focusedField = isLocationRequired ? .suburb : nil

                        }

                        .disabled(!odoIsNumeric)

                    } else {

                        Button("Done") {

                            focusedField = nil

                        }

                    }

                }

            }

        }

        .presentationDetents([.medium])

        .presentationDragIndicator(.visible)

        .interactiveDismissDisabled(true)

        .scrollDismissesKeyboard(.interactively)

        .onAppear {

            // ✅ reliable focus after sheet animation

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {

                focusedField = .odo

            }

            suburbSuggester.refresh()

        }

        .onChange(of: model.odoPromptOdoText) { _, _ in

            guard isLocationRequired else { return }

            guard odoIsNumeric else { return }

            guard focusedField == .odo else { return }

            odoJumpTask?.cancel()

            odoJumpTask = Task {

                try? await Task.sleep(nanoseconds: 1_400_000_000) // 1.4s pause

                if !Task.isCancelled {

                    focusedField = .suburb

                }

            }

        }

    }

}

```

  

---

  

## Views/Components/PlannerCard.swift

  

```swift

import SwiftUI

import Foundation

  

//======================================

// MARK: - Phase 1 Start Planner Card (Pre-Persistence Proxy)

//======================================

//

// Purpose:

// - "Plan next start" helper for drivers

// - Uses Phase 1 back-calc logic (AppModel.phase1_backCalculateFinish)

//

// Scope (pre-persistence):

// - Today-only rest proxy (not true rolling 24h)

// - Conservative heuristic (7h continuous rest + 12h total rest target)

// - Advisory only (no enforcement)

//

// Post-persistence evolution:

// - Will use real multi-day fatigue windows

// - True rolling 24h rest requirements

// - May move to Simulation screen (out of TodayView)

//

// Usage:

// - Shown in simulationview  at any time.

// - Lets driver pick desired start time → shows latest finish time

//

//======================================

  

struct Phase1StartPlannerCard: View {

  

    @EnvironmentObject var model: AppModel

    @State private var targetStart: Date = {

        let now = Date()

        return Calendar.current.date(bySettingHour: 4, minute: 0, second: 0, of: now) ?? now

    }()

    private var planningResult: Phase1StartPlanning? {

        model.phase1_backCalculateFinish(desiredStart: targetStart)

    }

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Plan next start (Phase 1 proxy)")

                .font(.headline)

            DatePicker(

                "Desired start time",

                selection: $targetStart,

                displayedComponents: [.hourAndMinute]

            )

            .datePickerStyle(.compact)

            if let planning = planningResult {

                VStack(alignment: .leading, spacing: 4) {

                    Text("To start at: \(formatTimeShort(targetStart))")

                        .font(.subheadline)

                    Text("Latest legal finish: \(formatTimeShort(planning.latestFinishToStartAtDesired))")

                        .font(.caption)

                    Text("Rest today (≥15m): \(formatTimeHM(planning.restToday))")

                        .font(.caption2)

                        .foregroundColor(.secondary)

                    if planning.requiredRestAfterShift > 0 {

                        Text("Rest needed after finish: \(formatTimeHM(planning.requiredRestAfterShift))")

                            .font(.caption2)

                            .foregroundColor(.secondary)

                    } else {

                        Text("No additional rest required after finish (based on rest banked today).")

                            .font(.caption2)

                            .foregroundColor(.secondary)

                    }

                }

                .padding(.top, 6)

            }

        }

        .padding()

        .background(Color.gray.opacity(0.06))

        .cornerRadius(12)

    }

    private func formatTimeHM(_ seconds: TimeInterval) -> String {

        let s = max(0, Int(seconds))

        let h = s / 3600

        let m = (s % 3600) / 60

        return String(format: "%dh %02dm", h, m)

    }

    private func formatTimeShort(_ date: Date) -> String {

        let f = DateFormatter()

        f.timeStyle = .short

        f.dateStyle = .none

        return f.string(from: date)

    }

}

```

  

---

  

## Views/Partials/Journal+LogSheet.swift

  

```swift

import SwiftUI

  

// future planning

```

  

---

  

## Views/Partials/Journal+MapReplaySheet.swift

  

```swift

import SwiftUI

  

// future planning

```

  

---

  

## Views/Partials/LoadView+LeftPanel.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Load Screen Left Panel

//======================================

//

// Purpose:

// - Left side of LoadView split layout

// - Contains mode picker, templates, quick actions, header fields, compartment grid

//

// Ownership:

// - This is a PARTIAL of LoadPlanView (not a standalone screen)

// - Shares @EnvironmentObject and @FocusState.Binding with parent

//

// Responsibilities:

// - Mode toggle (Load plan vs Unload planning)

// - Template application

// - Quick actions (Deliver / Full Unload / Degas)

// - Header fields (Load Code, Terminal, Vehicle, Driver)

// - Compartment editing grid (product picker + litres)

// - SG adjustment sliders (per product)

//

// Design notes:

// - Compartment edits auto-trigger activity segment switching (context-based)

// - Delivery sheet is a modal launched from here

// - Blend helper widget embedded in left panel

//

//======================================

  

struct LoadLeftPanel: View {

    @EnvironmentObject var model: AppModel

    @FocusState.Binding var focusedField: LoadPlanView.Field?

    @State private var showDeliverySheet = false

    @State private var showFillTruckSheet = false

    var body: some View {

        Form {

            modeSection

            modeHelpSection

            quickActionsSection

            terminalHeaderSection

            blendSection

            truckInfoSection

            sgSection

            compartmentsSection

        }

        .onChange(of: focusedField) { _, newFocus in

            guard newFocus != nil else { return }

            let expected = model.isUnloadMode ? ActivityType.workUnload : ActivityType.workLoad

            if model.currentActivity != expected {

                model.promptToSwitchSegmentForEditing(to: expected)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusedField = nil }

            }

        }

        .sheet(isPresented: $showDeliverySheet) {

            DeliverySheetView().environmentObject(model)

        }

        .sheet(isPresented: $showFillTruckSheet) {

            FillTruckSheet().environmentObject(model)

        }

    }

}

  

// MARK: - Sections (split for compiler sanity)

  

private extension LoadLeftPanel {

    var modeSection: some View {

        Picker("Mode", selection: $model.isUnloadMode) {

            Text("Load plan").tag(false)

            Text("Unload planning").tag(true)

        }

        .pickerStyle(.segmented)

        .onChange(of: model.isUnloadMode) { _, newValue in

            model.handleModeToggleAttempt(newIsUnloadMode: newValue)

        }

    }

    var modeHelpSection: some View {

        Section {

            Text(model.isUnloadMode

                 ? "UNLOAD PLANNING: Enter remaining litres or use Record delivery. Placard updates as remaining changes."

                 : "LOAD PLAN: Draft your load. Placard should reflect LAST CONFIRMED until you press Confirm.")

            .font(.caption)

            .foregroundColor(model.isUnloadMode ? .orange : .blue)

        }

    }

    var quickActionsSection: some View {

        Section(header: Text("Quick actions & templates")) {

            if model.isUnloadMode {

                Button("Record Partial delivery") { showDeliverySheet = true }

                    .buttonStyle(.borderedProminent)

                Button("Full unload (clear litres)") { model.fullUnload() }

                    .buttonStyle(.bordered)

                Button("Degassed (clear all)") { model.degasTruck() }

                    .buttonStyle(.borderedProminent)

                    .tint(.red)

            } else {

                Button("Fill Truck") { showFillTruckSheet = true }

                    .buttonStyle(.borderedProminent)

                Text("Record partial load at this terminal (multi-stop loading)")

                    .font(.caption2)

                    .foregroundColor(.secondary)

                Divider()

                templateMenus

            }

        }

    }

    @ViewBuilder

    var templateMenus: some View {

        if model.savedTemplates.isEmpty && model.typicalLoadTemplates.isEmpty {

            Text("No templates yet.")

                .font(.caption)

                .foregroundColor(.secondary)

        } else {

            if !model.savedTemplates.isEmpty {

                Menu("Apply template") {

                    ForEach(model.savedTemplates) { t in

                        Button(t.name) { model.applyTemplateToLoadPlan(t) }

                    }

                }

                Text("Applies a saved template from Simulation.")

                    .font(.caption2)

                    .foregroundColor(.secondary)

            }

            if !model.typicalLoadTemplates.isEmpty {

                Menu("Apply typical load") {

                    ForEach(model.typicalLoadTemplates) { template in

                        Button(template.name) { model.applyTypicalLoad(template) }

                    }

                }

                Text("Applies a built-in pattern (temporary until persistence).")

                    .font(.caption2)

                    .foregroundColor(.secondary)

            }

        }

    }

    var terminalHeaderSection: some View {

        Section("Terminal") {

            TextField("Load code", text: $model.loadCode)

                .keyboardType(.numberPad)

                .focused($focusedField, equals: .loadCode)

                .onChange(of: model.loadCode) { _, _ in

                    model.resolveLoadCodeAutofill()

                }

            if !model.loadAccountCandidates.isEmpty {

                Picker("Account", selection: accountSelection) {

                    Text("— choose —").tag(UUID?.none)

                    ForEach(model.loadAccountCandidates) { acct in

                        Text(accountRowText(for: acct))

                            .tag(UUID?.some(acct.id))

                    }

                }

            } else {

                HStack { Text("Supplier"); Spacer(); Text(model.supplierNameDisplay).foregroundColor(.secondary) }

                HStack { Text("Terminal");  Spacer(); Text(model.terminalNameDisplay).foregroundColor(.secondary) }

                HStack { Text("Role");      Spacer(); Text(model.billingRoleDisplay).foregroundColor(.secondary) }

                if let hint = model.loadAccountResolveHint {

                    Text(hint).font(.caption).foregroundColor(.orange)

                }

            }

            TextField("Vehicle ID", text: $model.vehicleId)

                .focused($focusedField, equals: .vehicleId)

            TextField("Driver", text: $model.settings.driverName)

                .focused($focusedField, equals: .driverName)

        }

    }

    func accountRowText(for acct: LoadAccount) -> String {

        let termShort = model.terminals.first(where: { $0.id == acct.terminalID })?.shortName ?? "—"

        return "\(acct.label) • \(acct.billingRole.rawValue) • \(termShort)"

    }

    var accountSelection: Binding<UUID?> {

        Binding(

            get: { model.resolvedLoadAccountID },

            set: { newID in

                model.resolvedLoadAccountID = newID

                guard let newID,

                      let chosen = model.loadAccounts.first(where: { $0.id == newID }) else { return }

                model.resolvedTerminalID = chosen.terminalID

                model.terminalName = model.terminalNameDisplay // bridge

                model.loadAccountCandidates = []

                model.loadAccountResolveHint = nil

            }

        )

    }

    var blendSection: some View {

        Section(header: Text("Blend helper")) { BlendWidget() }

    }

    var truckInfoSection: some View {

        Section(header: Text("Truck 92 – Load Plan")) {

            Text("Safe fills per compartment (SFL) are fixed for this truck.")

                .font(.caption)

                .foregroundColor(.secondary)

                .fixedSize(horizontal: false, vertical: true)

        }

    }

    var sgSection: some View {

        Section(header: Text("SG (per product)")) {

            let usedCodes = Set(model.compartments.compactMap { $0.selectedProduct?.code })

            let selectedProducts = FuelProducts.all.filter { usedCodes.contains($0.code) }

            if selectedProducts.isEmpty {

                Text("Select products below to adjust SG.")

                    .font(.caption)

                    .foregroundColor(.secondary)

            } else {

                ForEach(selectedProducts, id: \.id) { product in

                    SGRow(product: product)

                        .environmentObject(model)

                }

            }

        }

    }

    var compartmentsSection: some View {

        Section(header: Text("Compartments (match paper sheet)")) {

            ForEach(model.compartments.indices, id: \.self) { index in

                CompartmentRow(index: index, isUnloadMode: model.isUnloadMode, focusedField: $focusedField)

                    .environmentObject(model)

            }

        }

    }

}

  

// MARK: - Subviews

  

private struct SGRow: View {

    @EnvironmentObject var model: AppModel

    let product: Product

    var body: some View {

        VStack(alignment: .leading, spacing: 4) {

            Text("\(product.shortName) SG").font(.subheadline)

            let binding = Binding<Double>(

                get: { model.sg(for: product) },

                set: { model.setSg($0, for: product) }

            )

            Slider(value: binding, in: product.sgMin...product.sgMax, step: 0.0001)

            HStack {

                Text(String(format: "Min %.4f", product.sgMin)).font(.caption2).foregroundColor(.secondary)

                Spacer()

                Text(String(format: "Current %.4f", model.sg(for: product))).font(.caption)

                Spacer()

                Text(String(format: "Max %.4f", product.sgMax)).font(.caption2).foregroundColor(.secondary)

            }

        }

        .padding(.vertical, 4)

    }

}

  

private struct CompartmentRow: View {

    @EnvironmentObject var model: AppModel

    let index: Int

    let isUnloadMode: Bool

    let focusedField: FocusState<LoadPlanView.Field?>.Binding

    var body: some View {

        VStack(alignment: .leading) {

            HStack {

                Text(model.compartments[index].name).font(.headline)

                Spacer()

                Text("SFL \(model.compartments[index].capacityLitres) L")

                    .font(.caption)

                    .foregroundColor(.secondary)

            }

            Picker("Product", selection: productCodeBinding) {

                Text("None").tag(String?.none)

                ForEach(FuelProducts.all, id: \.code) { product in

                    Text(product.name).tag(String?.some(product.code))

                }

            }

            .pickerStyle(.menu)

            HStack {

                Text(isUnloadMode ? "Remaining L" : "Litres")

                TextField("0", text: litresBinding)

                    .keyboardType(.numberPad)

                    .focused(focusedField, equals: .litres(index))

            }

        }

        .padding(.vertical, 4)

    }

    var productCodeBinding: Binding<String?> {

        Binding(

            get: { model.compartments[index].selectedProduct?.code },

            set: { newCode in

                if let code = newCode,

                   let p = FuelProducts.all.first(where: { $0.code == code }) {

                    model.compartments[index].selectedProduct = p

                } else {

                    model.compartments[index].selectedProduct = nil

                }

            }

        )

    }

    var litresBinding: Binding<String> {

        Binding(

            get: { model.compartments[index].litresText },

            set: { newValue in

                let digits = newValue.filter { $0.isNumber }

                if digits.isEmpty {

                    model.compartments[index].litresText = ""

                    return

                }

                let typed = Int(digits) ?? 0

                let sfl = model.compartments[index].capacityLitres

                let clamped = min(typed, sfl)

                model.compartments[index].litresText = String(clamped)

                if clamped > 0 { model.compartments[index].isDegassed = false }

            }

        )

    }

}

```

  

---

  

## Views/Partials/LoadView+Sheet.swift

  

```swift

import SwiftUI

//======================================

// MARK: - Loadview+Sheet.swift

//======================================

//

//  Read-only, print-style summary of the current load or unload plan.

//

//  This view:

//  • Presents the authoritative snapshot of the *current draft* load plan

//  • Combines compartment truth, totals, axle loading and DG placarding

//  • Allows the driver to explicitly CONFIRM a load into immutable history

//

//  This view deliberately:

//  • Does NOT allow editing (all edits happen in the left panel)

//  • Does NOT enforce compliance (visual guidance only)

//  • Assumes it sits under EnvironmentObject(AppModel)

//

//  Think of this as the “paper sheet you’d hand to someone”,

//  rendered live from the model.

  

struct LoadSheetView: View {

    @EnvironmentObject var model: AppModel

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 12) {

                headerCard

                compartmentTable

                totalsAndAxlesWithPlacardRow

                confirmedLoadsSection

            }

            .padding()

            .frame(maxWidth: .infinity, alignment: .topLeading)

        }

        .background(Color(.systemBackground))

    }

    //======================================

    // MARK: - Header card (print-ish summary)

    //======================================

    private var headerCard: some View {

        VStack(alignment: .leading, spacing: 4) {

            HStack {

                Text("BFA") // Placeholder logo text (Phase 4: replace with image)

                    .font(.title2)

                    .fontWeight(.bold)

                Spacer()

                Text(model.isUnloadMode ? "Unload Planning (remaining on truck)" : "Load Plan")

                    .font(.headline)

            }

            Divider()

            HStack(alignment: .top) {

                VStack(alignment: .leading, spacing: 2) {

                    Text("Load code: \(model.loadCode)")

                    Text("Terminal: \(model.terminalNameDisplay)")

                    Text("Supplier: \(model.supplierNameDisplay)")

                    Text("Role: \(model.billingRoleDisplay)")

                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {

                    Text("Driver: \(model.settings.driverName)")

                    Text("Vehicle: \(model.vehicleId)")

                    Text("Date: \(formattedToday)")

                }

            }

            .font(.subheadline)

        }

        .padding()

        .background(Color.gray.opacity(0.08))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Compartment table

    //======================================

    private var compartmentTable: some View {

        VStack(alignment: .leading, spacing: 4) {

            Text("Compartments")

                .font(.headline)

            HStack {

                Text("Comp").frame(width: 50, alignment: .leading)

                Text("SFL").frame(width: 60, alignment: .trailing)

                Text("Prod").frame(width: 60, alignment: .leading)

                Text("SG").frame(width: 60, alignment: .trailing)

                Text("Qty L").frame(width: 70, alignment: .trailing)

                Text("Mass kg").frame(width: 80, alignment: .trailing)

            }

            .font(.caption.bold())

            Divider()

            ForEach(model.compartments) { comp in

                let litres = Double(comp.litresText) ?? 0

                let product = comp.selectedProduct

                let productCode = product?.shortName ?? ""

                let sgValue = product.map { model.sg(for: $0) }

                let mass = model.massKg(for: comp)

                HStack {

                    Text(comp.name)

                        .frame(width: 50, alignment: .leading)

                    Text("\(comp.capacityLitres)")

                        .frame(width: 60, alignment: .trailing)

                    Text(productCode)

                        .frame(width: 60, alignment: .leading)

                    if let sg = sgValue {

                        Text(String(format: "%.4f", sg))

                            .frame(width: 60, alignment: .trailing)

                    } else {

                        Text("—")

                            .foregroundColor(.secondary)

                            .frame(width: 60, alignment: .trailing)

                    }

                    if litres > 0 {

                        Text(String(format: "%.0f", litres))

                            .frame(width: 70, alignment: .trailing)

                    } else {

                        Text("—")

                            .foregroundColor(.secondary)

                            .frame(width: 70, alignment: .trailing)

                    }

                    if let mass = mass {

                        Text(String(format: "%.0f", mass))

                            .frame(width: 80, alignment: .trailing)

                    } else {

                        Text("—")

                            .foregroundColor(.secondary)

                            .frame(width: 80, alignment: .trailing)

                    }

                }

                .font(.caption)

            }

        }

        .padding()

        .background(Color.gray.opacity(0.03))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Totals

    //======================================

    private var totalsSection: some View {

        VStack(alignment: .leading, spacing: 4) {

            Text("Totals")

                .font(.headline)

            Text("Total litres: \(model.totalLitres)")

            Text(String(format: "Total mass: %.0f kg", model.totalMassKg))

        }

        .padding()

        .background(Color.gray.opacity(0.03))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Axles (demo colours)

    //======================================

    private var lazyAxleBinding: Binding<Bool> {

        Binding(

            get: { model.lazyAxleIsUp },

            set: { model.lazyAxleIsUp = $0 }

        )

    }

    private var axlesSection: some View {

        let cfg = model.truckConfig

        let steer = model.steerLoadedKg

        let drive = model.driveLoadedKg

        let gvm   = model.gvmLoadedKg

        // UI-only colour helper (not enforcement).

        func colour(for load: Double, limit: Double) -> Color {

            guard limit > 0 else { return .primary }

            let ratio = load / limit

            if ratio > 1.0 { return .red }

            if ratio > 0.9 { return .orange }

            return .primary

        }

        return VStack(alignment: .leading, spacing: 4) {

            if model.truckConfig.hasLazyAxle {

                Toggle("Lazy axle lifted", isOn: lazyAxleBinding)

                    .toggleStyle(.switch)

                    .font(.caption)

            }

            // Running tank slider (stepped; kg-only heuristic)

            // - Drives AppModel.fuelStepIndex (0..6)

            // - fuelFraction is computed from that index (read-only)

            VStack(alignment: .leading, spacing: 6) {

                let fullKg = cfg.runTankFullKg

                let runningKg = fullKg * model.fuelFraction

                let missingKg = fullKg * (1.0 - model.fuelFraction)

                HStack {

                    Text("Running tank:")

                        .font(.caption)

                        .foregroundStyle(.secondary)

                    Text("\(model.fuelStepLabel) (≈\(Int(runningKg.rounded())) kg)")

                        .font(.caption)

                        .bold()

                    Spacer()

                    Text("Tare −\(Int(missingKg.rounded())) kg")

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                }

                Slider(

                    value: Binding(

                        get: { Double(model.fuelStepIndex) },

                        set: { model.fuelStepIndex = Int($0.rounded()) }

                    ),

                    in: 0...6,

                    step: 1

                )

                HStack {

                    Text("0")

                    Spacer()

                    Text("1/4")

                    Spacer()

                    Text("1/3")

                    Spacer()

                    Text("1/2")

                    Spacer()

                    Text("2/3")

                    Spacer()

                    Text("3/4")

                    Spacer()

                    Text("FULL")

                }

                .font(.caption2)

                .foregroundStyle(.secondary)

            }

            .padding(.top, 6)

            Text("Axles (demo)")

                .font(.headline)

            HStack {

                Text("Steer").frame(width: 60, alignment: .leading)

                Text(String(format: "%.0f / %.0f kg", steer, cfg.maxSteerKg))

                    .foregroundColor(colour(for: steer, limit: cfg.maxSteerKg))

            }

            .font(.caption)

            HStack {

                Text("Drive").frame(width: 60, alignment: .leading)

                Text(String(format: "%.0f / %.0f kg", drive, cfg.maxDriveKg))

                    .foregroundColor(colour(for: drive, limit: cfg.maxDriveKg))

            }

            .font(.caption)

            HStack {

                Text("GVM").frame(width: 60, alignment: .leading)

                Text(String(format: "%.0f / %.0f kg", gvm, cfg.maxGvmKg))

                    .foregroundColor(colour(for: gvm, limit: cfg.maxGvmKg))

            }

            .font(.caption)

        }

        .padding()

        .background(Color.gray.opacity(0.03))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Totals + Axles + Placard row

    //======================================

    private var totalsAndAxlesWithPlacardRow: some View {

        HStack(alignment: .top, spacing: 16) {

            VStack(alignment: .leading, spacing: 12) {

                totalsSection

                axlesSection

            }

            Spacer()

            // Placard reads model.displayedDGPlacardDecision.

            // Assumes this view sits under the same EnvironmentObject(AppModel).

            DGPlacardView()

                .frame(width: 500) // Phase 4: make responsive for split view / smaller iPads

                .padding(.top, 4)

        }

    }

    //======================================

    // MARK: - Confirmed loads list

    //======================================

    private var confirmedLoadsSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            HStack {

                Text("Confirmed loads (today)")

                    .font(.headline)

                Spacer()

                // This is the ONE place the draft becomes "authoritative history".

                Button("Confirm this load") {

                    // Tier 3 Confirm Guard: ALWAYS verify segment before confirming

                    let expectedSegment = model.isUnloadMode ? ActivityType.workUnload : ActivityType.workLoad

                    if model.currentActivity != expectedSegment {

                        // Wrong segment — block and prompt

                        model.presentSegmentMismatchBlocker(expected: expectedSegment)

                    } else {

                        // Correct segment — allow confirm

                        model.confirmCurrentLoad()

                    }

                }

                .font(.subheadline)

                .buttonStyle(.borderedProminent)

                .disabled(!model.canConfirmCurrentLoad)

                .opacity(model.canConfirmCurrentLoad ? 1.0 : 0.35)

            }

            if !model.canConfirmCurrentLoad {

                Text("No changes since last confirmed load.")

                    .font(.caption2)

                    .foregroundColor(.secondary)

            }

            if model.confirmedLoads.isEmpty {

                Text("No loads confirmed yet.")

                    .font(.caption)

                    .foregroundColor(.secondary)

            } else {

                ForEach(model.confirmedLoads) { load in

                    DisclosureGroup {

                        // Expanded: per-compartment truth at that moment

                        VStack(alignment: .leading, spacing: 6) {

                            HStack {

                                Text("Comp").font(.caption.bold())

                                Spacer()

                                Text("Prod").font(.caption.bold())

                                Spacer()

                                Text("L").font(.caption.bold())

                                Spacer()

                                Text("kg").font(.caption.bold())

                            }

                            .foregroundColor(.secondary)

                            ForEach(load.compartments) { line in

                                HStack {

                                    Text(line.name)

                                        .font(.caption)

                                        .frame(width: 40, alignment: .leading)

                                    Spacer()

                                    Text(line.productShort)

                                        .font(.caption)

                                        .frame(width: 60, alignment: .leading)

                                    Spacer()

                                    Text(formatLitres(line.litres))

                                        .font(.caption)

                                        .frame(width: 60, alignment: .trailing)

                                    Spacer()

                                    Text(formatKg(line.massKg))

                                        .font(.caption)

                                        .frame(width: 80, alignment: .trailing)

                                }

                            }

                        }

                        .padding(.top, 6)

                    } label: {

                        // Collapsed summary

                        VStack(alignment: .leading, spacing: 2) {

                            HStack {

                                Text(loadHeader(load))

                                    .font(.caption.bold())

                                Spacer()

                                Text(load.mode.rawValue)

                                    .font(.caption2.bold())

                                    .padding(.horizontal, 8)

                                    .padding(.vertical, 3)

                                    .background(load.mode == .loadConfirmed

                                                ? Color.blue.opacity(0.15)

                                                : Color.orange.opacity(0.18))

                                    .cornerRadius(8)

                            }

                            Text(String(format: "Total: %d L, %.0f kg",

                                        load.totalLitres, load.totalMassKg))

                            .font(.caption)

                            Text(String(format: "Axles S/D/G: %.0f / %.0f / %.0f kg",

                                        load.steerKg, load.driveKg, load.gvmKg))

                            .font(.caption2)

                            .foregroundColor(.secondary)

                        }

                        .padding(.vertical, 4)

                    }

                    Divider()

                }

            }

        }

        .padding()

        .background(Color.gray.opacity(0.03))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Small helpers

    //======================================

    private func loadHeader(_ load: ConfirmedLoad) -> String {

        // Phase 4: hoist DateFormatter to static if this ever becomes hot.

        let df = DateFormatter()

        df.timeStyle = .short

        df.dateStyle = .none

        return "\(df.string(from: load.timestamp)) – \(load.terminalName) \(load.loadCode)"

    }

    private var formattedToday: String {

        // Phase 4: hoist DateFormatter to static if this ever becomes hot.

        let df = DateFormatter()

        df.dateStyle = .short

        df.timeStyle = .none

        return df.string(from: Date())

    }

}

  

private func formatLitres(_ litres: Double) -> String {

    String(format: "%.0f", litres)

}

  

private func formatKg(_ kg: Double) -> String {

    String(format: "%.0f", kg)

}

```

  

---

  

## Views/Partials/TodayView+Actions.swift

  

```swift

import SwiftUI

  

extension TodayView {

    //======================================

    // MARK: - Todayview+Actions block

    //

    // Primary on-duty driver actions shown on TodayView.

    // This view is intentionally "dumb UI":

    // - It reflects current AppModel state

    // - It delegates all business logic to AppModel

    // - It does NOT enforce fatigue or NHVR rules itself

    //

    // Updated (segment/state catches):

    // - All actions funnel through AppModel.request(...)

    //   so AppModel can coach/guard impossible combos.

    //

    // Pre-persistence scope:

    // - Coaching prompts only (no blocking)

    // - No persistent record of prompt responses

    // - Driver always has final say

    //

    // Post-persistence evolution:

    // - May create advisory events ("user overrode prompt")

    // - Still never blocks actions

    //

    //======================================

    var actionsBlock: some View {

  

        VStack(spacing: 8) {

            if model.isOnDuty {

                let columns = [GridItem(.flexible()), GridItem(.flexible())]

                LazyVGrid(columns: columns, spacing: 8) {

                    // DRIVE (press-style)

                    Button {

                        model.request(.drive)

                    } label: {

                        Text(model.isDriving ? "Driving" : "Drive")

                            .frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.borderedProminent)

                    .disabled(!model.canPressDrive)   // IMPORTANT: no toggling in UI anymore

                    // BREAK (press-style)

                    Button {

                        model.request(.breakTime)

                    } label: {

                        Text(model.isOnBreak ? "On Break" : "Break")

                            .frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.borderedProminent)

                    .disabled(!model.canPressBreak)   // IMPORTANT

                    // LOAD / UNLOAD (guarded; AppModel decides)

                    Button {

                        model.request(.load)

                        // optional: switch tabs / navigate to LoadView later

                    } label: {

                        Text("Load").frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.bordered)

                    .disabled(!model.canPressLoad)

                    Button {

                        model.request(.unload)

                        // optional: switch tabs / navigate to LoadView later

                    } label: {

                        Text("Unload").frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.bordered)

                    .disabled(!model.canPressUnload)

                    // INCIDENT (event only for now; still route via guard for consistency)

                    Button {

                        model.openIncidentSheet()

                    } label: {

                        Text("Incident").frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.bordered)

                    // OTHER (sheet; selection should call model.request(.startOther(...)))

                    Button {

                        showingOtherSheet = true

                    } label: {

                        Text("Other").frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.bordered)

                }

                .font(.footnote)

            }

        }

    }

}

```

  

---

  

## Views/Partials/TodayView+Fatigue.swift

  

```swift

import SwiftUI

  

extension TodayView {

    //======================================

    // MARK: - Todayview+Fatigue dashboard (right column)

    //

    // Purpose:

    // - Render *today* fatigue indicators using AppModel's current segments.

    //

    // Important constraints (pre-persistence):

    // - These are day-scoped proxies (NOT true rolling windows).

    // - Labels explicitly say "proxy" where NHVR rules are normally rolling.

    // - UI should avoid implying legal compliance guarantees.

    //

    // NOTE ON ICON SEMANTICS:

    // - For 5h15 spacing:

    //   - Grey circle = no ≥15m legal rest logged yet today.

    //   - Green tick = compliant so far since the last ≥15m legal rest.

    //   - Red = breached (worked ≥5h15 since last ≥15m legal rest). post-persistence.

    //======================================

    var workWindowSection: some View {

        let workToday = model.nhvrWorkSecondsToday

        let legalRest = model.totalLegalRestToday

        let inRestLimbo15 = model.isInRestLimbo15

        let limboRemaining15 = model.secondsUntilLegal15

        let hasTakenLegalRest15 = legalRest >= FatigueConstants.legalBreak15

        let twelveHours: TimeInterval = FatigueConstants.nhvrDailyCap

        // NHVR spacing proxy: work since last >=15m legal rest

        let workSinceLegalRest15 = model.nhvrWorkSecondsSinceLastLegalRest(minBreak: FatigueConstants.legalBreak15)

        let ratio = min(workToday / twelveHours, 1.0)

        let elevenHours: TimeInterval = CountdownThresholds.dailyCapWarningThreshold

        let colour: Color

        if workToday <= elevenHours { colour = .green }

        else if workToday <= twelveHours { colour = .orange }

        else { colour = .red }

        return VStack(alignment: .leading, spacing: 12) {

            Text("Fatigue (today • proxy pre-persistence)")

                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {

                HStack {

                    Text("Work today (total NHVR proxy)")

                        .font(.subheadline)

                    Spacer()

                    Text("\(formatTimeHM(workToday)) / 12h 00m")

                        .font(.caption)

                }

                ProgressView(value: ratio)

                    .tint(colour)

                HStack {

                    Text("Total work towards 12h daily cap.")

                    let remaining = max(twelveHours - workToday, 0)

                    Spacer()

                    Text("Remaining: \(formatTimeHM(remaining))")

                }

                .font(.caption2)

                .foregroundColor(.secondary)

            }

            Divider()

                .padding(.vertical, 4)

            // Spacing: true "since last >=15m legal rest" logic (still day-scoped pre-persistence)

            spacingRuleRow(

                title: "5h15 spacing rule (NHVR)",

                description: "Max 5h15 work between ≥15m legal rests.",

                workSinceRest: workSinceLegalRest15,

                limitHours: FatigueConstants.nhvrSpacingLimit / 3600,

                hasTakenLegalRest15: hasTakenLegalRest15,

                inRestLimbo15: inRestLimbo15,

                limboRemaining15: limboRemaining15

            )

            ruleStatusRow(

                title: "7h30 threshold (8h window proxy)",

                description: "If ≥7h30 work, you must have ≥30m legal breaks (today proxy).",

                workToday: workToday,

                limitHours: FatigueConstants.nhvrSevenPointFiveHours / 3600,

                requiredRestSeconds: workToday >= FatigueConstants.nhvrSevenPointFiveHours ? FatigueConstants.legalBreak30 : 0,

                legalRest: legalRest,

                inRestLimbo15: inRestLimbo15,

                limboRemaining15: limboRemaining15

            )

            ruleStatusRow(

                title: "10h threshold (11h window proxy)",

                description: "If ≥10h work, you must have ≥60m legal breaks (today proxy).",

                workToday: workToday,

                limitHours: FatigueConstants.nhvrTenHours / 3600,

                requiredRestSeconds: workToday >= FatigueConstants.nhvrTenHours ? FatigueConstants.legalBreak60 : 0,

                legalRest: legalRest,

                inRestLimbo15: inRestLimbo15,

                limboRemaining15: limboRemaining15

            )

            cap12StatusRow(workToday: workToday)

            nextRuleCountdownSection

            Text("Legal rest today (≥15m blocks): \(formatTimeHM(legalRest))")

                .font(.caption2)

                .foregroundColor(.secondary)

                .padding(.top, 4)

        }

    }

    var nextRuleCountdownSection: some View {

        let workToday     = model.nhvrWorkSecondsToday

        let legalRest     = model.totalLegalRestToday

        let inRestLimbo15 = model.isInRestLimbo15

        let limboRemaining15 = model.secondsUntilLegal15

        let workSinceRest = model.nhvrWorkSecondsSinceLastLegalRest(minBreak: FatigueConstants.legalBreak15)

        let next = determineNextRule(

            workSinceRest: workSinceRest,

            workToday: workToday,

            legalRest: legalRest

        )

        let severity = countdownSeverity(

            forRemaining: next.remaining,

            window: next.window

        )

        // NOTE: This ratio is used as a "remaining" bar, not "progress used".

        // (If you later prefer a "time used" bar, invert this maths.)

        let ratio = max(0.0, min(next.remaining / max(next.limit, 1), 1.0))

        let barColor: Color = {

            switch severity {

            case .normal:   return .green

            case .caution:  return .yellow

            case .warning:  return .orange

            case .critical: return .red

            case .breached: return .red

            }

        }()

        let barOpacity: Double =

        (severity == .breached && countdownFlashOn) ? 0.3 : 1.0

        let remaining = next.remaining

        let remainingText = formatTimeHM(abs(remaining))

        let sign = remaining >= 0 ? "" : "-"

        var subtitleText: String

        var subtitleColor: Color

        // --- Rest-state messaging must override severity messaging ---

        // 1) Limbo: break is happening but < 15m → still counts as work for NHVR.

        if inRestLimbo15 {

            subtitleText = "Rest in progress (<15m) — still counts as NHVR work. Legal rest begins counting in \(formatTimeHM(limboRemaining15))."

            subtitleColor = .secondary

        } else {

            // 2) If currently resting AND we've already crossed ≥15m,

            // NHVR work is paused and remaining time can increase.

            // (We infer "currently resting" from currentActivity; avoids needing extra state.)

            let currentlyResting = !model.currentActivity.isWork && model.isOnDuty

            let currentlyLegalResting = currentlyResting && (model.secondsUntilLegal15 <= 0)

            if currentlyLegalResting {

                subtitleText = "Legal rest in progress (≥15m). NHVR work is paused — remaining time may increase while resting."

                subtitleColor = .secondary

            } else {

                // 3) Normal severity-driven messaging

                switch severity {

                case .breached:

                    let ruleName = next.title.replacingOccurrences(of: "Next rule: ", with: "")

                    subtitleText = "\(ruleName) is now due / exceeded. Take legal rest as soon as practicable."

                    subtitleColor = .red

                case .critical:

                    subtitleText = "\(next.descriptionPrefix) in \(remainingText)."

                    subtitleColor = .red

                default:

                    subtitleText = "\(next.descriptionPrefix) in \(remainingText)."

                    subtitleColor = .secondary

                }

            }

        }

        return VStack(alignment: .leading, spacing: 4) {

            HStack {

                Text(next.title)

                    .font(.subheadline)

                Spacer()

                Text("\(sign)\(remainingText) remaining")

                    .font(.caption)

            }

            ProgressView(value: ratio)

                .tint(barColor)

                .opacity(barOpacity)

                .onAppear {

                    updateCountdownFlashing(for: severity)

                }

                .onChange(of: severity, initial: false) { _, newSeverity in

                    updateCountdownFlashing(for: newSeverity)

                }

            Text(subtitleText)

                .font(.caption2)

                .foregroundColor(subtitleColor)

                .fixedSize(horizontal: false, vertical: true)

        }

        .padding(.top, 8)

    }

    func updateCountdownFlashing(for severity: CountdownSeverity) {

        if severity == .breached {

            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {

                countdownFlashOn = true

            }

        } else {

            countdownFlashOn = false

        }

    }

    //======================================

    // MARK: - Rule rows (UI helpers)

    //======================================

    // Spacing rule row:

    // - Uses work time since last >=15m legal rest

    // - Grey until the first >=15m legal rest exists (avoids “always green” vibe)

    // - Green means "compliant so far since last legal rest"

    // - Red means breached (work since last legal rest >= limit)

    func spacingRuleRow(

        title: String,

        description: String,

        workSinceRest: TimeInterval,

        limitHours: Double,

        hasTakenLegalRest15: Bool,

        inRestLimbo15: Bool,

        limboRemaining15: TimeInterval

    ) -> some View {

        let limitSeconds = FatigueConstants.nhvrSpacingLimit

        if inRestLimbo15 {

            let remaining = formatTimeHM(limboRemaining15)

            return HStack(alignment: .top, spacing: 8) {

                Image(systemName: "hourglass")

                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {

                    Text(title).font(.subheadline)

                    Text(description).font(.caption2).foregroundColor(.secondary)

                    Text("Rest in progress — qualifies as ≥15m legal rest in \(remaining).")

                        .font(.caption2)

                        .foregroundColor(.secondary)

                }

            }

            .padding(.vertical, 2)

        }

        let symbolName: String

        let color: Color

        let statusText: String

        if workSinceRest < limitSeconds {

            let remaining = formatTimeHM(limitSeconds - workSinceRest)

            if !hasTakenLegalRest15 {

                // Before any >=15m legal rest exists today,

                // show neutral “pending” state (like 7.5/10h rows).

                symbolName = "circle"

                color = .gray

                statusText = "No ≥15m legal rest logged yet. First legal rest due in \(remaining)."

            } else {

                // Normal operating state once at least one legal rest exists.

                symbolName = "checkmark.circle.fill"

                color = .green

                statusText = "OK. Next legal rest due in \(remaining)."

            }

        } else {

            symbolName = "xmark.octagon.fill"

            color = .red

            let over = formatTimeHM(workSinceRest - limitSeconds)

            statusText = "Over by \(over). Take ≥15m legal rest ASAP."

        }

        return HStack(alignment: .top, spacing: 8) {

            Image(systemName: symbolName)

                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {

                Text(title)

                    .font(.subheadline)

                Text(description)

                    .font(.caption2)

                    .foregroundColor(.secondary)

                Text(statusText)

                    .font(.caption2)

                    .foregroundColor(color)

            }

        }

        .padding(.vertical, 2)

    }

    func ruleStatusRow(

        title: String,

        description: String,

        workToday: TimeInterval,

        limitHours: Double,

        requiredRestSeconds: TimeInterval,

        legalRest: TimeInterval,

        inRestLimbo15: Bool,

        limboRemaining15: TimeInterval

    ) -> some View {

        let limitSeconds = limitHours * 3600

        let symbolName: String

        let color: Color

        let statusText: String

        if workToday < limitSeconds {

            symbolName = "circle"

            color = .gray

            statusText = "Not yet reached \(String(format: "%.2f", limitHours))h of work."

        } else {

            if inRestLimbo15 && requiredRestSeconds > 0 {

                let remaining = formatTimeHM(limboRemaining15)

                symbolName = "hourglass"

                color = .secondary

                statusText = "Rest in progress — legal rest starts counting in \(remaining)."

            } else if legalRest >= requiredRestSeconds {

                symbolName = "checkmark.circle.fill"

                color = .green

                statusText = "Requirement met (legal rest \(formatTimeHM(legalRest)))."

            } else {

                symbolName = "xmark.octagon.fill"

                color = .red

                let needed = formatTimeHM(requiredRestSeconds)

                let actual = formatTimeHM(legalRest)

                statusText = "Need \(needed) legal rest; currently \(actual)."

            }

        }

        return HStack(alignment: .top, spacing: 8) {

            Image(systemName: symbolName).foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {

                Text(title).font(.subheadline)

                Text(description).font(.caption2).foregroundColor(.secondary)

                Text(statusText).font(.caption2).foregroundColor(color)

            }

        }

        .padding(.vertical, 2)

    }

    func cap12StatusRow(workToday: TimeInterval) -> some View {

        let elevenHours: TimeInterval = CountdownThresholds.dailyCapWarningThreshold

        let twelveHours: TimeInterval = FatigueConstants.nhvrDailyCap

        let symbolName: String

        let color: Color

        let statusText: String

        if workToday < elevenHours {

            symbolName = "checkmark.circle.fill"

            color = .green

            statusText = "Well within 12h daily cap."

        } else if workToday <= twelveHours {

            symbolName = "exclamationmark.triangle.fill"

            color = .orange

            statusText = "Within 1 hour of 12h daily cap."

        } else {

            symbolName = "xmark.octagon.fill"

            color = .red

            statusText = "Exceeded 12h daily cap."

        }

        return HStack(alignment: .top, spacing: 8) {

            Image(systemName: symbolName)

                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {

                Text("12h cap")

                    .font(.subheadline)

                Text("Simple cap – 12h max work in any day.")

                    .font(.caption2)

                    .foregroundColor(.secondary)

                Text(statusText)

                    .font(.caption2)

                    .foregroundColor(color)

            }

        }

        .padding(.vertical, 2)

    }

}

```

  

---

  

## Views/Partials/TodayView+StatusCard.swift

  

```swift

import SwiftUI

  

extension TodayView {

    //======================================

    // MARK: - Todayview+StatusCard (Top-Left Panel)

    //======================================

    //

    // Purpose:

    // - Quick-glance shift status

    // - Driver name, truck ID, odometer, location

    // - Work/rest/drive totals (both human and NHVR views)

    // - Start Shift / End Shift primary actions

    //

    // Displays:

    // - OFF DUTY state: "Start Shift" button

    // - ON DUTY state: current status, totals, "End Shift" button

    //

    // NHVR totals (Phase 1 scope):

    // - NHVR work = work + short rest (<15m)

    // - Legal rest = sum of >=15m rest blocks

    // - Short rest shown separately with explainer

    //

    // Post-persistence:

    // - May add shift ID, multi-day context

    // - May link to History screen

    //

    //======================================

    private func kmDisplay(_ km: Double) -> String {

        if km >= 10 {

            return "\(Int(km.rounded()))"

        } else {

            return String(format: "%.1f", km)

        }

    }

    var statusCard: some View {

  

        VStack(alignment: .leading, spacing: 8) {

            if !model.isOnDuty {

                Text("STATUS: OFF DUTY")

                    .font(.headline)

                Text("Tap Start Shift to begin.")

                    .font(.subheadline)

                Button(action: { showingStartShift = true }) {

                    Text("▶ Start Shift")

                        .font(.headline)

                        .padding(.vertical, 8)

                        .frame(maxWidth: .infinity)

                        .background(Color.blue.opacity(0.15))

                        .cornerRadius(8)

                }

            } else {

                Text("STATUS: \(currentStatusText)")

                    .font(.headline)

                Text(model.settings.driverName)

                    .font(.subheadline)

                let truckLabel = model.settings.truckIdentifier.isEmpty

                ? "Truck"

                : model.settings.truckIdentifier

                // Truck + odo line

                if !model.odoText.isEmpty {

                    Text("\(truckLabel) · Odo: \(model.odoText)")

                        .font(.subheadline)

                } else {

                    Text(truckLabel)

                        .font(.subheadline)

                }

                if let last = model.odoLocationRecords.last {

                    Text("Last odo: \(last.timestamp, style: .time)")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

                let segKm   = model.currentSegmentKmApprox          // segment (by segments model)

                let shiftKm = model.shiftKmBySegmentsApprox         // shift (by segments model)

                // Optional: show live GPS too (separately), because it will drift by design.

                let liveKm  = model.shiftKmLiveGps                  // raw LM accumulator

                Text("Km this segment: \(kmDisplay(segKm))")

                Text("Km this shift: \(kmDisplay(shiftKm))")

                // optional debug line:

                Text("Km live GPS: \(kmDisplay(liveKm))")

                    .font(.caption2)

                    .foregroundStyle(.secondary)

                // Manual odo update (always available while on duty)

                Button("Add odo reading") {

                    model.requestOdoCapture(.odoUpdate)

                }

                .font(.caption)

                .buttonStyle(.borderless)

                HStack {

                    Text("Drive today:")

                    Text(formatTimeHM(model.driveSecondsToday))

                        .bold()

                }

                .font(.subheadline)

                VStack(alignment: .leading, spacing: 2) {

                    // Human totals

                    HStack {

                        Text("Work today: \(formatTimeHM(model.workSecondsToday))")

                        Spacer()

                        Text("Rest today: \(formatTimeHM(model.restSecondsToday))")

                    }

                    // NHVR lens totals

                    HStack {

                        Text("NHVR work: \(formatTimeHM(model.nhvrWorkSecondsToday))")

                        Spacer()

                        Text("Legal rest:  \(formatTimeHM(model.legalRestSecondsToday))")

                            .bold()

                    }

                    if model.shortRestSecondsToday > 0 {

                        Text("Short rest (<15m): \(formatTimeHM(model.shortRestSecondsToday))")

                            .font(.caption)

                        Text("Counts as work for NHVR")

                            .font(.caption2)

                            .foregroundColor(.secondary)

                    }

                }

                .font(.caption)

                .foregroundColor(.secondary)

                Button(action: {

                    model.endShift()

                }) {

                    Text("End Shift")

                        .font(.subheadline)

                        .padding(.horizontal, 12)

                        .padding(.vertical, 6)

                        .background(Color.red.opacity(0.15))

                        .cornerRadius(8)

                }

                .disabled(!model.canPressEndShift)

                .padding(.top, 4)

            }

            if let reason = model.activityDisabledReason {

                Text(reason)

                    .font(.caption)

                    .foregroundColor(.secondary)

            }

        }

        // ✅ These now style the WHOLE CARD (both duty states)

        .padding()

        .background(Color.gray.opacity(0.1))

        .cornerRadius(12)

    }

  

}

```

  

---

  

## Views/Partials/TodayView+Timeline.swift

  

```swift

import SwiftUI

  

extension TodayView {

    //======================================

    // MARK: - Todayview+Timeline Section (Expandable Rows)

    //======================================

    //

    // Purpose:

    // - Show chronological list of activity segments

    // - Expandable rows reveal contextual data (odo, location, events, loads)

    //

    // Pre-persistence scope:

    // - Operates on in-memory segmentsToday + confirmedLoads + odoLocationRecords

    // - Lost on restart

    //

    // Post-persistence:

    // - Will query from SQLite

    // - May support editing (time corrections, notes)

    //

    // Design:

    // - Always shows Start Shift + End Shift markers as "slots"

    //   (data fills in once events exist)

    // - Collapsed: segment type + time range + location (if available)

    // - Expanded: odo/location details, events during segment, confirmed loads

    //

    //======================================

    var timelineSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Timeline")

                .font(.headline)

            // Segments (finished + current)

            let segs = model.timelineSegmentsIncludingCurrent

            // Shift markers anchored to ODO capture contexts (visible everywhere)

            let startRec = model.odoLocationRecords.last(where: { $0.context == .shiftStart })

            let endRec   = model.odoLocationRecords.last(where: { $0.context == .shiftEnd })

            // --- START SHIFT slot (always visible) ---

            ShiftMarkerRow(

                title: "START SHIFT",

                time: startRec?.timestamp,

                subtitle: startRec == nil

                ? "Pending (odo/location not captured yet)"

                : "Odo \(startRec!.odoText) • \(startRec!.suburb.trimmingCharacters(in: .whitespacesAndNewlines))",

                symbol: "play.circle.fill"

            )

            Divider()

            // --- Segment list ---

            if segs.isEmpty {

                Text("No activity recorded yet.")

                    .font(.caption)

                    .foregroundStyle(.secondary)

            } else {

                ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in

                    TimelineRow(segment: seg)

                        .environmentObject(model)

                    Divider()

                }

            }

            // --- END SHIFT slot (always visible) ---

            ShiftMarkerRow(

                title: "END SHIFT",

                time: endRec?.timestamp,

                subtitle: endRec == nil

                ? "Pending (odo/location not captured yet)"

                : "Odo \(endRec!.odoText) • \(endRec!.suburb.trimmingCharacters(in: .whitespacesAndNewlines))",

                symbol: "stop.circle.fill"

            )

        }

    }

}

  

// MARK: - Shift marker row (outside segments)

  

private struct ShiftMarkerRow: View {

    let title: String

    let time: Date?

    let subtitle: String?

    let symbol: String

    var body: some View {

        HStack(alignment: .top, spacing: 10) {

            Image(systemName: symbol)

                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {

                HStack {

                    Text(title)

                        .font(.subheadline)

                        .fontWeight(.bold)

                    Spacer()

                    if let time {

                        Text(time, style: .time)

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    } else {

                        Text("—")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                }

                if let subtitle, !subtitle.isEmpty {

                    Text(subtitle)

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                }

            }

        }

        .padding(.vertical, 4)

        .padding(.horizontal, 6)

        .background(Color.gray.opacity(0.08))

        .cornerRadius(8)

    }

}

  

private struct TimelineRow: View {

    @EnvironmentObject var model: AppModel

    let segment: ActivitySegment

    @State private var isExpanded: Bool = false

    private var endTime: Date { segment.end ?? Date() }

    private var isLive: Bool { segment.end == nil }

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            Button {

                isExpanded.toggle()

            } label: {

                HStack(alignment: .top) {

                    VStack(alignment: .leading, spacing: 2) {

                        Text(segment.type.displayName)

                            .font(.subheadline)

                        Text("\(segment.start, style: .time) → \(isLive ? "now" : endTime.formatted(date: .omitted, time: .shortened))")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                        if let rec = model.odoRecord(for: segment) {

                            let suburb = rec.suburb.trimmingCharacters(in: .whitespacesAndNewlines)

                            if !suburb.isEmpty {

                                Text(suburb)

                                    .font(.caption2)

                                    .foregroundStyle(.secondary)

                            }

                        }

                        let km = model.kmApprox(for: segment)

                        Text(String(format: "Segment distance (klm): %.1f", km))

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.right")

                        .font(.caption)

                        .foregroundStyle(.secondary)

                }

            }

            .buttonStyle(.plain)

            if isExpanded {

                expandedDetails

                    .padding(.top, 2)

            }

        }

        .padding(.vertical, 4)

    }

    @ViewBuilder

    private var expandedDetails: some View {

        let rec = model.odoRecord(for: segment)

        let segEvents = model.events(during: segment)

        let segLoads: [ConfirmedLoad] = model.confirmedLoadsDuring(segment)

        VStack(alignment: .leading, spacing: 6) {

            // Odo + location

            if let rec {

                HStack {

                    Text("Odo:")

                    Text(rec.odoText).bold()

                    Spacer()

                    Text(rec.timestamp, style: .time)

                        .foregroundStyle(.secondary)

                }

                .font(.caption)

                let suburb = rec.suburb.trimmingCharacters(in: .whitespacesAndNewlines)

                if !suburb.isEmpty {

                    Text("Location: \(suburb)")

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                }

            } else {

                // Odo + location (ONLY if we have a record)

                if let rec = model.odoRecord(for: segment) {

                    HStack {

                        Text("Odo:")

                        Text(rec.odoText).bold()

                        Spacer()

                        Text(rec.timestamp, style: .time)

                            .foregroundStyle(.secondary)

                    }

                    .font(.caption)

                    let suburb = rec.suburb.trimmingCharacters(in: .whitespacesAndNewlines)

                    if !suburb.isEmpty {

                        Text("Location: \(suburb)")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                }

            }

            // Events inside segment

            if !segEvents.isEmpty {

                Text("Events:")

                    .font(.caption)

                    .bold()

                let visibleEvents = segEvents.filter { ev in

                    ![

                        .driveStart,

                        .load,

                        .unload

                    ].contains(ev.kind)

                }

                if !visibleEvents.isEmpty {

                    ForEach(visibleEvents, id: \.id) { ev in

                        let note = (ev.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                        let line = "• \(ev.kind.rawValue)" + (note.isEmpty ? "" : " — \(note)")

                        Text(line)

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                }

            }

            // Confirmed loads inside segment

            // Confirmed loads inside segment

            if !segLoads.isEmpty {

                Text("Confirmed loads:")

                    .font(.caption)

                    .bold()

                ForEach(segLoads, id: \.id) { load in

                    // Find previous confirmed load in the *global* list (not just this segment)

                    let prevTotal: Int = {

                        guard let idx = model.confirmedLoads.firstIndex(where: { $0.id == load.id }) else { return 0 }

                        guard idx > 0 else { return 0 }

                        return model.confirmedLoads[idx - 1].totalLitres

                    }()

                    let delta = abs(load.totalLitres - prevTotal)

                    // Friendly verb based on mode (optional)

                    let verb = (load.mode.rawValue.uppercased().contains("UNLOAD")) ? "UNLOAD" : "LOAD"

                    Text("• \(verb) @ \(load.timestamp.formatted(date: .omitted, time: .shortened)) — \(delta)L / \(load.totalLitres)L")

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                }

            }

            Text("Notes: (post-persistence)")

                .font(.caption2)

                .foregroundStyle(.secondary)

        }

        .padding(8)

        .background(Color.gray.opacity(0.08))

        .cornerRadius(8)

    }

}

```

  

---

  

## Views/Screens/BannerShellView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - BannerShellView

//======================================

//

// Purpose:

// - Always-visible top banner across the whole app.

// - Holds: integrity triangle (left), NOW (gps/suburb/speed), nav tabs (center),

//          FUTURE projection (right), settings gear (far right).

//

// Notes:

// - Keeps layout stable: areas exist even when empty.

// - The triangle is hidden when there are no issues (does not collapse into NOW).

//======================================

  

struct SpeedBadge: View {

    let speedKmh: Int

    private let limitGate = HysteresisGate(upper: 101, lower: 99)

    @State private var isOverLimit: Bool = false

  

    var body: some View {

        ZStack {

            Circle()

                .stroke(.primary.opacity(0.35), lineWidth: 2)

            // optional outer ring (OFF by default)

            if isOverLimit {

                Circle()

                    .stroke(.red, lineWidth: 6)

                    .padding(-3) // makes it sit slightly outside

            }

            Text("\(speedKmh)")

                .font(.system(size: 18, weight: .bold, design: .rounded))

                .foregroundStyle(isOverLimit ? .red : .primary)

        }

        .frame(width: 44, height: 44)

        .accessibilityLabel("Speed \(speedKmh) kilometres per hour")

        .onAppear {

            isOverLimit = limitGate.nextState(current: speedKmh, isActive: isOverLimit)

        }

        .onChange(of: speedKmh) { _, newValue in

            isOverLimit = limitGate.nextState(current: newValue, isActive: isOverLimit)

        }

    }

}

  

import SwiftUI

  

struct HeadingBadge: View {

    let degrees: Double?   // nil = unknown

    let fill: Color        // pass in .green/.yellow etc

    var body: some View {

        ZStack {

            // ticks

            TicksRing(tickCount: 32)

            // heading marker (moves with heading)

            if let d = normalizedDegrees {

                Rectangle()

                    .fill(.red)

                    .frame(width: 2, height: 10)

                    .offset(y: -22) // radius from centre

                    .rotationEffect(.degrees(d)) // <- clockwise compass heading

            } else {

                // Optional: show a faint "north" hint when unknown

                Rectangle()

                    .fill(.red.opacity(0.25))

                    .frame(width: 2, height: 10)

                    .offset(y: -22)

            }

            // inner disc

            Circle()

                .fill(fill.opacity(0.85))

                .frame(width: 34, height: 34)

            Text(compassText(degrees))

                .font(.system(size: 14, weight: .bold, design: .rounded))

                .foregroundStyle(.black.opacity(0.85))

        }

        .frame(width: 44, height: 44)

        .accessibilityLabel(accessibilityString)

    }

    private var accessibilityString: String {

        if let d = normalizedDegrees { return "Heading \(Int(d)) degrees" }

        return "Heading unknown"

    }

    private var normalizedDegrees: Double? {

        guard let deg = degrees, deg.isFinite else { return nil }

        // normalize to 0..<360

        return (deg.truncatingRemainder(dividingBy: 360) + 360)

            .truncatingRemainder(dividingBy: 360)

    }

    private let compassDirs16: [String] = [

        "N","NNE","NE","ENE",

        "E","ESE","SE","SSE",

        "S","SSW","SW","WSW",

        "W","WNW","NW","NNW"

    ]

    private func compassText(_ degrees: Double?) -> String {

        guard let deg = degrees, deg.isFinite else { return "—" }

        let normalized = (deg.truncatingRemainder(dividingBy: 360) + 360)

            .truncatingRemainder(dividingBy: 360)

        let step = 360.0 / 16.0   // 22.5°

        let rawIndex = (normalized / step).rounded()

        let idx = Int(rawIndex) % 16

        return compassDirs16[idx]

    }

}

  

struct TicksRing: View {

    let tickCount: Int

    var body: some View {

        ZStack {

            ForEach(0..<tickCount, id: \.self) { i in

                Rectangle()

                    .fill(.primary.opacity(i % 2 == 0 ? 0.45 : 0.25))

                    .frame(width: 2, height: i % 2 == 0 ? 8 : 5) // every 2nd tick longer

                    .offset(y: -22)

                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(tickCount))))

            }

            Circle()

                .stroke(.primary.opacity(0.35), lineWidth: 2)

        }

    }

}

  

struct BannerShellView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    @Binding var selectedTab: MainTab

    // Banner height — tune later.

    private let height: CGFloat = 70

    var body: some View {

        HStack(spacing: 12) {

            integrityArea

                .frame(width: 44)

            nowArea

                .frame(minWidth: 250, maxWidth: .infinity, alignment: .leading)

                .layoutPriority(1)

            navArea

                .frame(maxWidth: .infinity, alignment: .center)

                .layoutPriority(10)

            futureArea

                .frame(minWidth: 220, alignment: .trailing)

                .layoutPriority(1)

            settingsArea

                .frame(width: 44)

        }

        .frame(height: height)

        .padding(.horizontal, 12)

        .background(.ultraThinMaterial)

        .overlay(Divider(), alignment: .bottom)

    }

    // MARK: - Areas

    private var integrityArea: some View {

        ZStack {

            Color.clear.frame(width: 44, height: 44)

            if model.integrityIssueCount > 0 {

                Button {

                    model.presentIntegritySheet()

                } label: {

                    Image(systemName: "exclamationmark.triangle.fill")

                        .font(.system(size: 22, weight: .semibold))

                        .foregroundStyle(.yellow)

                }

            } else {

                #if DEBUG

                if DebugFlags.all || DebugFlags.trianglePlaceholder {

                    Circle()

                        .stroke(.green, lineWidth: 1.5)

                        .frame(width: 10, height: 10)

                }

                #endif

            }

        }

        .frame(width: 44, height: 44)

    }

    private var nowArea: some View {

        HStack(spacing: 8) {

            SpeedBadge(speedKmh: Int(model.speedKmh ?? 0))

            Spacer(minLength: 4)

            switch model.bannerContext(for: selectedTab) {

            case .motion:

                MotionPillView()

                    .environmentObject(model)

                    .environmentObject(locationManager)

            case .heading:

                HeadingBadge(

                    degrees: locationManager.courseDegrees,

                    fill: .green // later: map to confidence

                )

            case .odo:

                if let est = model.suggestedOdoFromGps {

                    Text("Odo ~\(est)")

                        .font(.caption.monospaced())

                        .lineLimit(1)

                } else {

                    Text("Odo: \(model.odoText)")

                        .font(.caption.monospaced())

                        .lineLimit(1)

                }

            case .cost:

                Text(model.liveCostPerKmText) // stub

                    .font(.caption)

            }

            Spacer(minLength: 5)

            Text(locationManager.liveSuburb)

                .font(.caption)

                .foregroundStyle(.secondary)

                .lineLimit(2)

                .font(.system(size:20))

        }

    }

    private var navArea: some View {

        HStack(spacing: 10) {

            tabButton(.today, title: "Today", system: "clock")

            tabButton(.load,  title: "Load",  system: "shippingbox")

            tabButton(.map,   title: "Map",   system: "map")

            tabButton(.sim,   title: "Sim",   system: "speedometer")

            tabButton(.command, title: "Cmd", system: "command")

        }

        .frame(maxWidth: .infinity, alignment: .center)

        .layoutPriority(1) // ✅ don’t squeeze me first

    }

    private func tabButton(_ tab: MainTab, title: String, system: String) -> some View {

        Button {

            selectedTab = tab

        } label: {

            Label(title, systemImage: system)

                .font(.caption)

                .padding(.horizontal, 10)

                .padding(.vertical, 12)

                .background(selectedTab == tab ? Color.primary.opacity(0.10) : Color.clear)

                .clipShape(Capsule())

                .contentShape(Rectangle()) // <- easiest “fat finger” win

                .lineLimit(1)

        }

        .buttonStyle(.plain)

    }

    private var futureArea: some View {

        VStack(alignment: .trailing, spacing: 4) {

            // ===== 1) OLD GPS (authoritative) =====

            Text("GPS \(fmtKm(model.gpsShiftMetersLive / 1000.0)) km")

                .font(.caption.monospaced())

            // ===== 2) NEW BG advisory (separate, never merges into totals) =====

            if let est = model.lastBackgroundGapEstimate {

                Text("BG +\(est.suggestedOdoDeltaKm) km  \(est.method.rawValue) / \(est.confidence.rawValue)")

                    .font(.caption2.monospaced())

                    .foregroundStyle(.secondary)

                    .lineLimit(1)

            } else {

                Text("BG —")

                    .font(.caption2.monospaced())

                    .foregroundStyle(.secondary)

            }

            // ===== 3) ODO delta vs GPS delta (error readout) =====

            if let odoCompareLine = odoVsGpsLine() {

                Text(odoCompareLine)

                    .font(.caption2.monospaced())

                    .foregroundStyle(.secondary)

                    .lineLimit(1)

            } else {

                Text("ODOΔ — | GPSΔ — | err —")

                    .font(.caption2.monospaced())

                    .foregroundStyle(.secondary)

            }

        }

        .frame(maxWidth: .infinity, alignment: .trailing)

    }

    private var settingsArea: some View {

        Button {

            model.isShowingSettingsSheet = true // stub; or use navigation

        } label: {

            Image(systemName: "gearshape.fill")

                .font(.system(size: 20))

                .frame(width: 44, height: 44)

        }

        .buttonStyle(.plain)

    }

    // MARK: - Helpers (BannerShellView)

    private func fmtKm(_ km: Double) -> String {

        guard km.isFinite else { return "—" }

        return String(format: "%.1f", km)

    }

    private func parseOdoKm(_ text: String) -> Int? {

        // Accept "123456", "123,456", "123 456", "123456km"

        let digits = text.filter { $0.isNumber }

        return Int(digits)

    }

    private func gpsWindowKmSinceLastOdo() -> Double? {

        // Raw GPS evidence since last odo anchor (segments are keyed by UUID)

        let sum = model.gpsKmSinceLastOdoBySegment.values.reduce(0, +)

        return sum.isFinite ? sum : nil

    }

    private func odoVsGpsLine() -> String? {

        guard

            let anchor = model.lastOdoAnchorKm,

            let current = parseOdoKm(model.odoText)

        else { return nil }

        let odoDelta = max(0, current - anchor)

        guard let gpsDelta = gpsWindowKmSinceLastOdo() else { return nil }

        let err = Double(odoDelta) - gpsDelta

        return "ODOΔ \(odoDelta) | GPSΔ \(fmtKm(gpsDelta)) | err \(fmtKm(err))"

    }

}
```

  

---

  

## Views/Screens/CommandView.swift

  

```swift

import SwiftUI

  

enum CommandSection: String, Identifiable {

    case menu, journal, truck, numbers

    var id: String { rawValue }

}

  

struct CommandView: View {

    @State private var section: CommandSection = .menu

    var body: some View {

        ZStack {

            switch section {

            case .menu:

                menu

            case .journal:

                JournalSheet(onClose: { section = .menu })

            case .truck:

                TruckProfile2DSheet(onClose: { section = .menu })

            case .numbers:

                NumbersSheet(onClose: { section = .menu })

            }

        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

    private var menu: some View {

        VStack(spacing: 16) {

            Text("Command").font(.largeTitle.bold())

            Text("Pick a module.").foregroundStyle(.secondary)

            VStack(spacing: 12) {

                Button("Journal") { section = .journal }

                Button("Truck")   { section = .truck }

                Button("Numbers") { section = .numbers }

            }

            .buttonStyle(.borderedProminent)

            Spacer()

        }

        .padding()

    }

}

```

  

---

  

## Views/Screens/ContentView.swift

  

```swift

import SwiftUI

import Combine

  

//======================================

// MARK: - Contentview (root tab container)

//======================================

//

// Purpose:

// - Owns the main TabView for the app.

// - Hosts the five primary workflows:

//   • Today (shift + fatigue)

//   • Load (load plan, placards, mass)

//   • Map (pins, telemetry, routing)

//   • Sim (fatigue simulation / planning)

//   • Command (where Journal (history) , numbers (owner costings etc) and truck (truck profile setup) live)

//

// Notes:

// - SplashView is deliberately layered *above* the TabView

//   so tabs initialise underneath while splash fades out.

// - No persistence assumptions here; this is purely navigation.

// - Any future debug / admin tabs should be injected here,

//   not inside individual screens.

//======================================

  

enum MainTab: Hashable {

    case today

    case load

    case map

    case sim

    case command

}

  

struct ContentView: View {

    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    @State private var selectedTab: MainTab = .today

    @State private var progress: Double = 0.0

    @State private var status: String = "Starting up..."

    var body: some View {

        ZStack {

            TabView(selection: $selectedTab) {

                NavigationStack { TodayView() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.today)

                NavigationStack { LoadPlanView() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.load)

                NavigationStack { MapScreen() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.map)

                NavigationStack { SimulationView() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.sim)

                NavigationStack { CommandView() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.command)

            }

            .toolbar(.hidden, for: .tabBar) // ✅ native tab bar gone

            if !model.didFinishSplash {

                SplashView(

                    progress: $progress,

                    status: $status,

                    didFinishSplash: $model.didFinishSplash

                )

                .transition(.opacity)

                .zIndex(10)

            }

        }

        .safeAreaInset(edge: .top) {

            BannerShellView(selectedTab: $selectedTab)

                .environmentObject(model)

                .environmentObject(locationManager)

        }

        .sheet(item: $model.activeGuardPrompt) { prompt in

            GuardPromptSheet(prompt: prompt)

                .environmentObject(model)

        }

        .sheet(isPresented: $model.isShowingSettingsSheet) {

            SettingsView()

                .environmentObject(model)

                .environmentObject(locationManager)

        }

        .onChange(of: scenePhase) {

            guard model.didFinishSplash else { return }

            switch scenePhase {

            case .inactive:

                model.onAppBackgrounded(locationManager: locationManager)

            case .background:

                model.onAppBackgrounded(locationManager: locationManager)

            case .active:

                model.onAppBecameActive(locationManager: locationManager)

            default:

                break

            }

        }

        .onAppear {

            model.requestGpsKickFromUI = { reason in

                locationManager.kickUpdates(reason: reason)

            }

            model.requestLmResetShiftMetersFromUI = { [weak locationManager] reason in

                Task { @MainActor in

                    locationManager?.resetShiftMeters(reason: reason)

                }

            }

            guard !model.splashSetupStarted else { return }

            model.splashSetupStarted = true

            model.connect(locationManager: locationManager)

            runSplashSequence()

            model.startTickerIfNeeded()

        }

        .onReceive(locationManager.$lastUpdateAt) { _ in

            if model.backgroundGapResumePending {

                model.onAppBecameActive(locationManager: locationManager)

            }

        }

        .onReceive(

            Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

        ) { _ in

            DebugLog.motion("🟡 motion tick")

            model.tickMotionState()

        }

    }

    private func runSplashSequence() {

        // keep your exact timing

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {

            status = "AppModel ready"; progress = 0.25

            DebugLog.ui("🟠 Batch 1: AppModel ready")

            model.ensureAutosaveSetup()

        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {

            status = "Preparing location services"; progress = 0.5

            DebugLog.ui("🟠 Batch 2: Location prep")

        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {

            status = "Starting location updates"; progress = 0.75

            DebugLog.ui("🟠 Batch 3: Calling locationManager.start()")

            locationManager.start()

        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            status = "Loading complete"; progress = 1.0

            DebugLog.ui("🟠 Batch 4: Done")

            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {

                model.didFinishSplash = true

            }

        }

    }

}

```

  

---

  

## Views/Screens/LoadView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Load planning screen (container)

//======================================

//

// Purpose:

// - Hosts the entire Load workflow.

// - Splits the screen into:

//   • Left panel: data entry, templates, actions

//   • Right panel: printable-style load sheet + placard

//

// Design notes:

// - This is intentionally a *wide* split view.

// - On iPad, this behaves like a two-column workspace.

// - On smaller devices, future work may collapse panels

//   (but NOT in Phase 1 / pre-persistence).

//======================================

  

struct LoadPlanView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    // Focus targets for fields inside LoadLeftPanel

    enum Field: Hashable {

        case loadCode

        case terminalName

        case vehicleId

        case driverName

        case litres(Int)

    }

    @FocusState private var focusedField: Field?

    var body: some View {

            HStack(spacing: 0) {

                LoadLeftPanel(focusedField: $focusedField)

                    .frame(maxWidth: 340)

                Divider()

                LoadSheetView()

            }

            .navigationTitle("Load")

            .onAppear {

                // Tier 1 Entry Guard: Soft prompt when entering LoadView in wrong segment

                guard model.isOnDuty else { return }

                let expectedSegment: ActivityType = model.isUnloadMode ? .workUnload : .workLoad

  

                if model.currentActivity != expectedSegment {

                    // Give the view a moment to settle before showing prompt

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                        if self.model.isUnloadMode {

                            self.model.promptToSwitchToUnload()

                        } else {

                            self.model.promptToSwitchToLoad()

                        }

                    }

                }

                // Also prime stopped nudge (existing code)

                model.primeStoppedNudgeInLoadEntry()

            }

            .onDisappear {

                model.stoppedStartAt = nil

                model.pendingStoppedNudge?.cancel()

                model.pendingStoppedNudge = nil

            }

            .sheet(isPresented: $model.showStoppedNudgeInLoad) {

                StoppedNudgeSheet(

                    onLoad: {

                        model.isUnloadMode = false

                        model.pressLoad()

                        model.showStoppedNudgeInLoad = false

                    },

                    onUnload: {

                        model.isUnloadMode = true

                        model.pressUnload()

                        model.showStoppedNudgeInLoad = false

                    },

                    onKeepDriving: {

                        model.snoozeStoppedNudgeInLoad()

                        model.showStoppedNudgeInLoad = false

                    },

                    onCancel: {

                        model.showStoppedNudgeInLoad = false

                    }

                )

                .presentationDetents([.height(320)])     // fits all buttons, no scrolling

                .presentationDragIndicator(.visible)

            }

            .onReceive(locationManager.$speedMps) { newSpeed in

                model.considerStoppedNudgeInLoad(speedMps: newSpeed)

            }

    }

}

```

  

---

  

## Views/Screens/MapView.swift

  

```swift

import SwiftUI

import MapKit

import CoreLocation

  

//======================================

// MARK: - MapView (Split Layout)

//======================================

//

// Purpose:

// - Left panel: map tools, pin management, future run planning

// - Right panel: live map with GPS blue dot + session pins

//

// Phase 1 scope (pre-persistence):

// - Session pins only (lost on restart)

// - Tap-to-drop pin workflow

// - Manual category selection

// - NHVR base radius overlay (if address provided in settings)

//

// Post-persistence scope:

// - Durable pins with stable IDs

// - Pin editing (rename, category, delete)

// - Saved runs (ordered stop sequences)

// - Breadcrumb trails (GPS history)

//

// Design separation:

// - MapScreen = container (left panel + right pane)

// - MapPane = actual Map + overlays + tap handling

//

//======================================

  

//======================================

// MARK: - Map Pane (Live Map + Overlays)

//======================================

//

// Purpose (pre-persistence):

// - Show live GPS position (UserAnnotation blue dot)

// - Render session pins with category colors

// - Show NHVR base radius (if configured)

// - Handle tap-to-drop pin workflow

//

// Important state:

// - `pins` is session-only (pre-persistence)

// - `cameraPosition` is user-controlled (auto-follow optional)

// - `didUserMoveMap` prevents fighting with auto-recenter

// - `programmaticMove` flag prevents false "user panned" detection

//

// Post-persistence:

// - Pins become durable (stable IDs, editable)

// - Camera position may be restored from last session

// - Breadcrumb trails may be rendered from JSONL files

//

//======================================

  

struct MapPane: View {

  

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    @Binding var isFollowingUser: Bool

    @Binding var didUserMoveMap: Bool

    @Binding var cameraPosition: MapCameraPosition

    @Binding var pins: [LocationPin]

    @State private var selectedCategory: LocationCategory = .customer

    @State private var baseCoordinate: CLLocationCoordinate2D? = nil

    // prevents “camera moved” callback from disabling follow when WE moved it

    @State private var programmaticMove: Bool = false

    var body: some View {

        ZStack {

            MapReader { proxy in

                Map(position: $cameraPosition) {

                    UserAnnotation()

                    if let base = baseCoordinate {

                        MapCircle(center: base, radius: model.settings.nhvrRadiusKm * 1000)

                            .foregroundStyle(.blue.opacity(0.12))

                        Marker("NHVR Base", coordinate: base).tint(.blue)

                    }

                    ForEach(Array(pins.enumerated()), id: \.element.id) { idx, pin in

                        let number = idx + 1

                        Annotation(pin.name, coordinate: pin.coordinate) {

                            ZStack {

                                Circle()

                                    .fill(Color.blue.opacity(0.9))

                                    .frame(width: 30, height: 30)

                                Text("\(number)")

                                    .font(.caption.bold())

                                    .foregroundStyle(.white)

                            }

                            .overlay(

                                Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)

                            )

                            .shadow(radius: 2)

                            .accessibilityLabel("\(pin.category.rawValue) \(number): \(pin.name)")

                        }

                    }

                }

                .onMapCameraChange { _ in

                    if programmaticMove {

                        programmaticMove = false

                        return

                    }

                    // user touched the map -> they’re steering now, so stop following

                    didUserMoveMap = true

                    if isFollowingUser {

                        isFollowingUser = false

                    }

                }

                .onTapGesture { location in

                    if let coord = proxy.convert(location, from: .local) {

                        let newPin = LocationPin(

                            coordinate: coord,

                            category: selectedCategory

                        )

                        pins.append(newPin)

                    }

                }

            }

            // keep your overlay picker for now (you can move it left later)

            VStack {

                HStack {

                    Picker("Category", selection: $selectedCategory) {

                        ForEach(LocationCategory.allCases) { category in

                            Text(category.rawValue).tag(category)

                        }

                    }

                    .pickerStyle(.menu)

                    if !pins.isEmpty {

                        Button("Undo last") { _ = pins.popLast() }

                    }

                }

                .padding(8)

                .background(.thinMaterial)

                .cornerRadius(10)

                .padding()

                Spacer()

            }

        }

        .onAppear {

            geocodeNhvrBaseIfNeeded()

        }

        .onChange(of: model.settings.nhvrBaseAddress) { _, _ in

            geocodeNhvrBaseIfNeeded()

        }

        .onChange(of: locationManager.lastLocation) { _, newValue in

            guard isFollowingUser, let coord = newValue?.coordinate else { return }

            programmaticMove = true

            cameraPosition = .region(

                MKCoordinateRegion(

                    center: coord,

                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)

                )

            )

        }

        .onReceive(locationManager.$lastDeltaMeters) { delta in

            DebugLog.gps("🟢 lastDeltaMeters → \(delta)")

            guard delta > 0 else { return }

            model.ingestGpsDeltaMeters(delta)

        }

    }

    private func geocodeNhvrBaseIfNeeded() {

        let address = model.settings.nhvrBaseAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !address.isEmpty else {

            baseCoordinate = nil

            return

        }

        CLGeocoder().geocodeAddressString(address) { placemarks, error in

            guard error == nil else { return }

            guard let coord = placemarks?.first?.location?.coordinate else { return }

            DispatchQueue.main.async {

                baseCoordinate = coord

                if !didUserMoveMap && !isFollowingUser {

                    self.programmaticMove = true

                    cameraPosition = .region(

                        MKCoordinateRegion(

                            center: coord,

                            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)

                        )

                    )

                }

            }

        }

    }

}

  

//======================================

// MARK: - Map screen (split layout)

//======================================

//

// Purpose:

// - Left column: placeholder “Map tools” panel.

// - Right column: the actual map pane.

// - Mirrors the same split-view approach as LoadPlanView.

//

struct MapScreen: View {

    @EnvironmentObject var model: AppModel

    // Phase 1 session-only map state (shared between left panel + MapPane)

    @State private var pins: [LocationPin] = []

    @State private var didUserMoveMap: Bool = false

    @State private var cameraPosition: MapCameraPosition = .region(

        MKCoordinateRegion(

            center: CLLocationCoordinate2D(latitude: -27.25, longitude: 152.95),

            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)

        )

    )

    @EnvironmentObject var locationManager: LocationManager

    @State private var isFollowingUser: Bool = false

    var body: some View {

            HStack(spacing: 0) {

                // LEFT: tools panel (placeholder scaffolding)

                VStack(alignment: .leading, spacing: 12) {

                    Button {

                        isFollowingUser.toggle()

                        if isFollowingUser {

                            locationManager.requestPermissionIfNeeded()

                            locationManager.start()

                            didUserMoveMap = false

                        } else {

                        }

                    } label: {

                        Label(isFollowingUser ? "Following" : "Follow Me",

                              systemImage: isFollowingUser ? "location.fill" : "location")

                    }

                    .buttonStyle(.bordered)

                    Text("Map tools")

                        .font(.headline)

                    // ---------------------------------

                    // Pins (session only)

                    // ---------------------------------

                    Text("Pins (session)")

                        .font(.subheadline)

                    if pins.isEmpty {

                        Text("No pins yet. Tap on the map to drop one.")

                            .font(.caption)

                            .foregroundColor(.secondary)

                            .fixedSize(horizontal: false, vertical: true)

                    } else {

                        List {

                            ForEach(Array(pins.enumerated()), id: \.element.id) { idx, pin in

                                let number = idx + 1

                                Button {

                                    // Jump the map to this pin

                                    didUserMoveMap = true

                                    cameraPosition = .region(

                                        MKCoordinateRegion(

                                            center: pin.coordinate,

                                            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)

                                        )

                                    )

                                } label: {

                                    HStack(spacing: 10) {

                                        // Number badge

                                        Text("\(number)")

                                            .font(.caption.bold())

                                            .foregroundStyle(.white)

                                            .frame(width: 26, height: 26)

                                            .background(Circle().fill(Color.blue.opacity(0.9)))

                                        VStack(alignment: .leading, spacing: 2) {

                                            Text(pin.name)

                                                .font(.body)

                                            Text(pin.category.rawValue)

                                                .font(.caption2)

                                                .foregroundColor(.secondary)

                                        }

                                        Spacer()

                                    }

                                }

                            }

                            .onDelete { indexSet in

                                pins.remove(atOffsets: indexSet)

                            }

                        }

                        .listStyle(.plain)

                    }

                    // Keep your future scaffolding notes if you want them:

                    Divider()

                    Text("Later:\n• Saved milk runs\n• Edit / reorder stops\n• Filters (night, DG type, etc.)")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                }

                .padding()

                .frame(maxWidth: 340, alignment: .topLeading)

                .background(Color(.systemBackground))

                .clipped()

                Divider()

                // RIGHT: actual map

                MapPane(

                    isFollowingUser: $isFollowingUser,

                    didUserMoveMap: $didUserMoveMap,

                    cameraPosition: $cameraPosition,

                    pins: $pins

                )

            }

            .navigationTitle("Map")

    }

}

```

  

---

  

## Views/Screens/SimulationView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Simulation Screen (v0.2)

//======================================

//

// Purpose:

// - Load template "sandbox" for Truck 92 mass simulation.

// - Save templates and apply them to the live Load Plan.

// - Includes a separate fatigue simulator (Phase 1 testing aid).

//

// Important separation (TWO simulators in one screen):

// 1. LOAD MASS SIM (top panels):

//    - Driven by AppModel.draftTemplate

//    - Edits DO affect saved templates

//    - "Apply to Load Plan" writes to live AppModel.compartments

//

// 2. FATIGUE SIM (bottom panel):

//    - Driven by local SimulationModel (isolated)

//    - Changes do NOT affect real shift data

//    - Pure sandbox for testing fatigue rules

//

// Notes / constraints (pre-persistence):

// - Saved templates are currently in-memory (lost on relaunch) unless you later persist them.

// - This screen intentionally mixes two "simulators":

//   (1) Load mass sim (driven by AppModel.draftTemplate + recalcDraftSimulation())

//   (2) Fatigue sim (local SimulationModel, does NOT touch real shift data)

//

// Future:

// - After persistence, templates become durable + searchable + taggable.

// - Fatigue sim can move behind a Debug/Dev panel.

//

//======================================

  

struct SimulationView: View {

  

    @EnvironmentObject var model: AppModel

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 16) {

                // A) Template editor

                templateEditor

                // B) Results preview

                resultsPanel

                // C) Save + library

                templateLibrary

                // D) Fatigue simulation (Phase 1 testing aid)

                Phase1StartPlannerCard()

                FatigueSimulationView()

            }

            .padding()

        }

        .navigationTitle("Simulation")

    }

}

  

//======================================

// MARK: - Fatigue Simulation (local-only)

//======================================

//

// This is intentionally isolated from AppModel.

// It exists purely as a “what if I did…” sandbox for fatigue testing.

//

struct FatigueSimulationView: View {

    @StateObject private var sim = SimulationModel()

    @State private var sliderTime: Double = 0    // seconds from 0 → 25h

    @State private var simScheme: FatigueScheme = .standardHV

    private func dayAndClock(_ t: TimeInterval) -> String {

        let totalMin = Int(t / 60)

        let day = totalMin / (24*60) + 1

        let minsInDay = totalMin % (24*60)

        let h = minsInDay / 60

        let m = minsInDay % 60

        return "Day \(day) • \(String(format: "%02d:%02d", h, m))"

    }

    @State private var simStartDate: Date = {

        var cal = Calendar(identifier: .gregorian)

        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

        return cal.startOfDay(for: Date())

    }()

    // For flashing the countdown bar when a rule is breached (temporary UI)

    @State private var countdownFlashOn = false

    private let maxSimTime: TimeInterval = 365 * 24 * 3600

    private func nudge(_ delta: TimeInterval) {

        // Snap to whole minutes after every move to avoid float creep.

        let next = sliderTime + delta

        let clamped = min(max(next, 0), maxSimTime)

        sliderTime = (clamped / 60).rounded() * 60

    }

    var body: some View {

        VStack(spacing: 20) {

  

            timeControlsSection

            Divider()

            inputControlsSection

            Divider()

            driverSummarySection

            Divider()

            FatigueEnginePanel(

                scheme: $simScheme,

                segments: engineSegments,

                now: engineNow

            )

            Divider()

            //========================================

            // Fatigue bars (mirrors TodayView style)

            //========================================

            fatigueBars

            Divider()

            segmentsSection

  

        }

        .padding()

        .background(Color.gray.opacity(0.06))

        .cornerRadius(12)

        .onAppear {

            print("FatigueSimulationView appeared. simStartDate=\(simStartDate)")

        }

    }

    private var timeControlsSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Simulated time")

                .font(.headline)

            Slider(value: $sliderTime, in: 0...maxSimTime, step: 300)

            Text("Position: \(dayAndClock(sliderTime))")

                .font(.caption)

                .foregroundColor(.secondary)

            HStack(spacing: 8) {

                Button("-15m") { nudge(-15*60) }

                Button("-30m") { nudge(-30*60) }

                Button("-1h")  { nudge(-3600) }

                Button("+15m") { nudge(15*60) }

                Button("+30m") { nudge(30*60) }

                Button("+1h")  { nudge(3600) }

            }

            .buttonStyle(.bordered)

            HStack(spacing: 8) {

                Button("-5h")  { nudge(-5*3600) }

                Button("-7h")  { nudge(-7*3600) }

                Button("-12h") { nudge(-12*3600) }

                Button("+5h")  { nudge(5*3600) }

                Button("+7h")  { nudge(7*3600) }

                Button("+12h") { nudge(12*3600) }

            }

            .buttonStyle(.bordered)

            HStack(spacing: 8) {

                Button("◀︎ Day") { nudge(-24*3600) }

                Button("Snap 00:00") {

                    let day = floor(sliderTime / (24*3600))

                    sliderTime = day * 24*3600

                }

                Button("Day ▶︎") { nudge(24*3600) }

                Spacer()

                Text("Day \(Int(sliderTime / (24*3600)) + 1)")

                    .font(.caption2)

                    .foregroundStyle(.secondary)

            }

            .buttonStyle(.bordered)

        }

    }

    private var inputControlsSection: some View { 

        //========================================

        // Input controls

        //========================================

        HStack(spacing: 16) {

            Button("Add WORK to here") {

                sim.addWork(to: sliderTime)

            }

            .buttonStyle(.borderedProminent)

            Button("Add REST to here") {

                sim.addRest(to: sliderTime)

            }

            .buttonStyle(.bordered)

            Button("Reset") {

                sim.reset()

                sliderTime = 0

                simStartDate = {

                    var cal = Calendar(identifier: .gregorian)

                    cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

                    return cal.startOfDay(for: Date())

                }()

            }

            .buttonStyle(.bordered)

        }

    }    // add work/rest/reset

    private var driverSummarySection: some View { 

        VStack(alignment: .leading, spacing: 8) {

            Text("Driver Summary")

                .font(.headline)

            ForEach(driverSummaryGrowing, id: \.dayStart) { day in

                HStack {

                    VStack(alignment: .leading) {

                        Text(day.dayStart, style: .date)

                            .font(.subheadline)

                        if day.totalWork == 0 {

                            Text("OFF")

                                .foregroundColor(.secondary)

                        } else {

                            Text("Start: \(timeString(day.firstWorkStart))")

                            Text("Finish: \(timeString(day.lastWorkEnd))")

                            Text("Work: \(fmt(day.totalWork))")

                        }

                    }

                    Spacer()

                    if day.hasNightRest {

                        Text("🌙")

                    }

                }

                .padding(.vertical, 4)

                Divider()

            }

        }

        .padding()

        .background(Color(.systemGray6))

        .cornerRadius(8)

    }    // the 14-day list

    private var segmentsSection: some View { 

        //========================================

        // Timeline of simulated segments

        //========================================

        VStack(alignment: .leading, spacing: 6) {

            Text("Segments")

                .font(.headline)

            ForEach(sim.segments) { seg in

                HStack {

                    Text(seg.type == .work ? "WORK" : "REST")

                        .font(.caption)

                        .frame(width: 60, alignment: .leading)

                    Text("\(formatTimeHM(seg.start)) → \(formatTimeHM(seg.end))")

                        .font(.caption2)

                        .foregroundColor(.secondary)

                }

            }

            if sim.segments.isEmpty {

                Text("No segments yet. Use the buttons above to build a day.")

                    .font(.caption2)

                    .foregroundColor(.secondary)

                    .padding(.top, 4)

            }

        }

    }         // “Segments” list

    private func timeString(_ date: Date?) -> String {

        guard let date else { return "--:--" }

        let formatter = DateFormatter()

        formatter.dateFormat = "HH:mm"

        return formatter.string(from: date)

    }

    private func fmt(_ seconds: TimeInterval) -> String {

        let s = Int(seconds)

        let h = s / 3600

        let m = (s % 3600) / 60

        return "\(h)h \(m)m"

    }

    //========================================

    // MARK: - Fatigue bars (mirrors TodayView)

    //========================================

    private var fatigueBars: some View {

        let workToday = sim.workSecondsToday

        let legalRest = sim.legalRestToday

        let hasTakenLegalRest15 = legalRest >= FatigueConstants.legalBreak15

        // 12h bar maths

        let twelveHours: TimeInterval = FatigueConstants.nhvrDailyCap

        let elevenHours: TimeInterval = CountdownThresholds.cautionThresholdMinutes

        let ratio = min(workToday / twelveHours, 1.0)

        let colour: Color

        if workToday <= elevenHours { colour = .green }

        else if workToday <= twelveHours { colour = .orange }

        else { colour = .red }

        let remaining = max(twelveHours - workToday, 0)

        return VStack(alignment: .leading, spacing: 16) {

            Text("Fatigue (simulated)")

                .font(.headline)

            // 5h15 spacing rule (NHVR-style) — Simulation semantics match TodayView:

            // - Grey circle until the first ≥15m legal rest exists

            // - Green tick once at least one ≥15m legal rest exists (and not breached)

            // - Red when breached (worked ≥5h15 since last ≥15m legal rest)

            VStack(alignment: .leading, spacing: 6) {

                let w = sim.workSinceLastRest()

                let limit: TimeInterval = FatigueConstants.nhvrSpacingLimit

                let (symbolName, color, statusText): (String, Color, String) = {

                    if w < limit {

                        let remaining = formatTimeHM(limit - w)

                        if !hasTakenLegalRest15 {

                            return ("circle", .gray,

                                    "No ≥15m legal rest logged yet. First legal rest due in \(remaining).")

                        } else {

                            return ("checkmark.circle.fill", .green,

                                    "OK. Next legal rest due in \(remaining).")

                        }

                    } else {

                        let over = formatTimeHM(w - limit)

                        return ("xmark.octagon.fill", .red,

                                "Over by \(over). Take ≥15m legal rest ASAP.")

                    }

                }()

                HStack(alignment: .top, spacing: 8) {

                    Image(systemName: symbolName)

                        .foregroundColor(color)

                    VStack(alignment: .leading, spacing: 2) {

                        Text("5h15 spacing rule (NHVR)")

                            .font(.subheadline)

                        Text("Max 5h15 work between ≥15m legal rests.")

                            .font(.caption2)

                            .foregroundColor(.secondary)

                        Text(statusText)

                            .font(.caption2)

                            .foregroundColor(color)

                    }

                }

            }

            // 12h total work bar

            VStack(alignment: .leading, spacing: 4) {

                HStack {

                    Text("Work today (total)")

                        .font(.subheadline)

                    Spacer()

                    Text("\(formatTimeHM(workToday)) / 12h 00m")

                        .font(.caption)

                }

                ProgressView(value: ratio)

                    .tint(colour)

                HStack {

                    Text("Total work towards 12h daily cap.")

                    Spacer()

                    Text("Remaining: \(formatTimeHM(remaining))")

                }

                .font(.caption2)

                .foregroundColor(.secondary)

            }

            // Countdown to NEXT rule using shared logic

            nextRuleCountdownSection

            Text("Legal rest today (≥15m blocks): \(formatTimeHM(legalRest))")

                .font(.caption2)

                .foregroundColor(.secondary)

        }

    }

    //========================================

    // MARK: - Countdown bar (shared engine)

    //========================================

    private var nextRuleCountdownSection: some View {

        let workToday     = sim.workSecondsToday

        let legalRest     = sim.legalRestToday

        let workSinceRest = sim.workSinceLastRest()

        let next = determineNextRule(

            workSinceRest: workSinceRest,

            workToday: workToday,

            legalRest: legalRest

        )

        let severity = countdownSeverity(

            forRemaining: next.remaining,

            window: next.window

        )

        let ratio = max(0.0, min(next.remaining / max(next.limit, 1), 1.0))

        let barColor: Color = {

            switch severity {

            case .normal:   return .green

            case .caution:  return .yellow

            case .warning:  return .orange

            case .critical: return .red

            case .breached: return .red

            }

        }()

        let barOpacity: Double =

        (severity == .breached && countdownFlashOn) ? 0.3 : 1.0

        let remaining = next.remaining

        let remainingText = formatTimeHM(abs(remaining))

        let sign = remaining >= 0 ? "" : "-"

        let subtitleText: String

        let subtitleColor: Color

        switch severity {

        case .breached:

            let ruleName = next.title.replacingOccurrences(of: "Next rule: ", with: "")

            subtitleText = "\(ruleName) is now due / exceeded. Take legal rest as soon as practicable."

            subtitleColor = .red

        case .critical:

            subtitleText = "\(next.descriptionPrefix) in \(remainingText)."

            subtitleColor = .red

        default:

            subtitleText = "\(next.descriptionPrefix) in \(remainingText)."

            subtitleColor = .secondary

        }

        return VStack(alignment: .leading, spacing: 4) {

            HStack {

                Text(next.title)

                    .font(.subheadline)

                Spacer()

                Text("\(sign)\(remainingText) remaining")

                    .font(.caption)

            }

            ProgressView(value: ratio)

                .tint(barColor)

                .opacity(barOpacity)

                .onAppear { updateCountdownFlashing(for: severity) }

                .onChange(of: severity, initial: false) { _, newSeverity in

                    updateCountdownFlashing(for: newSeverity)

                }

            Text(subtitleText)

                .font(.caption2)

                .foregroundColor(subtitleColor)

                .fixedSize(horizontal: false, vertical: true)

        }

        .padding(.top, 8)

    }

    private func updateCountdownFlashing(for severity: CountdownSeverity) {

        if severity == .breached {

            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {

                countdownFlashOn = true

            }

        } else {

            countdownFlashOn = false

        }

    }

    //========================================

    // MARK: - Engine bridge (Sim time → real Dates)

    //========================================

    private var engineNow: Date {

        simStartDate.addingTimeInterval(sliderTime)

    }

    private var engineSegments: [WorkRestSegment] {

        sim.segments.map { s in

            WorkRestSegment(

                kind: (s.type == .work) ? .work : .rest,

                start: simStartDate.addingTimeInterval(s.start),

                end: simStartDate.addingTimeInterval(s.end),

                stationaryRest: (s.type == .rest) // sim currently assumes rest is stationary

            )

        }

    }

    private var driverSummary14: [DailyDriverSummary] {

        FatigueEngine.build14DaySummary(

            segments: engineSegments,

            now: engineNow,

            tz: TimeZone(identifier: "Australia/Brisbane") ?? .current

        )

    }

  var driverSummaryGrowing: [DailyDriverSummary] {

        let tz = TimeZone(identifier: "Australia/Brisbane") ?? .current

        var cal = Calendar(identifier: .gregorian)

        cal.timeZone = tz

        let endDay   = cal.startOfDay(for: engineNow)

        let startDay = cal.date(byAdding: .day, value: -13, to: endDay)!

        // If you want night-rest to match the engine's judgement,

        // we can reuse build14DaySummary as a "night rest oracle" for nearby days.

        let nightByDay = Dictionary(uniqueKeysWithValues: driverSummary14.map { ($0.dayStart, $0.hasNightRest) })

        func minDate(_ a: Date?, _ b: Date) -> Date { a.map { min($0, b) } ?? b }

        func maxDate(_ a: Date?, _ b: Date) -> Date { a.map { max($0, b) } ?? b }

        var out: [DailyDriverSummary] = []

        var day = startDay

        while day <= endDay {

            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!

            var total: TimeInterval = 0

            var first: Date? = nil

            var last: Date?  = nil

            for seg in engineSegments where seg.kind == .work {

                let segStart = seg.start

                let segEnd   = seg.end ?? engineNow   // ✅ unwrap optional end using "now"

                // overlap test with [day, nextDay)

                if segEnd <= day || segStart >= nextDay { continue }

                let s = max(segStart, day)

                let e = min(segEnd, nextDay)

                if e > s {

                    total += e.timeIntervalSince(s)

                    first = minDate(first, s)

                    last  = maxDate(last, e)

                }

            }

            out.append(

                DailyDriverSummary(

                    dayStart: day,

                    firstWorkStart: first,

                    lastWorkEnd: last,

                    totalWork: total,

                    hasNightRest: nightByDay[day] ?? false

                )

            )

            day = nextDay

        }

        return out

    }

}

  

//======================================

// MARK: - Load template simulation panels

//======================================

  

private extension SimulationView {

    var templateEditor: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Draft template")

                .font(.headline)

            TextField("Template name", text: $model.draftTemplate.name)

                .textFieldStyle(.roundedBorder)

                .onChange(of: model.draftTemplate.name) { _, _ in

                    model.recalcDraftSimulation()

                }

            ForEach($model.draftTemplate.items) { $item in

                HStack(spacing: 12) {

                    // Product picker that writes into item.productShortName

                    Picker("", selection: $item.productShortName) {

                        Text("—").tag("")

                        ForEach(FuelProducts.all) { p in

                            Text(p.shortName).tag(p.shortName)

                        }

                    }

                    .pickerStyle(.menu)

                    .frame(width: 90, alignment: .leading)

                    .onChange(of: item.productShortName) { _, _ in

                        model.recalcDraftSimulation()

                    }

                    TextField("Litres", value: $item.litres, format: .number)

                        .textFieldStyle(.roundedBorder)

                        .keyboardType(.numberPad)

                        .frame(width: 90)

                        .onChange(of: item.litres) { _, _ in

                            model.recalcDraftSimulation()

                        }

                    // SG slider bound to the PRODUCT (same product moves together)

                    if let prod = FuelProducts.all.first(where: { $0.code == item.productShortName }) {

                        let sgBinding = Binding<Double>(

                            get: { model.sg(for: prod) },

                            set: { newValue in

                                model.setSg(newValue, for: prod)

                                model.recalcDraftSimulation()

                            }

                        )

                        HStack(spacing: 8) {

                            Text("SG").font(.caption)

                            Slider(value: sgBinding, in: prod.sgMin...prod.sgMax, step: 0.001)

                            Text(String(format: "%.3f", model.sg(for: prod)))

                                .font(.caption)

                                .foregroundStyle(.secondary)

                        }

                    }

                }

            }

        }

        .padding()

        .background(.thinMaterial)

        .cornerRadius(12)

    }

    var resultsPanel: some View {

        let r = model.draftSimulationResult

        return VStack(alignment: .leading, spacing: 8) {

            Text("Result")

                .font(.headline)

            Text("Total litres: \(r.totalLitres)")

            Text("Total mass: \(Int(r.totalMassKg)) kg")

            Divider()

            Text("Steer: \(Int(r.steerKg)) / \(Int(r.maxSteerKg)) kg")

            Text("Drive: \(Int(r.driveKg)) / \(Int(r.maxDriveKg)) kg")

            Text("GVM: \(Int(r.gvmKg)) / \(Int(r.maxGvmKg)) kg")

            if let warning = r.warning, !warning.isEmpty {

                Divider()

                Text(warning)

                    .font(.subheadline)

                    .foregroundStyle(.red)

            }

        }

        .padding()

        .background(.thinMaterial)

        .cornerRadius(12)

    }

    var templateLibrary: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("Saved templates")

                    .font(.headline)

                Spacer()

                Button("Save template") {

                    model.saveDraftAsNewTemplate()

                }

                .buttonStyle(.borderedProminent)

            }

            if model.savedTemplates.isEmpty {

                Text("No templates yet.")

                    .foregroundStyle(.secondary)

            } else {

                ForEach(model.savedTemplates) { t in

                    HStack {

                        VStack(alignment: .leading) {

                            Text(t.name).font(.headline)

                            Text("\(t.items.map { "\($0.compartmentName): \($0.productShortName) \($0.litres)L" }.joined(separator: "  •  "))")

                                .font(.caption)

                                .foregroundStyle(.secondary)

                                .lineLimit(2)

                        }

                        Spacer()

                        Button("Load") {

                            model.draftTemplate = t

                            model.recalcDraftSimulation()

                        }

                        .buttonStyle(.bordered)

                        Button("Apply to Load") {

                            model.applyTemplateToLoadPlan(t)

                        }

                        .buttonStyle(.borderedProminent)

                    }

                    .padding(.vertical, 6)

                }

            }

        }

        .padding()

        .background(.thinMaterial)

        .cornerRadius(12)

    }

}
```

  

---

  

## Views/Screens/SplashView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Splash Screen

//======================================

//

// Purpose:

// - Lightweight launch screen shown briefly on app startup.

// - Displays app name and build info parsed from PATCHLOG.md.

//

// Design notes:

// - Intentionally minimal to avoid delaying app load.

// - No animations or timers live here (handled by ContentView).

// - Safe to remain static even as the app grows.

//

// Future (optional):

// - Replace system icon with custom brand asset.

// - Add subtle animation if desired (fade / scale).

// - Optionally hide version/build info in release builds.

//======================================

  

struct SplashView: View {

    @Binding var progress: Double

    @Binding var status: String

    @Binding var didFinishSplash: Bool

    // MARK: - Build Info

    private var buildInfo: String {

        guard let url = Bundle.main.url(forResource: "PATCHLOG", withExtension: "md"),

              let content = try? String(contentsOf: url, encoding: .utf8)

        else {

            return "v?.?.? • unknown date"

        }

        let lines = content.split(separator: "\n").map { String($0) }

        // Find first header line starting with ##

        guard let header = lines.first(where: {

            $0.trimmingCharacters(in: .whitespaces).hasPrefix("##")

        }) else {

            return "v?.?.? • unknown date"

        }

        let version = parseVersion(from: header) ?? "?.?.?"

        let rawDate = parseDate(from: header)

        let pretty = prettyDate(from: rawDate)

        return "v\(version) • \(pretty)"

    }

    // MARK: - Parsing Helpers

    private func parseVersion(from line: String) -> String? {

        guard let open = line.firstIndex(of: "["),

              let close = line[open...].firstIndex(of: "]")

        else { return nil }

        let inner = line[line.index(after: open)..<close]

        let trimmed = inner.trimmingCharacters(in: .whitespaces)

        return trimmed.isEmpty ? nil : String(trimmed)

    }

    // Tolerant: finds last 8-digit numeric token

    private func parseDate(from line: String) -> String? {

        let tokens = line

            .split(whereSeparator: { $0.isWhitespace })

            .map { String($0) }

        guard let last = tokens.last,

              last.count == 8,

              last.allSatisfy({ $0.isNumber })

        else { return nil }

        return last

    }

    private func prettyDate(from yyyymmdd: String?) -> String {

        guard let raw = yyyymmdd else { return "unknown date" }

        let dfIn = DateFormatter()

        dfIn.locale = Locale(identifier: "en_AU")

        dfIn.dateFormat = "yyyyMMdd"

        let dfOut = DateFormatter()

        dfOut.locale = Locale(identifier: "en_AU")

        dfOut.dateFormat = "d MMM yyyy"

        guard let date = dfIn.date(from: raw) else {

            return raw

        }

        return dfOut.string(from: date)

    }

    // MARK: - UI

    var body: some View {

        ZStack {

            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {

                Image(systemName: "fuelpump.fill")

                    .font(.system(size: 80))

                    .foregroundColor(.accentColor)

                Text("Driver Assistant")

                    .font(.largeTitle.bold())

                Text(status)

                    .font(.title3)

                    .foregroundColor(.secondary)

                    .multilineTextAlignment(.center)

                    .padding(.horizontal, 40)

                ProgressView(value: progress, total: 1.0)

                    .progressViewStyle(.linear)

                    .frame(maxWidth: 280)

                Text(buildInfo)

                    .font(.footnote)

                    .foregroundColor(.gray)

            }

        }

    }

}

```

  

---

  

## Views/Screens/TodayView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - TODAY VIEW (Main Tab)

//======================================

//

// Role:

// - The main operational screen during a shift.

// - Owns UI state that is shared across TodayView partials

//   (actions, fatigue, planner, timeline).

//

// Layout:

// - Split view:

//   • Left: status, last shift summary, action buttons, timeline.

//   • Right: fatigue dashboard + planner.

//

// State management:

// - Timer tick drives live durations (drive/work/rest) via model.tick().

// - Odo capture is driven by model.odoPromptContext and shown as a sheet.

// - Sheet toggles owned here: showingOtherSheet, showingStartShift, showingSettings

// - Countdown flash animation state: countdownFlashOn (used by TodayView+Fatigue)

//

// Extension files:

// - TodayView+Actions.swift: action button grid

// - TodayView+StatusCard.swift: top status card

// - TodayView+Fatigue.swift: right panel fatigue dashboard

// - TodayView+Timeline.swift: bottom timeline section

//

// Notes:

// - Some @State vars appear "unused" in this file because they are used

//   by TodayView extensions (partials).

// - Extensions are in Partials/ folder but logically part of this screen.

//

//======================================

  

struct TodayView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    // Sheet toggles (owned here, used by partials)

    @State var showingOtherSheet = false

    @State var showingStartShift = false

    @State var showingSettings   = false

    // Used by TodayView+fatigue (countdown flashing)

    @State var countdownFlashOn  = false

        var currentStatusText: String {

            guard model.isOnDuty else { return "OFF DUTY" }

            switch model.currentActivity {

            case .driving:        return "DRIVING"

            case .workLoad:       return "LOADING"

            case .workUnload:     return "UNLOADING"

            case .workGeneral:    return "ON DUTY"

            case .restBreak:      return "ON BREAK"

            case .restBreakdown:  return "BREAKDOWN"

            case .offDuty:        return "OFF DUTY"

            }

        }

    private var odoSheetIsCritical: Bool {

        guard let ctx = model.odoPromptContext else { return false }

        return ctx == .shiftEnd || ctx == .shiftStart || ctx == .legalBreakEnd

    }

        //======================================

        // MARK: - Body (split layout)

        //======================================

        var body: some View {

            HStack(spacing: 0) {

                // LEFT COLUMN – controls, summary & timeline

                VStack(spacing: 16) {

                    statusCard

                    if !model.isOnDuty, let summary = model.lastShiftSummary {

                        ShiftSummaryView(summary: summary)

                    }

                    actionsBlock

                    Spacer()

                }

                .padding()

                .frame(maxWidth: 340, alignment: .top)

                .background(Color(.systemBackground))

                Divider()

                // RIGHT COLUMN – fatigue dashboard + planner

                ScrollView {

                    VStack(alignment: .leading, spacing: 16) {

                        workWindowSection

                        Divider()

                        timelineSection

                    }

                    .padding()

                }

                .background(Color(.systemGroupedBackground))

            }

            .sheet(isPresented: $showingStartShift) {

                StartShiftView(isPresented: $showingStartShift)

                    .environmentObject(model)

            }

            .sheet(isPresented: $showingOtherSheet) {

                OtherActivitySheet()

                    .environmentObject(model)

                    .presentationDetents([.large])

                    .presentationDragIndicator(.visible)

            }

            .sheet(isPresented: $model.isShowingIncidentSheet) {

                IncidentSheet()

                    .environmentObject(model)

            }

            // Odo capture sheet is driven by model.odoPromptContext (single source of truth).

            .sheet(

                isPresented: Binding(

                    get: { model.odoPromptContext != nil },

                    set: { newValue in

                        // If this sheet is "critical" (shift start/end / legal break end),

                        // ignore interactive dismiss attempts.

                        if !newValue {

                            if odoSheetIsCritical { return }

                            model.odoPromptContext = nil

                        }

                    }

                )

            ) {

                OdoLocationSheet()

                    .presentationDetents([.medium])

                    .presentationDragIndicator(odoSheetIsCritical ? .hidden : .visible)

                    .interactiveDismissDisabled(odoSheetIsCritical)

            }

            .onAppear {

                if model.isMissingShiftStartOdo {

                    model.requestOdoCapture(.shiftStart)

                }

            }

            .onChange(of: model.odoPromptContext) { _, newCtx in

                // If prompt got cleared but a mandatory gate is still pending, bring it back.

                if newCtx == nil {

                    if model.isMissingShiftStartOdo {

                        model.requestOdoCapture(.shiftStart)

                    } else if model.pendingEndShiftCapture {

                        model.requestOdoCapture(.shiftEnd)

                    }

                }

            }

        }

    }

```

  

---

  

## Views/Sheets/AboutView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - About & Patch Log (v0.2)

//======================================

//

// Purpose:

// - Show PATCHLOG.md bundled with the app (Markdown rendered in-place).

// - Provides a simple “About” screen without any persistence dependencies.

//

// Notes:

// - PATCHLOG.md must be included in the app target's bundle resources.

// - Rendering uses `Text(.init(markdown))` which supports basic Markdown.

// - This screen is intentionally simple; richer formatting can come later.

//======================================

  

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    private let markdown: String

    init() {

        self.markdown = AboutView.loadPatchlogMarkdown() ?? AboutView.fallbackMarkdown

    }

    var body: some View {

        NavigationView {

            ScrollView {

                // Text(.init(...)) renders basic Markdown

                Text(.init(markdown))

                    .frame(maxWidth: .infinity, alignment: .leading)

                    .padding()

            }

            .navigationTitle("About & Patch Log")

            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") { dismiss() }

                }

            }

        }

    }

}

  

// MARK: - Helpers

private extension AboutView {

    static func loadPatchlogMarkdown() -> String? {

        guard let url = Bundle.main.url(forResource: "PATCHLOG", withExtension: "md"),

              let data = try? Data(contentsOf: url),

              let text = String(data: data, encoding: .utf8)

        else {

            return nil

        }

        return text

    }

    static let fallbackMarkdown: String = """

    # Driver Assistant

    Patch log not found in bundle.

    Make sure PATCHLOG.md is in the app target’s **Resources**.

    """

}

```

  

---

  

## Views/Sheets/DebugDashboardView.swift

  

```swift

import SwiftUI

import CoreLocation

  

//======================================

// MARK: - Debug Dashboard

//======================================

//

// Purpose:

// - Comprehensive diagnostic view for development/testing

// - State inspection, edge case triggers, autosave management

// - Only visible when DebugFlags.debugMenu == true

//

// Categories:

// 1. State Inspector - live app state monitoring

// 2. WorkFlow gates - force problematic scenarios

// 3. GPS and Motion - inspect/clear/restore saves

// 4. Timeline and Events - fake motion states

// 5. Autosave Management - event log inspection

// 6. Edge case triggers - manual countdown adjustment

// 7. Destructive actions.

//

// Safety:

// - All destructive actions require confirmation

// - Clear labeling of what each action does

// - Separate from production Settings

//======================================

  

struct DebugDashboardView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    @Environment(\.dismiss) private var dismiss

    @State private var showingClearConfirm = false

    @State private var showingResetConfirm = false

    @State private var showingAutosaveInspector = false

    var body: some View {

        NavigationStack {

            Form {

                // MARK: State Inspector

                Section(header: Text("🔍 State Inspector")) {

                    stateInspectorContent

                }

                // MARK: Workflow Gates

                Section(header: Text("🚪 Workflow Gates")) {

                    workflowGatesContent

                }

                // MARK: GPS & Motion

                Section(header: Text("📍 GPS & Motion")) {

                    gpsMotionContent

                }

                // MARK: Timeline

                Section(header: Text("📋 Timeline & Events")) {

                    timelineForensicsContent

                }

                // MARK: Autosave

                Section(header: Text("💾 Autosave Management")) {

                    autosaveManagementContent

                }

                // MARK: Edge Case Triggers

                Section(header: Text("⚠️ Edge Case Triggers")) {

                    edgeCaseTriggersContent

                }

                // MARK: Destructive

                Section(header: Text("💣 Destructive Actions")) {

                    destructiveActionsContent

                }

            }

            .navigationTitle("Debug Dashboard")

            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") { dismiss() }

                }

            }

            .sheet(isPresented: $showingAutosaveInspector) {

                AutosaveInspectorSheet()

                    .environmentObject(model)

            }

        }

    }

    //==================================

    // MARK: - Sections

    //==================================

    private var stateInspectorContent: some View {

        VStack(alignment: .leading, spacing: 8) {

            LabeledContent("On Duty", value: model.isOnDuty ? "✅" : "❌")

            LabeledContent("Activity", value: model.currentActivity.rawValue)

            LabeledContent("Driving", value: model.isDriving ? "✅" : "❌")

            LabeledContent("On Break", value: model.isOnBreak ? "✅" : "❌")

            if let sid = model.runningSegmentID {

                LabeledContent("Running Segment", value: sid.uuidString)

            } else {

                LabeledContent("Running Segment", value: "nil")

            }

            LabeledContent("Drive Seconds Today", value: formatDuration(model.driveSecondsToday))

            LabeledContent("Work Seconds Today", value: formatDuration(model.workSecondsToday))

            LabeledContent("Rest Seconds Today", value: formatDuration(model.restSecondsToday))

            LabeledContent("Motion State", value: model.motionState.rawValue)

        }

    }

    private var workflowGatesContent: some View {

        VStack(alignment: .leading, spacing: 8) {

            LabeledContent("Pending Start ODO", value: model.pendingStartShiftCapture ? "🔒" : "✅")

            LabeledContent("Missing Shift ODO", value: model.isMissingShiftStartOdo ? "⚠️" : "✅")

            LabeledContent("ODO Context", value: model.odoPromptContext?.rawValue ?? "nil")

            if model.pendingActionAfterOdo != nil {

                Label("Pending Action Queued", systemImage: "exclamationmark.triangle.fill")

                    .foregroundColor(.orange)

            }

            LabeledContent("Load Mode", value: model.isUnloadMode ? "Unload" : "Load")

            LabeledContent("Prestart Done", value: model.prestartDone ? "✅" : "❌")

        }

    }

    private func overallCertaintyDetail(now: Date = Date()) -> CertaintyDetail {

        let gpsD = gpsCertaintyDetail(now: now)

        let motD = motionCertaintyDetail(now: now)

        let gps = gpsD.score

        let motion = motD.score

        let lower = min(gps, motion)

        let higher = max(gps, motion)

        let overallRaw: Double = {

            if lower < 20 { return Double(lower) }

            else if lower < 35 { return Double(lower) * 0.8 + Double(higher) * 0.2 }

            else { return Double(lower) * 0.65 + Double(higher) * 0.35 }

        }()

        let overall = max(0, min(100, Int(overallRaw.rounded())))

        let weaker = (gps <= motion) ? "GPS" : "Motion"

        let blendReason: String = {

            if lower < 20 { return "blend: HARD floor (weaker=\(weaker))" }

            if lower < 35 { return "blend: 80/20 toward weaker=\(weaker)" }

            return "blend: 65/35 toward weaker=\(weaker)"

        }()

        return CertaintyDetail(

            score: overall,

            ageSeconds: nil,

            reasons: [blendReason]

        )

    }

    private struct CertaintyDetail {

        var score: Int

        var ageSeconds: Double?          // nil = unknown

        var reasons: [String]            // already includes penalties

    }

    private var gpsMotionContent: some View {

        VStack(alignment: .leading, spacing: 10) {

            // -----------------------------

            // Certainty scores (driver-useful)

            // -----------------------------

            let gpsD = gpsCertaintyDetail()

            let motD = motionCertaintyDetail()

            let ovD  = overallCertaintyDetail()

            LabeledContent("Overall certainty", value: "\(certaintyLabel(ovD.score)) (\(ovD.score)%)")

            Text(ovD.reasons.joined(separator: " • "))

                .font(.caption2)

                .foregroundStyle(.secondary)

            LabeledContent("GPS certainty", value: "\(certaintyLabel(gpsD.score)) (\(gpsD.score)%)")

            if let a = gpsD.ageSeconds {

                Text("age: \(Int(a))s • \(gpsD.reasons.joined(separator: " • "))")

                    .font(.caption2)

                    .foregroundStyle(.secondary)

            } else {

                Text(gpsD.reasons.joined(separator: " • "))

                    .font(.caption2)

                    .foregroundStyle(.secondary)

            }

            LabeledContent("Motion certainty", value: "\(certaintyLabel(motD.score)) (\(motD.score)%)")

            if let a = motD.ageSeconds {

                Text("age: \(Int(a))s • \(motD.reasons.joined(separator: " • "))")

                    .font(.caption2)

                    .foregroundStyle(.secondary)

            } else {

                Text(motD.reasons.joined(separator: " • "))

                    .font(.caption2)

                    .foregroundStyle(.secondary)

            }

            Divider()

            // -----------------------------

            // Key evidence (keep it tight)

            // -----------------------------

            LabeledContent("Location Auth", value: locationManager.authDebug)

            LabeledContent("Service State", value: locationManager.stateDebug)

            if let acc = locationManager.lastLocation?.horizontalAccuracy {

                LabeledContent("Accuracy", value: "\(Int(acc.rounded())) m")

            } else {

                LabeledContent("Accuracy", value: "nil")

            }

            if let v = locationManager.lastValidSpeedMps {

                LabeledContent("Speed (valid)", value: String(format: "%.1f km/h", v * 3.6))

            } else if let raw = locationManager.rawSpeedMps {

                LabeledContent("Speed (raw)", value: String(format: "%.1f km/h", raw * 3.6))

            } else {

                LabeledContent("Speed", value: "nil")

            }

            if let ts = locationManager.lastLocation?.timestamp {

                LabeledContent("Last GPS update", value: formatTimeAgo(ts))

            } else if let t = locationManager.lastUpdateAt {

                LabeledContent("Last GPS update", value: formatTimeAgo(t))

            } else {

                LabeledContent("Last GPS update", value: "nil")

            }

            LabeledContent("Motion", value: model.motionState.shortLabel)

            Divider()

            // -----------------------------

            // Background Gap (advisory)

            // -----------------------------

            GroupBox("Background gap (advisory)") {

                VStack(alignment: .leading, spacing: 8) {

                    LabeledContent("Resume pending", value: model.backgroundGapResumePending ? "✅" : "—")

                    if let est = model.lastBackgroundGapEstimate {

                        LabeledContent("Suggested", value: "+\(est.suggestedOdoDeltaKm) km")

                        LabeledContent("Method", value: est.method.rawValue)

                        LabeledContent("Confidence", value: est.confidence.rawValue)

                        Text(est.note)

                            .font(.caption2.monospaced())

                            .foregroundStyle(.secondary)

                            .lineLimit(3)

                    } else {

                        LabeledContent("Last estimate", value: "nil")

                    }

                    LabeledContent("History count", value: "\(model.backgroundGapHistory.count)")

                    // ODO vs GPS window sanity check (spicy but useful)

                    let gpsWindow = model.gpsKmSinceLastOdoBySegment.values.reduce(0, +)

                    LabeledContent("GPS window since ODO", value: "\(fmtKm(gpsWindow)) km")

                    if let anchor = model.lastOdoAnchorKm,

                       let current = Int(model.odoText.filter(\.isNumber)) {

                        let odoDelta = max(0, current - anchor)

                        let err = Double(odoDelta) - gpsWindow

                        LabeledContent("ODOΔ vs GPSΔ", value: "\(odoDelta) km | err \(fmtKm(err)) km")

                    }

                    // Quick controls

                    HStack {

                        Button {

                            model.clearBackgroundGapAdvisory(reason: "Debug Dashboard")

                        } label: {

                            Label("Clear BG advisory", systemImage: "xmark.circle")

                        }

                        Spacer()

                        Button {

                            locationManager.kickUpdates(reason: "Debug Dashboard (BG)")

                        } label: {

                            Label("Kick GPS", systemImage: "location.circle")

                        }

                    }

                    .font(.caption)

                }

            }

            // -----------------------------

            // Details (nerd view)

            // -----------------------------

            DisclosureGroup("Details") {

                VStack(alignment: .leading, spacing: 10) {

                    // ==========================

                    // GPS evidence (score inputs)

                    // ==========================

                    GroupBox("GPS evidence (feeds GPS score)") {

                        VStack(alignment: .leading, spacing: 8) {

                            if let t = locationManager.lastUpdateAt {

                                LabeledContent("LM lastUpdateAt", value: formatTimeAgo(t))

                            } else { LabeledContent("LM lastUpdateAt", value: "nil") }

                            if let ts = locationManager.lastLocation?.timestamp {

                                LabeledContent("CLLocation.timestamp", value: formatTimeAgo(ts))

                            } else { LabeledContent("CLLocation.timestamp", value: "nil") }

                            if let acc = locationManager.lastLocation?.horizontalAccuracy {

                                LabeledContent("Accuracy", value: "\(Int(acc.rounded())) m")

                            } else { LabeledContent("Accuracy", value: "nil") }

                            LabeledContent("Auth", value: locationManager.authDebug)

                            LabeledContent("Service State", value: locationManager.stateDebug)

                            LabeledContent("LM lastDeltaMeters", value: String(format: "%.1f", locationManager.lastDeltaMeters))

                            LabeledContent("LM gpsShiftMeters", value: String(format: "%.1f", locationManager.gpsShiftMeters))

                        }

                    }

                    // ==========================

                    // Motion evidence (score inputs)

                    // ==========================

                    GroupBox("Motion evidence (feeds Motion score)") {

                        VStack(alignment: .leading, spacing: 8) {

                            if let v = locationManager.lastValidSpeedMps {

                                LabeledContent("Speed (valid)", value: String(format: "%.1f km/h", v * 3.6))

                            } else if let raw = locationManager.rawSpeedMps {

                                LabeledContent("Speed (raw)", value: String(format: "%.1f km/h", raw * 3.6))

                            } else {

                                LabeledContent("Speed", value: "nil")

                            }

                            if let smoothed = locationManager.speedMps {

                                LabeledContent("Speed (smoothed)", value: String(format: "%.1f km/h", smoothed * 3.6))

                            } else { LabeledContent("Speed (smoothed)", value: "nil") }

                            if let c = locationManager.courseDegrees {

                                LabeledContent("Course (°)", value: String(format: "%.0f", c))

                            } else { LabeledContent("Course (°)", value: "nil") }

                            Divider()

                            // Read-only snapshot (keeps your current “why is this happening?” clarity)

                            GroupBox("AppConfig (loaded)") {

                                VStack(alignment: .leading, spacing: 8) {

                                    LabeledContent("SavedAt", value: formatTimeAgo(model.appConfig.savedAt))

                                    LabeledContent("StrikesToUnsure", value: "\(model.motionTunables.qualityStrikesToUnsure)")

                                    LabeledContent("MaxPlausibleSpeed", value: String(format: "%.1f m/s", model.gpsT.maxPlausibleSpeedMpsForDistance))

                                    Button {

                                        model.reloadAppConfig(reason: "Debug Dashboard")

                                    } label: {

                                        Label("Reload AppConfig", systemImage: "arrow.clockwise")

                                    }

                                }

                            }

                            // AppModel motion pipeline

                            LabeledContent("MotionState", value: model.motionState.shortLabel)

                            if let t = model.lastSpeedSampleAt {

                                LabeledContent("App lastSpeedSampleAt", value: formatTimeAgo(t))

                            } else { LabeledContent("App lastSpeedSampleAt", value: "nil") }

                            if let s = model.lastKnownSpeedMps {

                                LabeledContent("App lastKnownSpeed", value: String(format: "%.1f km/h", s * 3.6))

                            } else { LabeledContent("App lastKnownSpeed", value: "nil") }

                            LabeledContent("SpeedSamples", value: "\(model.speedSamples.count)")

                            LabeledContent("CourseSamples", value: "\(model.courseSamples.count)")

                            if let start = model.stoppedAccumulatorStart {

                                LabeledContent("Stop accumulator", value: formatTimeAgo(start))

                            } else {

                                LabeledContent("Stop accumulator", value: "nil")

                            }

                        }

                    }

                    // ==========================

                    // 🛠 AppConfig tweakables (MOVED UP)

                    // ==========================

                    GroupBox("🛠 AppConfig (live)") {

                        if let t = model.lastConfigLoadedAt {

                            Text("Loaded: \(t.formatted())")

                                .font(.caption2)

                                .foregroundStyle(.secondary)

                        }

                        Stepper(

                            "Quality strikes → UNSURE: \(model.appConfig.motion.qualityStrikesToUnsure)",

                            value: Binding(

                                get: { model.appConfig.motion.qualityStrikesToUnsure },

                                set: { model.appConfig.motion.qualityStrikesToUnsure = $0 }

                            ),

                            in: 1...6

                        )

                        Slider(

                            value: Binding(

                                get: { model.appConfig.motion.gpsStaleSeconds },

                                set: { model.appConfig.motion.gpsStaleSeconds = $0 }

                            ),

                            in: 1...6,

                            step: 0.5

                        ) {

                            Text("GPS stale seconds")

                        }

                        Text("gpsStaleSeconds: \(model.appConfig.motion.gpsStaleSeconds, specifier: "%.1f")")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                        Button("Apply (no save)") {

                            model.applyHotConfig(reason: "Debug apply")

                        }

                        Button("Save to JSON") {

                            model.saveAppConfig(reason: "Debug Dashboard")

                        }

                        Button("Reload from JSON") {

                            model.reloadAppConfig(reason: "Reload from JSON (Debug)")

                        }

                    }

                    // ==========================

                    // Distance / ODO (not score inputs)

                    // ==========================

                    GroupBox("Distance / ODO evidence (not used by certainty)") {

                        VStack(alignment: .leading, spacing: 8) {

                            LabeledContent("Pending GPS km", value: String(format: "%.3f", model.gpsKmPendingUntilFirstSegment))

                            LabeledContent("Km this segment", value: String(format: "%.3f", model.currentSegmentKmApprox))

                            LabeledContent("Km this shift (LIVE GPS)", value: String(format: "%.3f", model.shiftKmLiveGps))

                            LabeledContent("Km this shift", value: String(format: "%.3f", model.shiftKmBySegmentsApprox))

                            let drift = model.shiftKmLiveGps - model.shiftKmBySegmentsApprox

                            LabeledContent("Δ live-seg", value: String(format: "%.2f km", drift))

                        }

                    }

                    Divider()

                    // Actions stay at bottom

                    Button {

                        model.resetMotionInference(reason: "Debug Dashboard")

                        locationManager.kickUpdates(reason: "Debug Dashboard")

                    } label: {

                        Label("Reset Motion + Kick GPS", systemImage: "arrow.clockwise.circle")

                    }

                    Button {

                        locationManager.kickUpdates(reason: "Debug Dashboard")

                    } label: {

                        Label("Kick GPS Only", systemImage: "location.circle")

                    }

                }

                .padding(.top, 6)

            }

        }

    }

    // =====================================================

    // MARK: - Certainty helpers (pasted inside DebugDashboardView)

    // =====================================================

    private func certaintyLabel(_ score: Int) -> String {

        switch score {

        case 80...100: return "HIGH"

        case 55...79:  return "MED"

        case 30...54:  return "LOW"

        default:       return "UNTRUSTWORTHY"

        }

    }

    private func gpsCertaintyDetail(now: Date = Date()) -> CertaintyDetail {

        if locationManager.authDebug == "denied" || locationManager.authDebug == "restricted" {

            return CertaintyDetail(score: 0, ageSeconds: nil, reasons: ["auth \(locationManager.authDebug) (0)"])

        }

        var score = 100

        var reasons: [String] = []

        if locationManager.stateDebug == "reduced" {

            score -= 25

            reasons.append("reduced accuracy (-25)")

        }

        if let acc = locationManager.lastLocation?.horizontalAccuracy {

            if acc > 100 { score -= 40; reasons.append("accuracy \(Int(acc))m (-40)") }

            else if acc > 50 { score -= 20; reasons.append("accuracy \(Int(acc))m (-20)") }

            else if acc > 20 { score -= 10; reasons.append("accuracy \(Int(acc))m (-10)") }

        } else {

            score -= 25

            reasons.append("accuracy nil (-25)")

        }

        let age: Double? = {

            if let ts = locationManager.lastLocation?.timestamp { return now.timeIntervalSince(ts) }

            if let t = locationManager.lastUpdateAt { return now.timeIntervalSince(t) }

            return nil

        }()

        if let a = age {

            if a > 20 { score -= 60; reasons.append("stale \(Int(a))s (-60)") }

            else if a > 10 { score -= 35; reasons.append("stale \(Int(a))s (-35)") }

            else if a > 5 { score -= 15; reasons.append("stale \(Int(a))s (-15)") }

        } else {

            score -= 40

            reasons.append("age unknown (-40)")

        }

        if locationManager.stateDebug == "stalled" {

            let stoppedish = (locationManager.lastValidSpeedMps ?? 999) < 1.0

            if stoppedish {

                score -= 10

                reasons.append("stalled but stopped (-10)")

            } else {

                score -= 40

                reasons.append("stalled while moving (-40)")

            }

        }

        score = max(0, min(100, score))

        return CertaintyDetail(score: score, ageSeconds: age, reasons: reasons)

    }

    private func motionCertaintyDetail(now: Date = Date()) -> CertaintyDetail {

        var score = 100

        var reasons: [String] = []

        if model.motionState == .unsure {

            return CertaintyDetail(

                score: 25,

                ageSeconds: model.lastSpeedSampleAt.map { now.timeIntervalSince($0) },

                reasons: ["motionState UNSURE (cap 25)"]

            )

        }

        let age: Double? = model.lastSpeedSampleAt.map { now.timeIntervalSince($0) }

        if let a = age {

            if a > 10 { score -= 70; reasons.append("stale \(Int(a))s (-70)") }

            else if a > 5 { score -= 35; reasons.append("stale \(Int(a))s (-35)") }

            else if a > 2.5 { score -= 15; reasons.append("stale \(String(format: "%.1f", a))s (-15)") }

        } else {

            score -= 70

            reasons.append("no samples (-70)")

        }

        if model.lastKnownSpeedMps == nil {

            score -= 40

            reasons.append("no lastKnownSpeed (-40)")

        }

        if let v = model.lastKnownSpeedMps, v >= 5.5, model.speedSamples.count < 3 {

            score -= 15

            reasons.append("few speed samples (\(model.speedSamples.count)) (-15)")

        }

        score = max(0, min(100, score))

        return CertaintyDetail(score: score, ageSeconds: age, reasons: reasons)

    }

    private var timelineForensicsContent: some View {

        VStack(alignment: .leading, spacing: 8) {

            LabeledContent("Total Events", value: "\(model.events.count)")

            LabeledContent("Segments Today", value: "\(model.timelineSegmentsIncludingCurrent.count)")

            LabeledContent("Confirmed Loads", value: "\(model.confirmedLoads.count)")

            if let last = model.events.last {

                LabeledContent("Last Event", value: last.kind.rawValue)

                LabeledContent("Event Time", value: formatTime(last.time))

            }

            NavigationLink {

                TimelineDebugView()

                    .environmentObject(model)

            } label: {

                Text("View Events List")

            }

            if !model.confirmedLoads.isEmpty {

                NavigationLink {

                    ConfirmedLoadsDebugView()

                        .environmentObject(model)

                } label: {

                    Text("Inspect Confirmed Loads")

                }

            }

        }

    }

    private var autosaveManagementContent: some View {

        VStack(alignment: .leading, spacing: 8) {

            Button {

                showingAutosaveInspector = true

            } label: {

                Label("Inspect Autosave Files", systemImage: "doc.text.magnifyingglass")

            }

            Button {

                model.autosave?.flushNow(reason: "Debug: Manual flush")

            } label: {

                Label("Force Autosave Now", systemImage: "arrow.down.doc.fill")

            }

            if let lastSave = model.autosave?.lastAutosaveAt {

                LabeledContent("Last Save", value: formatTimeAgo(lastSave))

            }

            if let stats = getAutosaveStats() {

                LabeledContent("Total Size", value: formatBytes(stats.bytes))

                LabeledContent("File Count", value: "\(stats.count)")

            }

            Divider()

            Button("Print Saves folder path") {

                SaveStore().debugPrintSaveFolder()

            }

            Button("Print JSON folders") {

                SaveStore().debugPrintJSONFolders()

            }

        }

    }

    private var edgeCaseTriggersContent: some View {

        VStack(alignment: .leading, spacing: 8) {

            Button {

                triggerOdoDeadlock()

            } label: {

                Label("Trigger ODO Deadlock", systemImage: "lock.fill")

            }

            Text("⚠️ Simulates a stuck ODO gate for testing recovery paths.")

                .font(.caption2)

                .foregroundColor(.orange)

        }

    }

    private var destructiveActionsContent: some View {

        VStack(alignment: .leading, spacing: 8) {

            Button(role: .destructive) {

                model.saveStore.clearAutosaves()

                model.resetTransientWorkflows()

                model.requestLmResetShiftMetersFromUI?("Debug: Clear autosave & unlock workflow")

            } label: {

                Label("Clear Autosave & Unlock Workflow", systemImage: "lock.open.fill")

            }

            Text("Use if app reopens stuck in ODO/Load after a crash.")

                .font(.caption2)

                .foregroundColor(.secondary)

            Divider()

            Button(role: .destructive) {

                showingClearConfirm = true

            } label: {

                Label("Clear All Autosaves", systemImage: "trash.fill")

            }

            .confirmationDialog(

                "Clear all autosave files? This cannot be undone.",

                isPresented: $showingClearConfirm,

                titleVisibility: .visible

            ) {

                Button("Clear Autosaves", role: .destructive) {

                    model.saveStore.clearAutosaves()

                    model.resetTransientWorkflows()

                    model.requestLmResetShiftMetersFromUI?("Debug: Clear autosave")

                }

                Button("Cancel", role: .cancel) {}

            }

            Button(role: .destructive) {

                showingResetConfirm = true

            } label: {

                Label("End Shift + Wipe Shift Data (in-memory)", systemImage: "arrow.counterclockwise.circle.fill")

            }

            .confirmationDialog(

                "End shift and wipe today’s in-memory shift data? (Pre-persistence only)",

                isPresented: $showingResetConfirm,

                titleVisibility: .visible

            ) {

                Button("Wipe Shift Data", role: .destructive) {

                    wipeShiftData()

                }

                Button("Cancel", role: .cancel) {}

            }

        }

    }

    //==================================

    // MARK: - Helpers

    //==================================

    private func formatDuration(_ seconds: TimeInterval) -> String {

        let h = Int(seconds) / 3600

        let m = (Int(seconds) % 3600) / 60

        return String(format: "%dh %02dm", h, m)

    }

    private func formatTime(_ date: Date) -> String {

        let f = DateFormatter()

        f.timeStyle = .short

        return f.string(from: date)

    }

    private func formatTimeAgo(_ date: Date) -> String {

        let seconds = Date().timeIntervalSince(date)

        if seconds < 60 { return "\(Int(seconds))s ago" }

        if seconds < 3600 { return "\(Int(seconds/60))m ago" }

        return "\(Int(seconds/3600))h ago"

    }

    private func formatBytes(_ bytes: Int) -> String {

        if bytes < 1024 { return "\(bytes) B" }

        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes)/1024) }

        return String(format: "%.2f MB", Double(bytes)/(1024*1024))

    }

    private func getAutosaveStats() -> (bytes: Int, count: Int)? {

        let urls = model.saveStore.debugAutosaveFileURLs()

        var total = 0

        var count = 0

        for url in urls {

            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),

               let size = attrs[.size] as? Int {

                total += size

                count += 1

            }

        }

        return count == 0 ? nil : (total, count)

    }

    private func fmtKm(_ km: Double) -> String {

        guard km.isFinite else { return "—" }

        return String(format: "%.2f", km)

    }

    private func triggerOdoDeadlock() {

        model.pendingStartShiftCapture = true

        model.odoPromptContext = .shiftStart

        DebugLog.ui("⚠️ ODO Deadlock triggered")

    }

    private func wipeShiftData() {

        if model.isOnDuty {

            model.endShift()

        }

        model.events.removeAll()

        model.confirmedLoads.removeAll()

        model.gpsKmPendingUntilFirstSegment = 0

        model.gpsKmSinceLastOdoBySegment.removeAll()

        model.finalisedKmBySegment.removeAll()

        model.runningSegmentID = nil

        model.saveStore.clearAutosaves()

        model.resetTransientWorkflows()

        DebugLog.ui("💣 Shift data wiped")

    }

}

  

//======================================

// MARK: - Timeline Debug View (v0.1.292)

//======================================

  

struct TimelineDebugView: View {

    @EnvironmentObject var model: AppModel

    var body: some View {

        List {

            ForEach(model.events.indices.reversed(), id: \.self) { idx in

                let e = model.events[idx]

                VStack(alignment: .leading, spacing: 6) {

                    HStack {

                        Text(e.kind.rawValue)

                            .font(.headline)

                        Spacer()

                        Text("#\(idx)")

                            .font(.caption)

                            .foregroundColor(.secondary)

                    }

                    Text(formatDateTime(e.time))

                        .font(.caption)

                        .foregroundColor(.secondary)

                    if let note = e.note, !note.isEmpty {

                        Text(note)

                            .font(.caption2)

                            .foregroundColor(.secondary)

                            .italic()

                    }

                }

                .padding(.vertical, 4)

            }

        }

        .navigationTitle("Events (\(model.events.count))")

        .navigationBarTitleDisplayMode(.inline)

    }

    private func formatDateTime(_ date: Date) -> String {

        let f = DateFormatter()

        f.dateStyle = .short

        f.timeStyle = .medium

        return f.string(from: date)

    }

}

  

//======================================

// MARK: - Confirmed Loads Debug View

//======================================

  

struct ConfirmedLoadsDebugView: View {

    @EnvironmentObject var model: AppModel

    private var rows: [(Int, ConfirmedLoad)] {

        Array(model.confirmedLoads.enumerated())

    }

    var body: some View {

        List {

            ForEach(rows, id: \.0) { idx, load in

                confirmedLoadSection(idx: idx, load: load)

            }

        }

        .navigationTitle("Confirmed Loads")

        .navigationBarTitleDisplayMode(.inline)

    }

    private struct ConfirmedLoadDetailView: View {

        let load: ConfirmedLoad

        let formatDateTime: (Date) -> String

        var body: some View {

            VStack(alignment: .leading, spacing: 8) {

                LabeledContent("Mode", value: load.mode.displayName)

                LabeledContent("Time", value: formatDateTime(load.timestamp))

                ForEach(load.compartments.indices, id: \.self) { i in

                    let comp = load.compartments[i]

                    HStack {

                        Text(comp.name)

                        Spacer()

                        Text("\(Int(comp.litres.rounded()))L \(comp.productShort)")

                            .foregroundColor(.secondary)

                    }

                    .font(.caption)

                }

            }

            .padding(.vertical, 4)

        }

    }

    @ViewBuilder

    private func confirmedLoadSection(idx: Int, load: ConfirmedLoad) -> some View {

        Section {

            ConfirmedLoadDetailView(

                load: load,

                formatDateTime: formatDateTime

            )

        } header: {

            Text("Load #\(idx + 1)")

                .font(.subheadline.bold())

        }

    }

    private func formatDateTime(_ date: Date) -> String {

        let f = DateFormatter()

        f.dateStyle = .short

        f.timeStyle = .short

        return f.string(from: date)

    }

}

  

//======================================

// MARK: - Autosave Inspector Sheet

//======================================

  

struct AutosaveInspectorSheet: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        NavigationStack {

            List {

                let urls = model.saveStore.debugAutosaveFileURLs()

                let fm = FileManager.default

                if urls.isEmpty {

                    Text("No autosave files found")

                        .foregroundColor(.secondary)

                } else {

                    ForEach(urls.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }), id: \.self) { url in

                        VStack(alignment: .leading, spacing: 6) {

                            Text(url.lastPathComponent)

                                .font(.headline)

                            if let attrs = try? fm.attributesOfItem(atPath: url.path) {

                                if let size = attrs[.size] as? Int {

                                    Text("Size: \(formatBytes(size))")

                                        .font(.caption)

                                        .foregroundColor(.secondary)

                                }

                                if let modified = attrs[.modificationDate] as? Date {

                                    Text("Modified: \(formatDateTime(modified))")

                                        .font(.caption)

                                        .foregroundColor(.secondary)

                                }

                            }

                        }

                        .padding(.vertical, 4)

                    }

                }

            }

            .navigationTitle("Autosave Files")

            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") { dismiss() }

                }

            }

        }

    }

    private func formatBytes(_ bytes: Int) -> String {

        if bytes < 1024 { return "\(bytes) B" }

        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes)/1024) }

        return String(format: "%.2f MB", Double(bytes)/(1024*1024))

    }

    private func formatDateTime(_ date: Date) -> String {

        let f = DateFormatter()

        f.dateStyle = .short

        f.timeStyle = .medium

        return f.string(from: date)

    }

}

```

  

---

  

## Views/Sheets/DeliverySheetView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - DeliverySheetView workflow (important note)

//======================================

//

// Current (pre-persistence, Phase 1):

// - Compartment-first workflow:

//     Compartment → Litres delivered

// - Optimised for speed during unload planning.

// - Directly mutates “remaining litres” on the load plan.

// - Assumes one product per compartment and simple delivery scenarios.

//

// Planned (post-persistence, Phase 3+):

// - Product-first, customer-centric workflow:

//     Customer → Product → Litres → Compartments

// - Support for:

//     • Multiple products delivered to the same customer

//     • Single product delivered from multiple compartments

//     • Multiple delivery lines per stop

// - Delivery becomes a first-class record (`DeliveryRecord` / `DeliveryLine`)

//   rather than a simple subtraction from remaining litres.

// - UI will likely become a multi-step sheet or modal stack.

//

// This file intentionally remains simple until:

// - Persistence is in place

// - Delivery history & reconciliation matter

// - Driver value outweighs added UI complexity

//======================================

  

struct DeliverySheetView: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCompName: String = ""

    @State private var litresText: String = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case litres }

    // Sanitise to digits-only so "1,000" or accidental characters don’t break parsing.

    private var litresDelivered: Int {

        let digits = litresText.filter { $0.isNumber }

        return Int(digits) ?? 0

    }

    private var canApply: Bool {

        !selectedCompName.isEmpty && litresDelivered > 0

    }

    var body: some View {

        NavigationView {

            Form {

                Section(header: Text("What are you doing?")) {

                    Text("Record delivery (litres delivered). The app will subtract it from remaining litres.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

                Section(header: Text("Compartment")) {

                    Picker("Compartment", selection: $selectedCompName) {

                        ForEach(model.compartments.map(\.name), id: \.self) { name in

                            Text(name).tag(name)

                        }

                    }

                    .pickerStyle(.menu)

                    .onChange(of: selectedCompName) { _, newValue in

                        guard !newValue.isEmpty else { return }

                        // ✅ after menu closes, jump focus to litres

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {

                            focusedField = .litres

                        }

                    }

                }

                Section(header: Text("Litres delivered")) {

                    TextField("0", text: $litresText)

                        .keyboardType(.numberPad)

                        .textInputAutocapitalization(.never)

                        .autocorrectionDisabled()

                        .focused($focusedField, equals: .litres)

                        .onChange(of: litresText) { _, newValue in

                            // Digits only; allow empty while typing.

                            let digits = newValue.filter { $0.isNumber }

                            if digits != newValue { litresText = digits }

                        }

                }

                Section {

                    Text("Tip: You can still type Remaining L directly on the main screen (override), but delivery is the normal driver workflow.")

                        .font(.caption2)

                        .foregroundColor(.secondary)

                }

            }

            .navigationTitle("Record delivery")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") { dismiss() }

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Apply") {

                        model.applyDelivery(

                            compName: selectedCompName,

                            litresDelivered: litresDelivered

                        )

                        dismiss()

                    }

                    .disabled(!canApply)

                }

                // ✅ Done button for numberPad

                ToolbarItemGroup(placement: .keyboard) {

                    Spacer()

                    Button("Done") { focusedField = nil }

                }

            }

            .onAppear {

                // Default selection for speed (avoid blank state).

                if selectedCompName.isEmpty {

                    selectedCompName = model.compartments.first?.name ?? ""

                }

                // ✅ if we already have a selection, focus litres immediately

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {

                    if !selectedCompName.isEmpty {

                        focusedField = .litres

                    }

                }

            }

        }

        .presentationDetents([.medium])

        .presentationDragIndicator(.visible)

        .scrollDismissesKeyboard(.interactively)

    }

}
```

  

---

  

## Views/Sheets/FillTruckSheet.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Fill Truck Sheet (Multi-Terminal Loading)

//======================================

//

// Purpose:

// - Record a partial load at a specific terminal

// - Allows multi-stop loading with distinct terminal/load code per fill

// - Creates confirmed load snapshot WITHOUT clearing compartments

//

// Workflow:

// 1. Driver loads at Terminal A (e.g. BP)

// 2. Presses "Fill Truck"

// 3. Enters terminal/load code for THIS fill

// 4. Press "Record Fill" → creates confirmed load

// 5. Compartments retain current litres (not cleared)

// 6. Driver drives to Terminal B (e.g. Chevron)

// 7. Adds more litres to compartments

// 8. Presses "Fill Truck" again

// 9. Different terminal/load code for THIS fill

// 10. Result: TWO confirmed loads with distinct terminals

//

// Difference from "Confirm this load":

// - "Confirm this load" assumes ONE terminal per full load

// - "Fill Truck" allows MULTIPLE terminals in one run

//

//======================================

  

struct FillTruckSheet: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    // Sheet-local draft fields (don't mutate model until "Record Fill")

    @State private var fillTerminalName: String = ""

    @State private var fillLoadCode: String = ""

    // For display only

    private var currentLitresPerComp: [(name: String, product: String, litres: Int)] {

        model.compartments.compactMap { comp in

            guard let product = comp.selectedProduct else { return nil }

            let litres = Int(comp.litresText) ?? 0

            guard litres > 0 else { return nil }

            return (comp.name, product.shortName, litres)

        }

    }

    private var totalLitres: Int {

        currentLitresPerComp.reduce(0) { $0 + $1.litres }

    }

    private var canRecord: Bool {

        !fillTerminalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&

        !fillLoadCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&

        totalLitres > 0

    }

    var body: some View {

        NavigationView {

            Form {

                Section(header: Text("This Fill")) {

                    TextField("Terminal", text: $fillTerminalName)

                        .textInputAutocapitalization(.words)

                    TextField("Load Code", text: $fillLoadCode)

                        .keyboardType(.numberPad)

                }

                Section(header: Text("Current On-Truck Litres")) {

                    if currentLitresPerComp.isEmpty {

                        Text("No products loaded")

                            .foregroundColor(.secondary)

                    } else {

                        ForEach(currentLitresPerComp, id: \.name) { comp in

                            HStack {

                                Text(comp.name)

                                    .frame(width: 40, alignment: .leading)

                                Text(comp.product)

                                    .frame(width: 60, alignment: .leading)

                                Spacer()

                                Text("\(comp.litres) L")

                                    .bold()

                            }

                            .font(.caption)

                        }

                        Divider()

                        HStack {

                            Text("Total")

                                .bold()

                            Spacer()

                            Text("\(totalLitres) L")

                                .bold()

                        }

                        .font(.subheadline)

                    }

                }

                Section {

                    Text("This records a partial load at this terminal. Compartments will NOT be cleared. You can load more at another terminal and record another fill.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

            }

            .navigationTitle("Fill Truck")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") { dismiss() }

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Record Fill") {

                        recordFill()

                        dismiss()

                    }

                    .disabled(!canRecord)

                }

            }

        }

        .presentationDetents([.medium])

        .presentationDragIndicator(.visible)

        .onAppear {

            // Pre-fill from last known values

            fillTerminalName = model.terminalName

            fillLoadCode = model.loadCode

        }

    }

    private func recordFill() {

        // Create a confirmed load snapshot using the SHEET's terminal/load code

        // (not model.terminalName/loadCode)

        let confirmTime = Date()

        // Ensure we're in Loading segment

        if model.isOnDuty {

            model.isDriving = false

            model.isOnBreak = false

            model.startActivity(.workLoad, at: confirmTime)

        }

        // Build compartment snapshots (same logic as confirmCurrentLoad)

        var compSnapshots: [ConfirmedCompartment] = []

        for comp in model.compartments {

            let litres = Double(comp.litresText) ?? 0

            guard litres > 0, let product = comp.selectedProduct else { continue }

            let sgValue = model.sg(for: product)

            let mass = litres * sgValue

            let snap = ConfirmedCompartment(

                name: comp.name,

                sfl: comp.capacityLitres,

                productShort: product.shortName,

                sg: sgValue,

                litres: litres,

                massKg: mass

            )

            compSnapshots.append(snap)

        }

        // Use SHEET values (not model values)

        let load = ConfirmedLoad(

            timestamp: confirmTime,

            mode: .loadConfirmed,

            terminalName: fillTerminalName.trimmingCharacters(in: .whitespacesAndNewlines),

            loadCode: fillLoadCode.trimmingCharacters(in: .whitespacesAndNewlines),

            vehicleId: model.vehicleId,

            driverName: model.settings.driverName,

            compartments: compSnapshots,

            totalLitres: model.totalLitres,

            totalMassKg: model.totalMassKg,

            steerKg: model.steerLoadedKg,

            driveKg: model.driveLoadedKg,

            gvmKg: model.gvmLoadedKg

        )

        model.confirmedLoads.append(load)

        // Log event

        model.logEvent(.load, note: "Fill @ \(fillTerminalName)", at: confirmTime)

        // DO NOT clear compartments (that's the point of "Fill Truck")

        // DO NOT set suppressPlacardUntilNextConfirm

    }

}

  

#Preview {

    FillTruckSheet()

        .environmentObject(AppModel())

}

```

  

---

  

## Views/Sheets/GuardPromptSheet.swift

  

```swift

import SwiftUI

  

struct GuardPromptSheet: View {

    @EnvironmentObject var model: AppModel

    let prompt: AppModel.GuardPrompt

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text(prompt.title)

                .font(.title3).bold()

            Text(prompt.message)

                .font(.body)

            Spacer()

            VStack(spacing: 12) {

                ForEach(Array(prompt.actions.enumerated()), id: \.offset) { _, action in

                    Button(role: action.role) {

                        action.handler()

                        model.activeGuardPrompt = nil

                    } label: {

                        Text(action.title).frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.borderedProminent)

                }

            }

        }

        .padding()

        .presentationDetents([.medium])

        .presentationDragIndicator(.visible)

    }

}

```

  

---

  

## Views/Sheets/IncidentSheet.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - INCIDENT SHEET (PRE-PERSISTENCE)

//======================================

//

// Purpose:

// - Calm triage UI + computed action plan.

// - Uses IncidentAdviceEngine (pure logic) + DriverSettings.

//

// Phase 1 scope:

// - No persistence.

// - “Save” logs a simple timeline event for now.

//

//======================================

  

struct IncidentSheet: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        NavigationStack {

            Group {

                if model.incidentDraft == nil {

                    emptyState

                } else {

                    content

                }

            }

            .navigationTitle("Incident")

            .toolbar {

                ToolbarItem(placement: .topBarLeading) {

                    Button("Close") { close() }

                }

                ToolbarItem(placement: .topBarTrailing) {

                    Button("Save") { saveAndClose() }

                        .disabled(model.incidentDraft == nil)

                }

            }

        }

        .onAppear {

            if model.incidentDraft == nil {

                model.beginIncidentDraft()

            }

            model.recomputeIncidentAdvice()

        }

        .onChange(of: model.incidentDraft?.id) { _, _ in

            model.recomputeIncidentAdvice()

        }

        .onDisappear {

            DebugLog.ui("DISAPPEAR: clearing draft/plan")

            model.incidentDraft = nil

            model.lastIncidentAdvicePlan = nil

        }

    }

    private var emptyState: some View {

        ContentUnavailableView("Preparing incident…", systemImage: "exclamationmark.triangle")

    }

    private var content: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 14) {

                // Context snapshot

                contextCard

                // Triage

                triageCard

                // Evidence

                evidenceCard

                // Action plan (computed)

                planCard

                Spacer(minLength: 18)

            }

            .padding()

        }

    }

    private var contextCard: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Context").font(.headline)

            if let r = model.incidentDraft {

                HStack {

                    Text("Time")

                    Spacer()

                    Text(r.timestamp.formatted(date: .abbreviated, time: .shortened))

                        .foregroundStyle(.secondary)

                }

                HStack {

                    Text("Suburb")

                    Spacer()

                    Text((r.suburb?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? r.suburb! : "—")

                        .foregroundStyle(.secondary)

                }

                HStack {

                    Text("GPS")

                    Spacer()

                    if let lat = r.latitude, let lon = r.longitude {

                        Text("\(lat, specifier: "%.5f"), \(lon, specifier: "%.5f")")

                            .foregroundStyle(.secondary)

                    } else {

                        Text("—").foregroundStyle(.secondary)

                    }

                }

            }

        }

        .padding()

        .background(Color(.secondarySystemGroupedBackground))

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private var triageCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Triage").font(.headline)

            if model.incidentDraft != nil {

                let r = Binding<IncidentReport>(

                    get: { model.incidentDraft! },

                    set: { model.incidentDraft = $0 }

                )

                Picker("Type", selection: r.type) {

                    ForEach(IncidentType.allCases, id: \.self) { t in

                        Text(t.rawValue.capitalized).tag(t)

                    }

                }

                Picker("Severity", selection: r.severity) {

                    Text("Info only").tag(IncidentSeverity.informationOnly)

                    Text("Minor").tag(IncidentSeverity.minor)

                    Text("Serious").tag(IncidentSeverity.serious)

                    Text("Emergency").tag(IncidentSeverity.emergency)

                }

                ternaryPicker("Safe stopped?", selection: r.isSafeStopped)

                ternaryPicker("Injuries?", selection: r.injuriesPresent)

                ternaryPicker("Fire or spill?", selection: r.fireOrSpill)

                // Only show hit & run when it makes sense

                if r.wrappedValue.type == .accident || r.wrappedValue.type == .nearMiss {

                    ternaryPicker("Hit & run?", selection: r.hitAndRun)

                }

            }

        }

        .padding()

        .background(Color(.secondarySystemGroupedBackground))

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private var evidenceCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Evidence").font(.headline)

            if model.incidentDraft != nil {

                let r = Binding<IncidentReport>(

                    get: { model.incidentDraft! },

                    set: { model.incidentDraft = $0 }

                )

                Stepper("Photos taken: \(r.wrappedValue.photosTakenCount)",

                        value: r.photosTakenCount,

                        in: 0...20)

                TextField("1 sentence note (optional)", text: Binding(

                    get: { r.wrappedValue.shortNote ?? "" },

                    set: { r.shortNote.wrappedValue = $0.isEmpty ? nil : $0 }

                ))

                .textFieldStyle(.roundedBorder)

                if model.settings.hasVehicleCamera {

                    Text("Dashcam: if safe, preserve footage / note the time.")

                        .font(.footnote)

                        .foregroundStyle(.secondary)

                }

            }

        }

        .padding()

        .background(Color(.secondarySystemGroupedBackground))

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private var planCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Action plan").font(.headline)

            if let plan = model.lastIncidentAdvicePlan {

                Text(plan.headline)

                    .foregroundStyle(.secondary)

                ForEach(plan.actions) { action in

                    HStack(alignment: .top, spacing: 10) {

                        Image(systemName: icon(for: action))

                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {

                            Text(title(for: action))

                                .font(.body)

                            if let sub = subtitle(for: action) {

                                Text(sub)

                                    .font(.footnote)

                                    .foregroundStyle(.secondary)

                            }

                        }

                        Spacer()

                    }

                    .padding(.vertical, 4)

                }

            } else {

                Text("No plan yet.")

                    .foregroundStyle(.secondary)

            }

        }

        .padding()

        .background(Color(.secondarySystemGroupedBackground))

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private func ternaryPicker(_ label: String, selection: Binding<TernaryAnswer>) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(label).font(.subheadline)

            Picker(label, selection: selection) {

                Text("Unknown").tag(TernaryAnswer.unknown)

                Text("Yes").tag(TernaryAnswer.yes)

                Text("No").tag(TernaryAnswer.no)

            }

            .pickerStyle(.segmented)

        }

    }

    private func close() {

        dismiss()

        model.isShowingIncidentSheet = false

        DispatchQueue.main.async {

            model.incidentDraft = nil

            model.lastIncidentAdvicePlan = nil

        }

    }

    private func saveAndClose() {

        DebugLog.persistence("SAVE: commit start, draft nil? \(model.incidentDraft == nil)")

        model.commitIncidentDraft()

        DebugLog.persistence("SAVE: commit done, closing sheet")

        model.isShowingIncidentSheet = false

    }

    private func icon(for action: IncidentAdviceAction) -> String {

        switch action {

        case .call000: return "phone.fill"

        case .callSpecialistAdvice: return "cross.case.fill"

        case .callSupervisor: return "person.crop.circle.badge.exclamationmark"

        case .callMechanic: return "wrench.and.screwdriver.fill"

        case .reportToPolicelink: return "building.columns.fill"

        case .takePhotos: return "camera.fill"

        case .writeShortNote: return "square.and.pencil"

        case .hydrateAndRest: return "cup.and.saucer.fill"

        }

    }

    private func title(for action: IncidentAdviceAction) -> String {

        switch action {

        case .call000:

            return "Call 000 (Emergency)"

        case .callSpecialistAdvice(_):

            return "Call specialist advice"

        case .callSupervisor(_):

            return "Call supervisor"

        case .callMechanic(_):

            return "Call mechanic"

        case .reportToPolicelink:

            return "Report via Policelink (non-urgent)"

        case .takePhotos(let count):

            return "Take \(count) photos"

        case .writeShortNote:

            return "Write 1 sentence note"

        case .hydrateAndRest:

            return "Drink water and take a breath"

        }

    }

    private func subtitle(for action: IncidentAdviceAction) -> String? {

        switch action {

        case .callSpecialistAdvice(let phone):

            return phone.isEmpty ? "Add number in Settings" : phone

        case .callSupervisor(let phone):

            return phone.isEmpty ? "Add number in Settings" : phone

        case .callMechanic(let phone):

            return phone.isEmpty ? "Add number in Settings" : phone

        case .reportToPolicelink:

            return model.settings.policelinkPhone

        default:

            return nil

        }

    }

}

```

  

---

  

## Views/Sheets/JournalSheet.swift

  

```swift

import SwiftUI

  

struct JournalSheet: View {

    var onClose: () -> Void

    var body: some View {

        VStack {

            HStack {

                Button("Close") { onClose() }

                Spacer()

                Text("Journal").font(.headline)

                Spacer()

                // spacer to balance Close button width

                Color.clear.frame(width: 60, height: 1)

            }

            .padding()

            Divider()

            Spacer()

            Text("Journal (placeholder)")

            Spacer()

        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

}

```

  

---

  

## Views/Sheets/LocationStatusView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Location Status Overlay (Top-Left)

//======================================

//

// Purpose:

// - Show live GPS/location service status

// - Alert driver to permission issues, staleness, reduced accuracy

// - Provide manual "Recover" button when GPS wedges

//

// Display:

// - Status banner (dismissible, auto-hide after 6s)

// - Status pill (always visible):

//   - Colored dot (green/orange/red)

//   - Service state label

//   - "Updated Xs ago" counter

//   - "Recover" button (when stalled/error)

//

// States:

// - idle: grey (not started yet)

// - running: green (good GPS)

// - requestingPermission: orange (waiting for user)

// - reducedAccuracy: orange (precise location OFF)

// - pausedOrStalled: orange (no updates >20s)

// - denied: red (location permission denied)

// - restricted: red (MDM/parental controls)

// - error: red (CoreLocation failure)

//

// Notes:

// - Owned by ContentView (overlaid above TabView)

// - Observes LocationManager @Published state

// - Ticks every 1s to update "Xs ago" counter

//

//======================================

  

struct LocationStatusView: View {

  

    @EnvironmentObject var locationManager: LocationManager

    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {

        VStack(spacing: 8) {

            // Banner (only shows when manager wants it)

            if locationManager.showStatusBanner, let msg = locationManager.lastStatusMessage {

                HStack(spacing: 8) {

                    Image(systemName: "location.circle")

                    Text(msg)

                        .font(.caption)

                        .lineLimit(3)

                    Spacer()

                    Button("Dismiss") {

                        locationManager.showStatusBanner = false

                    }

                    .font(.caption)

                }

                .padding(10)

                .background(.thinMaterial)

                .cornerRadius(10)

            }

            // Status pill

            HStack(spacing: 8) {

                Circle()

                    .frame(width: 10, height: 10)

                    .foregroundStyle(dotColor(for: locationManager.serviceState))

                Text(label(for: locationManager.serviceState))

                    .font(.caption)

                    .foregroundStyle(.secondary)

                    .lineLimit(1)

                Spacer()

                // Age (compact, always visible when we have a timestamp)

                if let t = locationManager.lastUpdateAt {

                    Text("Updated \(Int(now.timeIntervalSince(t)))s ago")

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                        .monospacedDigit()

                }

                // Recover button

                if shouldShowRecover(for: locationManager.serviceState) {

                    Button("Recover") {

                        locationManager.recover(reason: "UI Recover")

                    }

                    .font(.caption)

                    .buttonStyle(.bordered)

                }

            }

            .padding(10)

            .background(.thinMaterial)

            .cornerRadius(10)

        }

        .onReceive(ticker) { now = $0 } // attach once, not inside conditional

    }

    private func shouldShowRecover(for state: LocationManager.ServiceState) -> Bool {

        switch state {

        case .pausedOrStalled:

            return true

        case .error:

            return true

        default:

            return false

        }

    }

    private func label(for state: LocationManager.ServiceState) -> String {

        switch state {

        case .idle: return "Location: idle"

        case .requestingPermission: return "Location: requesting permission"

        case .running: return "Location: running"

        case .pausedOrStalled: return "Location: stalled"

        case .denied: return "Location: denied"

        case .restricted: return "Location: restricted"

        case .reducedAccuracy: return "Location: reduced accuracy (Precise OFF)"

        case .error(let msg): return "Location: error (\(msg))"

        }

    }

    private func dotColor(for state: LocationManager.ServiceState) -> Color {

        switch state {

        case .running: return .green

        case .requestingPermission, .reducedAccuracy, .pausedOrStalled: return .orange

        case .denied, .restricted, .error: return .red

        case .idle: return .gray

        }

    }

}

```

  

---

  

## Views/Sheets/NumbersSheet.swift

  

```swift

import SwiftUI

  

struct NumbersSheet: View {

    var onClose: () -> Void

    var body: some View {

        VStack {

            HStack {

                Button("Close") { onClose() }

                Spacer()

                Text("Numbers").font(.headline)

                Spacer()

                // spacer to balance Close button width

                Color.clear.frame(width: 60, height: 1)

            }

            .padding()

            Divider()

            Spacer()

            Text("Numbers (placeholder)")

            Spacer()

        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

}

```

  

---

  

## Views/Sheets/OtherActivitySheet.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Other Activity Sheet (Phase 1)

//======================================

//

// Purpose (pre-persistence):

// - Fast, driver-friendly way to log “non-standard” activities

//   that don’t deserve a dedicated button (e.g. paperwork, delays).

// - Allow ad-hoc creation AND immediate use in a single flow.

// - Optional note captured at start time (not retroactive editing).

//

// Design decisions (intentional):

// - Activities are lightweight labels, not fully-managed entities.

// - Creation + usage are combined to minimise taps while on duty.

// - Activities live in-memory on AppModel until persistence exists.

//

// Planned evolution (post-persistence):

// - Activities become editable entities (rename, reorder, archive, delete).

// - Notes may become time-ranged or editable after the fact.

// - “Other activity” may merge with a general activity editor.

// - Fleet / driver defaults may seed common activities.

//

// This sheet is intentionally *not* a full CRUD editor yet.

// Speed and safety take priority over completeness in Phase 1.

//======================================

  

struct OtherActivitySheet: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""

    @State private var isWork: Bool = true

    @State private var optionalNote: String = ""

    private var optionalNoteClean: String? {

        let t = optionalNote.trimmingCharacters(in: .whitespacesAndNewlines)

        return t.isEmpty ? nil : t

    }

    var body: some View {

        NavigationStack {

            VStack(spacing: 3) {

                // TOP: fixed, non-scrolling inputs

                Form {

                    Section(header: Text("Optional note")) {

                        TextField("e.g. gate delay / paperwork / spill kit", text: $optionalNote)

                    }

                    Section(header: Text("Add new activity")) {

                        TextField("Label (e.g. \"Paperwork\")", text: $newName)

                        Toggle("Counts as work (on duty)", isOn: $isWork)

                        Button("Add and use") { addAndUseActivity() }

                            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    }

                }

                .scrollDisabled(true)          // KEY: stops the form stealing scroll

                .frame(height: 260)            // tweak if you want (240–300)

                Divider()

                    .padding(.top, 6)

                    .padding(.vertical, 8)

                // BOTTOM: the only scrolling region

                if model.otherActivities.isEmpty {

                    Text("No saved activities yet.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .padding()

                    Spacer()

                } else {

                    List {

                        ForEach(model.otherActivities) { activity in

                            Button {

                                model.startOtherActivity(activity, note: optionalNoteClean)

                                dismiss()

                            } label: {

                                HStack {

                                    Text(activity.name)

                                    Spacer()

                                    Text(activity.isWork ? "Work" : "Rest")

                                        .font(.caption)

                                        .foregroundColor(.secondary)

                                }

                            }

                        }

                    }

                    .listStyle(.plain)

                }

            }

            .navigationTitle("Other activity")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") { dismiss() }

                }

            }

        }

    }

    private func addAndUseActivity() {

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }

        if let existing = model.otherActivities.first(where: {

            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame && $0.isWork == isWork

        }) {

            model.startOtherActivity(existing, note: optionalNoteClean)

            dismiss()

            return

        }

        let activity = OtherActivity(id: UUID(), name: trimmed, isWork: isWork)

        model.otherActivities.append(activity)

        model.startOtherActivity(activity, note: optionalNoteClean)

        dismiss()

    }

    }

```

  

---

  

## Views/Sheets/SettingsView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Settings (Phase 1)

//======================================

//

// Purpose (v0.2):

// - Single place to edit driver identity + truck label used on Today/Load.

// - Capture NHVR “base” info (name/address + radius) used by the Map tab.

// - Provide an About/Patch Log entry point.

//

// Notes:

// - Settings are currently bound directly to `model.settings`.

//   Pre-persistence this is fine; post-persistence we’ll likely:

//   - load/save `DriverSettings` to disk (SwiftData/CoreData/UserDefaults)

//   - possibly add “Apply/Cancel” behaviour if we want to avoid live edits.

//

// Safety/Scope:

// - The NHVR base radius is an informational planning aid (100 km zone context),

//   not an enforcement/policing feature. Any future warnings should be framed

//   as reminders / situational awareness, not legal adjudication.

//

// Future (post-persistence):

// - Default week definition (Mon–Sun vs Sun–Sat) and day-boundary settings

// - Rule set selector (Standard / BFM / AFM / Two-up) + company policy toggles

// - Saved terminals/customers/break spots + pin persistence

// - Theme selection (navy / grey / leather + logbook yellow sheets)

//======================================

  

struct SettingsView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    @Environment(\.dismiss) private var dismiss

    @State private var showingAbout = false

    @State private var showingDebugDashboard = false

    var body: some View {

        NavigationStack {

            Form {

                //==================================

                // MARK: Driver

                //==================================

                Section(header: Text("Driver")) {

                    TextField("Driver name", text: $model.driverProfile.driverName)

                    DisclosureGroup("Licence & hours") {

                        Picker("Licence", selection: $model.driverProfile.licenceType) {

                            ForEach(DriverProfilePayloadV1.LicenceType.allCases, id: \.self) { t in

                                Text(t.rawValue).tag(t)

                            }

                        }

                        Picker("Hours mode", selection: $model.driverProfile.licenceHoursMode) {

                            ForEach(DriverProfilePayloadV1.LicenceHoursMode.allCases, id: \.self) { m in

                                Text(m.rawValue).tag(m)

                            }

                        }

                        Picker("Crew", selection: $model.driverProfile.crewMode) {

                            ForEach(DriverProfilePayloadV1.CrewMode.allCases, id: \.self) { c in

                                Text(c.rawValue).tag(c)

                            }

                        }

                        Toggle("Owner-driver", isOn: $model.driverProfile.isOwnerDriver)

                    }

                }

                // Mark:- Truck (phase 1)

                Section(header: Text("Truck")) {

                    TextField("Selected truck (temporary)", text: $model.selectedTruckLabel)

                        .textInputAutocapitalization(.characters)

                    Text("Later this becomes a Truck Profile picker (linked by ID).")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

                //==================================

                // MARK: NHVR base (100 km rule)

                //==================================

                Section(header: Text("NHVR base (100 km rule)")) {

                    TextField("Base name (e.g. BP 6750 depot)",

                              text: $model.settingsProfile.nhvrBaseName)

                    TextField("Base address or description",

                              text: $model.settingsProfile.nhvrBaseAddress)

                    HStack {

                        Text("Radius (km)")

                        Spacer()

                        TextField("100",

                                  value: $model.settingsProfile.nhvrRadiusKm,

                                  format: .number)

                        .keyboardType(.numberPad)

                        .multilineTextAlignment(.trailing)

                        Text("km")

                            .foregroundColor(.secondary)

                    }

                    Text("Later on, this radius will help warn when you're leaving the 100 km zone and should be running a logbook.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .fixedSize(horizontal: false, vertical: true)

                }

                //==================================

                // MARK: Future (placeholder)

                //==================================

                Section(header: Text("Coming later")) {

                    Text("• Saved terminals, customers and break spots\n• Preference for fatigue rule set (Standard / BFM / AFM / Two-up)\n• Theme (navy / grey / leather)")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .fixedSize(horizontal: false, vertical: true)

                }

                //==================================

                // MARK: Debug Dashboard (dev only)

                //==================================

                if DebugFlags.debugMenu {

                    Section(header: Text("🔧 Developer Tools")) {

                        Button {

                            showingDebugDashboard = true

                        } label: {

                            HStack {

                                Label("Debug Dashboard", systemImage: "hammer.fill")

                                Spacer()

                                Image(systemName: "chevron.right")

                                    .foregroundColor(.secondary)

                                    .font(.caption)

                            }

                        }

                        Text("Comprehensive state inspector, edge case triggers, and diagnostic tools.")

                            .font(.caption)

                            .foregroundColor(.secondary)

                            .fixedSize(horizontal: false, vertical: true)

                    }

                }

                //==================================

                // MARK: About / Patch log

                //==================================

                Section {

                    Button {

                        showingAbout = true

                    } label: {

                        HStack {

                            Text("About")

                            Spacer()

                            Text("v\(AppBuildInfo.shared.version) • \(AppBuildInfo.shared.buildDatePretty)")

                                .foregroundColor(.secondary)

                        }

                        .font(.footnote)

                    }

                }

            }

            .navigationTitle("Settings")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") { dismiss() }

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Save") { 

                        model.saveProfilesToJSON()

                        dismiss()}

                }

            }

            .sheet(isPresented: $showingAbout) {

                AboutView()

            }

            .sheet(isPresented: $showingDebugDashboard) {

                DebugDashboardView()

                    .environmentObject(model)

                    .environmentObject(locationManager)

            }

        }

    }

}

```

  

---

  

## Views/Sheets/ShiftSummaryView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Shift summary card (Today tab)

//======================================

//

// Purpose (Phase 1 / v0.2):

// - Display a compact “last shift” snapshot when the driver is OFF DUTY.

// - Provide a simple “earliest next legal start” hint using Phase 1

//   back-calc logic (a conservative proxy until persistence + full rule engine).

//

// Data source:

// - `summary` is a precomputed ShiftSummary from AppModel.

// - `earliestSimpleStart` uses `phase1_earliestNextStart(from:)`

//

// Notes / limitations (pre-persistence):

// - This is *not* a full NHVR compliance engine across rolling windows.

// - “Earliest next legal start” is a simplified coaching aid, not a legal verdict.

// - Once persistence lands, this card can be powered by real multi-day history.

//

// Future (post-persistence):

// - Show shift duration, break compliance, and breaches with timestamps.

// - Allow tapping into History (day/week/fortnight/month) views.

// - Replace Phase 1 proxies with real rolling-window calculations.

//======================================

  

struct ShiftSummaryView: View {

    let summary: ShiftSummary

    @EnvironmentObject var model: AppModel

    // Conservative “next start” hint (Phase 1 proxy)

    private var earliestSimpleStart: Date {

        let proposed = model.phase1_earliestNextStart(from: summary.end)

        // Phase 1 safety: never show a start time earlier than the shift end.

        return max(summary.end, proposed)

    }

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Last shift summary")

                .font(.headline)

            if let start = summary.start {

                Text("Start: \(formatTimeShort(start))")

            }

            Text("End:   \(formatTimeShort(summary.end))")

            Divider()

            Text("Work: \(formatTimeHM(summary.workSeconds))")

            Text("Rest: \(formatTimeHM(summary.restSeconds))")

            Text("Driving: \(formatTimeHM(summary.driveSeconds))")

            Divider()

            Text("Loads: \(summary.loadCount)")

            Text("Unloads: \(summary.unloadCount)")

            Divider()

            // This reads from the live model (today proxy), not from the shift summary.

            // That’s OK pre-persistence; post-persistence we’ll likely compute/restamp

            // rest figures per shift/day from stored segments.

            Text("Legal rest today (≥15m blocks): \(formatTimeHM(model.phase1_restToday))")

                .font(.caption)

                .foregroundColor(.secondary)

            if earliestSimpleStart <= summary.end.addingTimeInterval(60) {

                VStack(alignment: .leading, spacing: 2) {

                    Text("Next start (Phase 1 proxy)")

                        .font(.caption)

                        .foregroundColor(.secondary)

                    Text("OK to start again now.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

                .padding(.top, 4)

            } else {

                Text("Earliest next start (Phase 1 proxy): \(formatTimeShort(earliestSimpleStart))")

                    .font(.caption)

                    .foregroundColor(.secondary)

                    .padding(.top, 4)

            }

        }

        .padding()

        .background(Color.gray.opacity(0.1))

        .cornerRadius(12)

    }

}

```

  

---

  

## Views/Sheets/StartShiftView.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Start shift sheet

//======================================

//

// Purpose (v0.2 / pre-persistence):

// - Starts an on-duty “shift” in AppModel.

// - Optionally lets the driver back-date the start time *for today*,

//   so the fatigue counters don’t pretend you started “right now” if you didn’t.

// - Triggers the mandatory start-of-shift odometer + suburb capture.

//

// What this is (and is not):

// - This is a driver assistant / logging convenience UI.

// - It does not attempt to “police” NHVR compliance; it helps the driver

//   keep their own records and avoid accidental undercounting.

//

// Notes / limitations (pre-persistence):

// - `firstWorkTime` only captures HH:MM today (DatePicker hour/min only).

//   If the driver started “yesterday” or across midnight, this won’t represent it.

//   Post-persistence: shift start should be an actual stored timestamp.

// - The “minutes” back-date is clamped to ≥ 0 (future times ignored).

// - Odo capture is queued after dismiss to avoid sheet-on-sheet weirdness.

//

// Future (post-persistence):

// - Replace “previousMinutes” with a stored shift start timestamp.

// - Allow selecting the actual start date/time (incl. yesterday) if needed.

// - Optionally capture location automatically (with manual override).

//======================================

  

enum BackfillKind: Hashable {

    case onDutyNotDriving

    case driving

    case rest

    case other(OtherActivity)

}

  

  

struct StartShiftView: View {

    @EnvironmentObject var model: AppModel

    @Binding var isPresented: Bool

    // Optional: “I actually started earlier today”

    @State private var firstWorkTime: Date = Date()

    @State private var backfillKind: BackfillKind = .onDutyNotDriving

  

    var body: some View {

        NavigationView {

            Form {

                Section(header: Text("Truck")) {

                    Text(model.settings.truckIdentifier.isEmpty

                         ? "Not set (see Settings)"

                         : model.settings.truckIdentifier)

                    .foregroundColor(.secondary)

                }

                Section(header: Text("First work time today (optional)")) {

                    Text("If you actually started earlier today, set the time you first went on duty. Leave as now if you're starting fresh.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .fixedSize(horizontal: false, vertical: true)

                    DatePicker(

                        "First work today",

                        selection: $firstWorkTime,

                        displayedComponents: [.hourAndMinute]

                    )

                }

                if firstWorkTime < Date() {

                    Section(header: Text("Backfilled time counts as")) {

                        Picker("Type", selection: $backfillKind) {

                            Text("On duty (not driving)").tag(BackfillKind.onDutyNotDriving)

                            Text("Driving").tag(BackfillKind.driving)

                            Text("Rest / Break").tag(BackfillKind.rest)

                            if !model.otherActivities.isEmpty {

                                Divider()

                                ForEach(model.otherActivities) { act in

                                    Text("Other – \(act.name)").tag(BackfillKind.other(act))

                                }

                            }

                        }

                        .pickerStyle(.menu)

                        Text("This applies only to the minutes between your chosen First work time and now.")

                            .font(.caption)

                            .foregroundColor(.secondary)

                            .fixedSize(horizontal: false, vertical: true)

                    }

                }

                Section {

                    Toggle("Prestart done (optional)", isOn: $model.prestartDone)

                }

            }

            .navigationTitle("Start Shift")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") { isPresented = false }

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Start") {

                        let now = Date()

                        // Convert “firstWorkTime today” into a back-date delta (minutes).

                        // Future times are treated as 0 to avoid negative offsets.

                        let minutes: Int

                        if firstWorkTime < now {

                            minutes = Int(now.timeIntervalSince(firstWorkTime) / 60)

                        } else {

                            minutes = 0

                        }

                       model.startShift(previousMinutes: minutes, backfillKind: backfillKind)

                        // Close this sheet, then prompt mandatory odo/suburb.

                        // (Avoid presenting another sheet while this one is still up.)

                        isPresented = false

                    }

                }

            }

        }

    }

}

```

  

---

  

## Views/Sheets/StoppedNudgeSheet.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Stopped While Driving Nudge Sheet

//======================================

//

// Purpose:

// - Alert driver when GPS shows sustained stop while marked "Driving"

// - Offer quick actions: Switch to Load / Unload / Keep Driving

//

// Trigger:

// - model.considerStoppedNudgeInLoad() detects:

//   - Speed ≤ 1 m/s for ≥ 90 seconds

//   - Driver is marked "Driving"

//   - Not on break

//

// Cooldown:

// - 5 minutes between nudges (prevents spam at traffic lights)

//

// Actions:

// - Switch to Load: sets isUnloadMode = false, calls model.pressLoad()

// - Switch to Unload: sets isUnloadMode = true, calls model.pressUnload()

// - Keep Driving (snooze): resets cooldown timer

// - Cancel: dismisses sheet only

//

// Design:

// - Compact layout (no scrolling needed)

// - Clear visual hierarchy

// - Non-alarmist language

//

// Pre-persistence:

// - No record of nudge shown/dismissed

//

// Post-persistence:

// - May create advisory event ("stopped nudge shown")

//

//======================================

  

struct StoppedNudgeSheet: View {

  

    let onLoad: () -> Void

    let onUnload: () -> Void

    let onKeepDriving: () -> Void

    let onCancel: () -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                Image(systemName: "exclamationmark.triangle")

                Text("You appear to be stopped")

                    .font(.headline)

                Spacer()

            }

            Text("You're marked as Driving, but speed has been near zero for ~90 seconds. What would you like to do?")

                .font(.subheadline)

                .foregroundStyle(.secondary)

                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {

                Button(action: onLoad) {

                    Label("Switch to Load", systemImage: "shippingbox")

                        .frame(maxWidth: .infinity)

                }

                .buttonStyle(.borderedProminent)

                Button(action: onUnload) {

                    Label("Switch to Unload", systemImage: "tray.and.arrow.down")

                        .frame(maxWidth: .infinity)

                }

                .buttonStyle(.bordered)

                Button(action: onKeepDriving) {

                    Label("Keep driving (snooze)", systemImage: "car")

                        .frame(maxWidth: .infinity)

                }

                .buttonStyle(.bordered)

                Button(role: .cancel, action: onCancel) {

                    Text("Cancel")

                        .frame(maxWidth: .infinity)

                }

            }

            Spacer(minLength: 0)

        }

        .padding()

    }

}

```

  

---

  

## Views/Sheets/TruckProfile2DSheet.swift

  

```swift

import SwiftUI

  

struct TruckProfile2DSheet: View {

    var onClose: () -> Void

    var body: some View {

        VStack {

            HStack {

                Button("Close") { onClose() }

                Spacer()

                Text("Truck").font(.headline)

                Spacer()

                // spacer to balance Close button width

                Color.clear.frame(width: 60, height: 1)

            }

            .padding()

            Divider()

            Spacer()

            Text("Truck (placeholder)")

            Spacer()

        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

}

```

  

---

  

## Views/ViewHelpers/Colour+MotionPill.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - Motion Pill Colors

//======================================

//

// Purpose:

// - Central place for the motion pill palette.

// - Keeps TodayView clean.

// - Easy to tweak later.

//

// Palette request:

// - Green

// - Greeny-yellow (lime)

// - Yellowy-orange

// - Grey

//  Event flash (NOT a trust level):

//   - Manual override pulse = cyan

//=====================================

//======================================

  

extension Color {

    static let motionTrustHigh = Color.green

    static let motionTrustMed  = Color(red: 0.90, green: 0.90, blue: 0.10)      // lime-ish

    static let motionTrustLow  = Color(red: 0.98, green: 0.70, blue: 0.20)      // yellow-orange

    static let motionTrustBad  = Color.gray

    // Manual override pulse (event colour, NOT a trust level)

    static let motionManualOverride = Color(red: 0.00, green: 0.75, blue: 0.85)

}

  

//======================================

// MARK: - Motion Pill View (drop-in)

//======================================

//

// Usage:

// MotionPill(

//   title: model.motionStateLabel,

//   state: model.motionState,

//   isManualResetPulsing: model.isManualResetPulsing

// 

  

  

struct MotionPillView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    // Local UI-only state for the cyan pulse

    @State private var isPulsingManualReset: Bool = false

    private let stuckSeconds: TimeInterval = 8

    private var isStuckUnsure: Bool {

        guard model.motionState == .unsure else { return false }

        guard let t = model.lastSpeedSampleAt else { return true }

        return Date().timeIntervalSince(t) >= stuckSeconds

    }

    private var baseBackground: Color {

        let band = model.overallCertaintyBandForUI()

        let base: Color = {

            switch band {

            case .high:          return .motionTrustHigh

            case .medium:        return .motionTrustMed

            case .low:           return .motionTrustLow

            case .untrustworthy: return .motionTrustBad

            }

        }()

        // UNSURE always washed out

        if model.motionState == .unsure {

            return Color.gray.opacity(0.25)

        }

        // Low-speed crawl muted but still reflects confidence

        let lowSpeedCrawl: Bool = {

            guard let speed = model.speedKmh else { return false }

            return model.motionState == .crawling && speed < 5

        }()

        return lowSpeedCrawl ? base.opacity(0.18) : base.opacity(0.22)

    }

    private var background: Color {

        // Manual override pulse is an exception colour

        if isPulsingManualReset {

            return Color.motionManualOverride.opacity(0.45)

        }

        return baseBackground

    }

    private var foreground: AnyShapeStyle {

        AnyShapeStyle(.primary.opacity(0.75))

    }

    var body: some View {

        HStack(spacing: 8) {

            if model.showMotionDebug {

                Text(model.motionState.shortLabel)

                    .font(.caption2.monospaced())

                    .padding(.horizontal, 6)

                    .padding(.vertical, 2)

                    .background(background)

                    .cornerRadius(6)

                    .foregroundStyle(foreground)

                    .contentShape(RoundedRectangle(cornerRadius: 6))

                    .onLongPressGesture(minimumDuration: 0.8) {

                        guard model.motionState == .unsure else { return }

                        // 1) Thump

                        Haptics.heavyImpact()

                        // 2) Cyan pulse (linger)

                        withAnimation(.easeInOut(duration: 0.25)) {

                            isPulsingManualReset = true

                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {

                            withAnimation(.easeInOut(duration: 0.25)) {

                                isPulsingManualReset = false

                            }

                        }

                        // 3) Logical reset + GPS kick

                        model.resetMotionInference(reason: "Pill long-press")

                        locationManager.kickUpdates(reason: "Pill long-press (stuck UNSURE)")

                    }

            }

        }

    }

}

```

  

---

  

## Views/ViewHelpers/FatigueRules+UI.swift

  

```swift

import SwiftUI

  

extension FatigueRuleStatus {

    var uiColor: Color {

        switch self {

        case .ok:      return .green

        case .warning: return .orange

        case .over:    return .red

        }

    }

}

```

  

---

  

## Views/ViewHelpers/View+FitText.swift

  

```swift

import SwiftUI

  

//======================================

// MARK: - View+FitText.swift

//======================================

// 

// overarching display helper for different screen sizes.

  

extension View {

    /// Scales text down to fit within its available space.

    /// Useful for tight UI (e.g. headers, pills, compact rows).

    ///

    /// - Parameters:

    ///   - minScale: Smallest allowed scale factor before truncation would occur.

    ///   - lines: Maximum number of lines to allow.

    func fitText(minScale: CGFloat = 0.6, lines: Int = 1) -> some View {

        self

            .lineLimit(lines)

            .minimumScaleFactor(minScale)

            .allowsTightening(true)

    }

}

```

  

---

  

All source code contained in this snapshot is the intellectual property of [Cory Russell Olsen].

Unauthorized reproduction or distribution is prohibited.

  

# END OF SNAPSHOT