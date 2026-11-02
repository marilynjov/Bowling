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

    private func addBall(_ name: String, role: BallRole = .strike, brand: String = "") throws -> BallSummary {
        try store.balls.addBall(name: name, weightPounds: 15, intendedRole: role, brand: brand)
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
        #expect(ArsenalList.load(from: store).active.map(\.name) == ["Alpha", "Zed"])
    }

    @Test func detailShowsWeightAndRole() throws {
        _ = try addBall("Phaze")
        #expect(ArsenalList.load(from: store).active.map(\.detail) == ["15 lb · Strike"])
    }

    @Test func detailLeadsWithTheBrand() throws {
        _ = try addBall("Phaze", brand: "Storm")
        #expect(ArsenalList.load(from: store).active.map(\.detail) == ["Storm · 15 lb · Strike"])
    }

    @Test func blankBrandIsLeftOut() {
        let row = ArsenalList.row(id: BallID(), name: "Phaze", brand: "  ", weightPounds: 15, role: .strike, gamesBowled: 1)
        #expect(row.detail == "15 lb · Strike")
        #expect(row.accessibilityLabel == "Phaze, 15 pounds, strike, 1 game")
    }

    @Test func gameCountWording() throws {
        let none = try addBall("A")
        let one = try addBall("B")
        let many = try addBall("C")
        try bowl(one, games: 1)
        try bowl(many, games: 12)
        let rows = ArsenalList.load(from: store).active
        #expect(rows.map(\.id) == [none.id, one.id, many.id])
        #expect(rows.map(\.games) == ["No games yet", "1 game", "12 games"])
    }

    @Test func retiredBallsGoToTheRetiredGroup() throws {
        let kept = try addBall("Phaze")
        let retired = try addBall("Hammer")
        try store.balls.setRetired(true, for: retired.id)
        let list = ArsenalList.load(from: store)
        #expect(list.active.map(\.id) == [kept.id])
        #expect(list.retired.map(\.id) == [retired.id])
        #expect(list.retired.map(\.isRetired) == [true])
        #expect(list.retired.map(\.accessibilityLabel) == ["Hammer, 15 pounds, strike, no games yet, retired"])
    }

    @Test func emptyArsenalHasNoRows() throws {
        #expect(ArsenalList.load(from: store).isEmpty)
        let retired = try addBall("Hammer")
        try store.balls.setRetired(true, for: retired.id)
        #expect(!ArsenalList.load(from: store).isEmpty)
    }

    @Test func resurfaceDueShowsTheBadge() {
        let due = ArsenalList.row(id: BallID(), name: "Phaze", weightPounds: 15, role: .strike, gamesBowled: 40,
                                  isResurfaceDue: true)
        #expect(due.isResurfaceDue)
        #expect(due.accessibilityLabel == "Phaze, 15 pounds, strike, 40 games, resurface due")
        #expect(!ArsenalList.row(id: BallID(), name: "Phaze", weightPounds: 15, role: .strike, gamesBowled: 40).isResurfaceDue)
    }

    @Test func rowCarriesThePhotoFlag() throws {
        let ball = try addBall("Phaze")
        #expect(ArsenalList.load(from: store).active.map(\.hasPhoto) == [false])
        try store.balls.setPhoto(Data([0xFF, 0xD8, 0xFF]), for: ball.id)
        #expect(ArsenalList.load(from: store).active.map(\.hasPhoto) == [true])
    }

    @Test func placeholderIsStableForABall() throws {
        let id = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        let first = BallThumbnail.Placeholder(id: id, name: "phaze")
        #expect(first == BallThumbnail.Placeholder(id: id, name: "phaze"))
        #expect(first.style == 3 % BallThumbnail.Placeholder.styleCount)
        #expect(first.initial == "P")
    }

    @Test func placeholderStylesSpreadAcrossBalls() throws {
        let styles = Set((0..<BallThumbnail.Placeholder.styleCount).map {
            BallThumbnail.Placeholder(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\($0)")!, name: "A").style
        })
        #expect(styles.count == BallThumbnail.Placeholder.styleCount)
    }

    @Test func unknownRoleShowsOnlyTheWeight() {
        let row = ArsenalList.row(id: BallID(), name: "Phaze", weightPounds: 15, role: .unknown, gamesBowled: 1)
        #expect(row.detail == "15 lb")
        #expect(row.accessibilityLabel == "Phaze, 15 pounds, 1 game")
    }
}
