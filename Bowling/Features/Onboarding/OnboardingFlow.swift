import BowlingData
import SwiftUI

/// First launch (#6): name and hand, bowling style, ways to score. The answers stay in a
/// draft until Start, which creates the owner in one write; that ends onboarding and the
/// root shows the tabs. "Restore from iCloud" joins in phase 2.
struct OnboardingFlow: View {
    enum Step: Hashable {
        case style, scoring
    }

    @Environment(AppModel.self) private var app
    @State private var draft = OnboardingDraft()
    @State private var path: [Step] = []
    @State private var isSaving = false

    var body: some View {
        NavigationStack(path: $path) {
            ProfileStep(draft: $draft) { path.append(.style) }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .style:
                        BowlingStyleStep(draft: $draft) { path.append(.scoring) }
                    case .scoring:
                        ScoringModesStep(isSaving: isSaving, onStart: start)
                    }
                }
        }
    }

    /// Stays saving after success, so a second tap queued before the root swaps the flow
    /// out is ignored instead of failing with "Your profile already exists."
    private func start() {
        guard !isSaving else { return }
        isSaving = true
        do {
            _ = try app.write { try draft.createOwner(in: $0.bowlers) }
        } catch {
            app.error = error
            isSaving = false
        }
    }
}

#if DEBUG
#Preview {
    OnboardingFlow()
        .environment(AppModel(store: try! BowlingStore(inMemory: true)))
}
#endif
