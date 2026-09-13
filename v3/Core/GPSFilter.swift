//======================================
// MARK: - GPSFilter (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Port of proven V2 acceptance rules.
// Evaluates incoming samples; does not accumulate distance or own state.
//
// Phase: Chunk 2 — Distance truth engine
//======================================

import Foundation

public enum GPSFilterResult {
    case accept(deltaMeters: Double)
    case rejectAccuracy
    case rejectJump
    case rejectSpeed
    case rejectStale
}

public struct GPSFilterTuning: Sendable {
    public var maxHorizontalAccuracy: Double = 30
    public var maxSampleAge: TimeInterval = 15
    public var maxDistanceJumpMeters: Double = 250
    public var maxSpeedJumpKph: Double = 160

    public static let `default` = GPSFilterTuning()
}

public enum GPSFilter {
    public static func evaluate(
        newLocation: CLLocationLike,
        previousLocation: CLLocationLike?,
        now: Date = Date(),
        tuning: GPSFilterTuning = .default
    ) -> GPSFilterResult {
        // First fix
        guard let previous = previousLocation else {
            return .accept(deltaMeters: 0)
        }

        if newLocation.horizontalAccuracy < 0 || newLocation.horizontalAccuracy > tuning.maxHorizontalAccuracy {
            return .rejectAccuracy
        }

        let age = now.timeIntervalSince(newLocation.timestamp)
        if age > tuning.maxSampleAge {
            return .rejectStale
        }

        let distance = newLocation.distance(from: previous)
        if distance > tuning.maxDistanceJumpMeters {
            return .rejectJump
        }

        let time = newLocation.timestamp.timeIntervalSince(previous.timestamp)
        if time > 0 {
            let speedKph = (distance / time) * 3.6
            if speedKph > tuning.maxSpeedJumpKph {
                return .rejectSpeed
            }
        }

        return .accept(deltaMeters: distance)
    }
}
