// Saved layouts (spec section 7 "Customize" and "Layout rules"). A layout is the raw card
// IDs stored on the owner. It may hold IDs this build cannot show: cards from a newer app
// version, or cards that are not available yet. Those are skipped on display and kept
// on save, so a synced layout survives a round trip through an older device.
extension StatsPreset {
    /// The Stats cards to show, in order. An empty layout, or one with nothing this build
    /// can show, is the profile's preset.
    public static func displayedStatsCards(layout: [String], profile: StatsProfile) -> [StatsCardID] {
        displayed(layout, orPreset: statsCards(for: profile))
    }

    /// The Home tiles to show, in order. An empty layout, or one with nothing this build
    /// can show, is the profile's preset.
    public static func displayedHomeTiles(layout: [String], profile: StatsProfile) -> [StatsCardID] {
        displayed(layout, orPreset: homeTiles(for: profile))
    }

    /// The layout to store after Customize: `cards` in order, each written once, with every
    /// ID of `previous` this build cannot show kept right after the shown card it followed
    /// (or after the nearest earlier card still present, or first). An unavailable card in
    /// `cards` is dropped, so it is written only where `previous` kept it.
    public static func layoutToSave(_ cards: [StatsCardID], replacing previous: [String]) -> [String] {
        let cards = unique(cards.filter(\.isAvailable))
        var leading: [String] = []
        var following: [StatsCardID: [String]] = [:]
        var anchor: StatsCardID?
        for raw in previous {
            if let card = shownCard(raw) {
                if cards.contains(card) { anchor = card }
            } else if let anchor {
                following[anchor, default: []].append(raw)
            } else {
                leading.append(raw)
            }
        }
        return leading + cards.flatMap { [$0.rawValue] + following[$0, default: []] }
    }

    private static func displayed(_ layout: [String], orPreset preset: [StatsCardID]) -> [StatsCardID] {
        let cards = unique(layout.compactMap(shownCard))
        return cards.isEmpty ? preset : cards
    }

    private static func shownCard(_ raw: String) -> StatsCardID? {
        StatsCardID(rawValue: raw).flatMap { $0.isAvailable ? $0 : nil }
    }

    private static func unique(_ cards: [StatsCardID]) -> [StatsCardID] {
        var seen: Set<StatsCardID> = []
        return cards.filter { seen.insert($0).inserted }
    }
}
