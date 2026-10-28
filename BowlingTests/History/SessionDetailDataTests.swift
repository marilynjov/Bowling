import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct SessionDetailDataTests {
    let store: BowlingStore
    let sam: BowlerRecord
    let alex: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        sam = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        alex = try store.bowlers.createBowler(name: "Alex")
    }

    /// A final-only session: game n for every bowler (lineup order) gets `scores[bowler][n]`.
    func session(
        _ metadata: SessionMetadata = SessionMetadata(date: .now, eventType: .practice),
        lineup: [BowlerRecord], scores: [[Int]]
    ) throws -> SessionID {
        let id = try store.sessions.startSession(
            metadata, bowlers: lineup.map { (bowlerID: $0.id, defaultBallID: nil) }, entryMode: .finalOnly
        )
        for index in scores[0].indices {
            let games = index == 0
                ? try store.sessions.session(id).bowlers.compactMap { $0.games.first?.id }
                : try store.games.startNextGame(in: id)
            for (game, bowlerScores) in zip(games, scores) { try store.games.setFinalScore(bowlerScores[index], for: game) }
        }
        return id
    }

    @Test func sectionsFollowTheLineupWithSeries() throws {
        let id = try session(lineup: [alex, sam], scores: [[200, 190], [180, 170]])
        let data = try SessionDetailData.load(id, from: store)
        #expect(data.sections.map(\.name) == ["Alex", "Sam"])
        #expect(data.sections.map(\.seriesText) == ["Series 390", "Series 350"])
        #expect(data.sections[0].games.map(\.title) == ["Game 1", "Game 2"])
        #expect(data.sections[0].games.map(\.score) == [200, 190])
        #expect(data.gameCount == 4)
    }

    @Test func latestGameOnAnUnevenNight() throws {
        let id = try session(lineup: [alex, sam], scores: [[200, 190, 180], [180, 170, 160]])
        let alexGame3 = try #require(try store.sessions.session(id).bowlers[0].games.last?.id)
        try store.games.deleteGame(alexGame3)
        #expect(try SessionDetailData.load(id, from: store).latestGameIndex == 3)
    }

    @Test func resumableOnlyForTheResumableSession() throws {
        let open = try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: .practice),
            bowlers: [(bowlerID: sam.id, defaultBallID: nil)], entryMode: .finalOnly
        )
        let firstGame = try #require(try store.sessions.session(open).bowlers.first?.games.first?.id)
        let done = try session(lineup: [sam], scores: [[200]])
        #expect(try SessionDetailData.load(open, from: store).resumeTarget == ScoringTarget(sessionID: open, gameID: firstGame))
        #expect(try SessionDetailData.load(done, from: store).resumeTarget == nil)
    }

    @Test func theOnlyGameAsksToDeleteTheSession() throws {
        let one = try session(lineup: [sam], scores: [[200]])
        #expect(try SessionDetailData.load(one, from: store).sections[0].games[0].deleteRequest.target == .session(one))
        let two = try session(lineup: [sam], scores: [[200, 190]])
        let row = try SessionDetailData.load(two, from: store).sections[0].games[1]
        #expect(row.deleteRequest.target == .game(row.id))
    }

    @Test func headerLeavesOutMissingParts() throws {
        let id = try session(
            SessionMetadata(date: .now, eventType: .practice, lanes: "", notes: "  "),
            lineup: [sam], scores: [[200]]
        )
        let data = try SessionDetailData.load(id, from: store)
        #expect(data.headerParts == ["Practice"])
        #expect(data.notes == nil)
    }

    @Test func headerNamesEveryPart() throws {
        let center = try store.sessions.createCenter(name: "AMF Bowl")
        let league = try store.sessions.createLeague(name: "Tuesday Mixed", centerID: center)
        let oil = try store.sessions.createOilPattern(name: "House")
        let id = try session(
            SessionMetadata(
                date: .now, eventType: .league, centerID: center, leagueID: league, oilPatternID: oil,
                lanes: "13–14", notes: "Slick"
            ),
            lineup: [sam], scores: [[200]]
        )
        let data = try SessionDetailData.load(id, from: store)
        #expect(data.headerParts == ["League", "AMF Bowl", "Tuesday Mixed", "House", "Lanes 13–14"])
        #expect(data.notes == "Slick")
    }

    @Test func notesAreTrimmed() throws {
        let id = try session(
            SessionMetadata(date: .now, eventType: .practice, notes: "  Slick \n"), lineup: [sam], scores: [[200]]
        )
        #expect(try SessionDetailData.load(id, from: store).notes == "Slick")
    }

    @Test func aDeletedSessionThrows() {
        #expect(throws: RepositoryError.notFound) { try SessionDetailData.load(SessionID(), from: store) }
    }

    @Test func deletingTheOpenGamePopsItsRoute() throws {
        let id = try session(lineup: [sam], scores: [[200, 190]])
        let game = try #require(try store.sessions.session(id).bowlers[0].games.last?.id)
        let app = AppModel(store: store)
        app.historyPath = [.session(id), .game(game)]
        try app.delete(.game(game, gameIndex: 2, bowlerName: "Sam", sessionID: id, isOnlyGame: false))
        #expect(app.historyPath == [.session(id)])
        #expect(try store.sessions.session(id).bowlers[0].games.count == 1)
    }
}
