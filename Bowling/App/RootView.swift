import SwiftUI

/// First launch or the four tabs, plus the shared error alert.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        Group {
            if app.needsOnboarding {
                OnboardingFlow()
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
        .fullScreenCover(item: $app.scoring) { _ in
            ScoringPlaceholder()
                .sharedErrorAlert(in: .scoring)
        }
        .sharedErrorAlert(in: .root)
    }
}

#if DEBUG
#Preview {
    RootView()
        .environment(AppModel.preview())
}
#endif
