import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
    }
}

#if DEBUG
import BowlingCore
import BowlingFixtures

/// Proves previews can read the fixtures (#65); the app shell (#4) replaces this view.
private struct FixturePreview: View {
    var body: some View {
        let game = DemoFixture.games(relativeTo: .now).first { $0.id == DemoGame.tournament1.id }
        VStack {
            Text(DemoBowler.owner.name)
            Text(game.flatMap { Scorer.scorecard(for: $0).finalScore }.map(String.init) ?? "–")
                .font(.largeTitle)
        }
    }
}

#Preview("Fixtures") {
    FixturePreview()
}
#endif

#Preview {
    ContentView()
}
