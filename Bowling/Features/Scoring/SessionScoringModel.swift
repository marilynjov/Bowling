import BowlingCore
import BowlingData
import Foundation
import Observation

/// One open Scoring cover: a `ScoringModel` per bowler for the current game number, whose
/// turn it is, and when the game summary shows (spec §1 and §3).
@Observable final class SessionScoringModel {
    let sessionID: SessionID
    /// The highest game number among the open games, for the summary's title.
    private(set) var gameIndex: Int
    /// Lineup order. A bowler with no game of this number is left out; after Next game,
    /// each bowler's new game, which can differ in number on an uneven night.
    private(set) var bowlers: [ScoringModel]
    private(set) var currentIndex: Int
    /// Starts from the on-device setting; not saved per session.
    var rotates: Bool
    var isShowingSummary = false {
        didSet { app.isShowingGameSummary = isShowingSummary }
    }
    private let app: AppModel
    private let now: () -> Date
    /// Whether every game was finished after the last write, so the summary shows only
    /// when the last one finishes.
    private var wasAllFinished: Bool
    /// The current bowler's finished frames after the last write, to see a frame end.
    private var lastFinishedFrames: Int
    /// Next game wrote the games but they couldn't be opened, so a second tap can't add more.
    private var rebuildFailed = false

    /// - Throws: `.notFound` for a missing session or game.
    init(target: ScoringTarget, app: AppModel, now: @escaping () -> Date = Date.init) throws {
        self.app = app
        self.now = now
        sessionID = target.sessionID
        let rotates = app.scoringSettings.rotateBowlers
        self.rotates = rotates
        let game = try app.store.games.game(target.gameID)
        let bowlers = try Self.models(sessionID: target.sessionID, gameIndex: game.gameIndex, app: app, now: now)
        let targetIndex = bowlers.firstIndex { $0.target.gameID == target.gameID } ?? 0
        let games = bowlers.map(\.game)
        let start = !target.startsOnTarget && !Rotation.isFinished(game) && rotates
            ? Rotation.current(after: nil, games: games, rotates: true) ?? targetIndex
            : targetIndex
        self.bowlers = bowlers
        gameIndex = games.map(\.gameIndex).max() ?? game.gameIndex
        currentIndex = start
        wasAllFinished = games.allSatisfy(Rotation.isFinished)
        lastFinishedFrames = Rotation.finishedFrames(games[start])
        observeWrites()
    }

    /// The model for `target`, or nil with the error in `app.error`.
    static func open(_ target: ScoringTarget, app: AppModel, now: @escaping () -> Date = Date.init) -> SessionScoringModel? {
        do {
            return try SessionScoringModel(target: target, app: app, now: now)
        } catch {
            app.error = error
            return nil
        }
    }

    var current: ScoringModel { bowlers[currentIndex] }

    /// "Game 2 · Alex", with the current bowler's own game number.
    var title: String { "Game \(current.game.gameIndex) · \(current.bowlerName)" }

    var allFinished: Bool { bowlers.allSatisfy { Rotation.isFinished($0.game) } }

    /// One card per bowler for that bowler's open game, in lineup order.
    var summaries: [GameSummary] {
        guard let detail = try? app.store.sessions.session(sessionID) else { return [] }
        let open = Set(bowlers.map(\.target.gameID))
        return detail.bowlers.compactMap { bowler in
            bowler.games.first { open.contains($0.id) }.flatMap { GameSummary(bowler, gameIndex: $0.gameIndex) }
        }
    }

    /// Next game is offered only when this is the session's latest game number; an older
    /// one shows Done (spec §4).
    var offersNextGame: Bool {
        !rebuildFailed && (try? isLatestGame()) == true
    }

    /// A chip tap: that bowler bowls next, for someone bowling out of turn.
    func select(_ index: Int) {
        guard bowlers.indices.contains(index) else { return }
        currentIndex = index
        lastFinishedFrames = Rotation.finishedFrames(current.game)
    }

    /// The summary's Next game: every bowler's next game, then the rule picks who starts.
    /// If the write fails the error shows and the sheet stays. Only from the summary, so a
    /// second tap can't start another round.
    func nextGame() {
        guard isShowingSummary, allFinished, !rebuildFailed else { return }
        do {
            guard try isLatestGame() else { return }
            let ids = try app.write { try $0.games.startNextGame(in: sessionID) }
            show(nextGames: ids)
        } catch {
            app.error = error
        }
    }

    /// Opens the games Next game created, in the order given. On failure the error shows,
    /// the summary closes and Next game is no longer offered.
    func show(nextGames ids: [GameID]) {
        do {
            let models = try ids.map {
                try ScoringModel(target: ScoringTarget(sessionID: sessionID, gameID: $0), app: app, now: now)
            }
            guard !models.isEmpty else { throw RepositoryError.notFound }
            bowlers = models
            gameIndex = models.map(\.game.gameIndex).max() ?? gameIndex
            currentIndex = Rotation.current(after: nil, games: models.map(\.game), rotates: true) ?? 0
            wasAllFinished = allFinished
            lastFinishedFrames = Rotation.finishedFrames(current.game)
            observeWrites()
        } catch {
            app.error = error
            rebuildFailed = true
        }
        isShowingSummary = false
    }

    /// The Complete panel's Summary button.
    func showSummary() {
        isShowingSummary = true
    }

    /// This night's game number is the highest in the session.
    /// - Throws: `.notFound` for a missing session.
    private func isLatestGame() throws -> Bool {
        let detail = try app.store.sessions.session(sessionID)
        return gameIndex == detail.bowlers.flatMap(\.games).map(\.gameIndex).max()
    }

    private static func models(
        sessionID: SessionID, gameIndex: Int, app: AppModel, now: @escaping () -> Date
    ) throws -> [ScoringModel] {
        try app.store.sessions.session(sessionID).bowlers.compactMap { bowler in
            guard let game = bowler.games.first(where: { $0.gameIndex == gameIndex }) else { return nil }
            return try ScoringModel(target: ScoringTarget(sessionID: sessionID, gameID: game.id), app: app, now: now)
        }
    }

    private func observeWrites() {
        for (index, model) in bowlers.enumerated() {
            model.onWrite = { [weak self] kind in self?.didWrite(kind, by: index) }
        }
    }

    /// Rotation runs only after a roll that ends the current bowler's frame or game; Undo,
    /// Clear rolls, edits and mode changes keep the turn. Any write can bring up the summary.
    private func didWrite(_ kind: ScoringWrite, by index: Int) {
        if kind == .roll, index == currentIndex {
            let finished = Rotation.finishedFrames(current.game)
            if finished > lastFinishedFrames || Rotation.isFinished(current.game) {
                currentIndex = Rotation.current(after: currentIndex, games: bowlers.map(\.game), rotates: rotates)
                    ?? currentIndex
            }
        }
        let finished = allFinished
        if finished, !wasAllFinished { isShowingSummary = true }
        wasAllFinished = finished
        lastFinishedFrames = Rotation.finishedFrames(current.game)
    }
}
