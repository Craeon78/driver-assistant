import Foundation
import Combine

/// Core-owned runtime services extracted from the application shell.
/// This is an ownership boundary only; existing service behaviour is unchanged.
@MainActor
final class RuntimeServices {
    let time = TimeService()
    let saveStore = SaveStore()

    var autosave: AutoSaveController?
    var tickerTask: Task<Void, Never>?
    var gpsCancellables = Set<AnyCancellable>()
    var isGpsConnected = false

    func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }
}
