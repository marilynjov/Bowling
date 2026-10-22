import BowlingCore
import BowlingData
import Foundation
import Observation

/// One open Scoring cover: a `ScoringModel` per bowler for the current game number, whose
/// turn it is, and when the game summary shows (spec §1 and §3).
@Observable final class SessionScoringModel {
    let sessionID: SessionID
    private(set) var gameIndex: Int
    /// Lineup order. A bowler with no game of this number is left out.
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

    /// - Throws: `.notFound` for a missing session or game.
    init(target: ScoringTarget, app: AppModel, now: @escaping () -> Date = Date.init) throws {
        self.app = app
        self.now = now
        sessionID = target.sessionID
        let rotates = app.scoringSettings.rotateBowlers
        self.rotates = rotates
        let game = try app.store.games.game(target.gameID)
        gameIndex = game.gameIndex
        let bowlers = try Self.models(sessionID: target.sessionID, gameIndex: game.gameIndex, app: app, now: now)
        let targetIndex = bowlers.firstIndex { $0.target.gameID == target.gameID } ?? 0
        let games = bowlers.map(\.game)
        let start = !Rotation.isFinished(game) && rotates
            ? Rotation.current(after: nil, games: games, rotates: true) ?? targetIndex
            : targetIndex
        self.bowlers = bowlers
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

    /// "Game 2 · Alex".
    var title: String { "Game \(gameIndex) · \(current.bowlerName)" }

    var allFinished: Bool { bowlers.allSatisfy { Rotation.isFinished($0.game) } }

    /// One card per bowler, in lineup order.
    var summaries: [GameSummary] {
        guard let detail = try? app.store.sessions.session(sessionID) else { return [] }
        return detail.bowlers.compactMap { GameSummary($0, gameIndex: gameIndex) }
    }

    /// A chip tap: that bowler bowls next, for someone bowling out of turn.
    func select(_ index: Int) {
        guard bowlers.indices.contains(index) else { return }
        currentIndex = index
        lastFinishedFrames = Rotation.finishedFrames(current.game)
    }

    /// The summary's Next game: every bowler's next game, then the rule picks who starts.
    /// On failure the error shows and the sheet stays. Only from the summary, so a second
    /// tap can't start another round.
    func nextGame() {
        guard isShowingSummary, allFinished else { return }
        do {
            _ = try app.write { try $0.games.startNextGame(in: sessionID) }
            let next = gameIndex + 1
            let models = try Self.models(sessionID: sessionID, gameIndex: next, app: app, now: now)
            guard !models.isEmpty else { throw RepositoryError.notFound }
            gameIndex = next
            bowlers = models
            currentIndex = Rotation.current(after: nil, games: models.map(\.game), rotates: true) ?? 0
            wasAllFinished = allFinished
            lastFinishedFrames = Rotation.finishedFrames(current.game)
            observeWrites()
            isShowingSummary = false
        } catch {
            app.error = error
        }
    }

    /// The Complete panel's Summary button.
    func showSummary() {
        isShowingSummary = true
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
