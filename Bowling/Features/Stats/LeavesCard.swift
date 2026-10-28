import SwiftUI

/// The first ten leaves, then "Show all N leaves" to expand the rest in place.
struct LeavesCard: View {
    var rows: [LeaveRowContent]
    @State private var showsAll = false

    private static let shown = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let visible = showsAll ? rows : Array(rows.prefix(Self.shown))
            ForEach(Array(visible.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().overlay(Color.hairline) }
                LeaveRowView(row: row)
            }
            if !showsAll, rows.count > Self.shown {
                Button(String(localized: "Show all \(rows.count) leaves")) { showsAll = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accentText)
            }
        }
    }
}
