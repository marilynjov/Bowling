import BowlingCore
import BowlingData
import Foundation

/// The Log maintenance sheet's values (spec §7 "Ball detail", Maintenance). A resurface or
/// polish with a grit becomes the ball's current surface; other kinds don't change the
/// surface, so the sheet hides the grit field for them and logging drops a grit typed
/// before the kind changed.
struct MaintenanceDraft: Hashable {
    var kind: MaintenanceKind = .resurface
    var date: Date = .now
    var surfaceGrit = ""
    var notes = ""

    /// The kinds the picker offers, in the order the bowler meets them.
    static let kinds: [MaintenanceKind] = [.resurface, .polish, .oilExtraction, .plugAndRedrill, .other]

    var takesGrit: Bool {
        kind == .resurface || kind == .polish
    }

    /// - Throws: whatever `logMaintenance` throws.
    @discardableResult
    func log(for ball: BallID, in store: BowlingStore) throws -> MaintenanceRecord {
        try store.balls.logMaintenance(
            kind, date: date,
            surfaceGritAfter: takesGrit ? surfaceGrit.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), for: ball
        )
    }
}
