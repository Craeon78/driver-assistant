//======================================
// MARK: - ClassificationHarnessView (V3 Chunk 2b)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Field instrument for the final Chunk 2b differentiation gate.
// Records canonical accepted GPS evidence and lets Cory mark SIMULATED segment
// boundaries while stationary. After the drive it overlays provisional episode
// classifications for human comparison against what actually happened.
//
// This harness creates no production Driver/Operations/Site truth.
//======================================

import SwiftUI
import CoreLocation
import MapKit

private struct ClassificationLiveLocation: CLLocationLike {
    let coordinate: (latitude: Double, longitude: Double)
    let horizontalAccuracy: Double
    let timestamp: Date
    let speed: Double
    private let location: CLLocation

    init(_ location: CLLocation) {
        self.location = location
        coordinate = (location.coordinate.latitude, location.coordinate.longitude)
        horizontalAccuracy = location.horizontalAccuracy
        timestamp = location.timestamp
        speed = location.speed
    }

    func distance(from other: CLLocationLike) -> Double {
        guard let other = other as? ClassificationLiveLocation else { return 0 }
        return location.distance(from: other.location)
    }
}

struct ClassificationHarnessView: View {
    @StateObject private var loc = ClassificationLocationManager()
    @State private var trail = BreadcrumbTrail()
    @State private var previousAccepted: ClassificationLiveLocation?
    @State private var boundaries: [SimulatedSegmentBoundary] = []
    @State private var episodes: [ClassifiedBreadcrumbEpisode] = []
    @State private var isRecording = false
    @State private var acceptedCount = 0
    @State private var rejectedCount = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var log: [String] = ["Ready. Boundary buttons are simulation markers only."]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Chunk 2b — Classification Gate")
                    .font(.headline)

                HStack {
                    Button(isRecording ? "Stop Recording" : "Start Recording") {
                        toggleRecording()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Mark Segment Boundary") {
                        markBoundary()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isRecording || trail.points.isEmpty)
                }

                Text("For safety, mark boundaries only while stationary. Missing-boundary test: deliberately omit a marker at one known destination-like stop and review it after the drive.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 18) {
                    metric("Dense", "\(trail.count)")
                    metric("GPS A/R", "\(acceptedCount)/\(rejectedCount)")
                    metric("Boundaries", "\(boundaries.count)")
                    metric("Episodes", "\(episodes.count)")
                    metric("Traffic", "\(count(.traffic))")
                    metric("Yard?", "\(count(.yardCandidate))")
                    metric("Unresolved", "\(count(.unresolved))")
                }

