import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct HistoryListTests {
    let store: BowlingStore
    let sam: BowlerRecord
    let ana: BowlerRecord
    let calendar: Calendar

    init() throws {
        store = try BowlingStore(inMemory: true)
        sam = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        ana = try store.bowlers.createBowler(name: "Ana")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
    }

    func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    /// A finished final-only session: game n for every bowler gets `scores[n]`.
    @discardableResult
    func session(
        _ metadata: SessionMetadata, _ scores: [Int] = [150], bowlers: [BowlerID]? = nil
    ) throws -> SessionID {
        let lineup = bowlers ?? [sam.id]
        let id = try store.sessions.startSession(
            metadata, bowlers: lineup.map { (bowlerID: $0, defaultBallID: nil) }, entryMode: .finalOnly
        )
        var games = try store.sessions.session(id).bowlers.compactMap { $0.games.first?.id }
        for (index, score) in scores.enumerated() {
            if index > 0 { games = try store.games.startNextGame(in: id) }
            for game in games { try store.games.setFinalScore(score, for: game) }
        }
        return id
    }

    func rows() throws -> [RecentRow] {
        try store.sessions.sessions().map { RecentRow($0, owner: sam.id) }
    }

    func months() throws -> [HistoryMonth] {
        HistoryList.months(from: try store.sessions.sessions(), owner: sam.id, calendar: calendar)
    }

    @Test func monthsAreNewestFirst() throws {
        try session(SessionMetadata(date: date(9, 30), eventType: .casual))
        try session(SessionMetadata(date: date(10, 1), eventType: .casual))
        #expect(try months().map(\.title) == ["October 2026", "September 2026"])
    }

    @Test func sessionsAreNewestFirstInsideAMonth() throws {
        try session(SessionMetadata(date: date(10, 3), eventType: .casual))
        try session(SessionMetadata(date: date(10, 21), eventType: .casual))
        #expect(try months().flatMap(\.rows).map(\.date) == [date(10, 21), date(10, 3)])
    }

    @Test func noSessionsNoMonths() {
        #expect(HistoryList.months(from: [], owner: sam.id, calendar: calendar) == [])
    }

    @Test func leagueNightRow() throws {
        let center = try store.sessions.createCenter(name: "AMF Bowl")
        let league = try store.sessions.createLeague(name: "Tuesday Mixed", centerID: center)
        try session(
            SessionMetadata(date: date(10, 21), eventType: .league, centerID: center, leagueID: league),
            bowlers: [sam.id, ana.id, try store.bowlers.createBowler(name: "Lee").id]
        )
        let row = try #require(try rows().first)
        #expect(row.detailsText == "League · AMF Bowl · Tuesday Mixed")
        #expect(row.bowlersText == "3 bowlers")
    }

    @Test func oneBowlerHasNoBowlerCount() throws {
        try session(SessionMetadata(date: date(10, 21), eventType: .casual))
        #expect(try rows().first?.bowlersText == nil)
    }

    @Test func noCenterIsLeftOut() throws {
        try session(SessionMetadata(date: date(10, 21), eventType: .practice))
        #expect(try rows().first?.detailsText == "Practice")
    }

    @Test func practiceDropsTheLeague() throws {
        let league = try store.sessions.createLeague(name: "Tuesday Mixed", centerID: nil)
        try session(SessionMetadata(date: date(10, 21), eventType: .practice, leagueID: league))
        #expect(try rows().first?.leagueName == nil)
    }

    @Test func inProgressRow() throws {
        let id = try store.sessions.startSession(
            SessionMetadata(date: date(10, 21), eventType: .casual),
            bowlers: [(bowlerID: sam.id, defaultBallID: nil)], entryMode: .countOnly
        )
        let game = try #require(try store.sessions.session(id).bowlers.first?.games.first)
        _ = try store.games.recordRoll(.count(9), ballID: nil, in: game.id)
        #expect(try rows().first?.isInProgress == true)
    }

    @Test func scoresFollowLineupOrder() throws {
        try session(SessionMetadata(date: date(10, 21), eventType: .casual), [201, 189], bowlers: [ana.id, sam.id])
        #expect(try rows().first?.ownerScores == [201, 189])
    }

    @Test func gameCountIncludesEveryBowler() throws {
        try session(SessionMetadata(date: date(10, 21), eventType: .casual), [150, 160], bowlers: [sam.id, ana.id])
        #expect(try rows().first?.gameCount == 4)
    }
}
