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
    /// Nil follows the bowling style's preference.
    public var statsScope: StatsScope?
    /// A friend hidden from the new session pickers. Always false on the owner.
    public var isArchived: Bool
}

@MainActor
public final class BowlerRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Nil before first launch completes.
    public func owner() -> BowlerRecord? {
        context.owner()?.record()
    }

    /// The owner first, then everyone else by name. Archived friends are left out unless
    /// `includingArchived`, for the screen that manages friends; their past games still
    /// show in History and stats, which read sessions rather than this list.
    public func bowlers(includingArchived: Bool = false) -> [BowlerRecord] {
        let all = (try? context.fetch(FetchDescriptor<Bowler>())) ?? []
        let owner = context.owner()
        let others = all
            .filter { $0 !== owner && (includingArchived || !$0.isArchived) }
            .sorted(by: Bowler.byName)
        return ([owner].compactMap(\.self) + others).map { $0.record() }
    }

    /// - Throws: `.invalidBowler(.emptyName)` for a blank name, `.ownerAlreadyExists` when
    ///   an owner exists.
    public func createOwner(name: String, handedness: Handedness, statsProfile: StatsProfile) throws -> BowlerRecord {
        let name = try Self.validName(name)
        guard context.owner() == nil else { throw RepositoryError.ownerAlreadyExists }
        return try context.write {
            let owner = Bowler(name: name, isOwner: true)
            owner.handedness = handedness.rawValue
            owner.statsProfile = statsProfile.rawValue
            context.insert(owner)
            return owner.record()
        }
    }

    /// - Throws: `.invalidBowler(.emptyName)` for a blank name.
    public func createBowler(name: String) throws -> BowlerRecord {
        let name = try Self.validName(name)
        return try context.write {
            let bowler = Bowler(name: name)
            context.insert(bowler)
            return bowler.record()
        }
    }

    /// `.unknown` handedness keeps the stored value.
    /// - Throws: `.invalidBowler(.emptyName)` for a blank name.
    public func updateOwner(name: String, handedness: Handedness) throws {
        let name = try Self.validName(name)
        guard let owner = context.owner() else { throw RepositoryError.notFound }
        try context.write {
            owner.name = name
            if handedness != .unknown { owner.handedness = handedness.rawValue }
            owner.updatedAt = .now
        }
    }

    /// Leaves a customized layout and an explicit stats scope alone. `.unknown` keeps the
    /// stored value.
    public func setStatsProfile(_ profile: StatsProfile) throws {
        guard let owner = context.owner() else { throw RepositoryError.notFound }
        try context.write {
            if profile != .unknown { owner.statsProfile = profile.rawValue }
            owner.updatedAt = .now
        }
    }

    /// Nil follows the bowling style. `.unknown` keeps the stored value.
    public func setStatsScope(_ scope: StatsScope?) throws {
        guard let owner = context.owner() else { throw RepositoryError.notFound }
        try context.write {
            if scope != .unknown { owner.statsScope = scope?.rawValue ?? "" }
            owner.updatedAt = .now
        }
    }

    /// The name trimmed of surrounding whitespace, as `addBall` stores ball names.
    private static func validName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RepositoryError.invalidBowler(.emptyName) }
        return trimmed
    }

    /// Hides a friend from `bowlers()` and so from the new session pickers, keeping their
    /// games and stats; `false` brings them back.
    /// - Throws: `.cannotArchiveOwner`, `.notFound` for an unknown bowler.
    public func setArchived(_ isArchived: Bool, for id: BowlerID) throws {
        let bowler = try context.bowler(id)
        guard !bowler.isOwner else { throw RepositoryError.cannotArchiveOwner }
        guard bowler.isArchived != isArchived else { return }
        try context.write {
            bowler.isArchived = isArchived
            bowler.updatedAt = .now
        }
    }

    /// Deletes a friend. A friend with games is refused unless `includingGames`, so the app
    /// can show the count from `.bowlerHasGames(count:)` and offer archiving or deleting
    /// everything. With `includingGames` the friend's games go too (their frames, rolls,
    /// and photo by cascade), and so does every session left with no games; sessions that
    /// still hold someone else's games keep them.
    /// - Throws: `.cannotDeleteOwner`, `.bowlerHasGames(count:)` without `includingGames`,
    ///   `.notFound` for an unknown bowler.
    public func deleteBowler(_ id: BowlerID, includingGames: Bool = false) throws {
        let bowler = try context.bowler(id)
        guard !bowler.isOwner else { throw RepositoryError.cannotDeleteOwner }
        let games = bowler.games ?? []
        guard includingGames || games.isEmpty else { throw RepositoryError.bowlerHasGames(count: games.count) }
        try context.write {
            var sessions: [PersistentIdentifier: Session] = [:]
            for game in games {
                if let session = game.session { sessions[session.persistentModelID] = session }
                context.delete(game)
            }
            for session in sessions.values where (session.games ?? []).allSatisfy({ $0.bowler === bowler }) {
                context.delete(session)
            }
            context.delete(bowler)
        }
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
            homeLayout: Self.cardIDs(homeLayout),
            statsScope: Self.scope(statsScope),
            isArchived: isArchived && !isOwner
        )
    }

    static func byName(_ lhs: Bowler, _ rhs: Bowler) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    /// The owner first, then by name.
    static func ownerThenName(_ lhs: Bowler, _ rhs: Bowler) -> Bool {
        lhs.isOwner != rhs.isOwner ? lhs.isOwner : byName(lhs, rhs)
    }

    private static func scope(_ stored: String) -> StatsScope? {
        let scope = StatsScope(storedValue: stored)
        return scope == .unknown ? nil : scope
    }

    private static func cardIDs(_ layout: String) -> [String] {
        layout.split(separator: ",").map(String.init)
    }
}
