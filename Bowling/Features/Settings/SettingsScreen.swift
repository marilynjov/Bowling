import SwiftUI

/// Placeholder until #13. Pushed from Home's toolbar.
struct SettingsScreen: View {
    var body: some View {
        List {
            Text("Coming in #13")
            #if DEBUG
            Section("Testing") {
                NavigationLink("Pin deck test") { PinDeckTrialScreen() }
            }
            #endif
        }
        .navigationTitle("Settings")
    }
}

#if DEBUG
#Preview {
    NavigationStack { SettingsScreen() }
}
#endif
