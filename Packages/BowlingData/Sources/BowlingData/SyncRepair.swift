import BowlingCore
import Foundation
import SwiftData

/// What the repairs after a sync import changed that a screen may be showing.
public struct SyncRepairResult: Sendable, Hashable {
    /// Duplicate games deleted (§3.4 "Duplicate games"). A screen holding one, such as
    /// Scoring, has to leave it.
    public var deletedGames: Set<GameID> = []
}

extension BowlingStore {
    /// Every repair §3.4 needs after sync, in its order: duplicate games, frames, and rolls;
    /// then games relinked to their bowler; then the owner merge. The app calls it at launch
    /// and after each finished, successful CloudKit import event. Sync never signals that
    /// every record has arrived, so each step is idempotent and safe to run again.
    @discardableResult
    public func repairSyncedData() throws -> SyncRepairResult {
        let duplicates = try games.repairDuplicates()
        try relinkGamesToTheirBowlers()
        try mergeOwners()
        return SyncRepairResult(deletedGames: duplicates.deleted)
    }

    /// §3.4 "Games with no bowler": CloudKit does not import relationships atomically, so a
    /// game can arrive before its Bowler row. Links each game with no bowler to the Bowler
    /// whose id equals its `bowlerID`, without relying on Core Data to finish the link.
    /// Restores a value another device wrote, so neither `updatedAt` nor `lineupIndex`
    /// changes. A game whose bowler has not arrived, or was deleted, keeps waiting.
    func relinkGamesToTheirBowlers() throws {
        let orphans = try context.fetch(FetchDescriptor<Game>(
            predicate: #Predicate { $0.bowler == nil && $0.bowlerID != nil }
        ))
        let ids = Array(Set(orphans.compactMap(\.bowlerID)))
        guard !ids.isEmpty else { return }
        let bowlers = try context.fetch(FetchDescriptor<Bowler>(predicate: #Predicate { ids.contains($0.id) }))
        // Two rows share an ID only as a sync duplicate; merge order picks the same one
        // on every device.
        let byID = Dictionary(bowlers.sorted(by: Bowler.mergeOrder).map { ($0.id, $0) }) { first, _ in first }
        let found = orphans.compactMap { game in game.bowlerID.flatMap { byID[$0] }.map { (game, $0) } }
        guard !found.isEmpty else { return }
        try context.write {
            for (game, bowler) in found { game.assign(bowler) }
        }
    }
}
