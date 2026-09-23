import Foundation

/// Numbers consumes upstream domain truth for analytics.
/// It must not become an alternate owner of operational facts.
struct NumbersProjection {
    let generatedAt: Date

    init(generatedAt: Date = Date()) {
        self.generatedAt = generatedAt
    }
}
