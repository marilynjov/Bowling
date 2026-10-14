import Foundation
import BowlingCore

/// A foul in a `countOnlyGame` frame list.
let F = -1

/// Builds a countOnly game; each inner array is one frame's pin counts, `F` for a foul.
func countOnlyGame(_ frames: [[Int]]) -> GameRecord {
    let records = frames.enumerated().map { frameOffset, counts in
        FrameRecord(frameIndex: frameOffset + 1, rolls: counts.enumerated().map { rollOffset, count in
            count == F
                ? RollRecord(rollIndex: rollOffset + 1, pinCount: 0, pinsKnown: false, isFoul: true)
                : RollRecord(rollIndex: rollOffset + 1, pinCount: count, pinsKnown: false)
        })
    }
    return game(.countOnly, records)
}

/// A pinByPin roll; `nil` is a foul.
func pins(_ numbers: Int...) -> RollRecord? {
    let set = PinSet(pins: numbers)
    return RollRecord(rollIndex: 0, pinsDown: set, pinCount: set.count, pinsKnown: true)
}

let foul: RollRecord? = nil

/// Builds a pinByPin game; each inner array is one frame's rolls, `foul` for a foul.
func pinByPinGame(_ frames: [[RollRecord?]]) -> GameRecord {
    let records = frames.enumerated().map { frameOffset, rolls in
        FrameRecord(frameIndex: frameOffset + 1, rolls: rolls.enumerated().map { rollOffset, roll in
            var record = roll ?? RollRecord(rollIndex: 0, pinCount: 0, pinsKnown: true, isFoul: true)
            record.rollIndex = rollOffset + 1
            return record
        })
    }
    return game(.pinByPin, records)
}

func game(_ mode: EntryMode, _ frames: [FrameRecord], finalScore: Int = 0) -> GameRecord {
    GameRecord(
        gameIndex: 1, entryMode: mode, finalScore: finalScore, isComplete: false,
        frames: frames, sessionDate: Date(timeIntervalSince1970: 0), eventType: .league
    )
}
