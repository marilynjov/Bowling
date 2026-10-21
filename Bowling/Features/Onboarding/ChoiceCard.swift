import SwiftUI

/// One answer on a first-launch step: a Surface card that gets an accent border and a
/// checkmark when picked.
struct ChoiceCard: View {
    var title: String
    var detail: String?
    var isSelected: Bool
    var action: () -> Void

    init(title: String, detail: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.ink)
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.inkMuted)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.accentText)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(.surface, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color(.accent) : Color(.hairline), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The full-width primary button pinned under each first-launch step.
struct OnboardingButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(16)
        .background(.canvas)
    }
}
