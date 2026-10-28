import BowlingCore
import SwiftUI

/// One Stats card. A tile is a `StatTile`; everything else sits in the same Surface card
/// under its mono title.
struct StatsCardView: View {
    var card: StatsCard

    var body: some View {
        if case .tile(let content, let footnote) = card.body {
            StatTile(content, footnote: footnote)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(card.title).monoLabel()
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(.surface, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.hairline))
        }
    }

    @ViewBuilder private var content: some View {
        switch card.body {
        case .tile:
            EmptyView()
        case .trend(let trend):
            TrendCard(trend: trend)
        case .leaves(let rows):
            LeavesCard(rows: rows)
        case .leftMost(let row?):
            LeaveRowView(row: row, size: .regular)
        case .leftMost(nil):
            muted(String(localized: "No leave seen 3 times yet."))
        case .notApplicable(let text):
            muted(text)
        case .comingSoon:
            muted(String(localized: "Coming soon."))
        }
    }

    private func muted(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A leave's diagram with "Made 7 of 9" and its rate, read by VoiceOver as one element.
struct LeaveRowView: View {
    var row: LeaveRowContent
    var size: LeaveDiagramView.Size = .small

    var body: some View {
        HStack(spacing: 12) {
            LeaveDiagramView(leave: row.leave, size: size)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.rate)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.ink)
                Text(row.made)
                    .font(.figure)
                    .foregroundStyle(.inkMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

#if DEBUG
private struct StatsCardPreview: View {
    private let cards = StatsCards.make(cards: StatsCardID.allCases, report: PreviewData.report)
        + StatsCards.make(cards: [.average, .strikePct, .leavesTable],
                          report: StatsEngine.report(games: [], filter: StatsFilter(bowlerID: BowlerID())))

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(cards.enumerated()), id: \.offset) { StatsCardView(card: $0.element) }
            }
            .padding(16)
        }
        .background(Color.canvas)
    }
}

#Preview("Cards, light") { StatsCardPreview() }
#Preview("Cards, dark") { StatsCardPreview().preferredColorScheme(.dark) }
#Preview("Cards, AX5") { StatsCardPreview().dynamicTypeSize(.accessibility5) }
#endif
