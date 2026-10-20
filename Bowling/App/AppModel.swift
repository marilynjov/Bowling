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
    /// Scoring's on-device settings.
    let scoringSettings: ScoringSettings
    private(set) var revision = 0
    /// The New session sheet is up, shown by the root.
    var isStartingSession = false
    /// The Quick score sheet is up, shown by the root.
    var isQuickScoring = false
    /// The last quick score, which Home's banner can undo; nil hides the banner.
    var savedQuickScore: SavedQuickScore?
    /// The root's tab.
    var selectedTab: AppTab = .home
    /// The open Scoring session, shown by the root's full-screen cover.
    var scoring: ScoringTarget?
    /// Shown by the root's shared alert.
    var error: (any Error)?

    init(
        store: BowlingStore,
        sessionDefaults: SessionDefaultsStore = SessionDefaultsStore(),
        scoringSettings: ScoringSettings = ScoringSettings()
    ) {
        self.store = store
        self.sessionDefaults = sessionDefaults
        self.scoringSettings = scoringSettings
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
        let topmost: ErrorPresenter = scoring != nil ? .scoring
            : isStartingSession ? .newSession
            : isQuickScoring ? .quickScore
            : .root
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

    /// Home's Resume: opens Scoring on the unfinished game.
    func resume(_ target: ScoringTarget) {
        scoring = target
    }

    /// The sheet's Save: one complete casual game for the owner, dated `now`. Closes the
    /// sheet and offers Undo; a newer quick score replaces the older one's Undo.
    /// Does nothing once the sheet is closed, so a second tap on Save can't save twice.
    /// - Throws: whatever `quickScore` throws; the sheet stays and nothing is offered.
    func quickScore(_ score: Int, now: Date = .now) throws {
        guard isQuickScoring else { return }
        let id = try write { try $0.sessions.quickScore(finalScore: score, now: now) }
        isQuickScoring = false
        savedQuickScore = SavedQuickScore(sessionID: id, score: score)
    }

    /// The banner's Undo: deletes the last quick score's session. Does nothing once it has
    /// been undone or the banner has gone.
    func undoQuickScore() throws {
        guard let saved = savedQuickScore else { return }
        savedQuickScore = nil
        try write { try $0.sessions.deleteSession(saved.sessionID) }
    }

    /// The banner's timer: hides `saved` after `delay`, unless a newer quick score replaced
    /// it. Nil (VoiceOver) keeps it until Undo or a newer score; cancellation (Home left the
    /// screen) keeps it too, and the banner's task starts a fresh timer when Home is back.
    func dismissQuickScore(_ saved: SavedQuickScore, after delay: Duration?) async {
        guard let delay else { return }
        do { try await Task.sleep(for: delay) } catch { return }
        if savedQuickScore == saved { savedQuickScore = nil }
    }

    /// Closes Scoring. A session left before any roll is deleted (spec §8); one that is
    /// already gone needs nothing.
    func closeScoring() {
        guard let target = scoring else { return }
        scoring = nil
        do {
            try write { try $0.sessions.discardIfUnstarted(target.sessionID) }
        } catch RepositoryError.notFound {
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
    case root, newSession, quickScore, scoring
}

/// The root's tabs.
enum AppTab: Hashable {
    case home, history, stats, arsenal
}

/// A quick score Home can still undo.
struct SavedQuickScore: Hashable {
    var sessionID: SessionID
    var score: Int
}

/// The game Scoring opens, in its session.
struct ScoringTarget: Identifiable, Hashable {
    var sessionID: SessionID
    var gameID: GameID
    var id: SessionID { sessionID }
}
