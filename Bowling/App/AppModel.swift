import BowlingCore
import BowlingData
import Foundation
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

    /// Whether `presenter` shows the shared alert for `error`. Only the topmost view may:
    /// iOS can't present an alert from a view that is already presenting the Scoring cover.
    func showsError(in presenter: ErrorPresenter) -> Bool {
        guard error != nil else { return false }
        return (scoring != nil) == (presenter == .scoring)
    }

    /// No owner yet: show first launch.
    var needsOnboarding: Bool {
        _ = revision
        return store.bowlers.owner() == nil
    }

    /// Home's temporary Start (#4): a practice session for the owner, opened in Scoring.
    /// - Throws: `.notFound` before first launch.
    func startPracticeSession() throws {
        guard let owner = store.bowlers.owner() else { throw RepositoryError.notFound }
        let target = try write { store in
            let sessionID = try store.sessions.startSession(
                SessionMetadata(date: .now, eventType: .practice),
                bowlers: [(bowlerID: owner.id, defaultBallID: nil)],
                entryMode: .pinByPin
            )
            guard let gameID = try store.sessions.session(sessionID).bowlers.first?.games.first?.id else {
                throw RepositoryError.notFound
            }
            return ScoringTarget(sessionID: sessionID, gameID: gameID)
        }
        scoring = target
    }

    /// Closes Scoring. A session left before any roll is deleted (spec §8).
    func closeScoring() {
        guard let target = scoring else { return }
        scoring = nil
        do {
            try write { try $0.sessions.discardIfUnstarted(target.sessionID) }
        } catch {
            self.error = error
        }
    }

    #if DEBUG
    static func preview() -> AppModel {
        AppModel(store: try! BowlingStore.demo())
    }
    #endif
}

/// The views that can show the shared error alert.
enum ErrorPresenter {
    case root, scoring
}

/// The game Scoring opens, in its session.
struct ScoringTarget: Identifiable, Hashable {
    var sessionID: SessionID
    var gameID: GameID
    var id: SessionID { sessionID }
}
