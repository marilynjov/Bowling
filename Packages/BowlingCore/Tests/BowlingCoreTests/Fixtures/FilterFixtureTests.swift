import Foundation
import Testing
import BowlingCore
import BowlingFixtures

/// Shape of the 1b filter fixture: scores match their scoresheets and the tags are where
/// the filter tests expect them.
@Suite struct FilterFixtureTests {
    private let games = FilterFixture.games(relativeTo: DemoFixture.referenceDate)

    private func record(_ game: FilterGame) throws -> GameRecord {
        try #require(games.first { $0.id == game.id })
    }

    @Test func everyFilterGameAppearsOnceInOrder() {
        #expect(games.map(\.id) == FilterGame.allCases.map(\.id))
        #expect(Set(games.map(\.id)).isDisjoint(with: DemoGame.allCases.map(\.id)))
    }

    @Test(arguments: [
        // Frames 1-9 "9-": 9 * 9 = 81; frame 10 "8/9": 8 + 2 + 9 = 19; 81 + 19 = 100.
        (FilterGame.tuesdayRecent1, 100),
        // Ten "9-" frames: 10 * 9 = 90.
        (.tuesdayRecent2, 90), (.tuesdayRecentPartner, 90), (.tuesdayOpening1, 90),
        (.sundayDoubles1, 90), (.tournament1, 90),
    ])
    func scoresMatchScoresheets(game: FilterGame, score: Int) throws {
        let record = try record(game)
        #expect(record.finalScore == score)
        #expect(Scorer.scorecard(for: record).frames.last?.runningTotal == score)
        #expect(Scorer.validate(record).isEmpty)
    }

    @Test func ballOverridesAreOnTheMarkedRolls() throws {
        let spare = DemoBall.ownerSpare.id
        let recent = try record(.tuesdayRecent1)
        #expect(recent.defaultBallID == DemoBall.ownerStrike.id)
        #expect(recent.frames.flatMap(\.rolls).filter { $0.ballID == spare }.count == 1)
        #expect(recent.frames[9].rolls[1].ballID == spare)

        let doubles = try record(.sundayDoubles1)
        #expect(doubles.defaultBallID == nil)
        #expect(doubles.frames[0].rolls[1].ballID == spare)
        #expect(doubles.frames.flatMap(\.rolls).compactMap(\.ballID) == [spare])
    }

    @Test func sessionTagsAreCopiedOntoGames() throws {
        let recent = try record(.tuesdayRecent1)
        #expect(recent.centerID == FilterCenter.northLanes.id)
        #expect(recent.leagueID == FilterLeague.tuesdayMixed.id)
        #expect(recent.oilPatternID == FilterPattern.houseShot.id)
        let practice = try record(.practice1)
        #expect(practice.centerID == nil && practice.leagueID == nil && practice.oilPatternID == nil)
    }
}
