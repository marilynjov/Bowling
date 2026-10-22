import SwiftUI

/// One recent session: date, event and center, and the owner's scores.
struct RecentSessionRow: View {
    var row: RecentRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.date.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(Color.ink)
                Text([row.eventType.title, row.centerName].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 8)
            Text(row.scores)
                .font(.figure)
                .monospacedDigit()
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
