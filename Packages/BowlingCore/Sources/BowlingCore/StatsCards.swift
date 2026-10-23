// Raw values are persisted in `Bowler.statsLayout` and `homeLayout` and synced, so they
// never change; new cards add new cases. Case order is the catalog order (spec section 7),
// which the competitive preset relies on.

public enum StatsCardID: String, Sendable, Hashable, Codable, CaseIterable {
    // Overview (1a)
    case average, highGame, highSeries
    // Trend (1a)
    case trendChart
    // Strikes and spares (1a)
    case strikePct, sparePct, fouls
    // Strikes and spares (1b)
    case openPct, cleanGamePct, firstBallAverage, headPinRate
    // Leaves (1a)
    case leavesTable, leftMostMadeLeast, splitConversion, makeableConversion, singlePinConversion
    // By frame (1b)
    case byFrameStrike, byFrameAverage
    // What if (1b)
    case whatIfSinglePins

    public var group: StatsCardGroup {
        switch self {
        case .average, .highGame, .highSeries: .overview
        case .trendChart: .trend
        case .strikePct, .sparePct, .fouls, .openPct, .cleanGamePct, .firstBallAverage, .headPinRate:
            .strikesAndSpares
        case .leavesTable, .leftMostMadeLeast, .splitConversion, .makeableConversion, .singlePinConversion:
            .leaves
        case .byFrameStrike, .byFrameAverage: .byFrame
        case .whatIfSinglePins: .whatIf
        }
    }

    /// False for a card whose sub-phase has not shipped; presets and layouts leave it out.
    /// Every Phase 1 card is available since 1b: StatsReport fills each one's numbers.
    public var isAvailable: Bool { true }
}

public enum StatsCardGroup: String, Sendable, Hashable, Codable, CaseIterable {
    case overview, trend, strikesAndSpares, leaves, byFrame, whatIf
}
