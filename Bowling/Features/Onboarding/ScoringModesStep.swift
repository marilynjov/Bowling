import SwiftUI

/// First launch, step 3: the three ways to enter a game (Phase 1 spec §5), then Start.
struct ScoringModesStep: View {
    var isSaving: Bool
    var onStart: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The "Default" tag beside the title, or under it at accessibility sizes.
    private var titleLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    private static let modes: [(title: String, detail: String, isDefault: Bool)] = [
        ("Pin by pin", "Tap the pins on each ball. Unlocks leaves, splits, and spare stats.", true),
        ("Count only", "Enter how many pins fell on each ball.", false),
        ("Final score", "Just type the game's score.", false),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Self.modes, id: \.title) { mode in
                    row(mode.title, mode.detail, isDefault: mode.isDefault)
                }
                Text("You pick one for each session.")
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .background(.canvas)
        .navigationTitle("Ways to score")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            OnboardingButton(title: "Start", action: onStart)
                .disabled(isSaving)
        }
    }

    private func row(_ title: String, _ detail: String, isDefault: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titleLayout {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.ink)
                if isDefault {
                    // monoLabel's type, in accent: monoLabel fixes the color to InkMuted.
                    Text("Default")
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(.accentText)
                }
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.inkMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.surface, in: .rect(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Ways to score, light") {
    NavigationStack { ScoringModesStep(isSaving: false, onStart: {}) }.preferredColorScheme(.light)
}
#Preview("Ways to score, dark") {
    NavigationStack { ScoringModesStep(isSaving: false, onStart: {}) }.preferredColorScheme(.dark)
}
#Preview("Ways to score, AX3") {
    NavigationStack { ScoringModesStep(isSaving: false, onStart: {}) }.dynamicTypeSize(.accessibility3)
}
#Preview("Ways to score, AX5") {
    NavigationStack { ScoringModesStep(isSaving: false, onStart: {}) }.dynamicTypeSize(.accessibility5)
}
#endif
