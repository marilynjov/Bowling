import BowlingCore

/// Whose turn it is on a night with several bowlers: the lane console's rule, the first in
/// lineup order among unfinished games with the fewest finished frames.
enum Rotation {
    /// Rolls finished, or a final-only game with its score saved.
    static func isFinished(_ game: GameRecord) -> Bool {
        game.entryMode == .finalOnly ? game.isComplete : Scorer.nextRoll(in: game) == nil
    }

    /// Frame 10 counts only once the game is finished, so fill balls stay with the same
    /// bowler. A final-only game counts 0 until its score is saved, then 10.
    static func finishedFrames(_ game: GameRecord) -> Int {
        if isFinished(game) { return 10 }
        guard let next = Scorer.nextRoll(in: game) else { return 0 }
        return next.frameIndex - 1
    }

    /// - Parameters:
    ///   - current: The bowler whose turn it was, an index into `games`.
    ///   - games: Each bowler's game, in lineup order.
    ///   - rotates: Off, the current bowler keeps the turn until their game is finished.
    /// - Returns: An index into `games`, or nil when every game is finished.
    static func current(after current: Int?, games: [GameRecord], rotates: Bool) -> Int? {
        if !rotates, let current, !isFinished(games[current]) { return current }
        return games.indices
            .filter { !isFinished(games[$0]) }
            .min { finishedFrames(games[$0]) < finishedFrames(games[$1]) }
    }
}
