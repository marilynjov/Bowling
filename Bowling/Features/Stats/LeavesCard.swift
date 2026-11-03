import SwiftUI

/// The first ten leaves, then "Show all N leaves" to expand the rest in place. Each leave
/// opens its occurrence list.
struct LeavesCard: View {
    var rows: [LeaveRowContent]
    @State private var showsAll = false

    private static let shown = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let visible = showsAll ? rows : Array(rows.prefix(Self.shown))
            ForEach(Array(visible.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().overlay(Color.hairline) }
                LeaveRowLink(row: row)
            }
            if !showsAll, rows.count > Self.shown {
                Button(String(localized: "Show all \(rows.count) leaves")) { showsAll = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accentText)
            }
        }
    }
}

/// A leave row that opens the leave's occurrence list on the Stats stack.
struct LeaveRowLink: View {
    var row: LeaveRowContent
    var size: LeaveDiagramView.Size = .small

    var body: some View {
        NavigationLink(value: StatsRoute.leave(row.leave)) {
            HStack(spacing: 8) {
                LeaveRowView(row: row, size: size)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.inkMuted)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Shows every attempt at this leave."))
    }
}
