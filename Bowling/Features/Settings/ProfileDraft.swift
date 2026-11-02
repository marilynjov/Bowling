import BowlingCore
import BowlingData
import Foundation

/// The Profile screen's values, held until Save.
struct ProfileDraft: Hashable {
    var name: String
    /// Nil for a hand from a newer version: nothing is picked, and saving keeps it.
    var handedness: Handedness?

    init(owner: BowlerRecord) {
        name = owner.name
        handedness = owner.handedness == .unknown ? nil : owner.handedness
    }

    /// A name that isn't only whitespace.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The repository trims the name; `.unknown` keeps the stored hand.
    /// - Throws: the repository's errors, such as `.invalidBowler(.emptyName)`.
    func save(to bowlers: BowlerRepository) throws {
        try bowlers.updateOwner(name: name, handedness: handedness ?? .unknown)
    }
}
