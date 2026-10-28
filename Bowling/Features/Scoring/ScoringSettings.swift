import Foundation

/// Scoring's three on-device settings, kept in UserDefaults and never synced. Settings shows
/// their toggles.
struct ScoringSettings {
    private let defaults: UserDefaults

    init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The deck starts with every pin standing and you tap the ones that fell.
    var tapWhatFell: Bool {
        get { defaults.bool(forKey: "scoring.tapWhatFell") }
        nonmutating set { defaults.set(newValue, forKey: "scoring.tapWhatFell") }
    }

    /// A second ball records by itself once it makes a spare (with Tap what fell only).
    var autoAdvanceOnSpare: Bool {
        get { defaults.bool(forKey: "scoring.autoAdvanceOnSpare") }
        nonmutating set { defaults.set(newValue, forKey: "scoring.autoAdvanceOnSpare") }
    }

    /// On a night with several bowlers, the turn moves after each frame. Each Scoring cover
    /// starts its toggle from this.
    var rotateBowlers: Bool {
        get { defaults.object(forKey: "scoring.rotateBowlers") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "scoring.rotateBowlers") }
    }

    /// Delete all data: every setting reads its default again.
    func reset() {
        for key in ["scoring.tapWhatFell", "scoring.autoAdvanceOnSpare", "scoring.rotateBowlers"] {
            defaults.removeObject(forKey: key)
        }
    }
}
