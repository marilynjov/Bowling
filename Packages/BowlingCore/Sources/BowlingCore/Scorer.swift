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
