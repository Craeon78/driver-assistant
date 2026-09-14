//======================================
// MARK: - ClassificationHarnessView (V3 Chunk 2b)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Replacement Chunk 2b field instrument.
// Purpose:
// - Observe V3 rather than teach it during the drive.
// - Preserve accepted GPS evidence.
// - Snapshot the existing V3 MotionState alongside each accepted point.
// - Use driver-marked boundaries only to close/open test segments.
// - Infer a provisional DRIVE / OPERATIONAL / UNRESOLVED state per segment.
// - Let Cory correct both segment state and motion-state runs AFTER the fact.
//
// Important:
// - Raw machine observations are never overwritten by human corrections.
// - Corrections are stored separately as ground truth for later analysis.
// - The old TRAFFIC / YARD CANDIDATE episode classifier is intentionally not
//   used by this harness. It remains in Git history / test code for comparison.
// - This harness creates no production Driver/Operations/Site truth.
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

private enum SegmentMachineState: String, CaseIterable {
    case drive = "DRIVE"
    case operational = "OPERATIONAL"
    case unresolved = "UNRESOLVED"
}

private struct MotionObservation: Identifiable {
    let id = UUID()
    let trailIndex: Int
    let timestamp: Date
    let machineMotion: String
}

private struct MotionRun: Identifiable {
    let id: String
    let startIndex: Int
    let endIndex: Int
    let machineMotion: String
    let startTime: Date
    let endTime: Date

    var duration: TimeInterval { max(0, endTime.timeIntervalSince(startTime)) }
}

private struct SegmentAudit: Identifiable {
    let id: String
    let number: Int
    let startIndex: Int
    let endIndex: Int
    let startTime: Date
    let endTime: Date
    let machineState: SegmentMachineState
    let driveFraction: Double
    let operationalFraction: Double
    let unresolvedFraction: Double
    let averageSpeedKmh: Double
    let maxSpeedKmh: Double
    let distanceMeters: Double

    var duration: TimeInterval { max(0, endTime.timeIntervalSince(startTime)) }
}

struct ClassificationHarnessView: View {
    @EnvironmentObject private var model: AppModel

    @StateObject private var loc = ClassificationLocationManager()
    @State private var trail = BreadcrumbTrail()
    @State private var previousAccepted: ClassificationLiveLocation?
    @State private var boundaries: [SimulatedSegmentBoundary] = []
    @State private var observations: [MotionObservation] = []
    @State private var segmentGroundTruth: [String: SegmentMachineState] = [:]
    @State private var motionGroundTruth: [String: String] = [:]
    @State private var isRecording = false
    @State private var acceptedCount = 0
    @State private var rejectedCount = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var log: [String] = ["Ready. Observe first; infer second; correct after the fact."]

