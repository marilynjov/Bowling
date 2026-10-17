import Foundation

/// One frame number of the by-frame cards (spec §6 "By frame number"), over rollGames.
public struct FrameStats: Sendable, Hashable, Codable {
    /// 1...10.
    public var frameIndex: Int
    /// Strikes on roll 1 over games.
    public var strikes: Rate
    /// Pins of the frame's own rolls per game, bonuses excluded. Frame 10 includes its fill
    /// balls; a foul counts 0.
    public var pins: Mean

    public init(frameIndex: Int, strikes: Rate, pins: Mean) {
        self.frameIndex = frameIndex
        self.strikes = strikes
        self.pins = pins
    }

    /// Ten rows with empty samples, for a report with no rollGames.
    static let none = (1...10).map {
        FrameStats(frameIndex: $0, strikes: Rate(hits: 0, attempts: 0), pins: Mean(total: 0, count: 0))
    }
}

/// §6 "What if I made every single-pin spare", over pinGames.
public struct WhatIfSinglePins: Sendable, Hashable, Codable {
    /// The real average.
    public var actual: Mean
    /// The same games rescored with every missed single-pin leave converted. A frame 10
    /// spare made this way gets a fill ball of 0, so the gain is the spares' own.
    public var allMade: Mean
    /// Missed single-pin leaves rewritten as spares.
    public var rewritten: Int

    public init(actual: Mean, allMade: Mean, rewritten: Int) {
        self.actual = actual
        self.allMade = allMade
        self.rewritten = rewritten
    }

    /// Pins per game gained; nil with no games.
    public var difference: Double? {
        guard let made = allMade.value, let real = actual.value else { return nil }
        return made - real
    }

    static let none = WhatIfSinglePins(actual: Mean(total: 0, count: 0), allMade: Mean(total: 0, count: 0),
                                       rewritten: 0)
}
