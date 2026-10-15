import BowlingCore
import BowlingData
import Observation

/// The one object screens share. Every write goes through `write`, which bumps `revision`
/// so the other tabs reload in `.task(id: app.revision)`.
@Observable final class AppModel {
    let store: BowlingStore
    private(set) var revision = 0
    /// The open Scoring session, shown by the root's full-screen cover.
    var scoring: ScoringTarget?
    /// Shown by the root's shared alert.
    var error: (any Error)?

    init(store: BowlingStore) {
        self.store = store
    }

    /// Bumps `revision` even when `body` throws: the repository rolls back a failed write,
    /// so a reload after one is harmless.
    func write<T>(_ body: (BowlingStore) throws -> T) rethrows -> T {
        defer { revision += 1 }
        return try body(store)
    }

    /// No owner yet: show first launch.
    var needsOnboarding: Bool {
        _ = revision
        return store.bowlers.owner() == nil
    }

    #if DEBUG
    static func preview() -> AppModel {
        AppModel(store: try! BowlingStore.demo())
    }
    #endif
}

/// The game Scoring opens, in its session.
struct ScoringTarget: Identifiable, Hashable {
    var sessionID: SessionID
    var gameID: GameID
    var id: SessionID { sessionID }
}
