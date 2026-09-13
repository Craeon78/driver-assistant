//======================================
// MARK: - DistanceRegressionFixtures (V3)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Field-derived regression cases extracted from V2 known failures.
// These must continue to pass as the engine evolves.
//
// Phase: Chunk 2 — Distance truth engine
//======================================

import Foundation

/// Simple test double for CLLocationLike so fixtures need no CoreLocation.
public struct FakeLocation: CLLocationLike {
    public let coordinate: (latitude: Double, longitude: Double)
    public let horizontalAccuracy: Double
    public let timestamp: Date
    public let speed: Double

    public init(lat: Double, lon: Double, accuracy: Double = 5, time: Date, speed: Double = 0) {
        self.coordinate = (lat, lon)
        self.horizontalAccuracy = accuracy
        self.timestamp = time
        self.speed = speed
    }

    public func distance(from other: CLLocationLike) -> Double {
        // Haversine approximation sufficient for fixtures (metres)
        let R = 6_371_000.0
        let dLat = (other.coordinate.latitude - coordinate.latitude) * .pi / 180
        let dLon = (other.coordinate.longitude - coordinate.longitude) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(coordinate.latitude * .pi / 180) * cos(other.coordinate.latitude * .pi / 180) *
                sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }
}

public enum DistanceRegressionFixtures {

    /// Classic doubled-distance failure: two nearly identical samples accepted → distance roughly doubles.
    /// Engine must reject the second sample via jump or treat delta correctly.
    public static func doubledDistanceCase() -> (locations: [FakeLocation], expectedAccepted: Int) {
        let t0 = Date()
        let loc1 = FakeLocation(lat: -27.47, lon: 153.02, accuracy: 5, time: t0)
        let loc2 = FakeLocation(lat: -27.47, lon: 153.02, accuracy: 5, time: t0.addingTimeInterval(1)) // ~0 m
        return ([loc1, loc2], 2) // both may be accepted but delta of second must be ~0
    }

    /// ODO interval misallocation: ODO readings at 100 → 110 must produce exactly 10 km interval,
    /// never dump the whole delta into a later partial segment.
    public static func odoIntervalCase() -> (anchors: [ODOAnchor], expectedDelta: Double) {
        let t0 = Date()
        let a1 = ODOAnchor(km: 100, recordedAt: t0)
        let a2 = ODOAnchor(km: 110, recordedAt: t0.addingTimeInterval(3600))
        return ([a1, a2], 10.0)
    }

    /// Jump rejection: a 300 m teleport in 1 s must be rejected.
    public static func jumpRejectionCase() -> (locations: [FakeLocation], expectedAccepted: Int) {
        let t0 = Date()
        let loc1 = FakeLocation(lat: -27.47, lon: 153.02, accuracy: 5, time: t0)
        // ~300 m east
        let loc2 = FakeLocation(lat: -27.47, lon: 153.023, accuracy: 5, time: t0.addingTimeInterval(1))
        return ([loc1, loc2], 1) // second rejected
    }
}
