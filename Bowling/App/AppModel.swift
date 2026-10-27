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
    /// The History tab's pushed screens.
    var historyPath: [HistoryRoute] = []
    /// The session whose details form sheet is up, shown by History.
    var editingSessionDetails: SessionID?
    /// Shown by the root's shared alert.
    var error: (any Error)?
    /// The game summary sheet is up over Scoring, so its alert shows errors.
    var isShowingGameSummary = false

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
        let topmost: ErrorPresenter = scoring != nil ? (isShowingGameSummary ? .gameSummary : .scoring)
            : isStartingSession ? .newSession
            : isQuickScoring ? .quickScore
            : editingSessionDetails != nil ? .sessionDetails
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
    /// been undone or the banner has gone, or when the session was already deleted elsewhere.
    func undoQuickScore() throws {
        guard let saved = savedQuickScore else { return }
        savedQuickScore = nil
        do {
            try write { try $0.sessions.deleteSession(saved.sessionID) }
        } catch RepositoryError.notFound {}
    }

    /// The banner's timer: hides `saved` after `delay`, unless a newer quick score replaced
    /// it. Nil (VoiceOver) keeps it until Undo or a newer score; cancellation (Home left the
    /// screen) keeps it too, and the banner's task starts a fresh timer when Home is back.
    func dismissQuickScore(_ saved: SavedQuickScore, after delay: Duration?) async {
        guard let delay else { return }
        do { try await Task.sleep(for: delay) } catch { return }
        if savedQuickScore == saved { savedQuickScore = nil }
    }

    /// Shows `id` on the History tab, replacing whatever was pushed there.
    func openSession(_ id: SessionID) {
        selectedTab = .history
        historyPath = [.session(id)]
    }

    /// Removes `route` and everything above it, as after deleting what it shows. Does
    /// nothing when `route` isn't on the path.
    func popHistory(from route: HistoryRoute) {
        guard let index = historyPath.firstIndex(of: route) else { return }
        historyPath.removeSubrange(index...)
    }

    /// Deletes what `request` names, then pops the History screens that showed it.
    /// - Throws: whatever the delete throws; the path is left as it was.
    func delete(_ request: DeleteRequest) throws {
        switch request.target {
        case .session(let id):
            try write { try $0.sessions.deleteSession(id) }
            popHistory(from: .session(id))
        case .game(let id):
            try write { try $0.games.deleteGame(id) }
            popHistory(from: .game(id))
        }
    }

    /// Closes Scoring. A session left before any roll is deleted (spec §8), unless Scoring
    /// was opened on an existing session from History; one that is already gone needs nothing.
    func closeScoring() {
        guard let target = scoring else { return }
        scoring = nil
        isShowingGameSummary = false
        guard !target.startsOnTarget else { return }
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
    case root, newSession, quickScore, sessionDetails, scoring, gameSummary
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
    /// Scoring opens on `gameID` rather than the first unfinished game, and closing it never
    /// discards the session: it was opened from History.
    var startsOnTarget = false
    var id: SessionID { sessionID }
}

extension ScoringTarget {
    /// The first unfinished game, bowlers in lineup order and their games by `gameIndex`;
    /// nil when every game is complete.
    static func resume(_ session: SessionSummary) -> ScoringTarget? {
        session.games.first(where: { !$0.isComplete })
            .map { ScoringTarget(sessionID: session.id, gameID: $0.id) }
    }
}
