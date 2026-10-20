import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct HomeDataTests {
    let store: BowlingStore
    let sam: BowlerRecord
    let ana: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        sam = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        ana = try store.bowlers.createBowler(name: "Ana")
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: .now)!
    }

    /// A finished final-only session: game n for every bowler gets `scores[n]`.
    @discardableResult
    func session(_ type: EventType, _ scores: [Int], date: Date = .now, bowlers: [BowlerID]? = nil) throws -> SessionID {
        let lineup = bowlers ?? [sam.id]
        let id = try store.sessions.startSession(
            SessionMetadata(date: date, eventType: type),
            bowlers: lineup.map { (bowlerID: $0, defaultBallID: nil) }, entryMode: .finalOnly
        )
        var games = try store.sessions.session(id).bowlers.compactMap { $0.games.first?.id }
        for (index, score) in scores.enumerated() {
            if index > 0 { games = try store.games.startNextGame(in: id) }
            for game in games { try store.games.setFinalScore(score, for: game) }
        }
        return id
    }

    /// A count-only session whose first game per bowler has the given rolls and is unfinished.
    @discardableResult
    func unfinished(_ rolls: [Int], date: Date = .now, bowlers: [BowlerID]? = nil) throws -> SessionDetail {
        let lineup = bowlers ?? [sam.id]
        let id = try store.sessions.startSession(
            SessionMetadata(date: date, eventType: .league),
            bowlers: lineup.map { (bowlerID: $0, defaultBallID: nil) }, entryMode: .countOnly
        )
        for bowler in try store.sessions.session(id).bowlers {
            for pins in rolls { _ = try store.games.recordRoll(.count(pins), ballID: nil, in: bowler.games[0].id) }
        }
        return try store.sessions.session(id)
    }

    func average(_ data: HomeData) throws -> HomeTile {
        try #require(data.tiles.first { $0.card == .average })
    }

    @Test func noOwnerIsEmpty() throws {
        #expect(HomeData.load(from: try BowlingStore(inMemory: true)) == HomeData())
    }

    @Test func leagueOwnerSplitsTheAverage() throws {
        try session(.league, [200, 180])
        try session(.casual, [100])
        let tile = try average(HomeData.load(from: store))
        #expect(tile.value == "190")
        #expect(tile.sample?.hasSuffix("All games 160") == true)
    }

    @Test func noCompetitionGamesFallsBackToAllGames() throws {
        try session(.practice, [150])
        let tile = try average(HomeData.load(from: store))
        #expect(tile.value == "150")
        #expect(tile.sample == "1 game")
    }

    @Test func savedAllScopeNeverSplits() throws {
        try store.bowlers.setStatsScope(.all)
        try session(.league, [200])
        try session(.casual, [100])
        let tile = try average(HomeData.load(from: store))
        #expect(tile.value == "150")
        #expect(tile.sample?.contains("All games") == false)
    }

    @Test func casualOwnerUsesAllGames() throws {
        try store.bowlers.setStatsProfile(.casual)
        try session(.league, [200])
        try session(.casual, [100])
        let tile = try average(HomeData.load(from: store))
        #expect(tile.value == "150")
        #expect(tile.sample?.contains("All games") == false)
    }

    @Test func customLayoutIsUsed() throws {
        try store.bowlers.setHomeLayout([.fouls, .average])
        #expect(HomeData.load(from: store).tiles.map(\.card) == [.fouls, .average])
    }

    @Test func recentIsNewestThreeFirst() throws {
        let ids = try (1...4).map { try session(.practice, [100 + $0], date: daysAgo($0)) }
        #expect(HomeData.load(from: store).recent.map(\.id) == Array(ids.prefix(3)))
    }

    @Test func recentRowListsOnlyTheOwnersScores() throws {
        let id = try session(.league, [187, 201], bowlers: [ana.id, sam.id])
        let row = try #require(HomeData.load(from: store).recent.first)
        #expect(row.id == id)
        #expect(row.scores == "187 · 201")
        #expect(row.eventType == .league)
    }

    @Test func incompleteGameIsMarked() throws {
        try unfinished([7, 2])
        #expect(HomeData.load(from: store).recent.first?.scores == "9…")
    }

    @Test func resumeFollowsLineupOrder() throws {
        let detail = try unfinished([7], bowlers: [ana.id, sam.id])
        let resume = try #require(HomeData.load(from: store).resume)
        #expect(resume.target == ScoringTarget(sessionID: detail.id, gameID: detail.bowlers[0].games[0].id))
        #expect(detail.bowlers[0].bowler.id == ana.id)
    }

    @Test func resumeProgress() throws {
        try unfinished([7, 2, 10])
        #expect(HomeData.load(from: store).resume?.progress == "Game 1 · frame 3")
    }

    @Test func resumeProgressBeforeAnyRoll() throws {
        try unfinished([])
        #expect(HomeData.load(from: store).resume?.progress == "Game 1")
    }

    @Test func noResumeWhenEverythingIsComplete() throws {
        try session(.league, [200, 210])
        #expect(HomeData.load(from: store).resume == nil)
    }

    @Test func quickScoreKeepsResumeOnTheUnfinishedSession() throws {
        let detail = try unfinished([7], date: daysAgo(1))
        _ = try store.sessions.quickScore(finalScore: 190, now: .now)
        #expect(HomeData.load(from: store).resume?.target.sessionID == detail.id)
    }
}
