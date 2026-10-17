import BowlingCore
import Foundation
import SwiftData

extension GameRepository {
    /// §3.4: an unfinished game resumed on two devices while offline can sync back two
    /// Frame rows with one `frameIndex`, or two Roll rows with one `rollIndex` in a frame.
    /// Keeps the row with the newest `updatedAt` per index, ties to the smaller UUID string,
    /// so every device keeps the same rows; deletes the others and rescores the game.
    ///
    /// Does not validate: repair runs before validation, so a synced game can be saved
    /// again. Phase 2 calls it after every remote import.
    /// - Returns: The games that had duplicates.
    func repairDuplicates() throws -> Set<GameID> {
        let games = try context.fetch(FetchDescriptor<Game>())
        return try context.write {
            Set(games.filter { $0.removeDuplicateRows(in: context) }.map { game in
                let scored = Self.scored(game.record())
                game.finalScore = scored.finalScore
                game.isComplete = scored.isComplete
                game.updatedAt = .now
                return game.id
            })
        }
    }
}

extension Game {
    /// - Returns: Whether any row was deleted.
    fileprivate func removeDuplicateRows(in context: ModelContext) -> Bool {
        var removed = false
        for frame in Self.keepingNewest(frames ?? [], by: \.frameIndex, removed: &removed, in: context) {
            _ = Self.keepingNewest(frame.rolls ?? [], by: \.rollIndex, removed: &removed, in: context)
        }
        return removed
    }

    /// Deletes every row but the newest of each index, and returns the kept rows.
    private static func keepingNewest<Row: PersistentModel & SyncedRow>(
        _ rows: [Row], by index: KeyPath<Row, Int>, removed: inout Bool, in context: ModelContext
    ) -> [Row] {
        Dictionary(grouping: rows, by: { $0[keyPath: index] }).values.map { group in
            let sorted = group.sorted { ($0.updatedAt, $1.id.uuidString) > ($1.updatedAt, $0.id.uuidString) }
            for loser in sorted.dropFirst() {
                // Detached first: until the save, a deleted row is still in the relationship
                // the rescore reads.
                loser.detach()
                context.delete(loser)
                removed = true
            }
            return sorted[0]
        }
    }
}

private protocol SyncedRow: AnyObject {
    var id: UUID { get }
    var updatedAt: Date { get }
    func detach()
}

extension Frame: SyncedRow {
    fileprivate func detach() { game = nil }
}

extension Roll: SyncedRow {
    fileprivate func detach() { frame = nil }
}
