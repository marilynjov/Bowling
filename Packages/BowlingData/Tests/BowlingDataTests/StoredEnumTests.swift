import Foundation
import Testing
@testable import BowlingData

@Suite struct StoredEnumTests {
    private static let unknownRaw = "addedInAFutureVersion"

    @Test func unknownRawValuesFallBack() {
        #expect(Bowler.Handedness(stored: Self.unknownRaw) == .unknown)
        #expect(Bowler.StatsProfile(stored: Self.unknownRaw) == .unknown)
        #expect(Session.EventType(stored: Self.unknownRaw) == .casual)
        #expect(Game.EntryMode(stored: Self.unknownRaw) == .pinByPin)
        #expect(Game.InvitationStatus(stored: Self.unknownRaw) == .none)
        #expect(Ball.Coverstock(stored: Self.unknownRaw) == .unknown)
        #expect(Ball.CoreType(stored: Self.unknownRaw) == .unknown)
        #expect(Ball.IntendedRole(stored: Self.unknownRaw) == .strike)
        #expect(MaintenanceEvent.Kind(stored: Self.unknownRaw) == .other)
    }

    /// Stored strings from before the alias to the BowlingCore enums.
    @Test func ballEnumsKeepTheirStoredRawValues() {
        #expect(Ball.Coverstock.allCases.map(\.rawValue)
            == ["plastic", "urethane", "reactiveSolid", "reactivePearl", "reactiveHybrid", "other", "unknown"])
        #expect(Ball.CoreType.allCases.map(\.rawValue) == ["symmetric", "asymmetric", "pancake", "unknown"])
    }

    @Test func knownRawValuesRoundTrip() {
        for value in Ball.Coverstock.allCases {
            #expect(Ball.Coverstock(stored: value.rawValue) == value)
        }
        for value in Game.EntryMode.allCases {
            #expect(Game.EntryMode(stored: value.rawValue) == value)
        }
    }

    @Test func unknownStoredValueReadsAsFallbackAndIsKept() {
        let game = Game(gameIndex: 1)
        game.invitationStatus = Self.unknownRaw

        #expect(game.invitationStatusValue == .none)
        #expect(game.invitationStatus == Self.unknownRaw)
    }

    @Test func settingTypedValueWritesRawString() {
        let ball = Ball(name: "Phaze", weightPounds: 15)
        ball.coverstockValue = .reactiveSolid
        #expect(ball.coverstock == "reactiveSolid")
    }

    @Test func newModelsUseSpecDefaults() {
        #expect(Bowler(name: "Sam").handednessValue == .unknown)
        #expect(Bowler(name: "Sam").statsProfileValue == .unknown)
        #expect(Game(gameIndex: 1).invitationStatusValue == .none)
        #expect(Ball(name: "Phaze", weightPounds: 15).intendedRoleValue == .strike)
        #expect(Ball(name: "Phaze", weightPounds: 15).coverstockValue == .unknown)
        #expect(League(name: "Tuesday").gamesPerSession == 3)
        #expect(Roll(rollIndex: 1).isFoul == false)
    }
}