                if trail.count >= 2 {
                    Map(position: $cameraPosition) {
                        MapPolyline(coordinates: trail.points.map(coordinate))
                            .stroke(.gray.opacity(0.45), lineWidth: 2)

                        ForEach(episodes) { episode in
                            let points = episodePoints(episode)
                            if points.count >= 2 {
                                MapPolyline(coordinates: points.map(coordinate))
                                    .stroke(colour(episode.retentionClass), lineWidth: 6)
                            }
                        }

                        ForEach(boundaries) { boundary in
                            if let point = closestPoint(to: boundary.timestamp) {
                                Marker("Boundary", systemImage: "flag.fill", coordinate: coordinate(point))
                                    .tint(.purple)
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .frame(minHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Label("Traffic", systemImage: "line.diagonal").foregroundStyle(.orange)
                        Label("Yard candidate", systemImage: "line.diagonal").foregroundStyle(.green)
                        Label("Unresolved", systemImage: "line.diagonal").foregroundStyle(.red)
                        Spacer()
                        Button("Fit route") { cameraPosition = .automatic }
                            .buttonStyle(.bordered)
                    }
                    .font(.caption)
                } else {
                    ContentUnavailableView(
                        "Waiting for route",
                        systemImage: "map",
                        description: Text("Record accepted GPS evidence to begin the differentiation test.")
                    )
                    .frame(minHeight: 220)
                }

                Divider()

                Text("Episode audit")
                    .font(.subheadline.bold())

                if episodes.isEmpty {
                    Text("No low-movement episodes classified yet. Ordinary evidence outside episodes is implicitly NORMAL → E thinning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("#\(index + 1)  \(label(episode.retentionClass))")
                                .font(.system(.caption, design: .monospaced).bold())
                            Text(featureSummary(episode))
                                .font(.system(.caption2, design: .monospaced))
                            Text(episode.reasons.joined(separator: " • "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }

                Divider()

                Button("Reclassify") {
                    classify()
                }
                .buttonStyle(.bordered)

                Text("Human gate: compare coloured episodes with what actually happened. We want useful differentiation, not perfect destination recognition. Pins/Sites/Road Packs come later.")
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
        .onAppear {
            loc.onLocation = { cl in
                guard isRecording else { return }
                ingest(cl)
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            isRecording = false
            loc.stop()
            classify()
            cameraPosition = .automatic
            log.append("Stopped. Review coloured episodes against reality.")
        } else {
            trail = BreadcrumbTrail()
            previousAccepted = nil
            boundaries = []
            episodes = []
            acceptedCount = 0
            rejectedCount = 0
            cameraPosition = .automatic
            isRecording = true
            loc.request()
            log.append("Recording started")
        }
    }

    private func markBoundary() {
        guard let timestamp = trail.points.last?.timestamp else { return }
        boundaries.append(SimulatedSegmentBoundary(timestamp: timestamp))
        log.append("SIMULATED segment boundary marked")
        classify()
    }

    private func ingest(_ cl: CLLocation) {
        let live = ClassificationLiveLocation(cl)
        let result = GPSFilter.evaluate(newLocation: live, previousLocation: previousAccepted)

        switch result {
        case .accept:
            acceptedCount += 1
            previousAccepted = live
            trail.append(BreadcrumbPoint(
                latitude: cl.coordinate.latitude,
                longitude: cl.coordinate.longitude,
                accuracy: cl.horizontalAccuracy,
                speedMps: cl.speed,
                courseDegrees: cl.course >= 0 ? cl.course : nil,
                timestamp: cl.timestamp,
                isStopTransition: false,
                isKeyEvent: false
            ))
            if trail.count % 30 == 0 { classify() }
        case .rejectAccuracy, .rejectJump, .rejectSpeed, .rejectStale:
            rejectedCount += 1
        }
    }

    private func classify() {
        episodes = BreadcrumbEpisodeClassifier.classify(trail: trail, boundaries: boundaries)
        cameraPosition = .automatic
        log.append("Classified \(episodes.count) low-movement episodes")
    }

    private func count(_ retentionClass: BreadcrumbRetentionClass) -> Int {
        episodes.filter { $0.retentionClass == retentionClass }.count
    }

    private func episodePoints(_ episode: ClassifiedBreadcrumbEpisode) -> [BreadcrumbPoint] {
        guard episode.startIndex >= 0,
              episode.endIndex < trail.points.count,
              episode.startIndex <= episode.endIndex else { return [] }
        return Array(trail.points[episode.startIndex...episode.endIndex])
    }

    private func closestPoint(to timestamp: Date) -> BreadcrumbPoint? {
        trail.points.min { abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp)) }
    }

    private func coordinate(_ point: BreadcrumbPoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    private func colour(_ retentionClass: BreadcrumbRetentionClass) -> Color {
        switch retentionClass {
        case .normal: return .blue
        case .traffic: return .orange
        case .yardCandidate: return .green
        case .unresolved: return .red
        }
    }

    private func label(_ retentionClass: BreadcrumbRetentionClass) -> String {
        switch retentionClass {
        case .normal: return "NORMAL"
        case .traffic: return "TRAFFIC"
        case .yardCandidate: return "YARD CANDIDATE"
        case .unresolved: return "UNRESOLVED"
        }
    }

    private func featureSummary(_ episode: ClassifiedBreadcrumbEpisode) -> String {
        let f = episode.features
        return String(
            format: "%.0fs  path %.0fm  disp %.0fm  linear %.2f  radius %.0fm  stopped %.0f%%  heading %.0f°  boundary %@",
            f.durationSeconds,
            f.pathDistanceMeters,
            f.displacementMeters,
            f.linearity,
            f.maxRadiusFromStartMeters,
            f.stoppedFraction * 100,
            f.cumulativeHeadingChangeDegrees,
            f.nearSegmentBoundary ? "YES" : "NO"
        )
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.caption, design: .monospaced))
        }
    }
}

final class ClassificationLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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
        guard let latest = locations.last else { return }
        onLocation?(latest)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
