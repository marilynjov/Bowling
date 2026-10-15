import SwiftUI

/// First launch or the four tabs, plus the shared error alert.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if app.needsOnboarding {
                OnboardingPlaceholder()
            } else {
                TabView {
                    Tab("Home", systemImage: "house") {
                        NavigationStack { HomeScreen() }
                    }
                    Tab("History", systemImage: "clock") {
                        NavigationStack { HistoryScreen() }
                    }
                    Tab("Stats", systemImage: "chart.bar") {
                        NavigationStack { StatsScreen() }
                    }
                    Tab("Arsenal", systemImage: "circle.circle") {
                        NavigationStack { ArsenalScreen() }
                    }
                }
            }
        }
        .alert("Something went wrong", isPresented: isShowingError) {
            Button("OK") { app.error = nil }
        } message: {
            if let error = app.error {
                Text(ErrorText.message(for: error))
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { app.error != nil }, set: { if !$0 { app.error = nil } })
    }
}

#if DEBUG
#Preview {
    RootView()
        .environment(AppModel.preview())
}
#endif
