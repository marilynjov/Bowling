/// One frame of the scorecard strip.
public struct FrameScore: Sendable, Hashable {
    /// 1...10.
    public var frameIndex: Int
    /// One per roll, in `rollIndex` order.
    public var marks: [Mark]
    /// Nil until the frame is finished and its bonus rolls exist, so the UI shows a blank
    /// as a lane monitor does.
    public var runningTotal: Int?

    public init(frameIndex: Int, marks: [Mark], runningTotal: Int?) {
        self.frameIndex = frameIndex
        self.marks = marks
        self.runningTotal = runningTotal
    }
}

public struct Scorecard: Sendable, Hashable {
    /// Always ten entries, `frameIndex` 1...10.
    public var frames: [FrameScore]
    /// The tenth frame's running total, or the typed score of a finalOnly game; nil until known.
    public var finalScore: Int?

    public init(frames: [FrameScore], finalScore: Int?) {
        self.frames = frames
        self.finalScore = finalScore
    }
}

public enum Scorer {
    public static func scorecard(for game: GameRecord) -> Scorecard {
        guard game.entryMode != .finalOnly else {
            let empty = (1...10).map { FrameScore(frameIndex: $0, marks: [], runningTotal: nil) }
            return Scorecard(frames: empty, finalScore: game.finalScore)
        }
        let played = playedFrames(game)
        var runningTotal: Int? = 0
        let frames = played.enumerated().map { offset, frame in
            let later = played[(offset + 1)...].flatMap(\.rolls)
            if let total = runningTotal, let score = frame.score(bonusRolls: later) {
                runningTotal = total + score
            } else {
                runningTotal = nil
            }
            return FrameScore(frameIndex: frame.frameIndex, marks: frame.marks, runningTotal: runningTotal)
        }
        return Scorecard(frames: frames, finalScore: frames.last?.runningTotal)
    }

    /// Every violation, in frame and roll order; empty means valid. Repositories refuse to
    /// save a game with any.
    public static func validate(_ game: GameRecord) -> [ScoringError] {
        guard game.entryMode != .finalOnly else {
            return (0...300).contains(game.finalScore) ? [] : [.finalScoreOutOfRange]
        }
        var errors: [ScoringError] = []
        func report(_ error: ScoringError) {
            if !errors.contains(error) { errors.append(error) }
        }

        var seenFrames = Set<Int>()
        var previousFrame = 0
        for frame in game.frames {
            guard seenFrames.insert(frame.frameIndex).inserted else {
                report(.duplicateIndex(frameIndex: frame.frameIndex, rollIndex: nil))
                continue
            }
            if frame.frameIndex <= previousFrame || !(1...10).contains(frame.frameIndex) {
                report(.outOfOrder(frameIndex: frame.frameIndex))
            }
            previousFrame = max(previousFrame, frame.frameIndex)

            var seenRolls = Set<Int>()
            var previousRoll = 0
            for roll in frame.rolls {
                guard seenRolls.insert(roll.rollIndex).inserted else {
                    report(.duplicateIndex(frameIndex: frame.frameIndex, rollIndex: roll.rollIndex))
                    continue
                }
                if roll.rollIndex <= previousRoll || !(1...3).contains(roll.rollIndex) {
                    report(.outOfOrder(frameIndex: frame.frameIndex))
                }
                previousRoll = max(previousRoll, roll.rollIndex)
            }
        }

        let played = playedFrames(game)
        for (offset, frame) in played.enumerated() {
            guard let record = game.frames.first(where: { $0.frameIndex == frame.frameIndex }) else { continue }
            let rolls = record.rolls.sorted { $0.rollIndex < $1.rollIndex }
            if !rolls.isEmpty, offset > 0, !played[offset - 1].isFinished {
                report(.outOfOrder(frameIndex: frame.frameIndex))
            }
            if zip(frame.rolls, 1...).contains(where: { $0.rollIndex != $1 }) {
                report(.outOfOrder(frameIndex: frame.frameIndex))
            }
            for (roll, rack) in zip(frame.rolls, frame.racks) {
                rollErrors(roll, facing: rack, frameIndex: frame.frameIndex).forEach(report)
            }
            if frame.rolls.count < Set(rolls.map(\.rollIndex)).count {
                report(extraRollError(frame))
            }
        }
        return errors
    }

