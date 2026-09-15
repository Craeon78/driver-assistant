import Foundation
import Combine

/// Core-owned runtime services extracted from the application shell.
/// This is an ownership boundary only; existing service behaviour is unchanged.
///
/// AutoSaveController currently requires AppModel, so AppModel retains that adapter
/// until persistence is migrated. Core does not point back at the application shell.
@MainActor
final class RuntimeServices {
    let time = TimeService()
    let saveStore = SaveStore()

    var tickerTask: Task<Void, Never>?
    var gpsCancellables = Set<AnyCancellable>()
    var isGpsConnected = false

    func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }
}
