import BowlingCore
import BowlingData
import SwiftUI

/// A screen pushed on the Stats tab's stack.
enum StatsRoute: Hashable {
    case leave(Leave)
}

/// Every spare attempt at one leave for the Stats filter, newest first (spec §6 "Leave
/// occurrences"). The leave is drawn once in the header, since every row shares it. A row
/// opens its game in History.
struct LeaveOccurrencesScreen: View {
    @Environment(AppModel.self) private var app
    let leave: Leave
    @State private var rows: [LeaveOccurrenceRow] = []
    @State private var summary = ""

    private struct LoadKey: Hashable {
        var revision: Int
        var filter: StatsFilterDraft?
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    LeaveDiagramView(leave: leave, size: .regular)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
            Section {
                if rows.isEmpty {
                    Text("No attempts at this leave in these games.")
                        .foregroundStyle(.inkMuted)
                }
                ForEach(rows) { row in
                    Button { app.openGame(row.gameID, in: row.sessionID) } label: { OccurrenceRowView(row: row) }
                        .accessibilityHint(Text("Opens the game in History."))
                }
            }
        }
        .navigationTitle(leave.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: LoadKey(revision: app.revision, filter: app.statsFilter)) { load() }
    }

    private func load() {
        let store = app.store
        guard let draft = StatsFilterDraft.current(app.statsFilter, in: store) else {
            rows = []
            summary = LeaveOccurrenceRows.summary([])
            return
        }
        let occurrences = store.stats.leaveOccurrences(of: leave, matching: draft.filter, now: .now, calendar: .current)
        let owner = draft.filter.bowlerID
        let sessions = Dictionary(store.sessions.sessions().map { ($0.id, RecentRow($0, owner: owner).detailsText) },
                                  uniquingKeysWith: { first, _ in first })
        let balls = Dictionary((store.balls.activeBalls() + store.balls.retiredBalls()).map { ($0.id, $0.name) },
                               uniquingKeysWith: { first, _ in first })
        rows = LeaveOccurrenceRows.make(occurrences, sessions: sessions, balls: balls)
        summary = LeaveOccurrenceRows.summary(occurrences)
    }
}

private struct OccurrenceRowView: View {
    var row: LeaveOccurrenceRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.session.isEmpty ? row.date : "\(row.date) · \(row.session)")
                    .font(.body)
                    .foregroundStyle(.ink)
                Text(row.position)
                    .font(.figure)
                    .foregroundStyle(.inkMuted)
            }
            Spacer(minLength: 8)
            Text(row.result)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.isConverted ? Color.accentText : Color.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

#if DEBUG
private struct LeaveOccurrencesPreview: View {
    @State private var app = AppModel.preview()

    /// The demo's most-seen leave, so the list has rows.
    private var leave: Leave {
        let report = StatsEngine.report(
            games: app.store.stats.games(matching: StatsFilter(bowlerID: app.store.bowlers.owner()!.id),
                                         now: .now, calendar: .current),
            filter: StatsFilter(bowlerID: app.store.bowlers.owner()!.id)
        )
        return report.leaves.first?.leave ?? PreviewData.leave(10)
    }

    var body: some View {
        NavigationStack { LeaveOccurrencesScreen(leave: leave) }
            .environment(app)
    }
}

#Preview("Light") { LeaveOccurrencesPreview() }
#Preview("Dark") { LeaveOccurrencesPreview().preferredColorScheme(.dark) }
#Preview("AX5") { LeaveOccurrencesPreview().dynamicTypeSize(.accessibility5) }
#endif
