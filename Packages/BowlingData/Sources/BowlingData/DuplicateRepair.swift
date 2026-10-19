import BowlingCore
import Foundation
import SwiftData

extension GameRepository {
    /// §3.4: an unfinished game resumed on two devices while offline can sync back two
    /// Frame rows with one `frameIndex`, or two Roll rows with one `rollIndex` in a frame.
    /// Keeps the row with the newest `updatedAt` per index (a frame counts its rolls' too,
    /// since frames written before they were stamped on roll edits carry their creation
    /// time), ties to the smaller UUID string, so every device keeps the same rows; deletes
    /// the others and rescores the game.
    ///
    /// The kept rows can still form an invalid game, such as two rolls that each fit their
    /// own device's frame but not each other. Rolls are then cleared from the first one that
    /// no longer fits, as `replaceRoll` does, so every device ends with the same valid game.
    ///
    /// Also rescores every countOnly or pinByPin game whose cached `finalScore` or
    /// `isComplete` is stale, such as one whose rows were imported before its cached values,
    /// and stamps `updatedAt` only on a game that changed. Phase 2 calls it after every
    /// remote import.
    /// - Returns: The games that changed.
    func repairDuplicates() throws -> Set<GameID> {
        // TODO(Phase 2): read SwiftData persistent history to visit only the games an import
        // touched; every game is fetched for now.
        let games = try context.fetch(FetchDescriptor<Game>())
        return try context.write {
            try Set(games.filter { game in
                if game.removeDuplicateRows(in: context) {
                    try game.apply(Self.scored(Self.clearedFromFirstInvalidRoll(game.record())), in: context)
                    return true
                }
                // A finalOnly score is typed, and an unknown mode's comes from a newer app that
                // may not score from rolls, so this device must not overwrite either.
                let record = game.record()
                guard [.countOnly, .pinByPin].contains(record.entryMode) else { return false }
                let scored = Self.scored(record)
                guard (scored.finalScore, scored.isComplete) != (game.finalScore, game.isComplete) else { return false }
                game.finalScore = scored.finalScore
                game.isComplete = scored.isComplete
                game.updatedAt = .now
                return true
            }.map(\.id))
        }
    }

    /// `record` with its rolls kept, in order, up to the first one that does not validate.
    private static func clearedFromFirstInvalidRoll(_ record: GameRecord) -> GameRecord {
        guard !Scorer.validate(record).isEmpty else { return record }
        let rolls = record.frames.flatMap { frame in frame.rolls.map { (frameIndex: frame.frameIndex, roll: $0) } }
        var kept: [(frameIndex: Int, roll: RollRecord)] = []
        for next in rolls {
            var candidate = record
            candidate.frames = frames(kept + [next])
            guard Scorer.validate(candidate).isEmpty else { break }
            kept.append(next)
        }
        var cleared = record
        cleared.frames = frames(kept)
        return cleared
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
            let sorted = group.sorted { ($0.lastEdited, $1.id.uuidString) > ($1.lastEdited, $0.id.uuidString) }
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
    var lastEdited: Date { get }
    func detach()
}

extension Frame: SyncedRow {
    fileprivate var lastEdited: Date { (rolls ?? []).map(\.updatedAt).reduce(updatedAt, max) }
    fileprivate func detach() { game = nil }
}

extension Roll: SyncedRow {
    fileprivate var lastEdited: Date { updatedAt }
    fileprivate func detach() { frame = nil }
}
