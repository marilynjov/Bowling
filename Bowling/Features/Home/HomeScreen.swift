import BowlingData
import SwiftUI

/// Placeholder until #11.
struct HomeScreen: View {
    @Environment(AppModel.self) private var app
    @State private var ownerName = ""

    var body: some View {
        Text(ownerName)
            .font(.title)
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
}

#if DEBUG
#Preview {
    NavigationStack { HomeScreen() }
        .environment(AppModel.preview())
}
#endif
