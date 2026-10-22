import SwiftUI

/// Home's card for the unfinished session; tapping it opens Scoring there.
struct ResumeCardView: View {
    var card: ResumeCard
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resume").monoLabel()
                    Text([card.eventType.title, card.centerName].compactMap { $0 }.joined(separator: " · "))
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Text(card.progress)
                        .font(.figure)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.accentText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.surface, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
