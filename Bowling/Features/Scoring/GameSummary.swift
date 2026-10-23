import BowlingCore
import BowlingData
import Foundation

/// One bowler's card on the game summary: score, strikes, spares and opens, leaves, and the
/// series so far (spec §3).
struct GameSummary: Hashable, Identifiable {
    struct Counts: Hashable {
        var strikes: Int
        var spares: Int
        var opens: Int
    }

    enum Leaves: Hashable {
        /// Every frame's leave, in frame order (pin by pin).
        case diagrams([Leave])
        /// A count game: "Enter pins to see leaves".
        case enterPins
        /// Pin by pin with no leaves: "No leaves".
        case none
        /// Final score: no leaves line.
        case hidden
    }

    let id: BowlerID
    let name: String
    let score: Int
    /// From `StatsEngine`, so they match Stats; nil for final score.
    let counts: Counts?
    let leaves: Leaves
    /// The bowler's games up to this one; nil for game 1.
    let series: Int?

    /// Nil when the bowler has no game `gameIndex`.
    init?(_ bowler: SessionBowler, gameIndex: Int) {
        guard let game = bowler.games.first(where: { $0.gameIndex == gameIndex }) else { return nil }
        id = bowler.bowler.id
        name = bowler.bowler.name
        score = Self.score(game)
        switch game.entryMode {
        case .finalOnly:
            counts = nil
            leaves = .hidden
        case .countOnly:
            counts = Self.counts(game, bowler: id)
            leaves = .enterPins
        default:
            counts = Self.counts(game, bowler: id)
            let found = Scorer.scorecard(for: game).frames.compactMap(\.leave)
            leaves = found.isEmpty ? .none : .diagrams(found)
        }
        series = gameIndex == 1 ? nil : bowler.games.filter { $0.gameIndex <= gameIndex }.map(Self.score).reduce(0, +)
    }

    /// "6 strikes · 3 spares · 1 open".
    var countsText: String? {
        guard let counts else { return nil }
        let strikes = counts.strikes == 1 ? String(localized: "1 strike") : String(localized: "\(counts.strikes) strikes")
        let spares = counts.spares == 1 ? String(localized: "1 spare") : String(localized: "\(counts.spares) spares")
        return String(localized: "\(strikes) · \(spares) · \(counts.opens) open")
    }

    /// "Series 388".
    var seriesText: String? {
        series.map { String(localized: "Series \($0)") }
    }

    private static func score(_ game: GameRecord) -> Int {
        Scorer.scorecard(for: game).finalScore ?? game.finalScore
    }

    private static func counts(_ game: GameRecord, bowler: BowlerID) -> Counts {
        let report = StatsEngine.report(games: [game], filter: StatsFilter(bowlerID: bowler))
        return Counts(strikes: report.strikes.hits, spares: report.spares.hits, opens: report.openFrames.hits)
    }
}
