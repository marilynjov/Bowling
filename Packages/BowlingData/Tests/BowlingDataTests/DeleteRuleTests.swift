import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// One test per row of the delete-rule table in the phase 1 spec, section 3.3.
@Suite struct DeleteRuleTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try BowlingStore.makeContainer(inMemory: true)
        context = ModelContext(container)
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    private func deleteAndSave(_ model: some PersistentModel) throws {
        context.delete(model)
        try context.save()
    }

    // MARK: Cascade

    @Test func deletingSessionCascadesToGames() throws {
        let session = Session(date: .now)
        let game = Game(gameIndex: 1)
        context.insert(session)
        game.session = session
        try context.save()

        try deleteAndSave(session)
        #expect(try count(Game.self) == 0)
    }

    @Test func deletingGameCascadesToFrames() throws {
        let game = Game(gameIndex: 1)
        let frame = Frame(frameIndex: 1)
        context.insert(game)
        frame.game = game
        try context.save()

        try deleteAndSave(game)
        #expect(try count(Frame.self) == 0)
    }

    @Test func deletingFrameCascadesToRolls() throws {
        let frame = Frame(frameIndex: 1)
        let roll = Roll(rollIndex: 1)
        context.insert(frame)
        roll.frame = frame
        try context.save()

        try deleteAndSave(frame)
        #expect(try count(Roll.self) == 0)
    }

    @Test func deletingGameCascadesThroughFramesToRolls() throws {
        let session = Session(date: .now)
        let game = Game(gameIndex: 1)
        let frame = Frame(frameIndex: 1)
        let roll = Roll(rollIndex: 1)
        context.insert(session)
        game.session = session
        frame.game = game
        roll.frame = frame
        try context.save()

        try deleteAndSave(session)
        #expect(try count(Game.self) == 0)
        #expect(try count(Frame.self) == 0)
        #expect(try count(Roll.self) == 0)
    }

    @Test func deletingGameCascadesToPhoto() throws {
        let game = Game(gameIndex: 1)
        let photo = GamePhoto(imageData: Data([1, 2, 3]))
        context.insert(game)
        photo.game = game
        try context.save()

        try deleteAndSave(game)
        #expect(try count(GamePhoto.self) == 0)
    }

    @Test func deletingBallCascadesToPhoto() throws {
        let ball = Ball(name: "Phaze", weightPounds: 15)
        let photo = BallPhoto(imageData: Data([1, 2, 3]))
        context.insert(ball)
        photo.ball = ball
        try context.save()

        try deleteAndSave(ball)
        #expect(try count(BallPhoto.self) == 0)
    }

    @Test func deletingBallCascadesToMaintenance() throws {
        let ball = Ball(name: "Phaze", weightPounds: 15)
        let event = MaintenanceEvent(date: .now, kind: .resurface)
        context.insert(ball)
        event.ball = ball
        try context.save()

        try deleteAndSave(ball)
        #expect(try count(MaintenanceEvent.self) == 0)
    }

    // MARK: Nullify

    @Test func deletingBallNullifiesGamesDefaultBall() throws {
        let ball = Ball(name: "Phaze", weightPounds: 15)
        let game = Game(gameIndex: 1)
        context.insert(ball)
        game.defaultBall = ball
        try context.save()

        try deleteAndSave(ball)
        #expect(try count(Game.self) == 1)
        #expect(game.defaultBall == nil)
    }

    @Test func deletingBallNullifiesRollOverride() throws {
        let ball = Ball(name: "Spare", weightPounds: 14)
        let roll = Roll(rollIndex: 2)
        context.insert(ball)
        roll.ball = ball
        try context.save()

        try deleteAndSave(ball)
        #expect(try count(Roll.self) == 1)
        #expect(roll.ball == nil)
    }

    @Test func deletingBowlerNullifiesGames() throws {
        let bowler = Bowler(name: "Sam")
        let game = Game(gameIndex: 1)
        context.insert(bowler)
        game.bowler = bowler
        try context.save()

        try deleteAndSave(bowler)
        #expect(try count(Game.self) == 1)
        #expect(game.bowler == nil)
    }

    @Test func deletingCenterNullifiesSessions() throws {
        let center = BowlingCenter(name: "Lanes")
        let session = Session(date: .now)
        context.insert(center)
        session.center = center
        try context.save()

        try deleteAndSave(center)
        #expect(try count(Session.self) == 1)
        #expect(session.center == nil)
    }

    @Test func deletingCenterNullifiesLeagues() throws {
        let center = BowlingCenter(name: "Lanes")
        let league = League(name: "Tuesday")
        context.insert(center)
        league.center = center
        try context.save()

        try deleteAndSave(center)
        #expect(try count(League.self) == 1)
        #expect(league.center == nil)
    }

    @Test func deletingLeagueNullifiesSessions() throws {
        let league = League(name: "Tuesday")
        let session = Session(date: .now, eventType: .league)
        context.insert(league)
        session.league = league
        try context.save()

        try deleteAndSave(league)
        #expect(try count(Session.self) == 1)
        #expect(session.league == nil)
    }

    @Test func deletingOilPatternNullifiesSessions() throws {
        let pattern = OilPattern(name: "House")
        let session = Session(date: .now)
        context.insert(pattern)
        session.oilPattern = pattern
        try context.save()

        try deleteAndSave(pattern)
        #expect(try count(Session.self) == 1)
        #expect(session.oilPattern == nil)
    }

    // MARK: Child side

    @Test func deletingGameLeavesSessionBowlerAndBall() throws {
        let session = Session(date: .now)
        let bowler = Bowler(name: "Sam")
        let ball = Ball(name: "Phaze", weightPounds: 15)
        let game = Game(gameIndex: 1)
        context.insert(game)
        game.session = session
        game.bowler = bowler
        game.defaultBall = ball
        try context.save()

        try deleteAndSave(game)
        #expect(try count(Session.self) == 1)
        #expect(try count(Bowler.self) == 1)
        #expect(try count(Ball.self) == 1)
        #expect(session.games?.isEmpty ?? true)
    }
}
