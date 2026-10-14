import BowlingCore

/// One delivery with the rack it was thrown at, so the fixture tests can check §4 rules
/// and recount the hand-written expectations without depending on the Scorer (#18).
struct WalkedRoll {
    let frameIndex: Int
    let roll: RollRecord
    let standingBefore: PinSet
    let standingCountBefore: Int
    /// First ball on a rack (§6 "First balls").
    let isFirstBall: Bool

    var standingCountAfter: Int { standingCountBefore - roll.pinCount }
}

enum RollWalk {
    /// Every roll in order. The rack resets after a frame, after a rack is cleared, and
    /// after two balls on one rack; a foul leaves the rack as it was (§4 "Fouls").
    static func rolls(of game: GameRecord) -> [WalkedRoll] {
        var walked: [WalkedRoll] = []
        for frame in game.frames {
            var standing = PinSet.all
            var standingCount = 10
            var ballsOnRack = 0
            for roll in frame.rolls {
                walked.append(WalkedRoll(
                    frameIndex: frame.frameIndex, roll: roll, standingBefore: standing,
                    standingCountBefore: standingCount, isFirstBall: ballsOnRack == 0
                ))
                standing.subtract(roll.pinsDown)
                standingCount -= roll.pinCount
                ballsOnRack += 1
                if standingCount <= 0 || ballsOnRack == 2 {
                    standing = .all
                    standingCount = 10
                    ballsOnRack = 0
                }
            }
        }
        return walked
    }

    /// The tenth frame's running total, or for an unfinished game the last running total
    /// whose bonus rolls exist.
    static func score(of game: GameRecord) -> Int {
        let rolls = rolls(of: game)
        var total = 0
        for frame in game.frames {
            guard let start = rolls.firstIndex(where: { $0.frameIndex == frame.frameIndex })
            else { break }
            let own = frame.rolls.map(\.pinCount)
            let isStrike = own.first == 10
            let isSpare = !isStrike && own.count >= 2 && own[0] + own[1] == 10
            let counted = frame.frameIndex == 10 ? own.count : (isStrike ? 3 : isSpare ? 3 : 2)
            let isFinished = frame.frameIndex == 10
                ? own.count == (isStrike || isSpare ? 3 : 2)
                : (isStrike || own.count == 2)
            guard isFinished, start + counted <= rolls.count else { break }
            total += rolls[start..<start + counted].map(\.roll.pinCount).reduce(0, +)
        }
        return total
    }
}
