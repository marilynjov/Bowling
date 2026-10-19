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

    // OQ-7: an occurrence is its game plus frame. The owner's competition "10" has two in
    // leagueNight1 (F1 and F10), so the IDs differ by frame and all six are distinct.
    @Test func occurrenceIDIsGamePlusFrame() {
        let found = StatsEngine.leaveOccurrences(of: LeaveClassifier.classify(PinSet(pins: [10])),
                                                 games: scoped(DemoFixtureExpected.ownerCompetition))
        #expect(Set(found.map(\.id)).count == 6)
        #expect(found[1].id == LeaveOccurrence.ID(gameID: DemoGame.leagueNight1.id, frameIndex: 10))
    }

    /// A complete pinByPin game whose frame 1 leaves the 10 and converts it ("10 /").
    private func tenPinGame(session: SessionID, date: Date) -> GameRecord {
        GameRecord(gameIndex: 1, entryMode: .pinByPin, finalScore: 10, isComplete: true, frames: [
            FrameRecord(frameIndex: 1, rolls: [
                RollRecord(rollIndex: 1, pinsDown: PinSet(pins: 1...9), pinCount: 9, pinsKnown: true),
                RollRecord(rollIndex: 2, pinsDown: PinSet(pins: [10]), pinCount: 1, pinsKnown: true),
            ]),
        ], sessionID: session, sessionDate: date, eventType: .league)
    }

    // History orders sessions on the same date by newest created, which GameRecord does not
    // carry; the repository passes games oldest first, so a later session in `games` is the
    // newer one. The IDs are chosen so the session ID string order disagrees.
    @Test func sameDateSessionsFollowTheirOrderInGames() {
        let date = DemoFixture.referenceDate
        let older = tenPinGame(session: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000000")!, date: date)
        let newer = tenPinGame(session: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, date: date)
        let leave = LeaveClassifier.classify(PinSet(pins: [10]))
        #expect(StatsEngine.leaveOccurrences(of: leave, games: [older, newer]).map(\.game.gameID)
                == [newer.id, older.id])
        #expect(StatsEngine.leaveOccurrences(of: leave, games: [newer, older]).map(\.game.gameID)
                == [older.id, newer.id])
    }
}
