import BowlingCore
import SwiftUI

/// First launch, step 2: how the owner bowls, which picks the stats preset (Phase 1
/// spec §7, Home). Nothing is picked at first.
struct BowlingStyleStep: View {
    @Binding var draft: OnboardingDraft
    var onContinue: () -> Void

    private static let options: [(title: String, detail: String, style: StatsProfile)] = [
        ("Casually", "Now and then, for fun.", .casual),
        ("In a league", "A regular league night, and you want your league average.", .league),
        ("Competitively", "Leagues and tournaments, and you want every number.", .competitive),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("This decides which stats you see. You can change it anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
                    .padding(.bottom, 8)
                ForEach(Self.options, id: \.style) { option in
                    ChoiceCard(title: option.title, detail: option.detail, isSelected: draft.style == option.style) {
                        draft.style = option.style
                    }
                }
            }
            .padding(16)
        }
        .background(.canvas)
        .navigationTitle("How do you bowl?")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            OnboardingButton(title: "Continue", action: onContinue)
                .disabled(draft.style == nil)
        }
    }
}

#if DEBUG
private struct BowlingStyleStepPreview: View {
    @State var draft = OnboardingDraft(name: "Ana", handedness: .right)
    var body: some View {
        NavigationStack { BowlingStyleStep(draft: $draft, onContinue: {}) }
    }
}

#Preview("Style, light") { BowlingStyleStepPreview().preferredColorScheme(.light) }
#Preview("Style, dark") { BowlingStyleStepPreview().preferredColorScheme(.dark) }
#Preview("Style, AX3") { BowlingStyleStepPreview().dynamicTypeSize(.accessibility3) }
#Preview("Style, picked") {
    BowlingStyleStepPreview(draft: OnboardingDraft(name: "Ana", handedness: .right, style: .league))
}
#endif
