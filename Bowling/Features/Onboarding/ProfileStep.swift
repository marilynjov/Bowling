import BowlingCore
import SwiftUI

/// First launch, step 1: the owner's name and hand. Nothing is picked at first.
struct ProfileStep: View {
    @Binding var draft: OnboardingDraft
    var onContinue: () -> Void

    @FocusState private var nameFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Side by side, or stacked at accessibility sizes so "Right" never wraps mid-word.
    private var handLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name")
                        .font(.headline)
                        .foregroundStyle(.ink)
                    TextField("Name", text: $draft.name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit { nameFocused = false }
                        .padding(14)
                        .background(.surface, in: .rect(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.hairline, lineWidth: 1)
                        }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("You bowl")
                        .font(.headline)
                        .foregroundStyle(.ink)
                    handLayout {
                        hand("Right", .right)
                        hand("Left", .left)
                    }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.canvas)
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            OnboardingButton(title: "Continue", action: onContinue)
                .disabled(!draft.canLeaveProfile)
        }
        .onAppear { nameFocused = true }
    }

    private func hand(_ title: String, _ handedness: Handedness) -> some View {
        ChoiceCard(title: title, isSelected: draft.handedness == handedness) {
            draft.handedness = handedness
        }
    }
}

#if DEBUG
private struct ProfileStepPreview: View {
    @State var draft = OnboardingDraft()
    var body: some View {
        NavigationStack { ProfileStep(draft: $draft, onContinue: {}) }
    }
}

#Preview("Welcome, light") { ProfileStepPreview().preferredColorScheme(.light) }
#Preview("Welcome, dark") { ProfileStepPreview().preferredColorScheme(.dark) }
#Preview("Welcome, AX3") { ProfileStepPreview().dynamicTypeSize(.accessibility3) }
#Preview("Welcome, AX5") {
    ProfileStepPreview(draft: OnboardingDraft(name: "Ana", handedness: .left)).dynamicTypeSize(.accessibility5)
}
#Preview("Welcome, filled") { ProfileStepPreview(draft: OnboardingDraft(name: "Ana", handedness: .left)) }
#endif
