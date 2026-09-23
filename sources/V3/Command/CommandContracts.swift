import Foundation

/// Command translates explicit driver intent into requests for owning domains.
/// It does not silently mutate Driver, Vehicle, Operations or Cargo truth.
struct DriverCommand: Identifiable, Codable, Hashable {
    let id: UUID
    let issuedAt: Date
    let name: String

    init(id: UUID = UUID(), issuedAt: Date, name: String) {
        self.id = id
        self.issuedAt = issuedAt
        self.name = name
    }
}
