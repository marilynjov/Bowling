import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BallEditTests {
    let store: BowlingStore
    var balls: BallRepository { store.balls }

    nonisolated static let released = Date(timeIntervalSince1970: 1_760_000_000)
    nonisolated static let purchased = Date(timeIntervalSince1970: 1_770_000_000)

    /// Every field set to a non-default value.
    nonisolated static let full = BallFields(
        name: "Phaze II", brand: "Storm", weightPounds: 15, coverstock: .reactiveSolid,
        coverstockName: "TX-16 Solid", coreType: .symmetric, coreName: "Velocity",
        rg: 2.48, differential: 0.051, intermediateDifferential: 0.01, intendedRole: .both,
        serialNumber: "SN123", colorDescription: "Pacific blue", releaseDate: released,
        purchaseDate: purchased, factoryFinish: "1500 Polished", surfaceGrit: "2000 Abralon",
        resurfaceIntervalGames: 60, notes: "Pin up, 4 1/2 inches"
    )

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    @Test func addBallStoresEveryFieldAndDetailReadsThemBack() throws {
        let added = try balls.addBall(Self.full)
        #expect(added.fields == Self.full)
        #expect(!added.isRetired)
        #expect(!added.hasPhoto)
        #expect(added.gamesBowled == 0)
        #expect(try balls.detail(for: added.id) == added)
        #expect(balls.activeBalls().map(\.id) == [added.id])
    }

    @Test func addBallSeedsTheCurrentSurfaceFromTheFactoryFinish() throws {
        var fields = Self.full
        fields.surfaceGrit = ""
        let added = try balls.addBall(fields)
        #expect(added.fields.surfaceGrit == "1500 Polished")
    }

    @Test func onlyNameAndWeightAreRequired() throws {
        let added = try balls.addBall(BallFields(name: " Spare ", weightPounds: 14))
        #expect(added.fields == BallFields(name: "Spare", weightPounds: 14))
        #expect(added.fields.intendedRole == .strike)
        #expect(added.fields.coverstock == .unknown)
    }

    @Test func updateBallReplacesEveryField() throws {
        let id = try balls.addBall(name: "Old", weightPounds: 16, intendedRole: .spare, brand: "").id
        let before = try store.context.ball(id).updatedAt

        let updated = try balls.updateBall(id, with: Self.full)
        #expect(updated.fields == Self.full)
        #expect(try balls.detail(for: id).fields == Self.full)
        #expect(try store.context.ball(id).updatedAt > before)
    }

    @Test func updateBallClearsOptionalValues() throws {
        let id = try balls.addBall(Self.full).id
        let cleared = BallFields(name: "Phaze II", weightPounds: 15)
        let updated = try balls.updateBall(id, with: cleared)
        #expect(updated.fields == cleared)
        #expect(updated.fields.resurfaceIntervalGames == nil)
        #expect(updated.fields.surfaceGrit.isEmpty)
    }

    @Test func updateBallDoesNotSeedTheSurface() throws {
        let id = try balls.addBall(Self.full).id
        var fields = Self.full
        fields.surfaceGrit = ""
        #expect(try balls.updateBall(id, with: fields).fields.surfaceGrit.isEmpty)
    }

    @Test func unknownValuesKeepANewerVersionsStoredStrings() throws {
        let id = try balls.addBall(Self.full).id
        let ball = try store.context.ball(id)
        ball.coverstock = "polyester"
        ball.coreType = "dualDensity"
        ball.intendedRole = "hookAndSpare"
        try store.context.save()

        let read = try balls.detail(for: id).fields
        #expect(read.coverstock == .unknown)
        #expect(read.coreType == .unknown)
        #expect(read.intendedRole == .unknown)
        var renamed = read
        renamed.name = "Renamed"
        _ = try balls.updateBall(id, with: renamed)
        #expect(ball.coverstock == "polyester")
        #expect(ball.coreType == "dualDensity")
        #expect(ball.intendedRole == "hookAndSpare")
    }

    @Test func choosingUnknownOverAKnownValueStoresUnknown() throws {
        let id = try balls.addBall(Self.full).id
        var fields = Self.full
        fields.coverstock = .unknown
        fields.coreType = .unknown
        _ = try balls.updateBall(id, with: fields)
        #expect(try store.context.ball(id).coverstock == "unknown")
        #expect(try store.context.ball(id).coreType == "unknown")
    }

    nonisolated static let invalid: [(BallFields, BallFieldError)] = {
        func with(_ change: (inout BallFields) -> Void) -> BallFields {
            var fields = full
            change(&fields)
            return fields
        }
        return [
            (with { $0.name = "  " }, .emptyName),
            (with { $0.weightPounds = 5 }, .weightOutOfRange),
            (with { $0.weightPounds = 17 }, .weightOutOfRange),
            (with { $0.rg = -2.5 }, .negativeSpec),
            (with { $0.differential = -0.01 }, .negativeSpec),
            (with { $0.intermediateDifferential = .nan }, .negativeSpec),
            (with { $0.rg = .infinity }, .negativeSpec),
            (with { $0.resurfaceIntervalGames = 0 }, .resurfaceIntervalBelowOne),
            (with { $0.resurfaceIntervalGames = -10 }, .resurfaceIntervalBelowOne),
        ]
    }()

    @Test(arguments: invalid)
    func addBallRefusesInvalidFields(_ fields: BallFields, _ error: BallFieldError) {
        #expect(throws: RepositoryError.invalidBall(error)) { try balls.addBall(fields) }
        #expect(balls.activeBalls().isEmpty)
    }

    @Test(arguments: invalid)
    func updateBallRefusesInvalidFieldsAndKeepsTheBall(_ fields: BallFields, _ error: BallFieldError) throws {
        let id = try balls.addBall(Self.full).id
        #expect(throws: RepositoryError.invalidBall(error)) { try balls.updateBall(id, with: fields) }
        #expect(try balls.detail(for: id).fields == Self.full)
    }

    @Test func zeroSpecsAndAnIntervalOfOneAreAccepted() throws {
        var fields = Self.full
        fields.rg = 0
        fields.differential = 0
        fields.intermediateDifferential = 0
        fields.resurfaceIntervalGames = 1
        #expect(try balls.addBall(fields).fields == fields)
    }

    @Test func unknownBallIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try balls.detail(for: BallID()) }
        #expect(throws: RepositoryError.notFound) { try balls.updateBall(BallID(), with: Self.full) }
    }

    @Test func detailCountsGamesBowled() throws {
        let id = try balls.addBall(Self.full).id
        let record = GameRecord(
            gameIndex: 1, entryMode: .finalOnly, defaultBallID: id, finalScore: 200, isComplete: true,
            frames: [], sessionID: SessionID(), sessionDate: Self.purchased, eventType: .league
        )
        _ = try insertGame(record, into: store.context)
        #expect(try balls.detail(for: id).gamesBowled == 1)
    }
}
