import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct NewSessionDraftTests {
    let store: BowlingStore
    let owner: BowlerRecord
    let friend: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        friend = try store.bowlers.createBowler(name: "Ana")
    }

    private static let nothing = Available(centers: [], leagues: [], oilPatterns: [], balls: [])

    @Test func startsWithTheOwnerAlone() {
        let d = NewSessionDraft(owner: owner, date: .now)
        #expect(d.lineup.map(\.bowlerID) == [owner.id])
        #expect(d.lineup.first?.isOwner == true)
        #expect(d.entryMode == .pinByPin)
    }

    @Test func onlyLeagueSessionsKeepTheLeague() {
        var d = NewSessionDraft(owner: owner, date: .now, eventType: .league)
        d.leagueID = UUID()
        #expect(d.metadata.leagueID == d.leagueID)
        d.eventType = .practice
        #expect(d.metadata.leagueID == nil)
        #expect(d.defaults.leagueID == nil)
    }

    @Test func ownerCantBeRemoved() {
        var d = NewSessionDraft(owner: owner, date: .now)
        d.add(friend)
        d.remove(atOffsets: [0, 1])
        #expect(d.lineup.map(\.bowlerID) == [owner.id])
    }

    @Test func addingABowlerTwiceAddsOne() {
        var d = NewSessionDraft(owner: owner, date: .now)
        d.add(friend)
        d.add(friend)
        d.add(owner)
        #expect(d.lineup.map(\.bowlerID) == [owner.id, friend.id])
    }

    @Test func applyingDropsMissingIDs() {
        let kept = UUID()
        let d = NewSessionDraft(owner: owner, date: .now).applying(
            SessionDefaults(centerID: kept, leagueID: UUID(), oilPatternID: UUID(), ballID: UUID(), entryMode: .countOnly),
            available: Available(centers: [kept], leagues: [], oilPatterns: [], balls: [])
        )
        #expect(d.centerID == kept)
        #expect(d.leagueID == nil && d.oilPatternID == nil && d.ownerBallID == nil)
        #expect(d.entryMode == .countOnly)
    }

    @Test func applyingNothingGivesPinByPinAndNoPicks() {
        var d = NewSessionDraft(owner: owner, date: .now)
        d.centerID = UUID()
        d.entryMode = .finalOnly
        d = d.applying(SessionDefaults(), available: Self.nothing)
        #expect(d.centerID == nil && d.entryMode == .pinByPin)
    }

    @Test func switchingEventsRestoresEachTypesValues() {
        let league = UUID(), center = UUID()
        let all = Available(centers: [center], leagues: [league], oilPatterns: [], balls: [])
        var d = NewSessionDraft(owner: owner, date: .now, eventType: .league)
        d.add(friend)
        d.lanes = "13–14"
        d = d.applying(SessionDefaults(centerID: center, leagueID: league), available: all)
        d.eventType = .practice
        d = d.applying(SessionDefaults(), available: all)
        #expect(d.metadata.leagueID == nil && d.centerID == nil)
        d.eventType = .league
        d = d.applying(SessionDefaults(centerID: center, leagueID: league), available: all)
        #expect(d.metadata.leagueID == league && d.centerID == center)
        #expect(d.lanes == "13–14" && d.lineup.count == 2)
    }

    @Test func startCreatesOneGamePerBowlerInLineupOrder() throws {
        let ball = try store.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "Storm")
        var d = NewSessionDraft(owner: owner, date: .now)
        d.add(friend)
        d.move(fromOffsets: [1], toOffset: 0)
        d.ownerBallID = ball.id
        d.entryMode = .countOnly
        let detail = try store.sessions.session(try d.start(in: store.sessions))
        #expect(detail.bowlers.map(\.bowler.id) == [friend.id, owner.id])
        #expect(detail.bowlers.map { $0.games.count } == [1, 1])
        #expect(detail.bowlers[1].games[0].defaultBallID == ball.id)
        #expect(detail.bowlers[0].games[0].defaultBallID == nil)
        #expect(detail.bowlers[0].games[0].entryMode == .countOnly)
    }

    @Test func addBowlerListsOthersButChecksNamesAgainstEveryone() {
        var d = NewSessionDraft(owner: owner, date: .now)
        let all = store.bowlers.bowlers()
        #expect(d.addBowlerChoices(from: all).candidates.map(\.id) == [friend.id])
        d.add(friend)
        let choices = d.addBowlerChoices(from: all)
        #expect(choices.candidates.isEmpty)
        #expect(choices.addName(for: "ana") == nil)
        #expect(choices.addName(for: " sam ") == nil)
        #expect(choices.addName(for: "Luz") == "Luz")
    }

    @Test func leaguesFollowThePickedCenter() throws {
        let a = try store.sessions.createCenter(name: "AMF Bowl")
        let b = try store.sessions.createCenter(name: "Sunset Lanes")
        _ = try store.sessions.createLeague(name: "Tuesday Mixed", centerID: a)
        _ = try store.sessions.createLeague(name: "Friday Night", centerID: b)
        _ = try store.sessions.createLeague(name: "Open Doubles", centerID: nil)
        let records = store.sessions.leagueRecords()
        var d = NewSessionDraft(owner: owner, date: .now, eventType: .league)
        #expect(d.leagues(from: records).map(\.name) == ["Open Doubles"])
        d.centerID = a
        #expect(d.leagues(from: records).map(\.name) == ["Tuesday Mixed"])
        d.centerID = b
        let names = d.leagues(from: records).map(\.name)
        #expect(names == ["Friday Night"])
        #expect(NameSearch.addName(for: "tuesday mixed", existing: names) == "tuesday mixed")
    }

    @Test func changingTheCenterClearsTheLeague() {
        let a = UUID(), league = UUID()
        var d = NewSessionDraft(owner: owner, date: .now, eventType: .league)
        d.centerID = a
        d.leagueID = league
        d.centerID = a
        #expect(d.leagueID == league)
        d.centerID = UUID()
        #expect(d.leagueID == nil)
    }
}