    private static func rollErrors(_ roll: RollRecord, facing rack: Rack, frameIndex: Int) -> [ScoringError] {
        if roll.isFoul {
            let hasPins = roll.pinCount != 0 || !roll.pinsDown.isEmpty
            return hasPins ? [.foulWithPins(frameIndex: frameIndex, rollIndex: roll.rollIndex)] : []
        }
        var errors: [ScoringError] = []
        if !(0...rack.standing).contains(roll.pinCount) {
            errors.append(.pinsExceedAvailable(frameIndex: frameIndex, rollIndex: roll.rollIndex))
        }
        if roll.pinsKnown, let standing = rack.pins, !roll.pinsDown.isSubset(of: standing) {
            errors.append(.notSubsetOfStanding(frameIndex: frameIndex, rollIndex: roll.rollIndex))
        }
        return errors
    }

    /// The error for rolls past the ones `frame` allows.
    private static func extraRollError(_ frame: PlayedFrame) -> ScoringError {
        if frame.frameIndex == 10 {
            return frame.rolls.count == 2 ? .unearnedThirdRoll : .outOfOrder(frameIndex: 10)
        }
        return frame.marks.first == .strike
            ? .rollAfterStrike(frameIndex: frame.frameIndex)
            : .outOfOrder(frameIndex: frame.frameIndex)
    }

    /// Frames 1...10 in order, rolls in `rollIndex` order. Duplicates and indices out of range
    /// are dropped, so a game that fails `validate` still gets a best-effort scorecard.
    static func playedFrames(_ game: GameRecord) -> [PlayedFrame] {
        (1...10).map { index in
            let rolls = game.frames.first { $0.frameIndex == index }?.rolls ?? []
            var seen = Set<Int>()
            let ordered = rolls.sorted { $0.rollIndex < $1.rollIndex }
                .filter { (1...3).contains($0.rollIndex) && seen.insert($0.rollIndex).inserted }
            return PlayedFrame(frameIndex: index, rolls: ordered)
        }
    }
}

/// The pins a roll faces.
struct Rack: Hashable {
    var standing: Int
    /// Nil once a roll on this rack was recorded without pins.
    var pins: PinSet?
    /// No ball has been rolled at this rack yet; clearing it is a strike.
    var isFresh: Bool

    static let fresh = Rack(standing: 10, pins: .all, isFresh: true)

    /// The rack the next roll faces. A foul respots its pins (USBC), and a cleared rack in
    /// frame 10 is reset for the fill ball.
    func after(_ roll: RollRecord) -> Rack {
        if roll.isFoul { return Rack(standing: standing, pins: pins, isFresh: false) }
        if roll.pinCount >= standing { return .fresh }
        let remaining = roll.pinsKnown ? pins?.subtracting(roll.pinsDown) : nil
        return Rack(standing: standing - max(roll.pinCount, 0), pins: remaining, isFresh: false)
    }

    func mark(for roll: RollRecord) -> Mark {
        if roll.isFoul { return .foul }
        if roll.pinCount <= 0 { return .gutter }
        if roll.pinCount >= standing { return isFresh ? .strike : .spare }
        return .count(roll.pinCount)
    }
}

/// A frame's rolls replayed against the racks they faced.
struct PlayedFrame {
    let frameIndex: Int
    /// Rolls past the ones the frame allows are dropped.
    let rolls: [RollRecord]
    /// The rack each roll faced.
    let racks: [Rack]
    /// The rack the next roll in this frame would face; nil when the frame is finished.
    let nextRack: Rack?

    init(frameIndex: Int, rolls: [RollRecord]) {
        self.frameIndex = frameIndex
        var kept: [RollRecord] = []
        var racks: [Rack] = []
        var rack = Rack.fresh
        var allowed = 2
        for roll in rolls where kept.count < allowed {
            racks.append(rack)
            kept.append(roll)
            rack = rack.after(roll)
            if rack.isFresh {
                allowed = frameIndex == 10 ? 3 : kept.count
            }
        }
        self.rolls = kept
        self.racks = racks
        self.nextRack = kept.count < allowed ? rack : nil
    }

    var isFinished: Bool { nextRack == nil }

    var marks: [Mark] {
        zip(racks, rolls).map { $0.mark(for: $1) }
    }

    /// Pins plus bonus, or nil while the frame or its bonus is incomplete.
    func score(bonusRolls: [RollRecord]) -> Int? {
        guard isFinished else { return nil }
        let pins = rolls.map(\.scoredCount).reduce(0, +)
        guard frameIndex < 10 else { return pins }
        let bonusCount = switch marks.last {
        case .strike: 2
        case .spare: 1
        default: 0
        }
        guard bonusRolls.count >= bonusCount else { return nil }
        return pins + bonusRolls.prefix(bonusCount).map(\.scoredCount).reduce(0, +)
    }
}

extension RollRecord {
    /// A foul scores 0 whatever `pinCount` says.
    var scoredCount: Int { isFoul ? 0 : pinCount }
}
