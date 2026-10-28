import Foundation
import Testing
import BowlingCore

@Suite struct StoredEnumTests {
    private func decode<T: Decodable>(_ type: T.Type, _ raw: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data("\"\(raw)\"".utf8))
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    @Test func rawValuesAreTheStoredStrings() {
        #expect(EntryMode.allCases.map(\.rawValue) == ["pinByPin", "countOnly", "finalOnly", "unknown"])
        #expect(EventType.allCases.map(\.rawValue) == ["practice", "league", "tournament", "casual", "unknown"])
        #expect(StatsProfile.allCases.map(\.rawValue) == ["casual", "league", "competitive", "unknown"])
        #expect(Handedness.allCases.map(\.rawValue) == ["right", "left", "unknown"])
        #expect(BallRole.allCases.map(\.rawValue) == ["strike", "spare", "both", "unknown"])
        #expect(StatsScope.allCases.map(\.rawValue) == ["competition", "all", "unknown"])
        #expect(Coverstock.allCases.map(\.rawValue)
            == ["plastic", "urethane", "reactiveSolid", "reactivePearl", "reactiveHybrid", "other", "unknown"])
        #expect(CoreType.allCases.map(\.rawValue) == ["symmetric", "asymmetric", "pancake", "unknown"])
    }

    @Test func knownValuesRoundTrip() throws {
        for value in EntryMode.allCases { #expect(try roundTrip(value) == value) }
        for value in EventType.allCases { #expect(try roundTrip(value) == value) }
        for value in StatsProfile.allCases { #expect(try roundTrip(value) == value) }
        for value in Handedness.allCases { #expect(try roundTrip(value) == value) }
        for value in BallRole.allCases { #expect(try roundTrip(value) == value) }
        for value in StatsScope.allCases { #expect(try roundTrip(value) == value) }
        for value in Coverstock.allCases { #expect(try roundTrip(value) == value) }
        for value in CoreType.allCases { #expect(try roundTrip(value) == value) }
    }

    @Test func unknownRawValuesDecodeToUnknown() throws {
        #expect(try decode(EntryMode.self, "voice") == .unknown)
        #expect(try decode(EventType.self, "funLeague") == .unknown)
        #expect(try decode(StatsProfile.self, "pro") == .unknown)
        #expect(try decode(Handedness.self, "both") == .unknown)
        #expect(try decode(BallRole.self, "polished") == .unknown)
        #expect(try decode(StatsScope.self, "lastSeason") == .unknown)
        #expect(try decode(Coverstock.self, "polyester") == .unknown)
        #expect(try decode(CoreType.self, "dualDensity") == .unknown)
    }

    @Test func storedValueInitFallsBack() {
        #expect(EntryMode(storedValue: "countOnly") == .countOnly)
        #expect(EntryMode(storedValue: "") == .unknown)
        #expect(EventType(storedValue: "League") == .unknown)
        #expect(StatsProfile(storedValue: "x") == .unknown)
        #expect(Handedness(storedValue: "left") == .left)
        #expect(BallRole(storedValue: "x") == .unknown)
        #expect(StatsScope(storedValue: "all") == .all)
        #expect(StatsScope(storedValue: "") == .unknown)
        #expect(Coverstock(storedValue: "reactivePearl") == .reactivePearl)
        #expect(CoreType(storedValue: "x") == .unknown)
    }

    @Test func unknownStatsProfileIsTreatedAsCasual() {
        #expect(StatsProfile.unknown.effective == .casual)
        #expect(StatsProfile.competitive.effective == .competitive)
    }

    @Test func competitionIsLeagueAndTournament() {
        #expect(EventType.competition == [.league, .tournament])
    }
}
