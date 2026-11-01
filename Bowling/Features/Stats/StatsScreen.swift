import BowlingCore
import BowlingData
import SwiftUI

/// The Stats tab (spec §3): the filter bar, then the owner's cards for that filter.
struct StatsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var cards: [StatsCard] = []
    @State private var isEditingFilter = false

    private struct LoadKey: Hashable {
        var revision: Int
        var filter: StatsFilterDraft?
    }

    var body: some View {
        // The canvas is always there, so `.task` runs even before there are cards.
        ZStack {
            Color.canvas.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(cards) { StatsCardView(card: $0) }
                }
                .padding(16)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let filter = app.statsFilter {
                StatsFilterBar(chips: filter.chips) { isEditingFilter = true }
            }
        }
        .navigationTitle("Stats")
        .sheet(isPresented: $isEditingFilter) {
            if let filter = app.statsFilter {
                StatsFilterSheet(draft: filter)
            }
        }
        .task(id: LoadKey(revision: app.revision, filter: app.statsFilter)) { load() }
    }

    private func load() {
        let store = app.store
        guard let owner = store.bowlers.owner(),
              let draft = StatsFilterDraft.current(app.statsFilter, in: store) else { return cards = [] }
        // A changed filter restarts this task, which then loads with it.
        guard draft == app.statsFilter else { return app.statsFilter = draft }
        let report = StatsEngine.report(
            games: store.stats.games(matching: draft.filter, now: .now, calendar: .current), filter: draft.filter
        )
        cards = StatsCards.make(
            cards: StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: owner.statsProfile),
            report: report
        )
    }
}

#if DEBUG
private struct StatsScreenPreview: View {
    @State private var app: AppModel

    /// `profile` nil: an owner with no games yet.
    init(profile: StatsProfile? = .league) {
        guard let profile else {
            let store = try! BowlingStore(inMemory: true)
            _ = try! store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
            _app = State(initialValue: AppModel(store: store))
            return
        }
        let app = AppModel.preview()
        try! app.store.bowlers.setStatsProfile(profile)
        _app = State(initialValue: app)
    }

    var body: some View {
        NavigationStack { StatsScreen() }
            .environment(app)
    }
}

#Preview("League, light") { StatsScreenPreview() }
#Preview("League, dark") { StatsScreenPreview().preferredColorScheme(.dark) }
#Preview("League, AX5") { StatsScreenPreview().dynamicTypeSize(.accessibility5) }
#Preview("Casual") { StatsScreenPreview(profile: .casual) }
#Preview("Competitive") { StatsScreenPreview(profile: .competitive) }
#Preview("Competitive, dark") { StatsScreenPreview(profile: .competitive).preferredColorScheme(.dark) }
#Preview("Empty, light") { StatsScreenPreview(profile: nil) }
#Preview("Empty, dark") { StatsScreenPreview(profile: nil).preferredColorScheme(.dark) }
#Preview("Empty, AX5") { StatsScreenPreview(profile: nil).dynamicTypeSize(.accessibility5) }
#endif
