import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// Settings "Delete all data" (§7, contract OQ-12).
@MainActor @Suite struct DeleteAllDataTests {
    let store: BowlingStore

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    /// Saved rows per entity, read through a second context so only saved changes count.
    private func savedCounts() throws -> [String: Int] {
        let context = ModelContext(store.container)
        func count<T: PersistentModel>(_ type: T.Type) throws -> Int { try context.fetchCount(FetchDescriptor<T>()) }
        return try Dictionary(uniqueKeysWithValues: BowlingSchemaV1.models.map { ("\($0)", try count($0)) })
    }

    /// One of every entity, linked the way the app links them.
    private func fillEveryEntity() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let partner = try store.bowlers.createBowler(name: "Alex")
        let ball = try store.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "")
        let center = try store.sessions.createCenter(name: "Sunset Lanes")
        var metadata = SessionMetadata(date: DemoFixture.referenceDate, eventType: .league)
        metadata.centerID = center
        metadata.leagueID = try store.sessions.createLeague(name: "Tuesday Trios", centerID: center)
        metadata.oilPatternID = try store.sessions.createOilPattern(name: "House")
        let session = try store.sessions.startSession(
            metadata, bowlers: [(owner.id, ball.id), (partner.id, nil)], entryMode: .pinByPin
        )
        let game = try #require(try store.sessions.session(session).bowlers.first?.games.first)
        _ = try store.games.recordRoll(.pins(PinSet(pins: [1, 2, 3])), ballID: nil, in: game.id)

        let context = store.context
        let gameModel = try context.game(game.id)
        let ballModel = try context.ball(ball.id)
        let photo = GamePhoto(imageData: Data([1]))
        context.insert(photo)
        photo.game = gameModel
        let ballPhoto = BallPhoto(imageData: Data([2]))
        context.insert(ballPhoto)
        ballPhoto.ball = ballModel
        let event = MaintenanceEvent(date: DemoFixture.referenceDate, kind: .resurface)
        context.insert(event)
        event.ball = ballModel
        try context.save()
    }

    @Test func deletesEveryRecordIncludingTheOwner() throws {
        try fillEveryEntity()
        #expect(try savedCounts().values.allSatisfy { $0 > 0 })

        try store.deleteAllData()

        #expect(try savedCounts().values.allSatisfy { $0 == 0 })
        #expect(store.bowlers.owner() == nil)
        #expect(store.sessions.sessions().isEmpty)
    }

    // The app returns to first launch, which creates a new owner.
    @Test func firstLaunchCanCreateAnOwnerAgain() throws {
        try fillEveryEntity()
        try store.deleteAllData()
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .left, statsProfile: .casual)
        #expect(store.bowlers.bowlers() == [owner])
    }

    @Test func deletingAnEmptyStoreDoesNothing() throws {
        try store.deleteAllData()
        #expect(try savedCounts().values.allSatisfy { $0 == 0 })
    }
}
