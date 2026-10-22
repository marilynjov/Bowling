import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct HomeTilesTests {
    let bowler = BowlerID()

    /// Complete final-only games, one session per call so series group by it.
    func games(_ scores: [Int], _ type: EventType = .league, session: SessionID = SessionID()) -> [GameRecord] {
        scores.enumerated().map { index, score in
            GameRecord(
                bowlerID: bowler, gameIndex: index + 1, entryMode: .finalOnly, finalScore: score,
                isComplete: true, sessionID: session, sessionDate: .now, eventType: type
            )
        }
    }

    func report(_ games: [GameRecord]) -> StatsReport {
        StatsEngine.report(games: games, filter: StatsFilter(bowlerID: bowler))
    }

    func tile(_ card: StatsCardID, in tiles: [HomeTile]) throws -> HomeTile {
        try #require(tiles.first { $0.card == card })
    }

    @Test func scopeFollowsSavedChoiceThenStyle() {
        #expect(HomeTiles.prefersCompetition(scope: .competition, profile: .casual))
        #expect(!HomeTiles.prefersCompetition(scope: .all, profile: .league))
        #expect(HomeTiles.prefersCompetition(scope: nil, profile: .league))
        #expect(!HomeTiles.prefersCompetition(scope: nil, profile: .casual))
        #expect(HomeTiles.prefersCompetition(scope: .unknown, profile: .competitive))
    }

    @Test func tilesKeepTheGivenOrder() {
        let tiles = HomeTiles.make(cards: StatsPreset.homeTiles(for: .league), scoped: report([]), allGames: nil)
        #expect(tiles.map(\.card) == [.average, .highGame, .highSeries, .strikePct, .sparePct])
        #expect(tiles.map(\.title) == ["Average", "High game", "High series", "Strike %", "Spare %"])
    }

    @Test func nonTileCardsAreSkipped() {
        let tiles = HomeTiles.make(cards: [.trendChart, .average, .leavesTable, .fouls], scoped: report([]), allGames: nil)
        #expect(tiles.map(\.card) == [.average, .fouls])
    }

    @Test func averageWithAllGamesLine() throws {
        let competition = games([200, 180])
        let all = competition + games([100], .casual)
        let tiles = HomeTiles.make(cards: [.average], scoped: report(competition), allGames: report(all))
        let average = try tile(.average, in: tiles)
        #expect(average.value == "190")
        #expect(average.sample == "2 games · All games 160")
    }

    @Test func averageAlone() throws {
        let tiles = HomeTiles.make(cards: [.average], scoped: report(games([200, 180])), allGames: nil)
        #expect(try tile(.average, in: tiles).sample == "2 games")
    }

    @Test func emptyTiles() {
        let tiles = HomeTiles.make(cards: StatsPreset.homeTiles(for: .competitive) + [.fouls], scoped: report([]), allGames: nil)
        #expect(tiles.map(\.value) == Array(repeating: "–", count: 6))
        #expect(tiles.map(\.sample) == [
            "No games yet", "No games yet", "No games yet", "No frames yet", "No chances yet", "No games yet",
        ])
    }

    @Test func highSeriesIsTheThreeGameSeries() throws {
        let three = HomeTiles.make(cards: [.highSeries], scoped: report(games([200, 210, 220])), allGames: nil)
        #expect(try tile(.highSeries, in: three).value == "630")
        let two = HomeTiles.make(cards: [.highSeries], scoped: report(games([200, 210])), allGames: nil)
        #expect(try tile(.highSeries, in: two).value == "–")
    }

    @Test func highGameShowsScoreAndCount() throws {
        let tiles = HomeTiles.make(cards: [.highGame], scoped: report(games([200, 245])), allGames: nil)
        let high = try tile(.highGame, in: tiles)
        #expect(high.value == "245")
        #expect(high.sample == "2 games")
    }
}
