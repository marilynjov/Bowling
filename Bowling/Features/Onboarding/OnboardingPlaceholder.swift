import BowlingCore
import BowlingData
import SwiftUI

/// Creates a stand-in owner so the tabs can be reached. #6 replaces it with first launch.
struct OnboardingPlaceholder: View {
    @Environment(AppModel.self) private var app
    @State private var isCreating = false

    var body: some View {
        ContentUnavailableView {
            Label("Welcome", systemImage: "figure.bowling")
        } description: {
            Text("First launch is coming in #6.")
        } actions: {
            Button("Continue", action: createOwner)
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
        }
    }

    private func createOwner() {
        isCreating = true
        do {
            _ = try app.write { try $0.bowlers.createOwner(name: "Bowler", handedness: .right, statsProfile: .league) }
        } catch {
            app.error = error
            isCreating = false
        }
    }
}

#if DEBUG
#Preview {
    OnboardingPlaceholder()
        .environment(AppModel(store: try! BowlingStore(inMemory: true)))
}
#endif
