import BowlingCore
import BowlingData
import SwiftUI

/// One session (spec §2): its details, Resume when it's the unfinished one, and a section
/// per bowler with each game's scorecard. Edit opens the details form; a game row opens
/// game detail, and swipe or the VoiceOver action deletes it.
struct SessionDetailScreen: View {
    @Environment(AppModel.self) private var app
    let id: SessionID
    @State private var data: SessionDetailData?
    @State private var isDeleted = false
    @State private var pendingDelete: DeleteRequest?

    var body: some View {
        Group {
            if isDeleted {
                RecordDeletedView(message: "This session was deleted.")
            } else if let data {
                list(data)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
        .navigationTitle(data?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if data != nil, !isDeleted {
                Button("Edit") { app.editingSessionDetails = id }
            }
        }
        .sheet(isPresented: isEditing) {
            SessionDetailsForm(id: id)
                .sharedErrorAlert(in: .sessionDetails)
        }
        .deleteConfirmation($pendingDelete)
        .task(id: app.revision) { reload() }
    }

    private func list(_ data: SessionDetailData) -> some View {
        List {
            header(data)
            if let target = data.resumeTarget {
                Section {
                    Button { app.resume(target) } label: {
                        Text("Resume").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                    .controlSize(.large)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ForEach(data.sections) { section in
                Section {
                    ForEach(section.games) { game in
                        gameRow(game)
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(section.name)
                        Spacer()
                        Text(section.seriesText).monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(AccessibilityText.bowlerHeader(name: section.name, series: section.series))
                    .accessibilityAddTraits(.isHeader)
                }
                .listRowBackground(Color.surface)
            }
        }
        .scrollContentBackground(.hidden)
    }

    /// Date, then event · center · league · oil pattern · lanes, then notes.
    private func header(_ data: SessionDetailData) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.date.formatted(date: .complete, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(data.headerParts.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkMuted)
                if let notes = data.notes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.surface)
    }

    /// "Game 2" and its score over a compact, read-only scorecard; read as "Game 2, 189".
    private func gameRow(_ game: SessionDetailData.GameRow) -> some View {
        NavigationLink(value: HistoryRoute.game(game.id)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(game.title).foregroundStyle(Color.ink)
                    Spacer()
                    Text("\(game.score)")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                }
                ScorecardStrip(scorecard: game.scorecard, currentFrame: nil)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityText.gameRow(game.gameIndex, score: game.score))
        }
        .swipeActions {
            Button { pendingDelete = game.deleteRequest } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .accessibilityAction(named: "Delete") { pendingDelete = game.deleteRequest }
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { app.editingSessionDetails == id }, set: { if !$0 { app.editingSessionDetails = nil } })
    }

    /// A missing session shows the deleted state, unless this screen is already being
    /// popped after its own delete.
    private func reload() {
        do {
            data = try SessionDetailData.load(id, from: app.store)
            isDeleted = false
        } catch RepositoryError.notFound {
            if app.historyPath.contains(.session(id)) { isDeleted = true }
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
private struct SessionDetailScreenPreview: View {
    @State private var app: AppModel = {
        let app = AppModel.preview()
        if let session = app.store.sessions.sessions().first(where: { $0.bowlerCount > 1 })
            ?? app.store.sessions.sessions().first {
            app.historyPath = [.session(session.id)]
        }
        return app
    }()

    var body: some View {
        HistoryStack()
            .environment(app)
    }
}

#Preview("Light") { SessionDetailScreenPreview() }
#Preview("Dark") { SessionDetailScreenPreview().preferredColorScheme(.dark) }
#Preview("AX5") { SessionDetailScreenPreview().dynamicTypeSize(.accessibility5) }
#endif
