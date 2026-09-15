import Foundation

/// Canonical V3 representation of a driver-entered odometer observation.
/// The observation is a journey distance anchor, not distance owned by the
/// activity segment in which it happened.
struct OdometerObservation: Identifiable, Codable, Hashable {
    let id: UUID
    let occurredAt: Date
    let recordedAt: Date
    let kilometres: Int
    let context: OdoPromptContext
    let locationName: String?
    let sourceSegmentID: UUID?

    init(
        id: UUID = UUID(),
        occurredAt: Date,
        recordedAt: Date,
        kilometres: Int,
        context: OdoPromptContext,
        locationName: String? = nil,
        sourceSegmentID: UUID? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.kilometres = kilometres
        self.context = context
        self.locationName = locationName
        self.sourceSegmentID = sourceSegmentID
    }
}
