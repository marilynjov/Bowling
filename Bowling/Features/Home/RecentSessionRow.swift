import SwiftUI

/// One session in Home's recent list and History: date, event, center and league, and the
/// owner's scores.
struct RecentSessionRow: View {
    var row: RecentRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.date.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(Color.ink)
                Text(row.detailsText)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkMuted)
                if let bowlers = row.bowlersText {
                    Text(bowlers)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkMuted)
                }
                if row.isInProgress {
                    Text("In progress")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkMuted)
                }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.sessionRow(row))
    }
}
