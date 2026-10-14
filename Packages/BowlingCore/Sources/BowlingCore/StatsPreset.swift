/// The starting Stats and Home layouts and default scope for each bowling style
/// (spec section 7 "Presets", section 6 "Default scope"). `.unknown` uses the casual preset.
/// Cards from a later sub-phase are listed here and appear once they become available.
public enum StatsPreset {
    /// In display order, available cards only.
    public static func statsCards(for profile: StatsProfile) -> [StatsCardID] {
        let cards: [StatsCardID] = switch profile.effective {
        case .league:
            casualStatsCards + [.highSeries, .leavesTable, .leftMostMadeLeast, .singlePinConversion, .openPct]
        case .competitive:
            StatsCardID.allCases
        case .casual, .unknown:
            casualStatsCards
        }
        return cards.filter(\.isAvailable)
    }

    /// In display order, available cards only.
    public static func homeTiles(for profile: StatsProfile) -> [StatsCardID] {
        let tiles: [StatsCardID] = switch profile.effective {
        case .league, .competitive:
            [.average, .highGame, .highSeries, .strikePct, .sparePct]
        case .casual, .unknown:
            [.average, .highGame, .strikePct]
        }
        return tiles.filter(\.isAvailable)
    }

    /// True starts Stats on "Competition" (league and tournament), false on "All games".
    public static func prefersCompetition(_ profile: StatsProfile) -> Bool {
        switch profile.effective {
        case .league, .competitive: true
        case .casual, .unknown: false
        }
    }

    private static let casualStatsCards: [StatsCardID] = [.average, .highGame, .trendChart, .strikePct, .sparePct]
}
