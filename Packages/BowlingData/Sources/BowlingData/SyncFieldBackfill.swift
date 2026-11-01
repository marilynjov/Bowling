import Foundation
import SwiftData

extension BowlingStore {
    /// Stores created before #48 hold games with `bowlerID` nil and `recordedRollCount` 0,
    /// which sync repair would misread. Fills both from this device's rows, without stamping
    /// `updatedAt`, since neither is a user edit. A game already filled is skipped, so a
    /// second run changes nothing.
    ///
    /// Only correct while sync is off, when every row of a game is on this device.
    /// - Parameter defaults: Where a finished backfill is remembered, so later launches skip
    ///   even the fetch. Nil runs it every time, for in-memory stores that start empty.
    func backfillSyncFields(rememberingIn defaults: UserDefaults? = nil) throws {
        // TODO(Phase 2): remove before CloudKit turns on: a Game row can then arrive before
        // its rolls, and filling its count from the rows here would undercount it.
        guard defaults?.bool(forKey: Self.backfillDoneKey) != true else { return }
        try backfill()
        defaults?.set(true, forKey: Self.backfillDoneKey)
    }

    static let backfillDoneKey = "BowlingData.syncFieldsBackfilled"

    private func backfill() throws {
        let games = try context.fetch(FetchDescriptor<Game>(
            predicate: #Predicate { $0.bowlerID == nil || $0.recordedRollCount == 0 }
        ))
        let stale = games.filter { game in
            (game.bowlerID == nil && game.bowler != nil) || game.recordedRollCount != game.rowRollCount
        }
        guard !stale.isEmpty else { return }
        try context.write {
            for game in stale {
                if game.bowlerID == nil, let bowler = game.bowler { game.assign(bowler) }
                game.recordedRollCount = game.rowRollCount
            }
        }
    }
}

extension Game {
    /// Roll rows on this device, counted the way `apply(_:in:)` counts a record's rolls.
    fileprivate var rowRollCount: Int {
        (frames ?? []).reduce(0) { $0 + ($1.rolls?.count ?? 0) }
    }
}
