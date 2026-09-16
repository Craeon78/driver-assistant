import Foundation

/// V3 Site identity persists independently of shifts, runs and Cargo modules.
struct SiteRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double?
    var longitude: Double?
}

/// A Run organises site/job references without owning Site truth.
struct RunRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var siteIDs: [UUID]

    init(id: UUID = UUID(), siteIDs: [UUID] = []) {
        self.id = id
        self.siteIDs = siteIDs
    }
}
