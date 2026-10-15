import BowlingData
import SwiftUI

/// Placeholder until #11.
struct HomeScreen: View {
    @Environment(AppModel.self) private var app
    @State private var ownerName = ""

    var body: some View {
        VStack(spacing: 24) {
            Text(ownerName)
                .font(.title)
            Button("Start", action: start)
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Home")
        .toolbar {
            NavigationLink {
                SettingsScreen()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .task(id: app.revision) {
            ownerName = app.store.bowlers.owner()?.name ?? ""
        }
    }

    private func start() {
        do {
            try app.startPracticeSession()
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { HomeScreen() }
        .environment(AppModel.preview())
}
#endif
