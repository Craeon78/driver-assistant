//======================================
// MARK: - ClassificationHarnessView (V3 Chunk 2b)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Replacement Chunk 2b field instrument.
// This file is deliberately self-contained so the iPad test target does not
// depend on the production AppModel source set.
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

private enum HarnessMotionState: String, CaseIterable {
    case stopped, crawling, moving, unsure
}

private struct MotionObservation: Identifiable {
    let id = UUID()
    let trailIndex: Int
    let timestamp: Date
    let machineMotion: HarnessMotionState
}

private struct MotionRun: Identifiable {
    let id: String
    let machineMotion: HarnessMotionState
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
    @StateObject private var loc = ClassificationLocationManager()
    @State private var trail = BreadcrumbTrail()
    @State private var previousAccepted: ClassificationLiveLocation?
    @State private var boundaries: [SimulatedSegmentBoundary] = []
    @State private var observations: [MotionObservation] = []
    @State private var segmentGroundTruth: [String: SegmentMachineState] = [:]
    @State private var motionGroundTruth: [String: HarnessMotionState] = [:]
    @State private var isRecording = false
    @State private var acceptedCount = 0
    @State private var rejectedCount = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var log: [String] = ["Ready. Observe first; infer second; correct after the fact."]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Chunk 2b — Segment Observation Gate").font(.headline)

                HStack {
                    Button(isRecording ? "Stop Recording" : "Start Recording") { toggleRecording() }
                        .buttonStyle(.borderedProminent)
                    Button("Mark Segment Boundary") { markBoundary() }
                        .buttonStyle(.bordered)
                        .disabled(!isRecording || trail.points.isEmpty)
                }

