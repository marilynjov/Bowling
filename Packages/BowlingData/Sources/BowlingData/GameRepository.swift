import BowlingCore
import Foundation
import SwiftData

@MainActor
public final class GameRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    public func game(_ id: GameID) throws -> GameRecord {
        try context.game(id).record()
    }

    /// The one write path for a game's frames and rolls; per-roll entry and edits build on it.
    /// Validates with `Scorer`, sets the cached `finalScore` and `isComplete` (scored games
    /// only), and saves. Session context and `bowlerID` in `record` are ignored.
    /// - Throws: `.invalidGame` with every violation, and nothing is saved.
    func save(_ record: GameRecord) throws -> GameRecord {
        let game = try context.game(record.id)
        let errors = Scorer.validate(record)
        guard errors.isEmpty else { throw RepositoryError.invalidGame(errors) }
        return try context.write {
            try game.apply(Self.scored(record), in: context)
            return game.record()
        }
    }

    /// Before frame 10 is finished the cached score is the last known running total, so
    /// History shows a partial game's progress instead of 0.
    private static func scored(_ record: GameRecord) -> GameRecord {
        guard record.entryMode != .finalOnly else { return record }
        var scored = record
        scored.finalScore = Scorer.scorecard(for: record).frames.compactMap(\.runningTotal).last ?? 0
        scored.isComplete = Scorer.nextRoll(in: record) == nil
        return scored
    }

    /// - Throws: `.notFound` when the ball does not exist.
    public func setDefaultBall(_ ballID: BallID?, for game: GameID) throws {
        var record = try self.game(game)
        record.defaultBallID = ballID
        _ = try save(record)
    }

    /// Marks a finalOnly game complete with the typed score.
    /// - Throws: `.invalidGame([.finalScoreOutOfRange])` outside 0 through 300, and
    ///   `.invalidGame([])` for a game scored from rolls, whose score is never typed.
    public func setFinalScore(_ score: Int, for game: GameID) throws {
        var record = try self.game(game)
        guard record.entryMode == .finalOnly else { throw RepositoryError.invalidGame([]) }
        record.finalScore = score
        record.isComplete = true
        _ = try save(record)
    }

    /// Adds the next game for every bowler in the session, with the entry mode and default
    /// ball of that bowler's latest game.
    /// - Returns: The new games, in the session's bowler order.
    public func startNextGame(in session: SessionID) throws -> [GameID] {
        let session = try context.session(session)
        return try context.write {
            session.gamesByBowler().compactMap { group in
                guard let latest = group.games.last else { return nil }
                let game = Game(gameIndex: latest.gameIndex + 1)
                context.insert(game)
                game.entryMode = latest.entryMode
                game.session = session
                game.bowler = group.bowler
                game.defaultBall = latest.defaultBall
                return game.id
            }
        }
    }

    /// Cascades to the game's frames and rolls.
    public func deleteGame(_ id: GameID) throws {
        let game = try context.game(id)
        try context.write { context.delete(game) }
    }
}
