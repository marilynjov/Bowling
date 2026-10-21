#if DEBUG
import BowlingCore
import BowlingFixtures
import Foundation

/// Real values from the demo fixtures for component previews, so previews show what the
/// packages actually produce rather than hand-made marks.
enum PreviewData {
    static let games: [GameRecord] = DemoFixture.games(relativeTo: DemoFixture.referenceDate)

    static func game(_ game: DemoGame) -> GameRecord {
        games.first { $0.id == game.id }!
    }

    static func scorecard(_ game: DemoGame) -> Scorecard {
        Scorer.scorecard(for: self.game(game))
    }

    static let report: StatsReport = StatsEngine.report(
        games: games.filter { $0.bowlerID == DemoBowler.owner.id },
        filter: StatsFilter(bowlerID: DemoBowler.owner.id)
    )

    static func leave(_ pins: Int...) -> Leave {
        LeaveClassifier.classify(PinSet(pins: pins))
    }
}
#endif