    private let motionChoices = ["stopped", "crawling", "accelerating", "decelerating", "cruising", "unsure"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Chunk 2b — Segment Observation Gate")
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

                Text("During the drive: record only. Mark segment boundaries only while stationary. Human correction happens afterwards so the test data is not contaminated while it is being generated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 18) {
                    metric("Dense", "\(trail.count)")
                    metric("GPS A/R", "\(acceptedCount)/\(rejectedCount)")
                    metric("Boundaries", "\(boundaries.count)")
                    metric("Motion obs", "\(observations.count)")
                    metric("Segments", "\(segments.count)")
                    metric("Corrected", "\(segmentGroundTruth.count)")
                }

                if trail.count >= 2 {
                    Map(position: $cameraPosition) {
                        MapPolyline(coordinates: trail.points.map(coordinate))
                            .stroke(.gray.opacity(0.45), lineWidth: 2)

                        ForEach(segments) { segment in
                            let points = segmentPoints(segment)
                            if points.count >= 2 {
                                MapPolyline(coordinates: points.map(coordinate))
                                    .stroke(colour(segment.machineState), lineWidth: 6)
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
                        Label("Drive", systemImage: "line.diagonal").foregroundStyle(.blue)
                        Label("Operational", systemImage: "line.diagonal").foregroundStyle(.green)
                        Label("Unresolved", systemImage: "line.diagonal").foregroundStyle(.orange)
                        Spacer()
                        Button("Fit route") { cameraPosition = .automatic }
                            .buttonStyle(.bordered)
                    }
                    .font(.caption)
                } else {
                    ContentUnavailableView(
                        "Waiting for route",
                        systemImage: "map",
                        description: Text("Record accepted GPS evidence to begin the segment test.")
                    )
                    .frame(minHeight: 220)
                }

                Divider()

                Text("Retrospective segment review")
                    .font(.subheadline.bold())

                if segments.isEmpty {
                    Text("A segment is created from recording start → first boundary, boundary → boundary, and final boundary → recording stop.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(segments) { segment in
                        segmentCard(segment)
                    }
                }

                Divider()

                Text("Motion-state audit")
                    .font(.subheadline.bold())

                Text("These are the existing V3 MotionState observations grouped into contiguous runs. A correction never changes the original machine value; it is stored separately as Cory ground truth.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if motionRuns.isEmpty {
                    Text("No motion-state runs captured yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(motionRuns) { run in
                        motionRunRow(run)
                    }
                }

                Divider()

                Text("Gate question")
                    .font(.subheadline.bold())
                Text("Can the existing V3 motion engine plus whole-segment context distinguish predominantly DRIVE from predominantly OPERATIONAL activity, while ordinary road stops remain merely motion evidence rather than being promoted into yard truth?")
                    .font(.caption)

                Text("Log")
                    .font(.subheadline.bold())
                ForEach(log.suffix(12), id: \.self) { line in
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

    @ViewBuilder
    private func segmentCard(_ segment: SegmentAudit) -> some View {
        let truth = segmentGroundTruth[segment.id]

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Segment \(segment.number)")
                    .font(.system(.caption, design: .monospaced).bold())
                Spacer()
                Text("Machine: \(segment.machineState.rawValue)")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(colour(segment.machineState))
            }

            Text(segmentSummary(segment))
                .font(.system(.caption2, design: .monospaced))

            Text("motion mix — drive \(percent(segment.driveFraction)) · operational \(percent(segment.operationalFraction)) · unsure \(percent(segment.unresolvedFraction))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Cory truth:")
                    .font(.caption.bold())

                ForEach(SegmentMachineState.allCases, id: \.self) { state in
                    Button(state.rawValue) {
                        segmentGroundTruth[segment.id] = state
                        log.append("Segment \(segment.number) corrected: \(segment.machineState.rawValue) → \(state.rawValue)")
                    }
                    .buttonStyle(.bordered)
                    .tint(truth == state ? colour(state) : nil)
                }

                if truth != nil {
                    Button("Clear") {
                        segmentGroundTruth.removeValue(forKey: segment.id)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            if let truth {
                Text(truth == segment.machineState ? "✓ Machine agrees with Cory" : "Correction retained separately: machine \(segment.machineState.rawValue), Cory \(truth.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(truth == segment.machineState ? .secondary : .orange)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func motionRunRow(_ run: MotionRun) -> some View {
        let key = motionTruthKey(run)
        let truth = motionGroundTruth[key]

        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(time(run.startTime))–\(time(run.endTime))  \(run.machineMotion.uppercased())")
                    .font(.system(.caption, design: .monospaced).bold())
                Spacer()
                Text("\(Int(run.duration.rounded()))s")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Ground truth")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Picker("Motion truth", selection: Binding(
                    get: { truth ?? run.machineMotion },
                    set: { newValue in
                        motionGroundTruth[key] = newValue
                        log.append("Motion run corrected: \(run.machineMotion) → \(newValue)")
                    }
                )) {
                    ForEach(motionChoices, id: \.self) { choice in
                        Text(choice.uppercased()).tag(choice)
                    }
                }
                .pickerStyle(.menu)

                if truth != nil {
                    Button("Clear") {
                        motionGroundTruth.removeValue(forKey: key)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleRecording() {
        if isRecording {
            isRecording = false
            loc.stop()
            cameraPosition = .automatic
            log.append("Stopped. Segments finalised for retrospective review.")
        } else {
            trail = BreadcrumbTrail()
            previousAccepted = nil
            boundaries = []
            observations = []
            segmentGroundTruth = [:]
            motionGroundTruth = [:]
            acceptedCount = 0
            rejectedCount = 0
            cameraPosition = .automatic
            isRecording = true
            loc.request()
            log.append("Recording started — observation only")
        }
    }

    private func markBoundary() {
        guard let timestamp = trail.points.last?.timestamp else { return }
        boundaries.append(SimulatedSegmentBoundary(timestamp: timestamp))
        cameraPosition = .automatic
        log.append("SIMULATED segment boundary marked")
    }

    private func ingest(_ cl: CLLocation) {
        let live = ClassificationLiveLocation(cl)
        let result = GPSFilter.evaluate(newLocation: live, previousLocation: previousAccepted)

        switch result {
        case .accept:
            acceptedCount += 1
            previousAccepted = live

            let point = BreadcrumbPoint(
                latitude: cl.coordinate.latitude,
                longitude: cl.coordinate.longitude,
                accuracy: cl.horizontalAccuracy,
                speedMps: cl.speed,
                courseDegrees: cl.course >= 0 ? cl.course : nil,
                timestamp: cl.timestamp,
                isStopTransition: false,
                isKeyEvent: false
            )
            trail.append(point)

            observations.append(MotionObservation(
                trailIndex: trail.points.count - 1,
                timestamp: cl.timestamp,
                machineMotion: model.motionState.rawValue
            ))

        case .rejectAccuracy, .rejectJump, .rejectSpeed, .rejectStale:
            rejectedCount += 1
        }
    }

    private var segments: [SegmentAudit] {
        guard trail.points.count >= 2 else { return [] }

        var cutIndices: [Int] = [0]
        for boundary in boundaries {
            if let idx = closestIndex(to: boundary.timestamp), idx > cutIndices.last! {
                cutIndices.append(idx)
            }
        }

        let last = trail.points.count - 1
        if cutIndices.last != last { cutIndices.append(last) }

        guard cutIndices.count >= 2 else { return [] }

        var result: [SegmentAudit] = []
        for pair in zip(cutIndices.dropLast(), cutIndices.dropFirst()) {
            let start = pair.0
            let end = pair.1
            guard end > start else { continue }
            result.append(makeSegment(number: result.count + 1, start: start, end: end))
        }
        return result
    }

    private func makeSegment(number: Int, start: Int, end: Int) -> SegmentAudit {
        let segmentPoints = Array(trail.points[start...end])
        let segmentObs = observations.filter { $0.trailIndex >= start && $0.trailIndex <= end }

        let validObs = segmentObs.filter { $0.machineMotion != "unsure" }
        let total = max(1, segmentObs.count)

        let driveCount = segmentObs.filter { ["accelerating", "decelerating", "cruising"].contains($0.machineMotion) }.count
        let operationalCount = segmentObs.filter { ["stopped", "crawling"].contains($0.machineMotion) }.count
        let unresolvedCount = total - driveCount - operationalCount

        let driveFraction = Double(driveCount) / Double(total)
        let operationalFraction = Double(operationalCount) / Double(total)
        let unresolvedFraction = Double(max(0, unresolvedCount)) / Double(total)

        let speeds = segmentPoints.map { max(0, $0.speedMps) * 3.6 }
        let averageSpeed = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
        let maxSpeed = speeds.max() ?? 0

        let state: SegmentMachineState = {
            guard validObs.count >= 3 else { return .unresolved }
            if driveFraction >= 0.55 { return .drive }
            if operationalFraction >= 0.65 && averageSpeed < 20 { return .operational }
            return .unresolved
        }()

        return SegmentAudit(
            id: "\(start)-\(end)",
            number: number,
            startIndex: start,
            endIndex: end,
            startTime: segmentPoints.first!.timestamp,
            endTime: segmentPoints.last!.timestamp,
            machineState: state,
            driveFraction: driveFraction,
            operationalFraction: operationalFraction,
            unresolvedFraction: unresolvedFraction,
            averageSpeedKmh: averageSpeed,
            maxSpeedKmh: maxSpeed,
            distanceMeters: pathDistance(segmentPoints)
        )
    }

    private var motionRuns: [MotionRun] {
        guard let first = observations.first else { return [] }

        var runs: [MotionRun] = []
        var runStart = first
        var previous = first

        for obs in observations.dropFirst() {
            if obs.machineMotion != runStart.machineMotion {
                runs.append(MotionRun(
                    id: "\(runStart.trailIndex)-\(previous.trailIndex)-\(runStart.machineMotion)",
                    startIndex: runStart.trailIndex,
                    endIndex: previous.trailIndex,
                    machineMotion: runStart.machineMotion,
                    startTime: runStart.timestamp,
                    endTime: previous.timestamp
                ))
                runStart = obs
            }
            previous = obs
        }

        runs.append(MotionRun(
            id: "\(runStart.trailIndex)-\(previous.trailIndex)-\(runStart.machineMotion)",
            startIndex: runStart.trailIndex,
            endIndex: previous.trailIndex,
            machineMotion: runStart.machineMotion,
            startTime: runStart.timestamp,
            endTime: previous.timestamp
        ))

        return runs
    }

    private func motionTruthKey(_ run: MotionRun) -> String {
        run.id
    }

    private func closestIndex(to timestamp: Date) -> Int? {
        trail.points.indices.min {
            abs(trail.points[$0].timestamp.timeIntervalSince(timestamp)) <
            abs(trail.points[$1].timestamp.timeIntervalSince(timestamp))
        }
    }

    private func closestPoint(to timestamp: Date) -> BreadcrumbPoint? {
        guard let idx = closestIndex(to: timestamp) else { return nil }
        return trail.points[idx]
    }

    private func segmentPoints(_ segment: SegmentAudit) -> [BreadcrumbPoint] {
        guard segment.startIndex >= 0,
              segment.endIndex < trail.points.count,
              segment.startIndex <= segment.endIndex else { return [] }
        return Array(trail.points[segment.startIndex...segment.endIndex])
    }

    private func coordinate(_ point: BreadcrumbPoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    private func pathDistance(_ points: [BreadcrumbPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for pair in zip(points.dropLast(), points.dropFirst()) {
            let a = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let b = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            total += b.distance(from: a)
        }
        return total
    }

    private func colour(_ state: SegmentMachineState) -> Color {
        switch state {
        case .drive: return .blue
        case .operational: return .green
        case .unresolved: return .orange
        }
    }

    private func segmentSummary(_ segment: SegmentAudit) -> String {
        String(
            format: "%.0fs  %.0fm  avg %.1fkm/h  max %.1fkm/h",
            segment.duration,
            segment.distanceMeters,
            segment.averageSpeedKmh,
            segment.maxSpeedKmh
        )
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
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
