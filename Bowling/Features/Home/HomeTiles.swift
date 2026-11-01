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
    /// Tiles for `cards` in order, skipping cards that aren't tile-shaped (charts, tables).
    /// `allGames` non-nil means `scoped` is the competition report, so the Average's
    /// sample line also gives the all-games average.
    static func make(cards: [StatsCardID], scoped: StatsReport, allGames: StatsReport?) -> [HomeTile] {
        cards.compactMap { tile($0, scoped, allGames) }
    }

    private static func tile(_ card: StatsCardID, _ report: StatsReport, _ allGames: StatsReport?) -> HomeTile? {
        guard var content = StatTileContent.make(card, report) else { return nil }
        if card == .average, let allGames {
            content.sample = (content.sample ?? "") + " · " + String(localized: "All games \(StatFormat.average(allGames.average))")
        }
        return HomeTile(card: card, title: content.title, value: content.value,
                        sample: content.sample, progress: content.progress)
    }
}
