//======================================
// MARK: - Breadcrumb (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Dense location samples collected during a shift.
// Thinning is applied later; raw capture stays dense while the shift is open.
//
// Phase: Chunk 2b — Breadcrumb thinning
//======================================

import Foundation

public struct BreadcrumbPoint: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let latitude: Double
    public let longitude: Double
    public let accuracy: Double
    public let speedMps: Double          // negative = invalid
    public let courseDegrees: Double?    // nil = unknown
    public let timestamp: Date
    public let isStopTransition: Bool    // true when motion state changed to/from stopped
    public let isKeyEvent: Bool          // ODO anchor, load, manual pin, etc.

    public init(
        id: CanonicalID = .fresh(),
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        speedMps: Double,
        courseDegrees: Double? = nil,
        timestamp: Date,
        isStopTransition: Bool = false,
        isKeyEvent: Bool = false
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.speedMps = speedMps
        self.courseDegrees = courseDegrees
        self.timestamp = timestamp
        self.isStopTransition = isStopTransition
        self.isKeyEvent = isKeyEvent
    }
}

public struct BreadcrumbTrail: Codable, Sendable {
    public var points: [BreadcrumbPoint]

    public init(points: [BreadcrumbPoint] = []) {
        self.points = points
    }

    public var count: Int { points.count }

    public mutating func append(_ point: BreadcrumbPoint) {
        points.append(point)
    }
}
