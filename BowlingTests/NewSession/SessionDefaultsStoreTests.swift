import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct SessionDefaultsStoreTests {
    let suite = UserDefaults(suiteName: "test.\(UUID())")!
    let store: SessionDefaultsStore

    init() {
        store = SessionDefaultsStore(suite)
    }

    @Test func valuesRoundTripPerEventType() {
        let d = SessionDefaults(centerID: UUID(), leagueID: UUID(), oilPatternID: UUID(), ballID: UUID(), entryMode: .countOnly)
        store.save(d, for: .league)
        #expect(store.defaults(for: .league) == d)
    }

    @Test func savingLeagueLeavesPracticeAlone() {
        let practice = SessionDefaults(centerID: UUID(), entryMode: .finalOnly)
        store.save(practice, for: .practice)
        store.save(SessionDefaults(centerID: UUID()), for: .league)
        #expect(store.defaults(for: .practice) == practice)
        #expect(store.defaults(for: .tournament) == SessionDefaults())
    }

    @Test func unreadableDataReadsAsEmpty() {
        suite.set(Data("nope".utf8), forKey: "newSession.defaults.league")
        #expect(store.defaults(for: .league) == SessionDefaults())
    }

    @Test func lastEventTypeRoundTrips() {
        #expect(store.lastEventType == .practice)
        store.save(SessionDefaults(), for: .tournament)
        #expect(store.lastEventType == .tournament)
        suite.set("bogus", forKey: "newSession.lastEventType")
        #expect(store.lastEventType == .practice)
    }
}
