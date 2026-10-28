import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct SessionRepositoryTests {
    let store: BowlingStore
    var sessions: SessionRepository { store.sessions }
    let date = DemoFixture.referenceDate

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    private func metadata(daysAgo: Int = 0, _ eventType: EventType = .league) -> SessionMetadata {
        SessionMetadata(date: date.addingTimeInterval(Double(-daysAgo) * 86_400), eventType: eventType)
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try store.context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: Starting

    @Test func startSessionCreatesGameOneForEachBowler() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let partner = try store.bowlers.createBowler(name: "Alex")
        let ball = try store.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "")

        let id = try sessions.startSession(
            metadata(), bowlers: [(partner.id, nil), (owner.id, ball.id)], entryMode: .pinByPin
        )

        let detail = try sessions.session(id)
        #expect(detail.metadata == metadata())
        #expect(detail.bowlers.map(\.bowler.name) == ["Alex", "Sam"])
        let ownerGame = try #require(detail.bowlers.last?.games.first)
        #expect(detail.bowlers.map(\.games.count) == [1, 1])
        #expect(ownerGame.gameIndex == 1)
        #expect(ownerGame.entryMode == .pinByPin)
        #expect(ownerGame.defaultBallID == ball.id)
        #expect(ownerGame.bowlerID == owner.id)
        #expect(ownerGame.sessionID == id)
        #expect(ownerGame.eventType == .league)
        #expect(!ownerGame.isComplete)
    }

    // OQ-11: Scoring rotates bowlers like a lane console, so the lineup is the order given.
    @Test func sessionBowlersFollowTheLineupGivenAtStart() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let alex = try store.bowlers.createBowler(name: "Alex")
        let zoe = try store.bowlers.createBowler(name: "Zoe")

        let id = try sessions.startSession(
            metadata(), bowlers: [(zoe.id, nil), (owner.id, nil), (alex.id, nil)], entryMode: .pinByPin
        )

        #expect(try sessions.session(id).bowlers.map(\.bowler.name) == ["Zoe", "Sam", "Alex"])
        let lineup = try store.context.fetch(FetchDescriptor<Game>()).map { ($0.bowler!.name, $0.lineupIndex) }
        #expect(Dictionary(uniqueKeysWithValues: lineup) == ["Zoe": 1, "Sam": 2, "Alex": 3])
    }

    // Games stored before lineupIndex existed all read the default 1.
    @Test func equalLineupPositionsFallBackToOwnerThenName() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let alex = try store.bowlers.createBowler(name: "Alex")
        let zoe = try store.bowlers.createBowler(name: "Zoe")
        let id = try sessions.startSession(
            metadata(), bowlers: [(zoe.id, nil), (alex.id, nil), (owner.id, nil)], entryMode: .pinByPin
        )
        for game in try store.context.fetch(FetchDescriptor<Game>()) { game.lineupIndex = 1 }
        try store.context.save()

        #expect(try sessions.session(id).bowlers.map(\.bowler.name) == ["Sam", "Alex", "Zoe"])
    }

    @Test func startSessionWithMissingBowlerOrBallSavesNothing() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        #expect(throws: RepositoryError.notFound) {
            try sessions.startSession(metadata(), bowlers: [(owner.id, nil), (UUID(), nil)], entryMode: .countOnly)
        }
        #expect(throws: RepositoryError.notFound) {
            try sessions.startSession(metadata(), bowlers: [(owner.id, UUID())], entryMode: .countOnly)
        }
        var withMissingCenter = metadata()
        withMissingCenter.centerID = UUID()
        #expect(throws: RepositoryError.notFound) {
            try sessions.startSession(withMissingCenter, bowlers: [(owner.id, nil)], entryMode: .countOnly)
        }
        #expect(try count(Session.self) == 0)
        #expect(try count(Game.self) == 0)
    }

    @Test func quickScoreIsACasualFinalOnlyGameForTheOwner() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        let id = try sessions.quickScore(finalScore: 187, now: date)

        let detail = try sessions.session(id)
        #expect(detail.metadata.eventType == .casual)
        #expect(detail.metadata.date == date)
        let game = try #require(detail.bowlers.first?.games.first)
        #expect(detail.bowlers.map(\.bowler.id) == [owner.id])
        #expect(game.entryMode == .finalOnly)
        #expect(game.finalScore == 187)
        #expect(game.isComplete)
        #expect(game.frames.isEmpty)
    }

    @Test(arguments: [-1, 301])
    func quickScoreOutsideZeroTo300IsRefused(_ score: Int) throws {
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        #expect(throws: RepositoryError.invalidGame([.finalScoreOutOfRange])) {
            try sessions.quickScore(finalScore: score, now: date)
        }
        #expect(try count(Session.self) == 0)
    }

    @Test func quickScoreWithoutOwnerIsNotFound() throws {
        #expect(throws: RepositoryError.notFound) { try sessions.quickScore(finalScore: 150, now: date) }
    }

    // MARK: Reading

    @Test func sessionsAreNewestFirst() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        let old = try sessions.startSession(metadata(daysAgo: 5), bowlers: [(owner.id, nil)], entryMode: .countOnly)
        let new = try sessions.startSession(metadata(daysAgo: 1), bowlers: [(owner.id, nil)], entryMode: .countOnly)
        let sameDayLater = try sessions.startSession(metadata(daysAgo: 1), bowlers: [(owner.id, nil)], entryMode: .countOnly)
        try store.context.session(sameDayLater).createdAt = .distantFuture
        try store.context.save()

        #expect(sessions.sessions().map(\.id) == [sameDayLater, new, old])
    }

    @Test func summaryCarriesNamesCountsAndOrderedGames() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let partner = try store.bowlers.createBowler(name: "Alex")
        let center = try sessions.createCenter(name: "Sunset Lanes")
        let league = try sessions.createLeague(name: "Tuesday Trios", centerID: center)
        var data = metadata()
        data.centerID = center
        data.leagueID = league
        let id = try sessions.startSession(data, bowlers: [(partner.id, nil), (owner.id, nil)], entryMode: .finalOnly)
        _ = try store.games.startNextGame(in: id)

        let summary = try #require(sessions.sessions().first)
        #expect(summary.centerName == "Sunset Lanes")
        #expect(summary.leagueName == "Tuesday Trios")
        #expect(summary.bowlerCount == 2)
        #expect(summary.games.map(\.bowlerID) == [partner.id, partner.id, owner.id, owner.id])
        #expect(summary.games.map(\.gameIndex) == [1, 2, 1, 2])
        #expect(!summary.isComplete)
    }

    @Test func sessionIsCompleteWhenEveryGameIs() throws {
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        _ = try sessions.quickScore(finalScore: 150, now: date)
        #expect(sessions.sessions().first?.isComplete == true)
    }

    @Test func seriesTotalSumsTheBowlersFinalScores() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let id = try sessions.startSession(metadata(), bowlers: [(owner.id, nil)], entryMode: .finalOnly)
        let second = try #require(try store.games.startNextGame(in: id).first)
        let first = try #require(try sessions.session(id).bowlers.first?.games.first?.id)
        try store.games.setFinalScore(180, for: first)
        try store.games.setFinalScore(210, for: second)

        #expect(try sessions.session(id).bowlers.first?.seriesTotal == 390)
    }

    @Test func resumableSessionIsTheNewestWithAnIncompleteGame() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        #expect(sessions.resumableSession() == nil)
        let older = try sessions.startSession(metadata(daysAgo: 3), bowlers: [(owner.id, nil)], entryMode: .countOnly)
        _ = try sessions.startSession(metadata(daysAgo: 9), bowlers: [(owner.id, nil)], entryMode: .countOnly)
        _ = try sessions.quickScore(finalScore: 150, now: date)

        #expect(sessions.resumableSession()?.id == older)
    }

    @Test func missingSessionIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try sessions.session(UUID()) }
    }

    // MARK: Editing

    @Test func updateMetadataChangesTheSession() throws {
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        let id = try sessions.quickScore(finalScore: 150, now: date)
        let pattern = try sessions.createOilPattern(name: "House")
        var data = try sessions.session(id).metadata
        data.eventType = .league
        data.oilPatternID = pattern
        data.lanes = "17-18"
        data.notes = "Good look"

        try sessions.updateMetadata(id, data)
        #expect(try sessions.session(id).metadata == data)
        #expect(try sessions.session(id).bowlers.first?.games.first?.eventType == .league)
    }

    @Test func updateMetadataWithMissingReferenceSavesNothing() throws {
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        let id = try sessions.quickScore(finalScore: 150, now: date)
        var data = try sessions.session(id).metadata
        data.eventType = .league
        data.leagueID = UUID()

        #expect(throws: RepositoryError.notFound) { try sessions.updateMetadata(id, data) }
        #expect(try sessions.session(id).metadata.eventType == .casual)
    }

    @Test func unknownEventTypeReadsAsUnknownAndSurvivesAnEdit() throws {
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        let id = try sessions.quickScore(finalScore: 150, now: date)
        let model = try store.context.session(id)
        model.eventType = "bowlathon"

        var data = try sessions.session(id).metadata
        #expect(data.eventType == .unknown)
        data.notes = "edited"
        try sessions.updateMetadata(id, data)
        #expect(model.eventType == "bowlathon")
        #expect(model.notes == "edited")
    }

    // MARK: Deleting

    @Test func deleteSessionCascadesToGamesFramesAndRolls() throws {
        let fixture = try #require(DemoFixture.games(relativeTo: date).first { $0.finalScore == 300 })
        let game = try insertGame(fixture, into: store.context)
        let sessionID = try #require(game.session?.id)

        try sessions.deleteSession(sessionID)
        #expect(try count(Session.self) == 0)
        #expect(try count(Game.self) == 0)
        #expect(try count(Frame.self) == 0)
        #expect(try count(Roll.self) == 0)
        #expect(try count(Bowler.self) == 1)
        #expect(try count(Ball.self) == 1)
    }

    @Test func deletingMissingSessionIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try sessions.deleteSession(UUID()) }
    }

    // MARK: Backing out before any roll

    private func startTwoBowlerSession(_ entryMode: EntryMode) throws -> SessionID {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let partner = try store.bowlers.createBowler(name: "Alex")
        return try sessions.startSession(metadata(), bowlers: [(owner.id, nil), (partner.id, nil)], entryMode: entryMode)
    }

    private func gameIDs(_ session: SessionID) throws -> [GameID] {
        try sessions.session(session).bowlers.flatMap(\.games).map(\.id)
    }

    @Test func discardIfUnstartedDeletesASessionWithNoRolls() throws {
        let id = try startTwoBowlerSession(.pinByPin)
        try sessions.discardIfUnstarted(id)
        #expect(try count(Session.self) == 0)
        #expect(try count(Game.self) == 0)
        #expect(try count(Bowler.self) == 2)
    }

    @Test func discardIfUnstartedKeepsASessionWithARoll() throws {
        let id = try startTwoBowlerSession(.countOnly)
        let partnerGame = try #require(try gameIDs(id).last)
        _ = try store.games.recordRoll(.count(4), ballID: nil, in: partnerGame)

        try sessions.discardIfUnstarted(id)
        #expect(try count(Session.self) == 1)
        #expect(try count(Game.self) == 2)
    }

    @Test func discardIfUnstartedKeepsASessionWithATypedFinalScore() throws {
        let id = try startTwoBowlerSession(.finalOnly)
        let ownerGame = try #require(try gameIDs(id).first)
        try store.games.setFinalScore(0, for: ownerGame)

        try sessions.discardIfUnstarted(id)
        #expect(try count(Session.self) == 1)
    }

    @Test func discardIfUnstartedOnMissingSessionIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try sessions.discardIfUnstarted(UUID()) }
    }

    // MARK: Pickers

    @Test func pickersListByName() throws {
        _ = try sessions.createCenter(name: "sunset Lanes")
        _ = try sessions.createCenter(name: "AMF Bay")
        _ = try sessions.createOilPattern(name: "Shark")
        #expect(sessions.centers().map(\.name) == ["AMF Bay", "sunset Lanes"])
        #expect(sessions.oilPatterns().map(\.name) == ["Shark"])
        #expect(sessions.leagues().isEmpty)
    }

    @Test func createLeagueLinksItsCenter() throws {
        let center = try sessions.createCenter(name: "Sunset Lanes")
        let league = try sessions.createLeague(name: "Tuesday Trios", centerID: center)
        #expect(try store.context.league(league).center?.id == center)
        #expect(sessions.leagues() == [NamedRef(id: league, name: "Tuesday Trios")])
    }

    @Test func createLeagueWithMissingCenterSavesNothing() throws {
        #expect(throws: RepositoryError.notFound) { try sessions.createLeague(name: "Trios", centerID: UUID()) }
        #expect(sessions.leagues().isEmpty)
    }

    @Test func placeNamesAreTrimmed() throws {
        let center = try sessions.createCenter(name: "  Sunset Lanes\n")
        let league = try sessions.createLeague(name: "\tTuesday Trios ", centerID: center)
        let pattern = try sessions.createOilPattern(name: " Shark  ")
        #expect(sessions.centers() == [NamedRef(id: center, name: "Sunset Lanes")])
        #expect(sessions.leagues() == [NamedRef(id: league, name: "Tuesday Trios")])
        #expect(sessions.oilPatterns() == [NamedRef(id: pattern, name: "Shark")])
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func blankPlaceNamesAreRefused(_ name: String) throws {
        #expect(throws: RepositoryError.invalidPlace(.emptyName)) { try sessions.createCenter(name: name) }
        #expect(throws: RepositoryError.invalidPlace(.emptyName)) { try sessions.createLeague(name: name, centerID: nil) }
        #expect(throws: RepositoryError.invalidPlace(.emptyName)) { try sessions.createOilPattern(name: name) }
        #expect(sessions.centers().isEmpty)
        #expect(sessions.leagues().isEmpty)
        #expect(sessions.oilPatterns().isEmpty)
    }

    // MARK: League details

    @Test func leagueRecordReadsCenterSeasonAndGamesPerSession() throws {
        let center = try sessions.createCenter(name: "Sunset Lanes")
        let id = try sessions.createLeague(name: "Tuesday Mixed", centerID: center)
        let start = date.addingTimeInterval(-60 * 86_400)
        let end = date.addingTimeInterval(120 * 86_400)
        let league = try store.context.league(id)
        league.seasonStart = start
        league.seasonEnd = end
        league.seasonLabel = "2026-27"
        league.gamesPerSession = 4
        try store.context.save()

        #expect(try sessions.league(id) == LeagueRecord(
            id: id, name: "Tuesday Mixed", centerID: center, seasonLabel: "2026-27",
            seasonStart: start, seasonEnd: end, gamesPerSession: 4
        ))
    }

    @Test func newLeagueHasNoCenterNoSeasonAndThreeGames() throws {
        let id = try sessions.createLeague(name: "Sunday Doubles", centerID: nil)
        #expect(try sessions.league(id) == LeagueRecord(
            id: id, name: "Sunday Doubles", centerID: nil, seasonLabel: "",
            seasonStart: nil, seasonEnd: nil, gamesPerSession: 3
        ))
    }

    @Test func leagueRecordsListByName() throws {
        let sunday = try sessions.createLeague(name: "sunday Doubles", centerID: nil)
        let monday = try sessions.createLeague(name: "Monday Majors", centerID: nil)
        #expect(sessions.leagueRecords().map(\.id) == [monday, sunday])
        #expect(sessions.leagueRecords().map(\.name) == sessions.leagues().map(\.name))
    }

    @Test func leagueRecordsForACenterListOnlyItsLeaguesByName() throws {
        let sunset = try sessions.createCenter(name: "Sunset Lanes")
        let bay = try sessions.createCenter(name: "AMF Bay")
        let trios = try sessions.createLeague(name: "Trios", centerID: sunset)
        let majors = try sessions.createLeague(name: "Majors", centerID: sunset)
        _ = try sessions.createLeague(name: "Doubles", centerID: bay)
        _ = try sessions.createLeague(name: "Roaming", centerID: nil)

        #expect(sessions.leagueRecords(centerID: sunset).map(\.id) == [majors, trios])
        #expect(sessions.leagueRecords(centerID: UUID()).isEmpty)
    }

    @Test func missingLeagueIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try sessions.league(UUID()) }
    }
}
