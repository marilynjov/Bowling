/// One violation found by `Scorer.validate`.
public enum ScoringError: Sendable, Hashable, Error {
    /// A pin count outside 0 through the pins standing.
    case pinsExceedAvailable(frameIndex: Int, rollIndex: Int)
    /// A pinByPin roll knocked down a pin that was not standing.
    case notSubsetOfStanding(frameIndex: Int, rollIndex: Int)
    /// Frames or rolls out of order, an index out of range or skipped, rolls after an
    /// unfinished frame, or a roll after a spare or open in frames 1 through 9.
    case outOfOrder(frameIndex: Int)
    /// `rollIndex` nil means a duplicate frame.
    case duplicateIndex(frameIndex: Int, rollIndex: Int?)
    /// A frame 10 third roll without a strike or spare in the first two.
    case unearnedThirdRoll
    /// Frames 1 through 9.
    case rollAfterStrike(frameIndex: Int)
    case foulWithPins(frameIndex: Int, rollIndex: Int)
    /// finalOnly scores are 0 through 300.
    case finalScoreOutOfRange
}
