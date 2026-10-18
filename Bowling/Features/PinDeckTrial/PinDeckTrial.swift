#if DEBUG
import BowlingCore
import Foundation

/// One throwaway game for the pin deck test (#3): rolls go into a `GameRecord` that is
/// never saved, and the scorer says what the next roll faces. Every action is ignored once
/// the game is over.
struct PinDeckTrial {
    private(set) var game = GameRecord(
        gameIndex: 1, entryMode: .pinByPin, finalScore: 0, isComplete: false,
        sessionDate: .now, eventType: .practice
    )

    var position: RollPosition? { Scorer.nextRoll(in: game) }
    var scorecard: Scorecard { Scorer.scorecard(for: game) }

    /// Records the deck: every available pin not left `standing` went down.
    mutating func record(standing: PinSet) {
        guard let position else { return }
        let down = position.standingPins.subtracting(standing)
        add(RollRecord(rollIndex: position.rollIndex, pinsDown: down, pinCount: down.count, pinsKnown: true))
    }

    /// Strike on a fresh rack, spare otherwise.
    mutating func clearRack() { record(standing: []) }

    mutating func miss() {
        guard let position else { return }
        record(standing: position.standingPins)
    }

    mutating func foul() {
        guard let position else { return }
        add(RollRecord(rollIndex: position.rollIndex, pinCount: 0, pinsKnown: true, isFoul: true))
    }

    mutating func undo() {
        guard let last = game.frames.indices.last else { return }
        game.frames[last].rolls.removeLast()
        if game.frames[last].rolls.isEmpty { game.frames.removeLast() }
        refresh()
    }

    private mutating func add(_ roll: RollRecord) {
        guard let frameIndex = position?.frameIndex else { return }
        if game.frames.last?.frameIndex == frameIndex {
            game.frames[game.frames.count - 1].rolls.append(roll)
        } else {
            game.frames.append(FrameRecord(frameIndex: frameIndex, rolls: [roll]))
        }
        refresh()
    }

    private mutating func refresh() {
        game.isComplete = position == nil
        game.finalScore = scorecard.finalScore ?? 0
    }
}
#endif