                Text("During the drive: record only. Mark boundaries only while stationary. Review/correct after recording.")
                    .font(.caption).foregroundStyle(.secondary)

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
                                Marker("Boundary", systemImage: "flag.fill", coordinate: coordinate(point)).tint(.purple)
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
                        Button("Fit route") { cameraPosition = .automatic }.buttonStyle(.bordered)
                    }.font(.caption)
                } else {
                    ContentUnavailableView("Waiting for route", systemImage: "map", description: Text("Record accepted GPS evidence to begin the segment test."))
                        .frame(minHeight: 220)
                }

                Divider()
                Text("Retrospective segment review").font(.subheadline.bold())
                if segments.isEmpty {
                    Text("Segments are recording start → boundary, boundary → boundary, and final boundary → stop.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(segments) { segment in segmentCard(segment) }
                }

                Divider()
                Text("Motion-state audit").font(.subheadline.bold())
                Text("Harness motion is intentionally simple: STOPPED / CRAWLING / MOVING / UNSURE. Corrections are retained separately from machine observations.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(motionRuns) { run in motionRunRow(run) }

                Divider()
                Text("Gate question").font(.subheadline.bold())
                Text("Can whole-segment context distinguish predominantly DRIVE from predominantly OPERATIONAL activity without ordinary road stops becoming yard truth?").font(.caption)

                Text("Log").font(.subheadline.bold())
                ForEach(log.suffix(12), id: \.self) { line in
                    Text(line).font(.system(.caption2, design: .monospaced))
                }
            }.padding()
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
                Text("Segment \(segment.number)").font(.system(.caption, design: .monospaced).bold())
                Spacer()
                Text("Machine: \(segment.machineState.rawValue)")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(colour(segment.machineState))
            }
            Text(segmentSummary(segment)).font(.system(.caption2, design: .monospaced))
            Text("motion mix — drive \(percent(segment.driveFraction)) · operational \(percent(segment.operationalFraction)) · unsure \(percent(segment.unresolvedFraction))")
                .font(.caption2).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Cory truth:").font(.caption.bold())
                ForEach(SegmentMachineState.allCases, id: \.self) { state in
                    Button(state.rawValue) {
                        segmentGroundTruth[segment.id] = state
                        log.append("Segment \(segment.number): \(segment.machineState.rawValue) → \(state.rawValue)")
                    }.buttonStyle(.bordered)
                }
                if truth != nil {
                    Button("Clear") { segmentGroundTruth.removeValue(forKey: segment.id) }
                        .buttonStyle(.borderless).font(.caption)
                }
            }

            if let truth {
                if truth == segment.machineState {
                    Text("✓ Machine agrees with Cory").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Correction retained separately: machine \(segment.machineState.rawValue), Cory \(truth.rawValue)")
                        .font(.caption2).foregroundStyle(Color.orange)
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func motionRunRow(_ run: MotionRun) -> some View {
        let truth = motionGroundTruth[run.id]
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(time(run.startTime))–\(time(run.endTime))  \(run.machineMotion.rawValue.uppercased())")
                    .font(.system(.caption, design: .monospaced).bold())
                Spacer()
                Text("\(Int(run.duration.rounded()))s").font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
            HStack {
                Text("Ground truth").font(.caption2).foregroundStyle(.secondary)
                Picker("Motion truth", selection: Binding(
                    get: { truth ?? run.machineMotion },
                    set: { newValue in
                        motionGroundTruth[run.id] = newValue
                        log.append("Motion run: \(run.machineMotion.rawValue) → \(newValue.rawValue)")
                    }
                )) {
                    ForEach(HarnessMotionState.allCases, id: \.self) { choice in
                        Text(choice.rawValue.uppercased()).tag(choice)
                    }
                }.pickerStyle(.menu)
                if truth != nil {
                    Button("Clear") { motionGroundTruth.removeValue(forKey: run.id) }
                        .buttonStyle(.borderless).font(.caption2)
                }
            }
        }.padding(.vertical, 4)
    }

    private func toggleRecording() {
        if isRecording {
            isRecording = false
            loc.stop()
            cameraPosition = .automatic
            log.append("Stopped. Segments finalised for review.")
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
        switch GPSFilter.evaluate(newLocation: live, previousLocation: previousAccepted) {
        case .accept:
            acceptedCount += 1
            previousAccepted = live
            let point = BreadcrumbPoint(latitude: cl.coordinate.latitude, longitude: cl.coordinate.longitude, accuracy: cl.horizontalAccuracy, speedMps: cl.speed, courseDegrees: cl.course >= 0 ? cl.course : nil, timestamp: cl.timestamp, isStopTransition: false, isKeyEvent: false)
            trail.append(point)
            observations.append(MotionObservation(trailIndex: trail.points.count - 1, timestamp: cl.timestamp, machineMotion: inferMotion(cl.speed)))
        case .rejectAccuracy, .rejectJump, .rejectSpeed, .rejectStale:
            rejectedCount += 1
        }
    }

    private func inferMotion(_ speedMps: Double) -> HarnessMotionState {
        guard speedMps >= 0 else { return .unsure }
        if speedMps < 0.9 { return .stopped }
        if speedMps < 4.1 { return .crawling }
        return .moving
    }

    private var segments: [SegmentAudit] {
        guard trail.points.count >= 2 else { return [] }
        var cuts = [0]
        for boundary in boundaries {
            if let idx = closestIndex(to: boundary.timestamp), idx > (cuts.last ?? 0) { cuts.append(idx) }
        }
        let last = trail.points.count - 1
        if cuts.last != last { cuts.append(last) }
        var result: [SegmentAudit] = []
        for pair in zip(cuts.dropLast(), cuts.dropFirst()) where pair.1 > pair.0 {
            result.append(makeSegment(number: result.count + 1, start: pair.0, end: pair.1))
        }
        return result
    }

    private func makeSegment(number: Int, start: Int, end: Int) -> SegmentAudit {
        let points = Array(trail.points[start...end])
        let obs = observations.filter { $0.trailIndex >= start && $0.trailIndex <= end }
        let total = max(1, obs.count)
        let driveCount = obs.filter { $0.machineMotion == .moving }.count
        let operationalCount = obs.filter { $0.machineMotion == .stopped || $0.machineMotion == .crawling }.count
        let unresolvedCount = obs.filter { $0.machineMotion == .unsure }.count
        let driveFraction = Double(driveCount) / Double(total)
        let operationalFraction = Double(operationalCount) / Double(total)
        let unresolvedFraction = Double(unresolvedCount) / Double(total)
        let speeds = points.map { max(0, $0.speedMps) * 3.6 }
        let averageSpeed = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
        let maxSpeed = speeds.max() ?? 0
        let state: SegmentMachineState = {
            guard obs.count >= 3 else { return .unresolved }
            if driveFraction >= 0.55 { return .drive }
            if operationalFraction >= 0.65 && averageSpeed < 20 { return .operational }
            return .unresolved
        }()
        return SegmentAudit(id: "\(start)-\(end)", number: number, startIndex: start, endIndex: end, startTime: points.first!.timestamp, endTime: points.last!.timestamp, machineState: state, driveFraction: driveFraction, operationalFraction: operationalFraction, unresolvedFraction: unresolvedFraction, averageSpeedKmh: averageSpeed, maxSpeedKmh: maxSpeed, distanceMeters: pathDistance(points))
    }

    private var motionRuns: [MotionRun] {
        guard let first = observations.first else { return [] }
        var runs: [MotionRun] = []
        var start = first
        var previous = first
        for obs in observations.dropFirst() {
            if obs.machineMotion != start.machineMotion {
                runs.append(MotionRun(id: "\(start.trailIndex)-\(previous.trailIndex)-\(start.machineMotion.rawValue)", machineMotion: start.machineMotion, startTime: start.timestamp, endTime: previous.timestamp))
                start = obs
            }
            previous = obs
        }
        runs.append(MotionRun(id: "\(start.trailIndex)-\(previous.trailIndex)-\(start.machineMotion.rawValue)", machineMotion: start.machineMotion, startTime: start.timestamp, endTime: previous.timestamp))
        return runs
    }

    private func closestIndex(to timestamp: Date) -> Int? {
        trail.points.indices.min { abs(trail.points[$0].timestamp.timeIntervalSince(timestamp)) < abs(trail.points[$1].timestamp.timeIntervalSince(timestamp)) }
    }

    private func closestPoint(to timestamp: Date) -> BreadcrumbPoint? {
        guard let idx = closestIndex(to: timestamp) else { return nil }
        return trail.points[idx]
    }

    private func segmentPoints(_ segment: SegmentAudit) -> [BreadcrumbPoint] {
        guard segment.startIndex >= 0, segment.endIndex < trail.points.count, segment.startIndex <= segment.endIndex else { return [] }
        return Array(trail.points[segment.startIndex...segment.endIndex])
    }

    private func coordinate(_ point: BreadcrumbPoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    private func pathDistance(_ points: [BreadcrumbPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        return zip(points.dropLast(), points.dropFirst()).reduce(0) { total, pair in
            total + CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude).distance(from: CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude))
        }
    }

    private func colour(_ state: SegmentMachineState) -> Color {
        switch state { case .drive: return .blue; case .operational: return .green; case .unresolved: return .orange }
    }

    private func segmentSummary(_ segment: SegmentAudit) -> String {
        String(format: "%.0fs  %.0fm  avg %.1fkm/h  max %.1fkm/h", segment.duration, segment.distanceMeters, segment.averageSpeedKmh, segment.maxSpeedKmh)
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

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

    func request() { manager.requestWhenInUseAuthorization(); manager.startUpdatingLocation() }
    func stop() { manager.stopUpdatingLocation() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { if let latest = locations.last { onLocation?(latest) } }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.startUpdatingLocation() }
    }
}
