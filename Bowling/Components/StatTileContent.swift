import BowlingCore
import Foundation

/// One single-number stat's text, ready for `StatTile(title:value:sample:progress:)`.
/// Home and Stats both build their tiles here, so a number reads the same on both.
struct StatTileContent: Hashable {
    var title: String
    var value: String
    var sample: String?
    /// 0...1 for rates; nil for means and scores.
    var progress: Double?

    /// The single-number tile for `card`, or nil for charts, tables and 1b-later cards.
    static func make(_ card: StatsCardID, _ report: StatsReport) -> StatTileContent? {
        let games = StatFormat.sample(report.scoreGames, .games)
        switch card {
        case .average:
            return mean(String(localized: "Average"), report.average, .games)
        case .highGame:
            return StatTileContent(title: String(localized: "High game"),
                                   value: report.highGame.map { "\($0.score)" } ?? "–", sample: games)
        case .highSeries:
            // TODO: once #91's `LeagueRecord.gamesPerSession` lands, use the league's length
            // for a league bowler instead of a fixed 3-game series.
            return StatTileContent(title: String(localized: "High series"),
                                   value: threeGameSeries(report).map { "\($0.total)" } ?? "–", sample: games)
        case .strikePct:
            return rate(String(localized: "Strike %"), report.strikes, .frames)
        case .sparePct:
            return rate(String(localized: "Spare %"), report.spares, .chances)
        case .fouls:
            return mean(String(localized: "Fouls"), report.fouls, .games)
        case .openPct:
            return rate(String(localized: "Open %"), report.openFrames, .frames)
        case .cleanGamePct:
            return rate(String(localized: "Clean games %"), report.cleanGames, .games)
        case .firstBallAverage:
            return mean(String(localized: "First-ball average"), report.firstBallAverage, .firstBalls)
        case .headPinRate:
            return rate(String(localized: "Head pin %"), report.headPin, .firstBalls)
        case .splitConversion:
            return rate(String(localized: "Split conversion %"), report.splitConversion, .leaves)
        case .makeableConversion:
            return rate(String(localized: "Makeable conversion %"), report.makeableConversion, .leaves)
        case .singlePinConversion:
            return rate(String(localized: "Single-pin conversion %"), report.singlePinConversion, .leaves)
        case .trendChart, .leavesTable, .leftMostMadeLeast, .byFrameStrike, .byFrameAverage, .whatIfSinglePins:
            return nil
        }
    }

    /// The best 3-game series, the one the High series tile shows.
    static func threeGameSeries(_ report: StatsReport) -> HighSeries? {
        report.highSeries.first { $0.gameCount == 3 }
    }

    private static func rate(_ title: String, _ rate: Rate, _ unit: StatFormat.Unit) -> StatTileContent {
        StatTileContent(title: title, value: StatFormat.percent(rate),
                        sample: StatFormat.sample(rate.attempts, unit), progress: rate.value)
    }

    private static func mean(_ title: String, _ mean: Mean, _ unit: StatFormat.Unit) -> StatTileContent {
        StatTileContent(title: title, value: StatFormat.average(mean), sample: StatFormat.sample(mean.count, unit))
    }
}
