import BowlingCore
import BowlingData
import SwiftUI

/// Home's Start: the session's details and lineup. Start creates it and opens Scoring;
/// Cancel saves nothing about the session.
struct NewSessionSheet: View {
    @Environment(AppModel.self) private var app
    @State private var draft: NewSessionDraft?
    @State private var centers: [NamedRef] = []
    @State private var leagues: [LeagueRecord] = []
    @State private var oilPatterns: [NamedRef] = []
    @State private var balls: [BallSummary] = []
    @State private var bowlers: [BowlerRecord] = []

    var body: some View {
        NavigationStack {
            Group {
                if let draft = Binding($draft) {
                    form(draft)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("New session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { app.isStartingSession = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: start)
                        .disabled(draft == nil)
                }
            }
        }
        .task(id: app.revision) { reload() }
    }

    private func form(_ draft: Binding<NewSessionDraft>) -> some View {
        Form {
            Section {
                DatePicker("Date", selection: draft.date)
                Picker("Event", selection: eventType(draft)) {
                    ForEach([EventType.practice, .league, .tournament, .casual], id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.surface)

            Section {
                NavigationLink {
                    NamedRefPicker(title: "Center", items: centers, selection: draft.centerID) { name in
                        try app.write { try $0.sessions.createCenter(name: name) }
                    }
                } label: {
                    LabeledContent("Center", value: name(of: draft.wrappedValue.centerID, in: centers))
                }
                if draft.wrappedValue.eventType == .league {
                    NavigationLink {
                        NamedRefPicker(title: "League", items: draft.wrappedValue.leagues(from: leagues), selection: draft.leagueID) { name in
                            let centerID = draft.wrappedValue.centerID
                            return try app.write { try $0.sessions.createLeague(name: name, centerID: centerID) }
                        }
                    } label: {
                        LabeledContent("League", value: name(of: draft.wrappedValue.leagueID, in: leagues))
                    }
                }
                NavigationLink {
                    NamedRefPicker(title: "Oil pattern", items: oilPatterns, selection: draft.oilPatternID) { name in
                        try app.write { try $0.sessions.createOilPattern(name: name) }
                    }
                } label: {
                    LabeledContent("Oil pattern", value: name(of: draft.wrappedValue.oilPatternID, in: oilPatterns))
                }
                LabeledContent("Lanes") {
                    TextField("Lanes", text: draft.lanes, prompt: Text("13–14"))
                        .multilineTextAlignment(.trailing)
                }
            }
            .listRowBackground(Color.surface)

            Section("Bowlers") {
                ForEach(draft.lineup) { $entry in
                    if entry.isOwner {
                        NavigationLink {
                            BallPicker(balls: balls, selection: $entry.ballID)
                        } label: {
                            LabeledContent(entry.name, value: ballName(entry.ballID))
                        }
                        .deleteDisabled(true)
                    } else {
                        Text(entry.name)
                    }
                }
                .onDelete { draft.wrappedValue.remove(atOffsets: $0) }
                .onMove { draft.wrappedValue.move(fromOffsets: $0, toOffset: $1) }
                NavigationLink {
                    AddBowlerPicker(
                        choices: draft.wrappedValue.addBowlerChoices(from: bowlers),
                        onPick: { draft.wrappedValue.add($0) }
                    ) { name in
                        try app.write { try $0.bowlers.createBowler(name: name) }
                    }
                } label: {
                    Label("Add bowler", systemImage: "person.badge.plus")
                        .foregroundStyle(Color.accentText)
                }
            }
            .listRowBackground(Color.surface)

            Section {
                Picker("Scoring", selection: draft.entryMode) {
                    Text("Pin by pin").tag(EntryMode.pinByPin)
                    Text("Count").tag(EntryMode.countOnly)
                    Text("Final score").tag(EntryMode.finalOnly)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("You can switch before the first roll.")
                    .foregroundStyle(Color.inkMuted)
            }
            .listRowBackground(Color.surface)

            Section {
                TextField("Notes", text: draft.notes, axis: .vertical)
                    .lineLimit(3...)
            }
            .listRowBackground(Color.surface)
        }
    }

    /// Switching event type fills in that type's remembered values.
    private func eventType(_ draft: Binding<NewSessionDraft>) -> Binding<EventType> {
        Binding {
            draft.wrappedValue.eventType
        } set: { type in
            draft.wrappedValue.eventType = type
            draft.wrappedValue = draft.wrappedValue.applying(
                app.sessionDefaults.defaults(for: type), available: .current(in: app.store)
            )
        }
    }

    private func name(of id: UUID?, in items: [some NamedItem]) -> String {
        items.first { $0.id == id }?.name ?? "None"
    }

    private func ballName(_ id: BallID?) -> String {
        balls.first { $0.id == id }.map(BallPicker.label) ?? "No ball"
    }

    /// Lists reload after every write; the draft is made once, from the remembered values.
    private func reload() {
        let store = app.store
        centers = store.sessions.centers()
        leagues = store.sessions.leagueRecords()
        oilPatterns = store.sessions.oilPatterns()
        balls = store.balls.activeBalls()
        bowlers = store.bowlers.bowlers()
        guard draft == nil, let owner = store.bowlers.owner() else { return }
        let type = app.sessionDefaults.lastEventType
        draft = NewSessionDraft(owner: owner, date: .now, eventType: type)
            .applying(app.sessionDefaults.defaults(for: type), available: .current(in: store))
    }

    private func start() {
        guard let draft else { return }
        do {
            try app.startSession(draft)
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
private struct NewSessionSheetPreview: View {
    @State private var app: AppModel = {
        let app = AppModel.preview()
        app.isStartingSession = true
        return app
    }()

    var body: some View {
        NewSessionSheet()
            .environment(app)
    }
}

#Preview("Light") { NewSessionSheetPreview() }
#Preview("Dark") { NewSessionSheetPreview().preferredColorScheme(.dark) }
#Preview("AX5") { NewSessionSheetPreview().dynamicTypeSize(.accessibility5) }
#endif
