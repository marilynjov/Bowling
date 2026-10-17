import BowlingCore
import Foundation
import SwiftData

extension BowlingStore {
    /// Spec §3.4 "Two owners": sync can deliver another device's owner next to this one.
    /// Keeps the oldest owner (ties broken by the smaller UUID string), moves every game of
    /// the others to it, copies the non-empty fields it lacks, and deletes the others.
    /// Deterministic, so every device reaches the same store, and a second run changes
    /// nothing. Phase 2 calls it after every remote import.
    func mergeOwners() throws {
        let owners = try context.fetch(FetchDescriptor<Bowler>(predicate: #Predicate { $0.isOwner }))
            .sorted(by: Bowler.mergeOrder)
        guard owners.count > 1, let kept = owners.first else { return }
        try context.write {
            moveGames(of: owners, to: kept)
            // Oldest first, so when several owners have a field the oldest one's value wins.
            let copied = owners.dropFirst().map { kept.copyMissingFields(from: $0) }
            if copied.contains(true) { kept.updatedAt = .now }
            for other in owners.dropFirst() { context.delete(other) }
        }
    }

    /// A session two owners bowled in would otherwise hold two games with the same
    /// `gameIndex` and two lineup positions for one bowler. The first owner in merge order
    /// keeps its games' positions there; later owners' games follow its last game and take
    /// its `lineupIndex`.
    private func moveGames(of owners: [Bowler], to kept: Bowler) {
        var last: [PersistentIdentifier: (gameIndex: Int, lineupIndex: Int)] = [:]
        for owner in owners {
            var firstSeen: [PersistentIdentifier: (gameIndex: Int, lineupIndex: Int)] = [:]
            for game in (owner.games ?? []).sorted(by: Game.mergeOrder) {
                if let session = game.session?.persistentModelID {
                    if let previous = last[session] {
                        game.gameIndex = previous.gameIndex + 1
                        game.lineupIndex = previous.lineupIndex
                        last[session] = (game.gameIndex, game.lineupIndex)
                    } else {
                        firstSeen[session] = (game.gameIndex, game.lineupIndex)
                    }
                }
                if owner !== kept {
                    game.bowler = kept
                    game.updatedAt = .now
                }
            }
            last.merge(firstSeen) { current, _ in current }
        }
    }
}

extension Bowler {
    /// The order `ModelContext.owner()` and the merge agree on: oldest first, ties broken by
    /// the smaller UUID string.
    static func mergeOrder(_ lhs: Bowler, _ rhs: Bowler) -> Bool {
        (lhs.createdAt, lhs.id.uuidString) < (rhs.createdAt, rhs.id.uuidString)
    }

    /// Unknown enum values and empty strings count as missing. Returns whether anything
    /// was copied.
    fileprivate func copyMissingFields(from other: Bowler) -> Bool {
        var copied = false
        func fill(_ field: ReferenceWritableKeyPath<Bowler, String>, isMissing: (String) -> Bool) {
            guard isMissing(self[keyPath: field]), !isMissing(other[keyPath: field]) else { return }
            self[keyPath: field] = other[keyPath: field]
            copied = true
        }
        fill(\.name) { $0.isEmpty }
        fill(\.handedness) { BowlingCore.Handedness(storedValue: $0) == .unknown }
        fill(\.statsProfile) { BowlingCore.StatsProfile(storedValue: $0) == .unknown }
        fill(\.statsLayout) { $0.isEmpty }
        fill(\.homeLayout) { $0.isEmpty }
        fill(\.statsScope) { StatsScope(storedValue: $0) == .unknown }
        if (email ?? "").isEmpty, let otherEmail = other.email, !otherEmail.isEmpty {
            email = otherEmail
            copied = true
        }
        return copied
    }
}

extension Game {
    /// Ties on `gameIndex` within one bowler only come from sync duplicates; creation time
    /// and then the UUID string keep the order the same on every device.
    fileprivate static func mergeOrder(_ lhs: Game, _ rhs: Game) -> Bool {
        (lhs.gameIndex, lhs.createdAt, lhs.id.uuidString) < (rhs.gameIndex, rhs.createdAt, rhs.id.uuidString)
    }
}
