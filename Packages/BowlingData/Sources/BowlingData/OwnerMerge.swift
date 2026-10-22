import BowlingCore
import Foundation
import SwiftData

extension BowlingStore {
    /// Spec §3.4 "Two owners": sync can deliver another device's owner next to this one.
    /// Keeps the oldest owner (ties broken by the smaller UUID string), moves every game of
    /// the others to it, copies the non-empty fields it lacks, and deletes the others.
    /// Deterministic, so every device reaches the same store, and a second run changes
    /// nothing. Phase 2 calls it after every remote import, after `repairDuplicates()`:
    /// this merge renumbers clashing `gameIndex` values, which would hide duplicate games.
    ///
    /// Games with no bowler also go to the kept owner: sync can deliver a game whose
    /// bowler another device deleted. A game whose `bowlerID` names someone other than an
    /// owner is skipped: its bowler may not be imported yet, and claiming it would put a
    /// friend's games in the owner's stats. The rest of the orphan rule is #89.
    func mergeOwners() throws {
        let owners = try context.fetch(FetchDescriptor<Bowler>(predicate: #Predicate { $0.isOwner }))
            .sorted(by: Bowler.mergeOrder)
        let ownerIDs = Set(owners.map(\.id))
        let orphans = try context.fetch(FetchDescriptor<Game>(predicate: #Predicate { $0.bowler == nil }))
            .filter { $0.bowlerID.map(ownerIDs.contains) ?? true }
        guard let kept = owners.first, owners.count > 1 || !orphans.isEmpty else { return }
        try context.write {
            moveGames(owners.map { $0.games ?? [] } + [orphans], to: kept)
            // Oldest first, so when several owners have a field the oldest one's value wins.
            let copied = owners.dropFirst().map { kept.copyMissingFields(from: $0) }
            if copied.contains(true) { kept.updatedAt = .now }
            for other in owners.dropFirst() { context.delete(other) }
        }
    }

    /// A session two owners bowled in would otherwise hold two games with the same
    /// `gameIndex` and two lineup positions for one bowler. The first owner in merge order
    /// keeps its games' positions there. A moved game keeps its `gameIndex` when the kept
    /// owner has no game with it in that session; the ones that clash go after the
    /// highest, in merge order. Moved games take the first owner's `lineupIndex`. Orphan
    /// games come last, after every owner's.
    private func moveGames(_ groups: [[Game]], to kept: Bowler) {
        var taken: [PersistentIdentifier: Set<Int>] = [:]
        var lineup: [PersistentIdentifier: Int] = [:]
        var clashes: [(game: Game, session: PersistentIdentifier)] = []
        for (rank, games) in groups.enumerated() {
            for game in games.sorted(by: Game.mergeOrder) {
                if let session = game.session?.persistentModelID {
                    if rank > 0, let first = lineup[session] { game.lineupIndex = first }
                    lineup[session] = game.lineupIndex
                    if rank > 0, taken[session]?.contains(game.gameIndex) == true {
                        clashes.append((game, session))
                    } else {
                        taken[session, default: []].insert(game.gameIndex)
                    }
                }
                if game.bowler !== kept {
                    game.assign(kept)
                    game.updatedAt = .now
                }
            }
        }
        for (game, session) in clashes {
            game.gameIndex = (taken[session]?.max() ?? 0) + 1
            taken[session, default: []].insert(game.gameIndex)
        }
    }
}

extension Bowler {
    /// The order `ModelContext.owner()` and the merge agree on: oldest first, ties broken by
    /// the smaller UUID string.
    static func mergeOrder(_ lhs: Bowler, _ rhs: Bowler) -> Bool {
        (lhs.createdAt, lhs.id.uuidString) < (rhs.createdAt, rhs.id.uuidString)
    }

    /// Empty strings count as missing, and so does "unknown" in the enum fields. Missing is
    /// decided on the stored string, not the decoded enum: a raw value from a newer app
    /// decodes as `.unknown` here but is a real value. Returns whether anything was copied.
    fileprivate func copyMissingFields(from other: Bowler) -> Bool {
        var copied = false
        func fill(_ field: ReferenceWritableKeyPath<Bowler, String>, isMissing: (String) -> Bool) {
            guard isMissing(self[keyPath: field]), !isMissing(other[keyPath: field]) else { return }
            self[keyPath: field] = other[keyPath: field]
            copied = true
        }
        let isUnset: (String) -> Bool = { $0.isEmpty || $0 == "unknown" }
        fill(\.name) { $0.isEmpty }
        fill(\.handedness, isMissing: isUnset)
        fill(\.statsProfile, isMissing: isUnset)
        fill(\.statsLayout) { $0.isEmpty }
        fill(\.homeLayout) { $0.isEmpty }
        fill(\.statsScope, isMissing: isUnset)
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
