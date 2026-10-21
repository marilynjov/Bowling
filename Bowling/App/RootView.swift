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
                TabView(selection: $app.selectedTab) {
                    Tab("Home", systemImage: "house", value: AppTab.home) {
                        NavigationStack { HomeScreen() }
                    }
                    Tab("History", systemImage: "clock", value: AppTab.history) {
                        NavigationStack { HistoryScreen() }
                    }
                    Tab("Stats", systemImage: "chart.bar", value: AppTab.stats) {
                        NavigationStack { StatsScreen() }
                    }
                    Tab("Arsenal", systemImage: "circle.circle", value: AppTab.arsenal) {
                        NavigationStack { ArsenalScreen() }
                    }
                }
                .sheet(isPresented: $app.isQuickScoring) {
                    QuickScoreSheet()
                        .sharedErrorAlert(in: .quickScore)
                }
            }
        }
        .sheet(isPresented: $app.isStartingSession) {
            NewSessionSheet()
                .sharedErrorAlert(in: .newSession)
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
