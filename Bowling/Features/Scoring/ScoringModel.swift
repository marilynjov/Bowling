import BowlingCore
import BowlingData
import Foundation
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
    private let now: () -> Date
    /// When the last roll or Undo was written, for the tap lockout.
    private var lastWrite: Date?
    /// A second tap this soon after a write is ignored, so a double tap can't record a
    /// phantom roll on the next rack.
    static let tapLockout: TimeInterval = 0.3
    /// The finished roll being replaced; the pad is that roll's rack while it is set.
    private(set) var edit: FrameEdit?
    /// The frames the last replace dropped, other than the edited one, to enter again.
    private(set) var clearedFrames: [Int] = []
    /// Called after each write that worked, so the session model can rotate and show the
    /// summary.
    @ObservationIgnored var onWrite: ((ScoringWrite) -> Void)?

    /// - Throws: `.notFound` for a missing session or game.
    init(target: ScoringTarget, app: AppModel, now: @escaping () -> Date = Date.init) throws {
        self.target = target
        self.app = app
        self.now = now
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

    /// The model for `target`, or nil with the error in `app.error`. Scoring stays open,
    /// so its own alert shows the error.
    static func open(_ target: ScoringTarget, app: AppModel, now: @escaping () -> Date = Date.init) -> ScoringModel? {
        do {
            return try ScoringModel(target: target, app: app, now: now)
        } catch {
            app.error = error
            return nil
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

    /// The ball the next roll is recorded with: the picked one, else the edited roll's, else
    /// the game's default.
    var rollBallID: BallID? {
        if hasOverride { return ballOverride }
        if let roll = edit?.roll(in: game) { return roll.ballID ?? game.defaultBallID }
        return game.defaultBallID
    }

    /// The edited roll's count, for the count pad's highlight; nil for a foul or when not
    /// editing.
    var editedCount: Int? {
        guard let roll = edit?.roll(in: game), !roll.isFoul else { return nil }
        return roll.pinCount
    }

    /// The strip's chip: the last running total, or the typed score; 0 before either.
    var currentScore: Int {
        if game.entryMode == .finalOnly { return game.isComplete ? game.finalScore : 0 }
        return scorecard.frames.last { $0.runningTotal != nil }?.runningTotal ?? 0
    }

    /// Starts replacing `frame`'s first ball. Ignored for final score or a frame with no
    /// rolls.
    func beginEdit(frame: Int) {
        let edit = FrameEdit(frameIndex: frame, rollIndex: 1)
        guard game.entryMode != .finalOnly, edit.roll(in: game) != nil else { return }
        self.edit = edit
        clearedFrames = []
        ballOverride = nil
        hasOverride = false
        pad = makePad()
    }

    /// Ends the edit; balls already replaced stay replaced.
    func cancelEdit() {
        edit = nil
        ballOverride = nil
        hasOverride = false
        pad = makePad()
    }

    func next() { record { $0.nextInput } }
    func strike() { record { $0.strikeInput } }
    func spare() { record { $0.spareInput } }
    func miss() { record { $0.missInput } }
    func foul() { record { _ in .foul } }
    func count(_ pins: Int) { record { _ in .count(pins) } }

    /// Reopens the last roll. Does nothing before the first roll.
    func undo() {
        guard edit == nil, canUndo, acceptsTap() else { return }
        update(.other) { _ = try $0.games.undoLastRoll(in: target.gameID) }
    }

    /// Refused with `.entryModeLocked` once the game has a roll. Leaving final score
    /// resets the typed score.
    func setEntryMode(_ mode: EntryMode) {
        update(.other) { try $0.games.setEntryMode(mode, for: target.gameID) }
    }

    /// Removes every roll, which unlocks the entry mode.
    func clearRolls() {
        update(.other) { _ = try $0.games.clearRolls(in: target.gameID) }
    }

    /// Saves a typed score of 0 through 300 (the Quick score rule); other text is ignored.
    func saveFinalScore(_ text: String) {
        guard let score = QuickScoreEntry.score(text) else { return }
        if update(.roll, { try $0.games.setFinalScore(score, for: target.gameID) }) {
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
        if edit == nil, pad?.autoAdvances == true { next() }
    }

    /// Records the roll, or replaces the edited one.
    private func record(_ input: (RollPad) -> RollInput) {
        guard let pad, acceptsTap() else { return }
        let input = input(pad)
        let ball = rollBallID
        guard let edit else {
            update(.roll) { _ = try $0.games.recordRoll(input, ballID: ball, in: target.gameID) }
            return
        }
        var outcome: RollEditOutcome?
        update(.edit) {
            outcome = try $0.games.replaceRoll(
                frameIndex: edit.frameIndex, rollIndex: edit.rollIndex, with: input, ballID: ball, in: target.gameID
            )
        }
        guard let outcome else { return }
        clearedFrames = outcome.clearedFrames.filter { $0 != edit.frameIndex }
        self.edit = edit.next(in: outcome.game)
        self.pad = makePad()
    }

    /// False within `tapLockout` of the last roll or Undo.
    private func acceptsTap() -> Bool {
        let time = now()
        if let lastWrite, time.timeIntervalSince(lastWrite) < Self.tapLockout { return false }
        lastWrite = time
        return true
    }

    /// Runs one write, then reloads from the store whether it worked or not, and reports
    /// `kind` to `onWrite` when it worked.
    /// - Returns: Whether the write worked.
    @discardableResult
    private func update(_ kind: ScoringWrite, _ body: (BowlingStore) throws -> Void) -> Bool {
        let worked: Bool
        do {
            try app.write(body)
            worked = true
        } catch {
            app.error = error
            worked = false
        }
        reload()
        if worked {
            clearedFrames = []
            onWrite?(kind)
        }
        return worked
    }

    private func reload() {
        if let fresh = try? app.store.games.game(target.gameID) { game = fresh }
        scorecard = Scorer.scorecard(for: game)
        ballOverride = nil
        hasOverride = false
        if edit?.roll(in: game) == nil { edit = nil }
        pad = makePad()
    }

    /// The edited roll's rack, prefilled with what it left standing; otherwise the next roll.
    private func makePad() -> RollPad? {
        guard let edit else {
            return Scorer.nextRoll(in: game).map {
                RollPad(position: $0, entryMode: game.entryMode, settings: app.scoringSettings)
            }
        }
        guard let position = edit.position(in: game), let roll = edit.roll(in: game) else { return nil }
        var pad = RollPad(position: position, entryMode: game.entryMode, settings: app.scoringSettings)
        let knocked = roll.pinsKnown && !roll.isFoul ? roll.pinsDown : []
        pad.setShown(position.standingPins.subtracting(knocked))
        return pad
    }
}
