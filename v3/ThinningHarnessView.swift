//======================================
// MARK: - ThinningHarnessView (V3 Chunk 2b)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Human-in-the-loop Playgrounds harness.
// Records the accepted dense GPS stream, applies live-tunable thinning,
// and lets Cory compare route, distance and event fidelity visually.
//
// Temporary Chunk 2b policy-training UI only — not final Journal UX.
//
// Replace ContentView with this view.
//
// Phase: Chunk 2b — Breadcrumb thinning
//======================================

import SwiftUI
import CoreLocation
import MapKit

private enum TrailDisplayMode: String, CaseIterable, Identifiable {
    case both = "Both"
    case dense = "Dense"
    case thinned = "Thinned"

    var id: String { rawValue }
}

// MARK: - CoreLocation adapter for the canonical GPS filter
private struct BreadcrumbLiveLocation: CLLocationLike {
    let coordinate: (latitude: Double, longitude: Double)
    let horizontalAccuracy: Double
    let timestamp: Date
    let speed: Double
    private let location: CLLocation

    init(_ location: CLLocation) {
        self.location = location
        self.coordinate = (location.coordinate.latitude, location.coordinate.longitude)
        self.horizontalAccuracy = location.horizontalAccuracy
        self.timestamp = location.timestamp
        self.speed = location.speed
    }

    func distance(from other: CLLocationLike) -> Double {
        guard let other = other as? BreadcrumbLiveLocation else { return 0 }
        return location.distance(from: other.location)
    }
}

struct ThinningHarnessView: View {
    @StateObject private var loc = ThinningLocationManager()
    @State private var trail = BreadcrumbTrail()
    @State private var policy = ThinningPolicy.default
    @State private var thinned: [BreadcrumbPoint] = []
    @State private var isRecording = false
    @State private var lastMotionStopped = false
    @State private var previousAcceptedLocation: BreadcrumbLiveLocation?
    @State private var acceptedCount = 0
    @State private var rejectedCount = 0
    @State private var displayMode: TrailDisplayMode = .both
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var log: [String] = ["Ready. Start recording, move, then tune the knobs."]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Chunk 2b — Breadcrumb Thinning")
                    .font(.headline)

                // Recording controls
                HStack {
                    Button(isRecording ? "Stop Recording" : "Start Recording") {
                        toggleRecording()
                    }
                    .buttonStyle(.borderedProminent)

                    Text("Dense: \(trail.count)")
                        .font(.system(.body, design: .monospaced))
                    Text("Thinned: \(thinned.count)")
                        .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 18) {
                    metric("Keep", keepRatioText)
                    metric("GPS A/R", "\(acceptedCount)/\(rejectedCount)")
                    metric("Dense km", distanceText(denseDistanceKm))
                    metric("Thin km", distanceText(thinnedDistanceKm))
                    metric("Δ distance", distanceDeltaText)
                    metric("Stops", "\(denseStopTransitions)→\(thinnedStopTransitions)")
                }

                Divider()

                // Visual fidelity test
                Text("Route fidelity")
                    .font(.subheadline.bold())

                Picker("Trail", selection: $displayMode) {
                    ForEach(TrailDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if trail.count >= 2 {
                    Map(position: $cameraPosition) {
                        if displayMode == .both || displayMode == .dense {
                            MapPolyline(coordinates: denseCoordinates)
                                .stroke(.blue.opacity(displayMode == .both ? 0.45 : 0.9), lineWidth: 3)
                        }

                        if (displayMode == .both || displayMode == .thinned), thinned.count >= 2 {
                            MapPolyline(coordinates: thinnedCoordinates)
                                .stroke(.red.opacity(0.9), lineWidth: 4)
                        }

                        if let first = trail.points.first {
                            Marker("Start", coordinate: coordinate(first))
                                .tint(.green)
                        }
                        if let last = trail.points.last, trail.count > 1 {
                            Marker("Latest", coordinate: coordinate(last))
                                .tint(.orange)
                        }
                    }
                    .mapStyle(.standard)
                    .frame(minHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Label("Dense", systemImage: "line.diagonal")
                            .foregroundStyle(.blue)
                        Label("Thinned", systemImage: "line.diagonal")
                            .foregroundStyle(.red)
                        Spacer()
                        Button("Fit route") {
                            cameraPosition = .automatic
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)
                } else {
                    ContentUnavailableView(
                        "Waiting for route",
                        systemImage: "map",
                        description: Text("Record at least two accepted GPS points to compare dense and thinned trails.")
                    )
                    .frame(minHeight: 220)
                }

                Divider()

                // Live knobs
                Text("Thinning knobs (drag to experiment)")
                    .font(.subheadline.bold())

                knob("Min time (s)", value: $policy.minTimeInterval, range: 5...120, step: 5)
                knob("Min distance (m)", value: $policy.minDistanceMeters, range: 5...200, step: 5)
                knob("Min heading (°)", value: $policy.minHeadingChangeDegrees, range: 5...90, step: 5)

                Toggle("Keep stop transitions", isOn: $policy.keepStopTransitions)
                Toggle("Keep key events", isOn: $policy.keepKeyEvents)

                Button("Re-thin now") { rethin() }
                    .buttonStyle(.bordered)

                Divider()

                Text("Decision test")
                    .font(.subheadline.bold())
                Text("Find the most aggressive settings where the thinned trail still tells you where you went and where you stopped, while distance and event fidelity remain acceptable.")
                    .font(.caption)

                Text("Log")
                    .font(.subheadline.bold())
                ForEach(log.suffix(10), id: \.self) { line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
                }
            }
            .padding()
        }
        .onChange(of: policy) { _, _ in rethin() }
        .onChange(of: displayMode) { _, _ in
            cameraPosition = .automatic
        }
        .onAppear {
            loc.onLocation = { cl in
                guard isRecording else { return }
                ingest(cl)
            }
        }
    }

