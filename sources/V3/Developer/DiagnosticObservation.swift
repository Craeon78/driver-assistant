import Foundation

/// Developer diagnostics may observe domain state but own no business truth.
/// Test fixtures and regression cases remain separate from runtime observations.
struct DiagnosticObservation: Identifiable, Codable, Hashable {
    let id: UUID
    let observedAt: Date
    let subsystem: String
    let message: String

    init(id: UUID = UUID(), observedAt: Date, subsystem: String, message: String) {
        self.id = id
        self.observedAt = observedAt
        self.subsystem = subsystem
        self.message = message
    }
}
