
  

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