    // MARK: - Derived metrics

    private var keepRatioText: String {
        guard trail.count > 0 else { return "0.0%" }
        return String(format: "%.1f%%", (Double(thinned.count) / Double(trail.count)) * 100)
    }

    private var denseDistanceKm: Double {
        pathDistanceKm(trail.points)
    }

    private var thinnedDistanceKm: Double {
        pathDistanceKm(thinned)
    }

    private var distanceDeltaText: String {
        guard denseDistanceKm > 0 else { return "—" }
        let delta = ((thinnedDistanceKm - denseDistanceKm) / denseDistanceKm) * 100
        return String(format: "%+.2f%%", delta)
    }

    private var denseStopTransitions: Int {
        trail.points.filter(\.isStopTransition).count
    }

    private var thinnedStopTransitions: Int {
        thinned.filter(\.isStopTransition).count
    }

    private var denseCoordinates: [CLLocationCoordinate2D] {
        trail.points.map(coordinate)
    }

    private var thinnedCoordinates: [CLLocationCoordinate2D] {
        thinned.map(coordinate)
    }

    // MARK: - UI helpers

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
    }

    private func knob(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.0f", value.wrappedValue))
                    .font(.system(.body, design: .monospaced))
            }
            Slider(value: value, in: range, step: step)
        }
    }

    // MARK: - Recording / filtering / thinning

    private func toggleRecording() {
        if isRecording {
            isRecording = false
            loc.stop()
            rethin()
            cameraPosition = .automatic
            log.append("Recording stopped. Accepted dense points: \(trail.count)")
        } else {
            trail = BreadcrumbTrail()
            thinned = []
            previousAcceptedLocation = nil
            acceptedCount = 0
            rejectedCount = 0
            lastMotionStopped = false
            cameraPosition = .automatic
            isRecording = true
            loc.request()
            log.append("Recording started")
        }
    }

    private func ingest(_ cl: CLLocation) {
        let live = BreadcrumbLiveLocation(cl)
        let result = GPSFilter.evaluate(
            newLocation: live,
            previousLocation: previousAcceptedLocation
        )

        switch result {
        case .accept:
            acceptedCount += 1
            previousAcceptedLocation = live
            appendAcceptedPoint(cl)

        case .rejectAccuracy:
            rejectedCount += 1
            logRejection("accuracy")
        case .rejectJump:
            rejectedCount += 1
            logRejection("jump")
        case .rejectSpeed:
            rejectedCount += 1
            logRejection("speed")
        case .rejectStale:
            rejectedCount += 1
            logRejection("stale")
        }
    }

    private func appendAcceptedPoint(_ cl: CLLocation) {
        let speed = cl.speed
        let stopped = speed >= 0 && speed < 0.5
        let transition = trail.count > 0 && stopped != lastMotionStopped
        lastMotionStopped = stopped

        let point = BreadcrumbPoint(
            latitude: cl.coordinate.latitude,
            longitude: cl.coordinate.longitude,
            accuracy: cl.horizontalAccuracy,
            speedMps: speed,
            courseDegrees: cl.course >= 0 ? cl.course : nil,
            timestamp: cl.timestamp,
            isStopTransition: transition,
            isKeyEvent: false
        )
        trail.append(point)

        // Give the map an immediate candidate trail, then avoid re-thinning
        // every single fix on long drives.
        if trail.count == 1 || trail.count % 20 == 0 {
            rethin(logResult: false)
        }
    }

    private func rethin(logResult: Bool = true) {
        thinned = BreadcrumbThinner.thin(trail, policy: policy)
        cameraPosition = .automatic
        guard logResult else { return }
        let ratio = trail.count == 0 ? 0 : Double(thinned.count) / Double(trail.count)
        log.append(String(format: "Thinned %d → %d (%.1f%%), Δdist %@",
                          trail.count,
                          thinned.count,
                          ratio * 100,
                          distanceDeltaText))
    }

    private func logRejection(_ reason: String) {
        // Avoid flooding the UI log during a poor-fix burst.
        if rejectedCount <= 5 || rejectedCount % 10 == 0 {
            log.append("GPS rejected: \(reason) (total \(rejectedCount))")
        }
    }

    // MARK: - Geometry

    private func coordinate(_ point: BreadcrumbPoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    private func pathDistanceKm(_ points: [BreadcrumbPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var metres = 0.0
        var previous = CLLocation(latitude: points[0].latitude, longitude: points[0].longitude)

        for point in points.dropFirst() {
            let current = CLLocation(latitude: point.latitude, longitude: point.longitude)
            metres += current.distance(from: previous)
            previous = current
        }
        return metres / 1000.0
    }

    private func distanceText(_ km: Double) -> String {
        if km < 1 {
            return String(format: "%.0f m", km * 1000)
        }
        return String(format: "%.2f", km)
    }
}

// MARK: - Location manager (temporary harness)

final class ThinningLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onLocation: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = false
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        onLocation?(loc)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// Convenience so Playgrounds can just use ContentView = ThinningHarnessView
typealias ContentView = ThinningHarnessView
