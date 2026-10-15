import BowlingData
import Observation

/// Opens the store at launch. A failure is kept for the error screen; it never falls back
/// to an empty store, which would look like a first launch on top of unreadable data.
@Observable final class StoreLoader {
    private(set) var app: AppModel?
    private(set) var failure: (any Error)?
    private let open: () throws -> BowlingStore

    init(open: @escaping () throws -> BowlingStore = { try BowlingStore() }) {
        self.open = open
    }

    /// Sets exactly one of `app` and `failure`.
    func load() {
        do {
            app = AppModel(store: try open())
            failure = nil
        } catch {
            app = nil
            failure = error
        }
    }
}
