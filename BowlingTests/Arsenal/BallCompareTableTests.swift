import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct BallCompareTableTests {
    let us = Locale(identifier: "en_US")
    let phaze = BallID(), hyRoad = BallID(), spare = BallID()

    func row(_ ball: BallID, games: Int, average: Mean, strikes: Rate, firstBall: Mean, spares: Rate) -> BallComparisonRow {
        BallComparisonRow(ballID: ball, gamesBowled: games, averageAsMainBall: average, strikes: strikes,
                          firstBallAverage: firstBall, spares: spares)
    }

    /// Phaze leads on average and strikes, the spare ball has no strike sample, Hy-Road
    /// leads on spares and games.
    var table: BallCompareTable {
        BallCompareTable([
            row(phaze, games: 10, average: Mean(total: 2_000, count: 10), strikes: Rate(hits: 60, attempts: 100),
                firstBall: Mean(total: 880, count: 100), spares: Rate(hits: 20, attempts: 40)),
            row(hyRoad, games: 12, average: Mean(total: 2_220, count: 12), strikes: Rate(hits: 50, attempts: 120),
                firstBall: Mean(total: 1_080, count: 120), spares: Rate(hits: 45, attempts: 50)),
            row(spare, games: 8, average: Mean(total: 0, count: 0), strikes: Rate(hits: 0, attempts: 0),
                firstBall: Mean(total: 0, count: 0), spares: Rate(hits: 30, attempts: 40)),
        ], names: [phaze: "Phaze II", hyRoad: "Hy-Road", spare: "Spare Plastic"], locale: us)
    }

    func names(_ sort: BallCompareTable.Sort) -> [String] {
        table.sorted(by: sort).map(\.name)
    }

    @Test func cellsShowEachFigureWithItsSample() throws {
        let phazeRow = try #require(table.rows.first)
        #expect(phazeRow.cells[.games] == .init(value: "10", sample: nil, sortValue: 10))
        #expect(phazeRow.cells[.average]?.value == "200")
        #expect(phazeRow.cells[.average]?.sample == "10")
        #expect(phazeRow.cells[.strikes]?.value == "60%")
        #expect(phazeRow.cells[.strikes]?.sample == "100")
        #expect(phazeRow.cells[.firstBall]?.value == "8.8")
        #expect(phazeRow.cells[.spares]?.value == "50%")
        #expect(phazeRow.cells[.spares]?.sample == "40")
        #expect(table.rows.last?.cells[.strikes]?.value == "–")
    }

    @Test func sortsByEveryColumnBothWays() {
        let expected: [BallCompareTable.Column: [String]] = [
            .games: ["Hy-Road", "Phaze II", "Spare Plastic"],
            .average: ["Phaze II", "Hy-Road", "Spare Plastic"],
            .strikes: ["Phaze II", "Hy-Road", "Spare Plastic"],
            .firstBall: ["Hy-Road", "Phaze II", "Spare Plastic"],
            .spares: ["Hy-Road", "Spare Plastic", "Phaze II"],
        ]
        for column in BallCompareTable.Column.allCases {
            let high = names(.init(key: .column(column), ascending: false))
            #expect(high == expected[column], "\(column) high to low")
            let low = names(.init(key: .column(column), ascending: true))
            // Flipped, except a ball with no figure stays last.
            let blank = table.rows.filter { $0.cells[column]?.sortValue == nil }.map(\.name)
            #expect(low == high.filter { !blank.contains($0) }.reversed() + blank, "\(column) low to high")
        }
    }

    @Test func sortsByName() {
        #expect(names(.init(key: .name, ascending: true)) == ["Hy-Road", "Phaze II", "Spare Plastic"])
        #expect(names(.init(key: .name, ascending: false)) == ["Spare Plastic", "Phaze II", "Hy-Road"])
    }

    @Test func tiesGoAToZ() {
        let tied = BallCompareTable([
            row(phaze, games: 5, average: Mean(total: 0, count: 0), strikes: Rate(hits: 0, attempts: 0),
                firstBall: Mean(total: 0, count: 0), spares: Rate(hits: 0, attempts: 0)),
            row(hyRoad, games: 5, average: Mean(total: 0, count: 0), strikes: Rate(hits: 0, attempts: 0),
                firstBall: Mean(total: 0, count: 0), spares: Rate(hits: 0, attempts: 0)),
        ], names: [phaze: "Phaze II", hyRoad: "Hy-Road"], locale: us)
        for ascending in [true, false] {
            #expect(tied.sorted(by: .init(key: .column(.games), ascending: ascending)).map(\.name) == ["Hy-Road", "Phaze II"])
            #expect(tied.sorted(by: .init(key: .column(.average), ascending: ascending)).map(\.name) == ["Hy-Road", "Phaze II"])
        }
    }

    @Test func tappingFlipsTheSortedColumnAndStartsOthersHighToLow() {
        let start = BallCompareTable.Sort()
        #expect(start == .init(key: .column(.average), ascending: false))
        #expect(start.tapping(.column(.average)) == .init(key: .column(.average), ascending: true))
        #expect(start.tapping(.column(.spares)) == .init(key: .column(.spares), ascending: false))
        #expect(start.tapping(.name) == .init(key: .name, ascending: true))
    }

    @Test func accessibilityLabelReadsEachFigureWithItsSample() throws {
        #expect(table.rows.first?.accessibilityLabel
            == "Phaze II, 10 games, Average 200 over 10, Strike % 60% over 100, First ball 8.8 over 100, Spare % 50% over 40")
        #expect(try #require(table.rows.last?.accessibilityLabel).contains("Strike % none"))
    }

    @Test func loadComparesActiveBallsOnTheOwnersGames() throws {
        let store = try BowlingStore(inMemory: true)
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let friend = try store.bowlers.createBowler(name: "Ana")
        let used = try store.balls.addBall(BallFields(name: "Phaze", weightPounds: 15)).id
        let retired = try store.balls.addBall(BallFields(name: "Old", weightPounds: 15)).id
        try store.balls.setRetired(true, for: retired)
        let session = try store.sessions.startSession(
            SessionMetadata(date: .now.addingTimeInterval(-3_600), eventType: .league),
            bowlers: [(bowlerID: owner.id, defaultBallID: used)], entryMode: .finalOnly
        )
        let game = try #require(try store.sessions.session(session).bowlers.first?.games.first?.id)
        try store.games.setFinalScore(210, for: game)

        // The Stats filter is on the friend; Compare still reads the owner's games.
        let friendFilter = StatsFilterDraft.defaults(for: friend, owner: owner, in: store)
        let table = BallCompareTable.load(store: store, filter: friendFilter, locale: us)

        #expect(table.rows.map(\.name) == ["Phaze"])
        #expect(table.rows.first?.cells[.average]?.value == "210")
        #expect(table.chips.last == "Sam")
    }
}
