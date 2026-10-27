import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BallRepositoryTests {
    let store: BowlingStore
    var balls: BallRepository { store.balls }

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    @Test func addBallStoresTheArsenalFields() throws {
        let ball = try balls.addBall(name: "Phaze II", weightPounds: 15, intendedRole: .strike, brand: "Storm")
        #expect(ball.name == "Phaze II")
        #expect(ball.brand == "Storm")
        #expect(ball.weightPounds == 15)
        #expect(ball.intendedRole == .strike)
        #expect(ball.gamesBowled == 0)
        #expect(balls.activeBalls() == [ball])
    }

    @Test(arguments: [6, 16])
    func weightLimitsAreAccepted(_ weight: Int) throws {
        _ = try balls.addBall(name: "Ball", weightPounds: weight, intendedRole: .spare, brand: "")
        #expect(balls.activeBalls().count == 1)
    }

    @Test(arguments: [0, 5, 17])
    func weightOutsideSixToSixteenIsRefused(_ weight: Int) {
        #expect(throws: RepositoryError.invalidBall(.weightOutOfRange)) {
            try balls.addBall(name: "Ball", weightPounds: weight, intendedRole: .strike, brand: "")
        }
        #expect(balls.activeBalls().isEmpty)
    }

    @Test(arguments: ["", "   "])
    func blankNameIsRefused(_ name: String) {
        #expect(throws: RepositoryError.invalidBall(.emptyName)) {
            try balls.addBall(name: name, weightPounds: 15, intendedRole: .strike, brand: "")
        }
        #expect(balls.activeBalls().isEmpty)
    }

    @Test func nameIsTrimmed() throws {
        let ball = try balls.addBall(name: "  Hy-Road ", weightPounds: 15, intendedRole: .strike, brand: "")
        #expect(ball.name == "Hy-Road")
    }

    @Test func activeBallsSkipRetiredAndSortByName() throws {
        _ = try balls.addBall(name: "spare plastic", weightPounds: 14, intendedRole: .spare, brand: "")
        _ = try balls.addBall(name: "Hy-Road", weightPounds: 15, intendedRole: .strike, brand: "")
        let retired = Ball(name: "Old Ball", weightPounds: 15)
        retired.isRetired = true
        store.context.insert(retired)

        #expect(balls.activeBalls().map(\.name) == ["Hy-Road", "spare plastic"])
    }

    @Test func gamesBowledCountsDefaultAndOverrideGamesOnce() throws {
        let summary = try balls.addBall(name: "Spare", weightPounds: 14, intendedRole: .spare, brand: "")
        let ball = try store.context.ball(summary.id)
        let context = store.context

        let asDefault = Game(gameIndex: 1)
        context.insert(asDefault)
        asDefault.defaultBall = ball
        let overrideFrame = Frame(frameIndex: 1)
        context.insert(overrideFrame)
        overrideFrame.game = asDefault
        let overrideInSameGame = Roll(rollIndex: 2)
        context.insert(overrideInSameGame)
        overrideInSameGame.frame = overrideFrame
        overrideInSameGame.ball = ball

        let overrideOnly = Game(gameIndex: 2)
        context.insert(overrideOnly)
        for frameIndex in 1...2 {
            let frame = Frame(frameIndex: frameIndex)
            context.insert(frame)
            frame.game = overrideOnly
            let roll = Roll(rollIndex: 2)
            context.insert(roll)
            roll.frame = frame
            roll.ball = ball
        }
        try context.save()

        #expect(balls.activeBalls().first?.gamesBowled == 2)
    }

    @Test func summaryCarriesTheArsenalRowFlags() throws {
        let plain = try balls.addBall(name: "Plain", weightPounds: 15, intendedRole: .strike, brand: "")
        #expect(!plain.isRetired)
        #expect(!plain.hasPhoto)
        #expect(!plain.isResurfaceDue)

        try balls.setPhoto(Data([1]), for: plain.id)
        try balls.setRetired(true, for: plain.id)
        let retired = try #require(balls.retiredBalls().first)
        #expect(retired.isRetired)
        #expect(retired.hasPhoto)
    }

    @Test func resurfaceDueFollowsTheIntervalAndTheLatestResurface() throws {
        let id = try balls.addBall(BallFields(name: "Phaze", weightPounds: 15, resurfaceIntervalGames: 2)).id
        func insert(daysAgo: Double) throws {
            let record = GameRecord(
                gameIndex: 1, entryMode: .finalOnly, defaultBallID: id, finalScore: 200, isComplete: true,
                frames: [], sessionID: SessionID(), sessionDate: .now.addingTimeInterval(-daysAgo * 86_400),
                eventType: .league
            )
            _ = try insertGame(record, into: store.context)
        }
        try insert(daysAgo: 3)
        #expect(balls.activeBalls().first?.isResurfaceDue == false)
        try insert(daysAgo: 2)
        // 2 games, interval 2: due.
        #expect(balls.activeBalls().first?.isResurfaceDue == true)

        _ = try balls.logMaintenance(.resurface, date: .now.addingTimeInterval(-86_400), surfaceGritAfter: "",
                                     notes: "", for: id)
        // Nothing after yesterday's resurface: 0 games.
        #expect(balls.activeBalls().first?.isResurfaceDue == false)
        try insert(daysAgo: 0.5)
        try insert(daysAgo: 0.25)
        #expect(balls.activeBalls().first?.isResurfaceDue == true)

        var fields = try balls.detail(for: id).fields
        fields.resurfaceIntervalGames = nil
        _ = try balls.updateBall(id, with: fields)
        #expect(balls.activeBalls().first?.isResurfaceDue == false)
    }

    @Test func unknownStoredRoleReadsAsUnknown() throws {
        let ball = Ball(name: "Future", weightPounds: 15)
        ball.intendedRole = "hookAndSpare"
        store.context.insert(ball)
        #expect(balls.activeBalls().first?.intendedRole == .unknown)
        #expect(ball.intendedRole == "hookAndSpare")
    }
}
