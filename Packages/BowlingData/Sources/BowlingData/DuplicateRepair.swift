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
    /// First, "Next game" on two offline devices can sync back two games for one bowler with
    /// one `gameIndex` in a session. The bowler is `bowlerID` where set, else `bowler.id`;
    /// games with neither are never treated as duplicates. Keeps the game with the highest
    /// `recordedRollCount`, then the newest `updatedAt`, then the smaller UUID string, and
    /// deletes the others with their frames. Rolls are never merged across games. Only Game
    /// row fields decide, since a copy's Frame and Roll rows may not have arrived yet.
    ///
    /// Also rescores every countOnly or pinByPin game whose cached `finalScore` or
    /// `isComplete` is stale, such as one whose rows were imported before its cached values,
    /// and stamps `updatedAt` only on a game that changed. A game holding fewer rolls than its
    /// `recordedRollCount` is still importing: only its duplicate rows are removed, and it is
    /// neither cleared, rescored, nor stamped, so a partial copy never overwrites the rolls
    /// or the score other devices hold. Phase 2 calls it after every remote import,
    /// before `BowlingStore.mergeOwners()` (§3.4 "Repair order").
    /// - Returns: The games that changed and the duplicate games deleted. Phase 2 needs the
    ///   deleted IDs so a screen showing one of them, such as Scoring, can leave it.
    func repairDuplicates() throws -> DuplicateRepairResult {
        // TODO(Phase 2): read SwiftData persistent history to visit only the games an import
        // touched; every game is fetched for now.
        let games = try context.fetch(FetchDescriptor<Game>())
        return try context.write {
            var deleted: Set<GameID> = []
            let kept = Self.removingDuplicateGames(games, deleted: &deleted, in: context)
            let changed = try kept.filter { game in
                // Counted before the duplicate rows go: a losing frame can hold positions the
                // kept one lacks.
                let isImporting = game.rollsPresent < game.recordedRollCount
                if game.removeDuplicateRows(in: context) {
                    // A gap from rows still on the way would read as invalid and clear every
                    // roll after it, so a game still importing keeps everything else as is.
                    guard !isImporting else { return true }
                    try game.apply(Self.scored(Self.clearedFromFirstInvalidRoll(game.record())), in: context)
                    return true
                }
                // A finalOnly score is typed, and an unknown mode's comes from a newer app that
                // may not score from rolls, so this device must not overwrite either.
                let record = game.record()
                guard [.countOnly, .pinByPin].contains(record.entryMode), !isImporting else { return false }
                let scored = Self.scored(record)
                guard (scored.finalScore, scored.isComplete) != (game.finalScore, game.isComplete) else { return false }
                game.finalScore = scored.finalScore
                game.isComplete = scored.isComplete
                game.updatedAt = .now
                return true
            }
            return DuplicateRepairResult(changed: Set(changed.map(\.id)), deleted: deleted)
        }
    }

    /// Deletes every duplicate game but the one to keep, and returns the rest.
    private static func removingDuplicateGames(
        _ games: [Game], deleted: inout Set<GameID>, in context: ModelContext
    ) -> [Game] {
        let groups = Dictionary(grouping: games) { game in
            GameSlot(session: game.session?.id, bowler: game.bowlerID ?? game.bowler?.id, gameIndex: game.gameIndex)
        }
        return groups.flatMap { slot, group -> [Game] in
            guard slot.session != nil, slot.bowler != nil else { return group }
            let sorted = group.sorted {
                ($0.recordedRollCount, $0.updatedAt, $1.id.uuidString)
                    > ($1.recordedRollCount, $1.updatedAt, $0.id.uuidString)
            }
            for loser in sorted.dropFirst() {
                // Detached first: until the save, a deleted game is still in `Session.games`.
                loser.session = nil
                deleted.insert(loser.id)
                context.delete(loser)
            }
            return [sorted[0]]
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

struct DuplicateRepairResult: Equatable {
    /// Games kept whose rows or cached values changed.
    var changed: Set<GameID> = []
    /// Duplicate games deleted with their frames and rolls.
    var deleted: Set<GameID> = []

    var isEmpty: Bool { changed.isEmpty && deleted.isEmpty }
}

private struct GameSlot: Hashable {
    let session: UUID?
    let bowler: UUID?
    let gameIndex: Int
}

extension Game {
    /// Distinct frame and roll positions on this device, so duplicate rows count once.
    fileprivate var rollsPresent: Int {
        // rollIndex is 1 through 3, so frameIndex * 4 + rollIndex is unique per position.
        Set((frames ?? []).flatMap { frame in (frame.rolls ?? []).map { frame.frameIndex * 4 + $0.rollIndex } }).count
    }

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
