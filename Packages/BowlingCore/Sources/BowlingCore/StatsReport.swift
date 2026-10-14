import Foundation

/// A percentage with its denominator, so the UI can show "63% of 41 attempts" (spec §6).
public struct Rate: Sendable, Hashable, Codable {
    public var hits: Int
    public var attempts: Int

    public init(hits: Int, attempts: Int) {
        self.hits = hits
        self.attempts = attempts
    }

    /// Nil when there are no attempts, so zero games never show NaN (§8).
    public var value: Double? {
        attempts == 0 ? nil : Double(hits) / Double(attempts)
    }
}

/// An average with its sample size.
public struct Mean: Sendable, Hashable, Codable {
    public var total: Int
    public var count: Int

    public init(total: Int, count: Int) {
        self.total = total
        self.count = count
    }

    /// Nil when the sample is empty (§8).
    public var value: Double? {
        count == 0 ? nil : Double(total) / Double(count)
    }
}

public struct GameRef: Sendable, Hashable, Codable {
    public var gameID: GameID
    public var sessionID: SessionID?
    public var date: Date

    public init(gameID: GameID, sessionID: SessionID?, date: Date) {
        self.gameID = gameID
        self.sessionID = sessionID
        self.date = date
    }
}

public struct HighGame: Sendable, Hashable, Codable {
    public var score: Int
    public var game: GameRef

    public init(score: Int, game: GameRef) {
        self.score = score
        self.game = game
    }
}

public struct HighSeries: Sendable, Hashable, Codable {
    /// 3 is a three-game series.
    public var gameCount: Int
    public var total: Int
    public var sessionID: SessionID?
    public var date: Date

    public init(gameCount: Int, total: Int, sessionID: SessionID?, date: Date) {
        self.gameCount = gameCount
        self.total = total
        self.sessionID = sessionID
        self.date = date
    }
}

public struct TrendPoint: Sendable, Hashable, Codable {
    public var sessionID: SessionID?
    public var date: Date
    public var sessionAverage: Mean
    /// The last nine complete games up to the end of this session, or all of them when
    /// fewer exist.
    public var rollingAverage: Mean

    public init(sessionID: SessionID?, date: Date, sessionAverage: Mean, rollingAverage: Mean) {
        self.sessionID = sessionID
        self.date = date
        self.sessionAverage = sessionAverage
        self.rollingAverage = rollingAverage
    }
}

public struct LeaveRow: Sendable, Hashable, Codable {
    public var leave: Leave
    /// hits = converted, attempts = times the leave was left.
    public var conversion: Rate

    public init(leave: Leave, conversion: Rate) {
        self.leave = leave
        self.conversion = conversion
    }
}

/// Every 1a number on the Stats screen (spec §6 "Definitions (1a)"), each with its sample.
public struct StatsReport: Sendable, Hashable, Codable {
    public var filter: StatsFilter

    // Sample size per applicability group (§6 "Which games count for what").
    /// Complete games in every entry mode.
    public var scoreGames: Int
    /// Complete countOnly and pinByPin games.
    public var rollGames: Int
    /// Complete pinByPin games.
    public var pinGames: Int

    // Overview, over scoreGames.
    public var average: Mean
    public var averageLast10: Mean
    public var averageLast30: Mean
    public var highGame: HighGame?
    /// Best per game count, ascending game count.
    public var highSeries: [HighSeries]
    /// One point per session, ascending date.
    public var trend: [TrendPoint]

    // Strikes and spares, over rollGames.
    public var firstBalls: Int
    /// Strikes over first balls.
    public var strikes: Rate
    /// Spares over spare attempts: the only spare percentage shown.
    public var spares: Rate
    /// Fouls per game.
    public var fouls: Mean

    // Leaves, over pinGames.
    /// Split leaves over spare attempts.
    public var splitRate: Rate
    public var splitConversion: Rate
    /// Makeable and single-pin leaves together.
    public var makeableConversion: Rate
    public var singlePinConversion: Rate
    /// Most left first; equal counts by pin numbers ascending.
    public var leaves: [LeaveRow]
    /// The leave with the most misses (count times miss rate) among leaves seen at least 3
    /// times; nil when none of them was missed.
    public var leftMostMadeLeast: LeaveRow?

    public init(
        filter: StatsFilter, scoreGames: Int, rollGames: Int, pinGames: Int,
        average: Mean, averageLast10: Mean, averageLast30: Mean, highGame: HighGame?,
        highSeries: [HighSeries], trend: [TrendPoint],
        firstBalls: Int, strikes: Rate, spares: Rate, fouls: Mean,
        splitRate: Rate, splitConversion: Rate, makeableConversion: Rate,
        singlePinConversion: Rate, leaves: [LeaveRow], leftMostMadeLeast: LeaveRow?
    ) {
        self.filter = filter
        self.scoreGames = scoreGames
        self.rollGames = rollGames
        self.pinGames = pinGames
        self.average = average
        self.averageLast10 = averageLast10
        self.averageLast30 = averageLast30
        self.highGame = highGame
        self.highSeries = highSeries
        self.trend = trend
        self.firstBalls = firstBalls
        self.strikes = strikes
        self.spares = spares
        self.fouls = fouls
        self.splitRate = splitRate
        self.splitConversion = splitConversion
        self.makeableConversion = makeableConversion
        self.singlePinConversion = singlePinConversion
        self.leaves = leaves
        self.leftMostMadeLeast = leftMostMadeLeast
    }
}
