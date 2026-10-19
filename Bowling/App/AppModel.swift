import BowlingCore
import BowlingData
import Foundation
import Observation

/// The one object screens share. Every write goes through `write`, which bumps `revision`
/// so the other tabs reload in `.task(id: app.revision)`.
@Observable final class AppModel {
    let store: BowlingStore
    /// The new-session form's remembered values.
    let sessionDefaults: SessionDefaultsStore
    private(set) var revision = 0
    /// The New session sheet is up, shown by the root.
    var isStartingSession = false
    /// The open Scoring session, shown by the root's full-screen cover.
    var scoring: ScoringTarget?
    /// Shown by the root's shared alert.
    var error: (any Error)?

    init(store: BowlingStore, sessionDefaults: SessionDefaultsStore = SessionDefaultsStore()) {
        self.store = store
        self.sessionDefaults = sessionDefaults
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
        let topmost: ErrorPresenter = scoring != nil ? .scoring : isStartingSession ? .newSession : .root
        return presenter == topmost
    }

    /// No owner yet: show first launch.
    var needsOnboarding: Bool {
        _ = revision
        return store.bowlers.owner() == nil
    }

    /// The sheet's Start: creates the session, remembers the form's values for its event
    /// type, closes the sheet, and opens Scoring on the first lineup bowler's first game.
    /// Does nothing once the sheet is closed, so a second tap can't start a second session.
    /// - Throws: whatever `startSession` throws; nothing is remembered and the sheet stays.
    func startSession(_ draft: NewSessionDraft) throws {
        guard isStartingSession else { return }
        let target = try write { store in
            let sessionID = try draft.start(in: store.sessions)
            guard let gameID = try store.sessions.session(sessionID).bowlers.first?.games.first?.id else {
                throw RepositoryError.notFound
            }
            return ScoringTarget(sessionID: sessionID, gameID: gameID)
        }
        sessionDefaults.save(draft.defaults, for: draft.eventType)
        isStartingSession = false
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
    case root, newSession, scoring
}

/// The game Scoring opens, in its session.
struct ScoringTarget: Identifiable, Hashable {
    var sessionID: SessionID
    var gameID: GameID
    var id: SessionID { sessionID }
}
