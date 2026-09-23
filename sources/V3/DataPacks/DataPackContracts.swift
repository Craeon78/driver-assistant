import Foundation

/// Reference/template data supplied to DriverAssistant.
/// Data Packs may inform work but never become authoritative operational history.
protocol DataPack {
    var id: String { get }
    var version: String { get }
}

/// Advisory road information is reference evidence, not an instruction that may
/// silently change Driver, Vehicle or Operations truth.
struct RoadEventReference: Identifiable, Codable, Hashable {
    let id: UUID
    let recordedAt: Date
    let summary: String

    init(id: UUID = UUID(), recordedAt: Date, summary: String) {
        self.id = id
        self.recordedAt = recordedAt
        self.summary = summary
    }
}
