import BowlingCore
import SwiftUI

/// The game summary (spec §3): a card per bowler, then Next game and End session.
struct GameSummarySheet: View {
    @Environment(AppModel.self) private var app
    let session: SessionScoringModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(session.summaries) { SummaryCard(summary: $0) }
                }
                .padding(16)
            }
            .background(Color.canvas)
            .navigationTitle("Game \(session.gameIndex)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { buttons }
        }
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button(action: session.nextGame) {
                Text("Next game").frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button(action: app.closeScoring) {
                Text("End session").frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Color.canvas)
    }
}

/// One bowler: name and score, strikes · spares · opens, leaves, and the series so far.
private struct SummaryCard: View {
    let summary: GameSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.name)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(summary.score)")
                    .font(.scoreHero)
                    .monospacedDigit()
                    .foregroundStyle(Color.accentText)
            }
            if let counts = summary.countsText {
                Text(counts).font(.subheadline).foregroundStyle(Color.inkMuted)
            }
            leaves
            if let series = summary.seriesText {
                Text(series).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Diagrams wrap into rows, so they stack at accessibility sizes.
    @ViewBuilder private var leaves: some View {
        switch summary.leaves {
        case .diagrams(let leaves):
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), alignment: .top)], alignment: .leading, spacing: 8) {
                ForEach(leaves.indices, id: \.self) { LeaveDiagramView(leave: leaves[$0], size: .small) }
            }
        case .enterPins:
            Text("Enter pins to see leaves").font(.subheadline).foregroundStyle(Color.inkMuted)
        case .none:
            Text("No leaves").font(.subheadline).foregroundStyle(Color.inkMuted)
        case .hidden:
            EmptyView()
        }
    }
}
