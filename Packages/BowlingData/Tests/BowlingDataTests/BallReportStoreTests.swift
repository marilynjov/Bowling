import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// The ball detail's data path end to end: MixedBallFixture stored, read back through
/// `StatsRepository` and `BallRepository.maintenance(for:)`, then `StatsEngine.ballReport`.
/// The numbers are derived in BowlingCoreTests' MixedBallExpected.swift.
@MainActor @Suite struct BallReportStoreTests {
    let store: BowlingStore
    let now = DemoFixture.referenceDate
    let strikeBall = DemoBall.ownerStrike.id

    init() throws {
        store = try BowlingStore(inMemory: true)
        let context = store.context
        for game in MixedBallFixture.games(relativeTo: now) {
            _ = try insertGame(game, into: context)
        }
        for fixture in MixedBallCenter.allCases {
            let center = BowlingCenter(name: "Center \(fixture.rawValue)")
            center.id = fixture.id
            context.insert(center)
        }
        for fixture in MixedBallPattern.allCases {
            let pattern = OilPattern(name: "Pattern \(fixture.rawValue)")
            pattern.id = fixture.id
            context.insert(pattern)
        }
        for fixture in MixedBallSession.allCases {
            let session = try context.session(fixture.id)
            session.center = try fixture.center.map { try context.center($0.id) }
            session.oilPattern = try fixture.oilPattern.map { try context.oilPattern($0.id) }
        }
        try context.ball(strikeBall).resurfaceIntervalGames = MixedBallFixture.strikeBallResurfaceInterval
        try context.save()
        for event in MixedBallFixture.strikeBallMaintenance(relativeTo: now) {
            _ = try store.balls.logMaintenance(event.kind, date: event.date, surfaceGritAfter: event.surfaceGritAfter,
                                               notes: event.notes, for: strikeBall)
        }
    }

    @Test func recordsCarryTheSessionCenterAndPattern() throws {
        let league1 = try store.games.game(MixedBallGame.league1.id)
        #expect(league1.centerID == MixedBallCenter.home.id)
        #expect(league1.oilPatternID == MixedBallPattern.house.id)
        let casual1 = try store.games.game(MixedBallGame.casual1.id)
        #expect(casual1.centerID == MixedBallCenter.home.id)
        #expect(casual1.oilPatternID == nil)
    }

    @Test func ballReportFromTheStore() throws {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id)
        let games = store.stats.games(matching: filter, now: now, calendar: Calendar(identifier: .gregorian))
        let maintenance = try store.balls.maintenance(for: strikeBall)
        let report = StatsEngine.ballReport(for: strikeBall, games: games, maintenance: maintenance)

        // Every game of the strike ball, the incomplete one included: 6. After the
        // resurface 15 days ago: practice1, practiceInProgress, casual1, casual2 = 4 >= 4.
        #expect(maintenance.gamesBowled == 6)
        #expect(maintenance.gamesSinceResurface == 4)
        #expect(maintenance.isResurfaceDue)
        // Logged after every game was stored, yet each snapshot matches the fixture: the
        // polish 8 days ago follows league1, league2, practice1, practiceInProgress = 4;
        // the resurface 15 days ago follows league1, league2 = 2. Newest first.
        #expect(maintenance.events.map(\.gamesOnBallAtTime)
            == MixedBallFixture.strikeBallMaintenance(relativeTo: now).reversed().map(\.gamesOnBallAtTime))
        #expect(maintenance.events.map(\.gamesOnBallAtTime) == [4, 2])
        // The polish's grit is the latest copied to the ball.
        #expect(try store.context.ball(strikeBall).surfaceGrit == "3000 polished")

        // Complete games only: 5, with 18 strikes on 41 first balls and 6 of 12 spares.
        #expect(report.gamesBowled == 5)
        #expect(report.strikes == Rate(hits: 18, attempts: 41))
        #expect(report.spares == Rate(hits: 6, attempts: 12))
        // house 23 first balls; sport 7 and no pattern 11 fold into Other.
        #expect(report.byOilPattern.map(\.id) == [MixedBallPattern.house.id, nil])
        // home 34 first balls; away 7 folds into Other.
        #expect(report.byCenter.map(\.id) == [MixedBallCenter.home.id, nil])
    }

    @Test func compareActiveBalls() {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id)
        let games = store.stats.games(matching: filter, now: now, calendar: Calendar(identifier: .gregorian))
        let rows = StatsEngine.compareBalls(store.balls.activeBalls().map(\.id), games: games)
        // Both fixture balls are named "Ball" by insertGame, so compare as a set.
        // Strike ball: 5 games, 909 over 5 as main ball. Spare ball: 4 games, 150 over 1.
        #expect(Set(rows.map(\.ballID)) == [DemoBall.ownerStrike.id, DemoBall.ownerSpare.id])
        #expect(rows.first { $0.ballID == DemoBall.ownerStrike.id }?.averageAsMainBall == Mean(total: 909, count: 5))
        #expect(rows.first { $0.ballID == DemoBall.ownerSpare.id }?.averageAsMainBall == Mean(total: 150, count: 1))
    }
}
