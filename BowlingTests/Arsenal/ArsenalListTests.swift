import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct ArsenalListTests {
    let store: BowlingStore
    let owner: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
    }

    private func addBall(_ name: String, role: BallRole = .strike) throws -> BallSummary {
        try store.balls.addBall(name: name, weightPounds: 15, intendedRole: role, brand: "")
    }

    /// Starts `count` sessions with `ball` as the owner's default, one game each.
    private func bowl(_ ball: BallSummary, games count: Int) throws {
        for _ in 0..<count {
            var draft = NewSessionDraft(owner: owner, date: .now)
            draft.ownerBallID = ball.id
            _ = try draft.start(in: store.sessions)
        }
    }

    @Test func rowsFollowNameOrder() throws {
        _ = try addBall("Zed")
        _ = try addBall("Alpha")
        #expect(ArsenalList.load(from: store).rows.map(\.name) == ["Alpha", "Zed"])
    }

    @Test func detailShowsWeightAndRole() throws {
        _ = try addBall("Phaze")
        #expect(ArsenalList.load(from: store).rows.map(\.detail) == ["15 lb · Strike"])
    }

    @Test func gameCountWording() throws {
        let none = try addBall("A")
        let one = try addBall("B")
        let many = try addBall("C")
        try bowl(one, games: 1)
        try bowl(many, games: 12)
        let rows = ArsenalList.load(from: store).rows
        #expect(rows.map(\.id) == [none.id, one.id, many.id])
        #expect(rows.map(\.games) == ["No games yet", "1 game", "12 games"])
    }

    @Test func retiredBallsAreLeftOut() throws {
        let kept = try addBall("Phaze")
        let retired = try addBall("Hammer")
        try store.balls.setRetired(true, for: retired.id)
        #expect(ArsenalList.load(from: store).rows.map(\.id) == [kept.id])
    }

    @Test func unknownRoleShowsOnlyTheWeight() {
        let row = ArsenalList.row(id: BallID(), name: "Phaze", weightPounds: 15, role: .unknown, gamesBowled: 1)
        #expect(row.detail == "15 lb")
        #expect(row.accessibilityLabel == "Phaze, 15 pounds, 1 game")
    }
}
