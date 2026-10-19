import BowlingCore
import Foundation
import SwiftData

/// What the Scoring screen sends for one delivery.
public enum RollInput: Sendable, Hashable {
    /// pinByPin: the pins that fell on this roll.
    case pins(PinSet)
    /// pinByPin: the pins still standing after this roll, what the pin deck sends by
    /// default. The repository converts them to the pins that fell.
    case pinsLeft(PinSet)
    /// countOnly.
    case count(Int)
    /// Either mode.
    case foul
}

public struct RollEditOutcome: Sendable, Hashable {
    public var game: GameRecord
    /// Frames that lost rolls because the edit made them invalid, ascending; the user is
    /// told these need re-entry.
    public var clearedFrames: [Int]

    public init(game: GameRecord, clearedFrames: [Int]) {
        self.game = game
        self.clearedFrames = clearedFrames
    }
}

extension GameRepository {
    /// Appends at `Scorer.nextRoll(in:)` and saves, so an unfinished game survives the app
    /// being killed. The repository sets `rollIndex`, `pinCount`, and `pinsKnown`.
    /// - Throws: `.invalidGame` with the violations when the roll does not fit, including
    ///   pins left that were not standing, and `.invalidGame([])` for input of the other
    ///   entry mode, a finalOnly game, or a complete game; `.notFound` for a missing game
    ///   or ball. Nothing is saved.
    public func recordRoll(_ input: RollInput, ballID: BallID?, in game: GameID) throws -> GameRecord {
        var record = try self.game(game)
        guard let position = Scorer.nextRoll(in: record) else { throw RepositoryError.invalidGame([]) }
        let roll = try Self.roll(input, at: position, ballID: ballID, mode: record.entryMode)
        if let frame = record.frames.firstIndex(where: { $0.frameIndex == position.frameIndex }) {
            record.frames[frame].rolls.append(roll)
        } else {
            record.frames.append(FrameRecord(frameIndex: position.frameIndex, rolls: [roll]))
        }
        return try save(record)
    }

    /// Removes the last roll, and its frame once empty. A game with no rolls is returned unchanged.
    public func undoLastRoll(in game: GameID) throws -> GameRecord {
        var record = try self.game(game)
        guard let last = record.frames.lastIndex(where: { !$0.rolls.isEmpty }) else { return record }
        record.frames[last].rolls.removeLast()
        record.frames.removeAll { $0.rolls.isEmpty }
        return try save(record)
    }

    /// Replaces one roll, re-validates the rolls after it in order, and clears every roll
    /// from the first one that no longer fits, so the scorecard never shows a roll the new
    /// rack could not have produced.
    /// - Throws: `.notFound` when the game, roll, or ball does not exist; `.invalidGame`
    ///   when the new roll itself does not fit, as `recordRoll` would. Nothing is saved.
    public func replaceRoll(
        frameIndex: Int, rollIndex: Int, with input: RollInput, ballID: BallID?, in game: GameID
    ) throws -> RollEditOutcome {
        var record = try self.game(game)
        var rolls = record.frames.flatMap { frame in frame.rolls.map { (frameIndex: frame.frameIndex, roll: $0) } }
        guard let edited = rolls.firstIndex(where: { $0.frameIndex == frameIndex && $0.roll.rollIndex == rollIndex })
        else { throw RepositoryError.notFound }
        var faced = record
        faced.frames = Self.frames(Array(rolls[..<edited]))
        guard let position = Scorer.nextRoll(in: faced) else { throw RepositoryError.notFound }
        rolls[edited].roll = try Self.roll(input, at: position, ballID: ballID, mode: record.entryMode)

        var kept = Array(rolls[...edited])
        record.frames = Self.frames(kept)
        let errors = Scorer.validate(record)
        guard errors.isEmpty else { throw RepositoryError.invalidGame(errors) }
        for later in rolls[(edited + 1)...] {
            var candidate = record
            candidate.frames = Self.frames(kept + [later])
            guard Scorer.validate(candidate).isEmpty else { break }
            kept.append(later)
            record = candidate
        }

        let cleared = Set(rolls[kept.count...].map(\.frameIndex)).sorted()
        return RollEditOutcome(game: try save(record), clearedFrames: cleared)
    }

    static func frames(_ rolls: [(frameIndex: Int, roll: RollRecord)]) -> [FrameRecord] {
        Dictionary(grouping: rolls, by: \.frameIndex)
            .map { FrameRecord(frameIndex: $0.key, rolls: $0.value.map(\.roll)) }
            .sorted { $0.frameIndex < $1.frameIndex }
    }

    /// Rolls already entered were recorded for one mode, and there is no automatic upgrade
    /// from countOnly to pinByPin, so the mode is fixed once the first roll exists.
    /// - Throws: `.entryModeLocked` after the first roll; `clearRolls(in:)` unlocks it.
    public func setEntryMode(_ mode: EntryMode, for game: GameID) throws {
        var record = try self.game(game)
        record.entryMode = mode
        _ = try save(record)
    }

    /// Removes every frame and roll, the offer made after `.entryModeLocked`.
    public func clearRolls(in game: GameID) throws -> GameRecord {
        var record = try self.game(game)
        record.frames = []
        return try save(record)
    }

    /// - Throws: `.invalidGame([])` when `input` does not belong to `mode`, and
    ///   `.notSubsetOfStanding` for pins left that were not standing at `position`.
    private static func roll(
        _ input: RollInput, at position: RollPosition, ballID: BallID?, mode: EntryMode
    ) throws -> RollRecord {
        let rollIndex = position.rollIndex
        switch (input, mode) {
        case let (.pins(pins), .pinByPin):
            return RollRecord(rollIndex: rollIndex, pinsDown: pins, pinCount: pins.count, pinsKnown: true, ballID: ballID)
        case let (.pinsLeft(left), .pinByPin):
            guard position.standingPins.isSuperset(of: left) else {
                throw RepositoryError.invalidGame([
                    .notSubsetOfStanding(frameIndex: position.frameIndex, rollIndex: rollIndex),
                ])
            }
            let fell = position.standingPins.subtracting(left)
            return RollRecord(rollIndex: rollIndex, pinsDown: fell, pinCount: fell.count, pinsKnown: true, ballID: ballID)
        case let (.count(count), .countOnly):
            return RollRecord(rollIndex: rollIndex, pinCount: count, pinsKnown: false, ballID: ballID)
        case (.foul, .pinByPin), (.foul, .countOnly):
            return RollRecord(rollIndex: rollIndex, pinCount: 0, pinsKnown: mode == .pinByPin, isFoul: true, ballID: ballID)
        default:
            throw RepositoryError.invalidGame([])
        }
    }
}
