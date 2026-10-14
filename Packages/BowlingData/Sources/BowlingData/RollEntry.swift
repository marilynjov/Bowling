import BowlingCore
import Foundation
import SwiftData

/// What the Scoring screen sends for one delivery.
public enum RollInput: Sendable, Hashable {
    /// pinByPin: the pins that fell on this roll.
    case pins(PinSet)
    /// countOnly.
    case count(Int)
    /// Either mode.
    case foul
}

extension GameRepository {
    /// Appends at `Scorer.nextRoll(in:)` and saves, so an unfinished game survives the app
    /// being killed. The repository sets `rollIndex`, `pinCount`, and `pinsKnown`.
    /// - Throws: `.invalidGame` with the violations when the roll does not fit, and
    ///   `.invalidGame([])` for input of the other entry mode, a finalOnly game, or a
    ///   complete game; `.notFound` for a missing game or ball. Nothing is saved.
    public func recordRoll(_ input: RollInput, ballID: BallID?, in game: GameID) throws -> GameRecord {
        var record = try self.game(game)
        guard let position = Scorer.nextRoll(in: record) else { throw RepositoryError.invalidGame([]) }
        let roll = try Self.roll(input, rollIndex: position.rollIndex, ballID: ballID, mode: record.entryMode)
        if let frame = record.frames.firstIndex(where: { $0.frameIndex == position.frameIndex }) {
            record.frames[frame].rolls.append(roll)
        } else {
            record.frames.append(FrameRecord(frameIndex: position.frameIndex, rolls: [roll]))
        }
        return try save(record)
    }

    /// - Throws: `.invalidGame([])` when `input` does not belong to `mode`.
    private static func roll(_ input: RollInput, rollIndex: Int, ballID: BallID?, mode: EntryMode) throws -> RollRecord {
        switch (input, mode) {
        case let (.pins(pins), .pinByPin):
            RollRecord(rollIndex: rollIndex, pinsDown: pins, pinCount: pins.count, pinsKnown: true, ballID: ballID)
        case let (.count(count), .countOnly):
            RollRecord(rollIndex: rollIndex, pinCount: count, pinsKnown: false, ballID: ballID)
        case (.foul, .pinByPin), (.foul, .countOnly):
            RollRecord(rollIndex: rollIndex, pinCount: 0, pinsKnown: mode == .pinByPin, isFoul: true, ballID: ballID)
        default:
            throw RepositoryError.invalidGame([])
        }
    }
}
