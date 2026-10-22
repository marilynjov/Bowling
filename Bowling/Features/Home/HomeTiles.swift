import BowlingCore
import Foundation

/// One Home tile's text, ready for `StatTile(title:value:sample:progress:)`.
struct HomeTile: Hashable, Identifiable {
    var card: StatsCardID
    var title: String
    var value: String
    var sample: String?
    /// 0...1 for rates; nil for means and scores.
    var progress: Double?
    var id: StatsCardID { card }
}

/// Turns stats reports into Home's tiles.
enum HomeTiles {
    /// The saved scope wins; nil or `.unknown` follows the bowling style, like Stats.
    static func prefersCompetition(scope: StatsScope?, profile: StatsProfile) -> Bool {
        switch scope {
        case .competition: true
        case .all: false
        case nil, .unknown: StatsPreset.prefersCompetition(profile)
        }
    }

    /// Tiles for `cards` in order, skipping cards that aren't tile-shaped (charts, tables).
    /// `allGames` non-nil means `scoped` is the competition report, so the Average's
    /// sample line also gives the all-games average.
    static func make(cards: [StatsCardID], scoped: StatsReport, allGames: StatsReport?) -> [HomeTile] {
        cards.compactMap { tile($0, scoped, allGames) }
    }

    private static func tile(_ card: StatsCardID, _ report: StatsReport, _ allGames: StatsReport?) -> HomeTile? {
        let games = StatFormat.sample(report.scoreGames, .games)
        switch card {
        case .average:
            var sample = StatFormat.sample(report.average.count, .games)
            if let allGames {
                sample += " · " + String(localized: "All games \(StatFormat.average(allGames.average))")
            }
            return HomeTile(card: card, title: String(localized: "Average"),
                            value: StatFormat.average(report.average), sample: sample)
        case .highGame:
            return HomeTile(card: card, title: String(localized: "High game"),
                            value: report.highGame.map { "\($0.score)" } ?? "–", sample: games)
        case .highSeries:
            // TODO: once #91's `LeagueRecord.gamesPerSession` lands, use the league's length
            // for a league bowler instead of a fixed 3-game series.
            let series = report.highSeries.first { $0.gameCount == 3 }
            return HomeTile(card: card, title: String(localized: "High series"),
                            value: series.map { "\($0.total)" } ?? "–", sample: games)
        case .strikePct:
            return rate(card, String(localized: "Strike %"), report.strikes, .frames)
        case .sparePct:
            return rate(card, String(localized: "Spare %"), report.spares, .chances)
        case .fouls:
            return HomeTile(card: card, title: String(localized: "Fouls"),
                            value: StatFormat.average(report.fouls),
                            sample: StatFormat.sample(report.fouls.count, .games))
        default:
            return nil
        }
    }

    private static func rate(_ card: StatsCardID, _ title: String, _ rate: Rate, _ unit: StatFormat.Unit) -> HomeTile {
        HomeTile(card: card, title: title, value: StatFormat.percent(rate),
                 sample: StatFormat.sample(rate.attempts, unit), progress: rate.value)
    }
}
