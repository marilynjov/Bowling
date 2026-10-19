import Foundation

/// One spare attempt at a leave (spec §6 "Definitions (1b)", "Leave occurrences"),
/// addressed by game ID plus frame index (contract OQ-7). A frame holds at most one
/// spare attempt, because a frame 10 fill ball is not one.
public struct LeaveOccurrence: Sendable, Hashable, Codable, Identifiable {
    public struct ID: Sendable, Hashable, Codable {
        public var gameID: GameID
        public var frameIndex: Int

        public init(gameID: GameID, frameIndex: Int) {
            self.gameID = gameID
            self.frameIndex = frameIndex
        }
    }

    /// The game's ID, session, and session date.
    public var game: GameRef
    public var gameIndex: Int
    public var frameIndex: Int
    /// The spare attempt's roll override, otherwise the game's default ball; nil when
    /// neither is set.
    public var ballID: BallID?
    public var isConverted: Bool

    public var id: ID { ID(gameID: game.gameID, frameIndex: frameIndex) }

    public init(game: GameRef, gameIndex: Int, frameIndex: Int, ballID: BallID?, isConverted: Bool) {
        self.game = game
        self.gameIndex = gameIndex
        self.frameIndex = frameIndex
        self.ballID = ballID
        self.isConverted = isConverted
    }
}

extension StatsEngine {
    /// Every spare attempt at `leave` in `games`, newest first: session date descending,
    /// then session, then game index and frame descending. Uses the games the leaves table
    /// uses, complete pinByPin ones, so a row's count equals its occurrence count. Matches
    /// on the standing pins.
    public static func leaveOccurrences(of leave: Leave, games: [GameRecord]) -> [LeaveOccurrence] {
        games.filter { $0.isComplete && $0.entryMode == .pinByPin }
            .flatMap { game in occurrences(in: game).filter { $0.pins == leave.pins }.map(\.occurrence) }
            .sorted {
                ($1.game.date, $1.game.sessionID?.uuidString ?? "", $1.gameIndex, $1.frameIndex)
                    < ($0.game.date, $0.game.sessionID?.uuidString ?? "", $0.gameIndex, $0.frameIndex)
            }
    }

    /// The same spare attempts `RollTally` counts, those after a first-ball foul left out
    /// because they have no leave (§5).
    private static func occurrences(in game: GameRecord) -> [(pins: PinSet, occurrence: LeaveOccurrence)] {
        Scorer.playedFrames(game).compactMap { frame in
            let marks = frame.marks
            for (index, (roll, rack)) in zip(frame.rolls, frame.racks).enumerated() where rack.isFresh {
                guard marks[index] != .strike, index + 1 < frame.rolls.count else { continue }
                guard !roll.isFoul, roll.pinsKnown, let standing = frame.racks[index + 1].pins else { return nil }
                let occurrence = LeaveOccurrence(
                    game: GameRef(gameID: game.id, sessionID: game.sessionID, date: game.sessionDate),
                    gameIndex: game.gameIndex, frameIndex: frame.frameIndex,
                    ballID: frame.rolls[index + 1].ballID ?? game.defaultBallID,
                    isConverted: marks[index + 1] == .spare
                )
                return (standing, occurrence)
            }
            return nil
        }
    }
}
