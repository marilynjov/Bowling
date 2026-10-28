import BowlingCore
import BowlingData
import Foundation

/// The 1a add form's values (spec §2): name, brand, weight, and role.
struct BallDraft: Hashable {
    var name = ""
    var brand = ""
    /// Nil until the user picks one; the picker reads "Choose".
    var weightPounds: Int?
    var role: BallRole = .strike

    /// A name that isn't blank and a picked weight.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && weightPounds != nil
    }

    /// The repository trims the name and checks both fields again.
    /// - Throws: what `addBall` throws, or `.invalidBall(.weightOutOfRange)` with no weight.
    func save(to store: BowlingStore) throws -> BallSummary {
        guard let weightPounds else { throw RepositoryError.invalidBall(.weightOutOfRange) }
        return try store.balls.addBall(name: name, weightPounds: weightPounds, intendedRole: role, brand: brand)
    }
}
