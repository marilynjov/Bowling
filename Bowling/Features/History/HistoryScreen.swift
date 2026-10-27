import BowlingCore
import BowlingData
import SwiftUI

/// Sessions by month, newest first (spec §1). A row opens session detail; swipe or the
/// VoiceOver action deletes it after a confirmation.
struct HistoryScreen: View {
    @Environment(AppModel.self) private var app
    /// Nil until the first load, so the empty state doesn't flash.
    @State private var months: [HistoryMonth]?
    @State private var pendingDelete: DeleteRequest?

    var body: some View {
        Group {
            if let months, months.isEmpty {
                empty
            } else if let months {
                list(months)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
        .navigationTitle("History")
        .deleteConfirmation($pendingDelete)
        .task(id: app.revision) { reload() }
    }

    private func list(_ months: [HistoryMonth]) -> some View {
        List {
            ForEach(months) { month in
                Section(month.title) {
                    ForEach(month.rows) { row in
                        let request = DeleteRequest.session(row.id, gameCount: row.gameCount)
                        NavigationLink(value: HistoryRoute.session(row.id)) {
                            RecentSessionRow(row: row)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 16))
                        .swipeActions {
                            Button { pendingDelete = request } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .accessibilityAction(named: "Delete") { pendingDelete = request }
                    }
                }
                .listRowBackground(Color.surface)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Text("Your sessions show up here.")
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Button { app.isStartingSession = true } label: {
                Text("Start session").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .controlSize(.large)
        }
        .padding(16)
    }

    private func reload() {
        let store = app.store
        guard let owner = store.bowlers.owner() else { months = []; return }
        months = HistoryList.months(from: store.sessions.sessions(), owner: owner.id)
    }
}

#if DEBUG
private struct HistoryScreenPreview: View {
    @State private var app: AppModel

    /// `empty`: an owner with no sessions yet.
    init(empty: Bool = false) {
        guard empty else { _app = State(initialValue: .preview()); return }
        let store = try! BowlingStore(inMemory: true)
        _ = try! store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        _app = State(initialValue: AppModel(store: store))
    }

    var body: some View {
        HistoryStack()
            .environment(app)
    }
}

#Preview("Light") { HistoryScreenPreview() }
#Preview("Dark") { HistoryScreenPreview().preferredColorScheme(.dark) }
#Preview("AX5") { HistoryScreenPreview().dynamicTypeSize(.accessibility5) }
#Preview("Empty, light") { HistoryScreenPreview(empty: true) }
#Preview("Empty, dark") { HistoryScreenPreview(empty: true).preferredColorScheme(.dark) }
#Preview("Empty, AX5") { HistoryScreenPreview(empty: true).dynamicTypeSize(.accessibility5) }
#endif
