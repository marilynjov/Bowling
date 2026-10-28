import BowlingCore
import BowlingData
import SwiftUI

/// Session detail's Edit (spec §5): date, event, center, league, oil pattern, lanes, and
/// notes, from the saved details. No lineup, no scoring mode, and no remembered values.
/// Save writes them; Cancel discards.
struct SessionDetailsForm: View {
    @Environment(AppModel.self) private var app
    let id: SessionID
    @State private var draft: SessionDetailsDraft?
    @State private var centers: [NamedRef] = []
    @State private var leagues: [LeagueRecord] = []
    @State private var oilPatterns: [NamedRef] = []

    var body: some View {
        NavigationStack {
            Group {
                if let draft = Binding($draft) {
                    form(draft)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Session details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { app.editingSessionDetails = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft == nil)
                }
            }
        }
        .task(id: app.revision) { reload() }
    }

    private func form(_ draft: Binding<SessionDetailsDraft>) -> some View {
        Form {
            Section {
                DatePicker("Date", selection: draft.date)
                Picker("Event", selection: draft.eventType) {
                    ForEach([EventType.practice, .league, .tournament, .casual], id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.surface)

            SessionPlaceSection(details: draft, centers: centers, leagues: leagues, oilPatterns: oilPatterns)

            Section {
                TextField("Notes", text: draft.notes, axis: .vertical)
                    .lineLimit(3...)
            }
            .listRowBackground(Color.surface)
        }
    }

    /// Lists reload after every write; the draft is made once, from the saved details.
    /// A session deleted meanwhile closes the form, and session detail shows it's gone.
    private func reload() {
        let store = app.store
        centers = store.sessions.centers()
        leagues = store.sessions.leagueRecords()
        oilPatterns = store.sessions.oilPatterns()
        guard draft == nil else { return }
        do {
            draft = SessionDetailsDraft(try store.sessions.session(id).metadata)
        } catch RepositoryError.notFound {
            app.editingSessionDetails = nil
        } catch {
            app.error = error
        }
    }

    /// Closes the form once saved; a failed save keeps it open with the shared alert.
    private func save() {
        guard let draft else { return }
        do {
            try app.write { try $0.sessions.updateMetadata(id, draft.metadata) }
            app.editingSessionDetails = nil
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
private struct SessionDetailsFormPreview: View {
    @State private var app: AppModel = {
        let app = AppModel.preview()
        app.editingSessionDetails = app.store.sessions.sessions().first?.id
        return app
    }()

    var body: some View {
        if let id = app.editingSessionDetails {
            SessionDetailsForm(id: id)
                .environment(app)
        }
    }
}

#Preview("Light") { SessionDetailsFormPreview() }
#Preview("Dark") { SessionDetailsFormPreview().preferredColorScheme(.dark) }
#Preview("AX5") { SessionDetailsFormPreview().dynamicTypeSize(.accessibility5) }
#endif
