import BowlingData
import SwiftUI

/// Placeholder until #12.
struct ArsenalScreen: View {
    @Environment(AppModel.self) private var app
    @State private var ballCount = 0

    var body: some View {
        Text("\(ballCount) balls")
            .navigationTitle("Arsenal")
            .task(id: app.revision) {
                ballCount = app.store.balls.activeBalls().count
            }
    }
}

#if DEBUG
#Preview {
    NavigationStack { ArsenalScreen() }
        .environment(AppModel.preview())
}
#endif
