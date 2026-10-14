import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BowlerRepositoryTests {
    let store: BowlingStore
    var bowlers: BowlerRepository { store.bowlers }

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    private func bowlerCount() throws -> Int {
        try store.context.fetchCount(FetchDescriptor<Bowler>())
    }

    // MARK: Owner invariant

    @Test func noOwnerBeforeFirstLaunch() {
        #expect(bowlers.owner() == nil)
    }

    @Test func createOwnerStoresTheFirstLaunchAnswers() throws {
        let owner = try bowlers.createOwner(name: "Sam", handedness: .left, statsProfile: .league)
        #expect(owner.isOwner)
        #expect(owner.name == "Sam")
        #expect(owner.handedness == .left)
        #expect(owner.statsProfile == .league)
        #expect(owner.statsLayout == [])
        #expect(bowlers.owner() == owner)
    }

    @Test func secondOwnerIsRefused() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        #expect(throws: RepositoryError.ownerAlreadyExists) {
            try bowlers.createOwner(name: "Alex", handedness: .right, statsProfile: .casual)
        }
        #expect(try bowlerCount() == 1)
    }

    @Test func createdBowlersAreNeverOwners() throws {
        let other = try bowlers.createBowler(name: "Alex")
        #expect(!other.isOwner)
        #expect(bowlers.owner() == nil)
    }

    @Test func ownerAfterSyncDuplicateIsTheOldest() throws {
        let newer = Bowler(name: "Newer", isOwner: true)
        let older = Bowler(name: "Older", isOwner: true)
        older.createdAt = newer.createdAt.addingTimeInterval(-60)
        store.context.insert(newer)
        store.context.insert(older)
        try store.context.save()

        #expect(bowlers.owner()?.id == older.id)
    }

    // MARK: Listing

    @Test func bowlersListOwnerFirstThenByName() throws {
        _ = try bowlers.createBowler(name: "zoe")
        _ = try bowlers.createBowler(name: "Alex")
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        #expect(bowlers.bowlers().map(\.name) == ["Sam", "Alex", "zoe"])
    }

    @Test func layoutsSplitIntoCardIDs() throws {
        let owner = Bowler(name: "Sam", isOwner: true)
        owner.statsLayout = "average,futureCard,strikePct"
        store.context.insert(owner)
        #expect(bowlers.owner()?.statsLayout == ["average", "futureCard", "strikePct"])
        #expect(bowlers.owner()?.homeLayout == [])
    }

    // MARK: Updates

    @Test func updateOwnerChangesNameAndHandedness() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try bowlers.updateOwner(name: "Samantha", handedness: .left)
        #expect(bowlers.owner()?.name == "Samantha")
        #expect(bowlers.owner()?.handedness == .left)
    }

    @Test func updateOwnerWithoutOwnerIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try bowlers.updateOwner(name: "Sam", handedness: .left) }
        #expect(throws: RepositoryError.notFound) { try bowlers.setStatsProfile(.league) }
    }

    @Test func setStatsProfileChangesOnlyTheProfile() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try bowlers.setStatsProfile(.competitive)
        #expect(bowlers.owner()?.statsProfile == .competitive)
    }

    // MARK: Stats scope (OQ-14)

    @Test func statsScopeFollowsTheBowlingStyleUntilChosen() throws {
        let owner = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        #expect(owner.statsScope == nil)
        try bowlers.setStatsProfile(.casual)
        #expect(bowlers.owner()?.statsScope == nil)
    }

    @Test func setStatsScopeStoresAnExplicitChoice() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try bowlers.setStatsScope(.competition)
        #expect(bowlers.owner()?.statsScope == .competition)
        try bowlers.setStatsScope(nil)
        #expect(bowlers.owner()?.statsScope == nil)
    }

    @Test(arguments: [StatsScope.competition, .all], [StatsProfile.casual, .league, .competitive])
    func styleChangeNeverOverwritesAnExplicitScope(_ scope: StatsScope, _ profile: StatsProfile) throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        try bowlers.setStatsScope(scope)
        try bowlers.setStatsProfile(profile)
        #expect(bowlers.owner()?.statsScope == scope)
    }

    @Test func setStatsScopeWithoutOwnerIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try bowlers.setStatsScope(.all) }
    }

    // MARK: Unknown raw values

    @Test func unknownStoredValuesReadAsUnknownAndSurviveUnrelatedWrites() throws {
        let owner = Bowler(name: "Sam", isOwner: true)
        owner.handedness = "ambidextrous"
        owner.statsProfile = "bowlingCoach"
        owner.statsScope = "lastSeason"
        store.context.insert(owner)

        #expect(bowlers.owner()?.handedness == .unknown)
        #expect(bowlers.owner()?.statsProfile == .unknown)
        #expect(bowlers.owner()?.statsScope == nil)

        try bowlers.updateOwner(name: "Samantha", handedness: .unknown)
        try bowlers.setStatsProfile(.unknown)
        try bowlers.setStatsScope(.unknown)
        #expect(owner.handedness == "ambidextrous")
        #expect(owner.statsProfile == "bowlingCoach")
        #expect(owner.statsScope == "lastSeason")
    }

    // MARK: Delete refusals

    @Test func ownerCannotBeDeleted() throws {
        let owner = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        #expect(throws: RepositoryError.cannotDeleteOwner) { try bowlers.deleteBowler(owner.id) }
        #expect(try bowlerCount() == 1)
    }

    @Test func bowlerWithGamesCannotBeDeleted() throws {
        let other = try bowlers.createBowler(name: "Alex")
        let model = try #require(try store.context.fetch(FetchDescriptor<Bowler>()).first)
        for index in 1...2 {
            let game = Game(gameIndex: index)
            store.context.insert(game)
            game.bowler = model
        }
        try store.context.save()

        #expect(throws: RepositoryError.bowlerHasGames(count: 2)) { try bowlers.deleteBowler(other.id) }
        #expect(try bowlerCount() == 1)
    }

    @Test func bowlerWithoutGamesIsDeleted() throws {
        let other = try bowlers.createBowler(name: "Alex")
        try bowlers.deleteBowler(other.id)
        #expect(try bowlerCount() == 0)
    }

    @Test func deletingMissingBowlerIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try bowlers.deleteBowler(UUID()) }
    }
}
