import BowlingCore
import BowlingData
import Foundation

/// The first-launch answers, held until Start so quitting halfway saves nothing. Nothing
/// starts picked: the bowling style decides which stats show, so it is never guessed.
struct OnboardingDraft {
    var name = ""
    var handedness: Handedness?
    var style: StatsProfile?

    /// Welcome's Continue: a name that isn't only whitespace, and a hand.
    var canLeaveProfile: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && handedness != nil
    }

    /// Start: every answer given.
    var canFinish: Bool { canLeaveProfile && style != nil }

    /// Creates the owner, or returns nil and saves nothing while an answer is missing. The
    /// repository trims the name. The stats scope stays empty, so it follows the style.
    /// - Throws: the repository's errors, such as `.ownerAlreadyExists`.
    func createOwner(in bowlers: BowlerRepository) throws -> BowlerRecord? {
        guard canFinish, let handedness, let style else { return nil }
        return try bowlers.createOwner(name: name, handedness: handedness, statsProfile: style)
    }
}
