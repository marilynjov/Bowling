import Foundation

/// Spec §6 "Definitions (1b)".
extension StatsEngine {
    /// `rolled` are the complete countOnly and pinByPin games, `pinned` the pinByPin ones,
    /// as `report` splits them by the applicability table.
    static func add1bStats(to report: inout StatsReport, rolled: [GameRecord], pinned: [GameRecord]) {
        let games = rolled.map(Scorer.playedFrames)
        let openCounts = games.map { frames in frames.filter(\.isOpen).count }
        report.openFrames = Rate(hits: openCounts.reduce(0, +), attempts: 10 * games.count)
        report.cleanGames = Rate(hits: openCounts.filter { $0 == 0 }.count, attempts: games.count)

        let firstBalls = games.flatMap { $0.flatMap(\.firstBalls) }
        report.firstBallAverage = Mean(total: firstBalls.map(\.scoredCount).reduce(0, +), count: firstBalls.count)
        let thrown = pinned.flatMap { Scorer.playedFrames($0).flatMap(\.firstBalls) }.filter { !$0.isFoul }
        report.headPin = Rate(hits: thrown.filter { $0.pinsDown.contains(.pin1) }.count, attempts: thrown.count)

        report.byFrame = (0..<10).map { offset in
            let column = games.map { $0[offset] }
            return FrameStats(
                frameIndex: offset + 1,
                strikes: Rate(hits: column.filter { $0.marks.first == .strike }.count, attempts: column.count),
                pins: Mean(total: column.map(\.firstRackPinfall).reduce(0, +), count: column.count)
            )
        }
        report.whatIfSinglePins = whatIfSinglePins(pinned)
    }

    /// A game whose rewrite does not rescore is left out of both averages: counting its real
    /// score as the rescored one would show the card a false gain of 0. When the game scored
    /// before the rewrite, the rewrite broke it, so that asserts; a game marked complete
    /// whose frames never finish (only hand-built test input) is skipped quietly.
    private static func whatIfSinglePins(_ games: [GameRecord]) -> WhatIfSinglePins {
        let rescored = games.compactMap { game -> (actual: Int, made: Int, rewritten: Int)? in
            let made = singlePinsMade(game)
            guard let score = made.score else {
                if Scorer.scorecard(for: game).finalScore != nil {
                    assertionFailure("What-if rewrite of game \(game.id) no longer scores")
                }
                return nil
            }
            return (game.finalScore, score, made.rewritten)
        }
        return WhatIfSinglePins(
            actual: Mean(total: rescored.map(\.actual).reduce(0, +), count: rescored.count),
            allMade: Mean(total: rescored.map(\.made).reduce(0, +), count: rescored.count),
            rewritten: rescored.map(\.rewritten).reduce(0, +)
        )
    }

    /// Rewrites each missed single-pin spare attempt so the second ball knocks the pin down,
    /// and rescores with `Scorer`. A frame 10 spare made this way gets a fill ball of 0,
    /// since the bowler never threw one. The score is nil when the rewritten game does not
    /// finish, which a valid complete game never does.
    static func singlePinsMade(_ game: GameRecord) -> (score: Int?, rewritten: Int) {
        var rewritten = 0
        let frames = Scorer.playedFrames(game).map { frame in
            var rolls = frame.rolls
            let marks = frame.marks
            for index in rolls.indices.dropLast() where frame.racks[index].isFresh && !rolls[index].isFoul
                && marks[index] != .strike && marks[index + 1] != .spare {
                guard let standing = frame.racks[index + 1].pins,
                      LeaveClassifier.classify(standing).kind == .singlePin else { continue }
                let missed = rolls[index + 1]
                rolls[index + 1] = RollRecord(rollIndex: missed.rollIndex, pinsDown: standing, pinCount: standing.count,
                                              pinsKnown: true, ballID: missed.ballID)
                rewritten += 1
                if frame.frameIndex == 10, rolls.count == 2 {
                    rolls.append(RollRecord(rollIndex: 3, pinCount: 0, pinsKnown: true))
                }
            }
            return FrameRecord(frameIndex: frame.frameIndex, rolls: rolls)
        }
        var made = game
        made.frames = frames
        return (Scorer.scorecard(for: made).finalScore, rewritten)
    }
}

extension PlayedFrame {
    /// Neither a strike nor a spare. Frame 10 only gets a fill ball after one of them, so
    /// its fill balls never make it open.
    var isOpen: Bool { !marks.contains(.strike) && !marks.contains(.spare) }

    /// Rolls on a fresh rack (§6 "First balls").
    var firstBalls: [RollRecord] {
        zip(rolls, racks).filter { $0.1.isFresh }.map(\.0)
    }

    /// Pins on the frame's first rack: roll 1, plus roll 2 unless roll 1 was a strike.
    /// Frame 10's fill balls are left out so it compares with frames 1-9 on the by-frame
    /// chart; with them it read about 20 pins against about 9.7 (review of #82).
    var firstRackPinfall: Int {
        rolls.prefix(marks.first == .strike ? 1 : 2).map(\.scoredCount).reduce(0, +)
    }
}
