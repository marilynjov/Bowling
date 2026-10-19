import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct StartSessionTests {
    let app: AppModel
    let owner: BowlerRecord
    let friend: BowlerRecord

    init() throws {
        app = AppModel(
            store: try BowlingStore(inMemory: true),
            sessionDefaults: SessionDefaultsStore(UserDefaults(suiteName: "test.\(UUID())")!)
        )
        owner = try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
        friend = try app.write { try $0.bowlers.createBowler(name: "Ana") }
        app.isStartingSession = true
    }

    @Test func startOpensScoringAndRemembersValues() throws {
        let center = try app.write { try $0.sessions.createCenter(name: "Sunset") }
        var d = NewSessionDraft(owner: owner, date: .now, eventType: .league)
        d.centerID = center
        d.entryMode = .countOnly
        try app.startSession(d)
        let target = try #require(app.scoring)
        #expect(!app.isStartingSession)
        #expect(try app.store.sessions.session(target.sessionID).bowlers.first?.games.first?.id == target.gameID)
        #expect(app.sessionDefaults.defaults(for: .league) == SessionDefaults(centerID: center, entryMode: .countOnly))
        #expect(app.sessionDefaults.lastEventType == .league)
    }

    @Test func scoringOpensOnTheFirstLineupBowler() throws {
        var d = NewSessionDraft(owner: owner, date: .now)
        d.add(friend)
        d.move(fromOffsets: [1], toOffset: 0)
        try app.startSession(d)
        let target = try #require(app.scoring)
        let detail = try app.store.sessions.session(target.sessionID)
        #expect(detail.bowlers.map(\.bowler.id) == [friend.id, owner.id])
        #expect(detail.bowlers[0].games[0].id == target.gameID)
    }

    @Test func failedStartSavesNothing() {
        var d = NewSessionDraft(owner: owner, date: .now, eventType: .tournament)
        d.centerID = UUID()   // not in the store: startSession throws .notFound
        #expect(throws: RepositoryError.notFound) { try app.startSession(d) }
        #expect(app.scoring == nil && app.isStartingSession)
        #expect(app.sessionDefaults.defaults(for: .tournament) == SessionDefaults())
        #expect(app.store.sessions.sessions().isEmpty)
    }

    @Test func secondStartAfterSuccessDoesNothing() throws {
        let d = NewSessionDraft(owner: owner, date: .now)
        try app.startSession(d)
        try app.startSession(d)
        #expect(app.store.sessions.sessions().count == 1)
    }
}
