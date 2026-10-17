import BowlingData
import SwiftUI

/// Placeholder until #9.
struct HistoryScreen: View {
    @Environment(AppModel.self) private var app
    @State private var sessionCount = 0

    var body: some View {
        Text("\(sessionCount) sessions")
            .navigationTitle("History")
            .task(id: app.revision) {
                sessionCount = app.store.sessions.sessions().count
            }
    }
}

#if DEBUG
#Preview {
    NavigationStack { HistoryScreen() }
        .environment(AppModel.preview())
}
#endif
