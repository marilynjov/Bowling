import BowlingCore
import BowlingData
import Observation

/// One open game on the Scoring screen. Records each roll through `app.write`, which
/// saves it, then reloads the game and builds the next roll's pad. Errors go to
/// `app.error`, shown by the Scoring cover's alert.
@Observable final class ScoringModel {
    let target: ScoringTarget
    private(set) var game: GameRecord
    private(set) var scorecard: Scorecard
    /// The next roll's entry rules; nil when the game is complete or final-only.
    var pad: RollPad?
    private(set) var balls: [BallSummary]
    private(set) var bowlerName: String
    /// This roll's ball when one was picked; see `rollBallID`.
    private(set) var ballOverride: BallID?
    /// Change score: the saved final score's field is shown again.
    var isEditingFinalScore = false
    /// A ball (or No ball) was picked for this roll, so `ballOverride` replaces the
    /// game's default even when it is nil.
    private var hasOverride = false
    private let app: AppModel

    /// - Throws: `.notFound` for a missing session or game.
    init(target: ScoringTarget, app: AppModel) throws {
        self.target = target
        self.app = app
        let detail = try app.store.sessions.session(target.sessionID)
        guard let bowler = detail.bowlers.first(where: { $0.games.contains { $0.id == target.gameID } }) else {
            throw RepositoryError.notFound
        }
        bowlerName = bowler.bowler.name
        balls = app.store.balls.activeBalls()
        let game = try app.store.games.game(target.gameID)
        self.game = game
        scorecard = Scorer.scorecard(for: game)
        pad = Scorer.nextRoll(in: game).map {
            RollPad(position: $0, entryMode: game.entryMode, settings: app.scoringSettings)
        }
    }

    /// Rolls finished, or a final-only game with its score saved.
    var isComplete: Bool {
        game.entryMode == .finalOnly ? game.isComplete : Scorer.nextRoll(in: game) == nil
    }

    /// The game has a roll to undo.
    var canUndo: Bool {
        game.frames.contains { !$0.rolls.isEmpty }
    }

    /// The mode is fixed once the game has a roll; Clear rolls unlocks it.
    var canChangeEntryMode: Bool { !canUndo }

    /// A final-only game with its score saved: changing the mode discards the score, so
    /// the menu asks first.
    var discardsTypedScore: Bool {
        game.entryMode == .finalOnly && game.isComplete
    }

    /// The ball the next roll is recorded with: the picked one, else the game's default.
    var rollBallID: BallID? {
        hasOverride ? ballOverride : game.defaultBallID
    }

    func next() { record { $0.nextInput } }
    func strike() { record { $0.strikeInput } }
    func spare() { record { $0.spareInput } }
    func miss() { record { $0.missInput } }
    func foul() { record { _ in .foul } }
    func count(_ pins: Int) { record { _ in .count(pins) } }

    /// Reopens the last roll. Does nothing before the first roll.
    func undo() {
        guard canUndo else { return }
        update { try $0.games.undoLastRoll(in: target.gameID) }
    }

    /// Refused with `.entryModeLocked` once the game has a roll. Leaving final score
    /// resets the typed score.
    func setEntryMode(_ mode: EntryMode) {
        update { try $0.games.setEntryMode(mode, for: target.gameID) }
    }

    /// Removes every roll, which unlocks the entry mode.
    func clearRolls() {
        update { _ = try $0.games.clearRolls(in: target.gameID) }
    }

    /// Saves a typed score of 0 through 300 (the Quick score rule); other text is ignored.
    func saveFinalScore(_ text: String) {
        guard let score = QuickScoreEntry.score(text) else { return }
        if update({ try $0.games.setFinalScore(score, for: target.gameID) }) {
            isEditingFinalScore = false
        }
    }

    /// The ball for this roll only; nil records it with no ball.
    func pickBall(_ id: BallID?) {
        ballOverride = id
        hasOverride = true
    }

    /// The deck's binding: marks the pins, then records a spare by itself when the
    /// settings say so.
    func setShown(_ pins: PinSet) {
        pad?.setShown(pins)
        if pad?.autoAdvances == true { next() }
    }

    private func record(_ input: (RollPad) -> RollInput) {
        guard let pad else { return }
        let input = input(pad)
        let ball = rollBallID
        update { try $0.games.recordRoll(input, ballID: ball, in: target.gameID) }
    }

    /// Runs one write, then reloads from the store whether it worked or not.
    /// - Returns: Whether the write worked.
    @discardableResult
    private func update(_ body: (BowlingStore) throws -> Void) -> Bool {
        defer { reload() }
        do {
            try app.write(body)
            return true
        } catch {
            app.error = error
            return false
        }
    }

    private func reload() {
        if let fresh = try? app.store.games.game(target.gameID) { game = fresh }
        scorecard = Scorer.scorecard(for: game)
        ballOverride = nil
        hasOverride = false
        pad = makePad()
    }

    private func makePad() -> RollPad? {
        Scorer.nextRoll(in: game).map {
            RollPad(position: $0, entryMode: game.entryMode, settings: app.scoringSettings)
        }
    }
}
