import SwiftUI

/// Placeholder until #13. Pushed from Home's toolbar.
struct SettingsScreen: View {
    var body: some View {
        Text("Coming in #13")
            .navigationTitle("Settings")
    }
}

#if DEBUG
#Preview {
    NavigationStack { SettingsScreen() }
}
#endif
