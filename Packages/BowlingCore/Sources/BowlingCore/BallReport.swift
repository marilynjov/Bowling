import Foundation

/// The ball detail screen's performance numbers (spec §6 "Ball report"). Every roll counts
/// for the ball it was thrown with: its override, else the game's default ball. Usage and
/// performance cover the complete games passed in, so they honor the stats filter;
/// `maintenance` covers every game the ball was used in.
public struct BallReport: Sendable, Hashable {
    public var ballID: BallID

    // Usage.
    /// Complete games with the ball as the default or on any roll.
    public var gamesBowled: Int
    public var firstBalls: Int
    /// Spare attempts whose second roll was thrown with the ball.
    public var spareAttempts: Int
    public var firstUsed: Date?
    public var lastUsed: Date?
    /// Games since last resurface, resurface due, and the log the over-time chart marks.
    public var maintenance: BallMaintenance

    // As a strike ball, over first balls thrown with it.
    public var strikes: Rate
    /// Pins on first balls; a foul counts as 0.
    public var firstBallAverage: Mean
    /// First balls where pin 1 fell, over pinByPin first balls that were not fouls.
    public var headPin: Rate
    /// "Games with this ball as main ball": final scores of games where it is the default.
    public var averageAsMainBall: Mean

    // As a spare ball, over spare attempts thrown with it.
    public var spares: Rate
    public var singlePinConversion: Rate
    public var splitConversion: Rate
    /// Most left first; equal counts by pin numbers ascending.
    public var leaves: [LeaveRow]

    // By condition, over first balls thrown with it.
    /// Patterns with at least 10 first balls, most first balls first, then "Other".
    public var byOilPattern: [ConditionRow]
    /// Centers with at least 10 first balls, most first balls first, then "Other".
    public var byCenter: [ConditionRow]

    /// Strike rate per session, oldest first; sessions without a first ball with the ball
    /// have no point.
    public var overTime: [BallTrendPoint]

    public init(
        ballID: BallID, gamesBowled: Int, firstBalls: Int, spareAttempts: Int,
        firstUsed: Date?, lastUsed: Date?, maintenance: BallMaintenance,
        strikes: Rate, firstBallAverage: Mean, headPin: Rate, averageAsMainBall: Mean,
        spares: Rate, singlePinConversion: Rate, splitConversion: Rate, leaves: [LeaveRow],
        byOilPattern: [ConditionRow], byCenter: [ConditionRow], overTime: [BallTrendPoint]
    ) {
        self.ballID = ballID
        self.gamesBowled = gamesBowled
        self.firstBalls = firstBalls
        self.spareAttempts = spareAttempts
        self.firstUsed = firstUsed
        self.lastUsed = lastUsed
        self.maintenance = maintenance
        self.strikes = strikes
        self.firstBallAverage = firstBallAverage
        self.headPin = headPin
        self.averageAsMainBall = averageAsMainBall
        self.spares = spares
        self.singlePinConversion = singlePinConversion
        self.splitConversion = splitConversion
        self.leaves = leaves
        self.byOilPattern = byOilPattern
        self.byCenter = byCenter
        self.overTime = overTime
    }
}

/// One oil pattern or center on the ball detail's "By condition" tables.
public struct ConditionRow: Sendable, Hashable, Codable {
    /// The pattern or center; nil is "Other": every group under 10 first balls, plus games
    /// with no pattern or center recorded.
    public var id: UUID?
    public var strikes: Rate
    public var firstBallAverage: Mean

    public init(id: UUID?, strikes: Rate, firstBallAverage: Mean) {
        self.id = id
        self.strikes = strikes
        self.firstBallAverage = firstBallAverage
    }
}

public struct BallTrendPoint: Sendable, Hashable, Codable {
    public var sessionID: SessionID?
    public var date: Date
    public var strikes: Rate

    public init(sessionID: SessionID?, date: Date, strikes: Rate) {
        self.sessionID = sessionID
        self.date = date
        self.strikes = strikes
    }
}

/// One row of the Arsenal's Compare table (§6 "Comparison"), each figure with its sample.
public struct BallComparisonRow: Sendable, Hashable, Codable {
    public var ballID: BallID
    public var gamesBowled: Int
    public var averageAsMainBall: Mean
    public var strikes: Rate
    public var firstBallAverage: Mean
    public var spares: Rate

    public init(
        ballID: BallID, gamesBowled: Int, averageAsMainBall: Mean, strikes: Rate,
        firstBallAverage: Mean, spares: Rate
    ) {
        self.ballID = ballID
        self.gamesBowled = gamesBowled
        self.averageAsMainBall = averageAsMainBall
        self.strikes = strikes
        self.firstBallAverage = firstBallAverage
        self.spares = spares
    }
}
