import BowlingCore
import BowlingData
import SwiftUI

/// Placeholder until #10.
struct StatsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var gameCount = 0

    var body: some View {
        Text("\(gameCount) games")
            .navigationTitle("Stats")
            .task(id: app.revision) {
                guard let owner = app.store.bowlers.owner() else { return gameCount = 0 }
                gameCount = app.store.stats
                    .games(matching: StatsFilter(bowlerID: owner.id), now: .now, calendar: .current)
                    .count
            }
    }
}

#if DEBUG
#Preview {
    NavigationStack { StatsScreen() }
        .environment(AppModel.preview())
}
#endif
