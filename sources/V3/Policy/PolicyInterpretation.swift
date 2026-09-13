import Foundation

/// Policy interprets evidence; it does not own Driver, Vehicle, Operations or Cargo truth.
/// Consequential state changes remain explicit and driver-authorised.
struct PolicyInterpretation: Identifiable, Codable, Hashable {
    let id: UUID
    let evaluatedAt: Date
    let policyID: String
    let summary: String
    let isAdvisory: Bool

    init(
        id: UUID = UUID(),
        evaluatedAt: Date,
        policyID: String,
        summary: String,
        isAdvisory: Bool = true
    ) {
        self.id = id
        self.evaluatedAt = evaluatedAt
        self.policyID = policyID
        self.summary = summary
        self.isAdvisory = isAdvisory
    }
}
