import BowlingCore
import Foundation
import SwiftData

public struct BowlerRecord: Sendable, Hashable, Identifiable {
    public var id: BowlerID
    public var name: String
    public var isOwner: Bool
    public var handedness: Handedness
    /// Meaningful on the owner only.
    public var statsProfile: StatsProfile
    /// Raw stats card IDs, unknown ones included; empty means the profile's preset.
    public var statsLayout: [String]
    /// Raw Home tile card IDs; empty means the profile's preset.
    public var homeLayout: [String]
}

@MainActor
public final class BowlerRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Nil before first launch completes.
    public func owner() -> BowlerRecord? {
        context.owner()?.record()
    }

    /// The owner first, then everyone else by name.
    public func bowlers() -> [BowlerRecord] {
        let all = (try? context.fetch(FetchDescriptor<Bowler>())) ?? []
        let owner = context.owner()
        let others = all.filter { $0 !== owner }.sorted(by: Bowler.byName)
        return ([owner].compactMap(\.self) + others).map { $0.record() }
    }

    /// - Throws: `.ownerAlreadyExists` when an owner exists.
    public func createOwner(name: String, handedness: Handedness, statsProfile: StatsProfile) throws -> BowlerRecord {
        guard context.owner() == nil else { throw RepositoryError.ownerAlreadyExists }
        return try context.write {
            let owner = Bowler(name: name, isOwner: true)
            owner.handedness = handedness.rawValue
            owner.statsProfile = statsProfile.rawValue
            context.insert(owner)
            return owner.record()
        }
    }

    public func createBowler(name: String) throws -> BowlerRecord {
        try context.write {
            let bowler = Bowler(name: name)
            context.insert(bowler)
            return bowler.record()
        }
    }

    /// `.unknown` handedness keeps the stored value.
    public func updateOwner(name: String, handedness: Handedness) throws {
        guard let owner = context.owner() else { throw RepositoryError.notFound }
        try context.write {
            owner.name = name
            if handedness != .unknown { owner.handedness = handedness.rawValue }
            owner.updatedAt = .now
        }
    }

    /// Leaves a customized layout alone. `.unknown` keeps the stored value.
    public func setStatsProfile(_ profile: StatsProfile) throws {
        guard let owner = context.owner() else { throw RepositoryError.notFound }
        try context.write {
            if profile != .unknown { owner.statsProfile = profile.rawValue }
            owner.updatedAt = .now
        }
    }

    /// - Throws: `.cannotDeleteOwner`, or `.bowlerHasGames(count:)` so the user can delete
    ///   the games first.
    public func deleteBowler(_ id: BowlerID) throws {
        let bowler = try context.bowler(id)
        guard !bowler.isOwner else { throw RepositoryError.cannotDeleteOwner }
        let gameCount = bowler.games?.count ?? 0
        guard gameCount == 0 else { throw RepositoryError.bowlerHasGames(count: gameCount) }
        try context.write { context.delete(bowler) }
    }
}

extension Bowler {
    func record() -> BowlerRecord {
        BowlerRecord(
            id: id,
            name: name,
            isOwner: isOwner,
            handedness: BowlingCore.Handedness(storedValue: handedness),
            statsProfile: BowlingCore.StatsProfile(storedValue: statsProfile),
            statsLayout: Self.cardIDs(statsLayout),
            homeLayout: Self.cardIDs(homeLayout)
        )
    }

    static func byName(_ lhs: Bowler, _ rhs: Bowler) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    /// The owner first, then by name.
    static func ownerThenName(_ lhs: Bowler, _ rhs: Bowler) -> Bool {
        lhs.isOwner != rhs.isOwner ? lhs.isOwner : byName(lhs, rhs)
    }

    private static func cardIDs(_ layout: String) -> [String] {
        layout.split(separator: ",").map(String.init)
    }
}
