import BowlingCore

// Customize on Stats and Home (spec section 7). Layouts are stored comma-separated on the
// owner; an empty one means the profile's preset.
extension BowlerRepository {
    /// Saves the Stats cards in order, keeping stored card IDs this build cannot show.
    /// Saving the profile's preset unedited stores "", so the owner keeps following it.
    public func setStatsLayout(_ cards: [StatsCardID]) throws {
        try writeOwner {
            let preset = StatsPreset.statsCards(for: StatsProfile(storedValue: $0.statsProfile))
            $0.statsLayout = Self.saved(cards, replacing: $0.statsLayout, preset: preset)
        }
    }

    /// Saves the Home tiles in order, keeping stored card IDs this build cannot show.
    /// Saving the profile's preset unedited stores "", so the owner keeps following it.
    public func setHomeLayout(_ cards: [StatsCardID]) throws {
        try writeOwner {
            let preset = StatsPreset.homeTiles(for: StatsProfile(storedValue: $0.statsProfile))
            $0.homeLayout = Self.saved(cards, replacing: $0.homeLayout, preset: preset)
        }
    }

    /// "Reset to preset" on Stats. Unknown card IDs are cleared too.
    public func resetStatsLayout() throws {
        try writeOwner { $0.statsLayout = "" }
    }

    /// "Reset to preset" on Home. Unknown card IDs are cleared too.
    public func resetHomeLayout() throws {
        try writeOwner { $0.homeLayout = "" }
    }

    /// Replaces both layouts with the preset, for when the user accepts the new preset
    /// after changing the bowling style.
    public func resetLayouts() throws {
        try writeOwner {
            $0.statsLayout = ""
            $0.homeLayout = ""
        }
    }

    private func writeOwner(_ change: (Bowler) -> Void) throws {
        guard let owner = context.owner() else { throw RepositoryError.notFound }
        try context.write {
            change(owner)
            owner.updatedAt = .now
        }
    }

    // An explicit copy of the preset would freeze it: cards added to the preset later,
    // such as a 1b card becoming available, would never reach this owner.
    private static func saved(_ cards: [StatsCardID], replacing stored: String, preset: [StatsCardID]) -> String {
        let previous = stored.split(separator: ",").map(String.init)
        let layout = StatsPreset.layoutToSave(cards, replacing: previous)
        return layout == preset.map(\.rawValue) ? "" : layout.joined(separator: ",")
    }
}
