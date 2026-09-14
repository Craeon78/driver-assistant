//======================================
// MARK: - ThinningHarnessView (V3 Chunk 2b)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Human-in-the-loop Playgrounds harness.
// Records dense breadcrumbs (or accepts a pre-loaded trail) and lets Cory
// live-tune the thinning policy to discover the practical floor.
//
// Replace ContentView with this view.
//
// Phase: Chunk 2b — Breadcrumb thinning
//======================================

import SwiftUI
import CoreLocation

struct ThinningHarnessView: View {
    @StateObject private var loc = ThinningLocationManager()
    @State private var trail = BreadcrumbTrail()
    @State private var policy = ThinningPolicy.default
    @State private var thinned: [BreadcrumbPoint] = []
    @State private var isRecording = false
    @State private var lastMotionStopped = false
    @State private var log: [String] = ["Ready. Start recording, drive, then tune the knobs."]

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

                if trail.count > 0 {
                    let ratio = Double(thinned.count) / Double(max(trail.count, 1))
                    Text(String(format: "Keep ratio: %.1f%%", ratio * 100))
                        .font(.system(.body, design: .monospaced))
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
        .onAppear {
            loc.onLocation = { cl in
                guard isRecording else { return }
                ingest(cl)
            }
        }
    }

    // MARK: - UI helpers

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

    // MARK: - Logic

    private func toggleRecording() {
        if isRecording {
            isRecording = false
            loc.stop()
            log.append("Recording stopped. Dense points: \(trail.count)")
            rethin()
        } else {
            trail = BreadcrumbTrail()
            thinned = []
            isRecording = true
            loc.request()
            log.append("Recording started")
        }
    }

    private func ingest(_ cl: CLLocation) {
        let speed = cl.speed
        let stopped = speed >= 0 && speed < 0.5
        let transition = stopped != lastMotionStopped
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

        // Live thin every ~20 points so the UI stays responsive
        if trail.count % 20 == 0 {
            rethin()
        }
    }

    private func rethin() {
        thinned = BreadcrumbThinner.thin(trail, policy: policy)
        let ratio = trail.count == 0 ? 0 : Double(thinned.count) / Double(trail.count)
        log.append(String(format: "Thinned %d → %d (%.1f%%)", trail.count, thinned.count, ratio * 100))
    }
}

// MARK: - Location manager (tiny)

final class ThinningLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onLocation: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
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
