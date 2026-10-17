import Foundation
import Testing
import BowlingCore
import BowlingFixtures

/// §6 "Leave occurrences" against the hand-computed lists in
/// DemoFixtureExpectedOccurrences.swift and the 1a leaves tables in
/// DemoFixtureExpectedReports.swift.
@Suite struct LeaveOccurrenceTests {
    private static let games = DemoFixture.games(relativeTo: DemoFixture.referenceDate)

    /// What the repository would pass: the bowler's games in the scope's event types,
    /// incomplete ones included, in reverse so the engine cannot rely on input order.
    private func scoped(_ report: ExpectedReport) -> [GameRecord] {
        Self.games.filter {
            $0.bowlerID == report.bowler.id && report.eventTypes.contains($0.eventType)
        }.reversed()
    }

    private func leave(named name: String) -> Leave {
        LeaveClassifier.classify(PinSet(pins: name.split(separator: "-").map { Int($0)! }))
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func occurrenceCountsMatchTheLeavesTable(_ report: ExpectedReport) {
        let games = scoped(report)
        for (name, row) in report.leaves {
            let occurrences = StatsEngine.leaveOccurrences(of: leave(named: name), games: games)
            #expect(occurrences.count == row.count, "\(name)")
            #expect(occurrences.filter(\.isConverted).count == row.converted, "\(name)")
        }
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func occurrenceCountsMatchTheEnginesLeaveRows(_ report: ExpectedReport) {
        let games = scoped(report)
        let filter = StatsFilter(datePreset: .allTime, eventTypes: report.eventTypes,
                                 bowlerID: report.bowler.id)
        for row in StatsEngine.report(games: games, filter: filter).leaves {
            let occurrences = StatsEngine.leaveOccurrences(of: row.leave, games: games)
            #expect(Rate(hits: occurrences.filter(\.isConverted).count, attempts: occurrences.count)
                    == row.conversion, "\(row.leave.name)")
        }
    }

    @Test(arguments: DemoFixtureExpected.occurrences)
    func occurrencesCarryGameSessionFrameAndBall(_ expected: ExpectedOccurrences) {
        let leave = LeaveClassifier.classify(PinSet(pins: expected.pins))
        let occurrences = StatsEngine.leaveOccurrences(of: leave, games: scoped(expected.report))
        let wanted = expected.occurrences.map { occurrence in
            let game = Self.games.first { $0.id == occurrence.game.id }!
            return LeaveOccurrence(
                game: GameRef(gameID: occurrence.game.id, sessionID: occurrence.game.session.id,
                              date: game.sessionDate),
                gameIndex: game.gameIndex, frameIndex: occurrence.frameIndex,
                ballID: occurrence.ball?.id, isConverted: occurrence.converted
            )
        }
        #expect(occurrences == wanted)
    }

    // §6 applicability: countOnly games know no pins, so tournament2's and the partner's
    // spare attempts never list as occurrences of any leave.
    @Test func countOnlyGamesHaveNoOccurrences() {
        let countOnly = Self.games.filter { $0.entryMode == .countOnly }
        for pins in [[10], [7], [1, 2, 4, 10]] {
            #expect(StatsEngine.leaveOccurrences(of: LeaveClassifier.classify(PinSet(pins: pins)),
                                                 games: countOnly).isEmpty)
        }
    }

    // §5: a first-ball foul respots the rack, so leagueNight1 F5 "F /" is no occurrence
    // of a full rack.
    @Test func aFirstBallFoulIsNoOccurrence() {
        let game = Self.games.filter { $0.id == DemoGame.leagueNight1.id }
        #expect(StatsEngine.leaveOccurrences(of: LeaveClassifier.classify(.all), games: game).isEmpty)
    }
}
