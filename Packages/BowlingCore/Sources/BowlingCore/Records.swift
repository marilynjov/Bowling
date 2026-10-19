import Foundation

public struct RollRecord: Sendable, Hashable, Codable {
    /// 1...3.
    public var rollIndex: Int
    /// Empty for countOnly rolls and fouls.
    public var pinsDown: PinSet
    /// Always set; 0 on a foul. Equals `pinsDown.count` when `pinsKnown`.
    public var pinCount: Int
    /// True in pinByPin.
    public var pinsKnown: Bool
    public var isFoul: Bool
    /// Per-roll override; nil means the game's default ball.
    public var ballID: BallID?

    public init(
        rollIndex: Int, pinsDown: PinSet = [], pinCount: Int,
        pinsKnown: Bool, isFoul: Bool = false, ballID: BallID? = nil
    ) {
        self.rollIndex = rollIndex
        self.pinsDown = pinsDown
        self.pinCount = pinCount
        self.pinsKnown = pinsKnown
        self.isFoul = isFoul
        self.ballID = ballID
    }
}

public struct FrameRecord: Sendable, Hashable, Codable {
    /// 1...10.
    public var frameIndex: Int
    /// Sorted by `rollIndex`, 0...3 elements.
    public var rolls: [RollRecord]

    public init(frameIndex: Int, rolls: [RollRecord]) {
        self.frameIndex = frameIndex
        self.rolls = rolls
    }
}

public struct GameRecord: Sendable, Hashable, Codable, Identifiable {
    public var id: GameID
    public var bowlerID: BowlerID?
    /// 1-based within the session for this bowler.
    public var gameIndex: Int
    public var entryMode: EntryMode
    public var defaultBallID: BallID?
    /// Cached; typed by the user for finalOnly.
    public var finalScore: Int
    /// All ten frames bowled, or a finalOnly game. Only complete games count toward stats.
    public var isComplete: Bool
    /// Sorted by `frameIndex`; empty for finalOnly.
    public var frames: [FrameRecord]

    // Session context, copied in by the repository because StatsEngine takes only
    // [GameRecord] yet needs dates, event types, and series grouping. Read-only to the app.
    public var sessionID: SessionID?
    public var sessionDate: Date
    public var eventType: EventType
    // 1b: session context for the filters and "By condition".
    public var centerID: CenterID?
    public var leagueID: LeagueID?
    public var oilPatternID: OilPatternID?

    public init(
        id: GameID = GameID(), bowlerID: BowlerID? = nil, gameIndex: Int,
        entryMode: EntryMode, defaultBallID: BallID? = nil, finalScore: Int,
        isComplete: Bool, frames: [FrameRecord] = [],
        sessionID: SessionID? = nil, sessionDate: Date, eventType: EventType,
        centerID: CenterID? = nil, leagueID: LeagueID? = nil, oilPatternID: OilPatternID? = nil
    ) {
        self.id = id
        self.bowlerID = bowlerID
        self.gameIndex = gameIndex
        self.entryMode = entryMode
        self.defaultBallID = defaultBallID
        self.finalScore = finalScore
        self.isComplete = isComplete
        self.frames = frames
        self.sessionID = sessionID
        self.sessionDate = sessionDate
        self.eventType = eventType
        self.centerID = centerID
        self.leagueID = leagueID
        self.oilPatternID = oilPatternID
    }
}

/// How one roll is drawn on the scorecard.
public enum Mark: Sendable, Hashable, Codable {
    case strike
    case spare
    /// 1...9.
    case count(Int)
    /// Zero on a roll where pins were available.
    case gutter
    /// Shown as F.
    case foul
}
