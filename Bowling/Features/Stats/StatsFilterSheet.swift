import BowlingCore
import BowlingData
import SwiftUI

/// "Filters" (spec §2): date, games and bowler. Edits a copy; Done applies it.
struct StatsFilterSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var draft: StatsFilterDraft
    /// Kept apart from `draft.scope` so picking exactly League and Tournament under Custom
    /// doesn't jump the picker to Competition.
    @State private var scope: StatsFilterDraft.Scope
    @State private var bowlers: [BowlerRecord] = []

    private static let customTypes: [EventType] = [.practice, .league, .tournament, .casual]

    init(draft: StatsFilterDraft) {
        _draft = State(initialValue: draft)
        _scope = State(initialValue: draft.scope)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Date", selection: $draft.filter.datePreset) {
                    ForEach(DatePreset.allCases, id: \.self) { Text(StatsFilterDraft.title($0)).tag($0) }
                }
                Section("Games") {
                    Picker("Games", selection: scopeBinding) {
                        Text("Competition").tag(StatsFilterDraft.Scope.competition)
                        Text("All games").tag(StatsFilterDraft.Scope.allGames)
                        Text("Custom").tag(StatsFilterDraft.Scope.custom)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    if scope == .custom {
                        ForEach(Self.customTypes, id: \.self) { type in
                            Toggle(type.title, isOn: typeBinding(type))
                        }
                    }
                }
                Picker("Bowler", selection: bowlerBinding) {
                    ForEach(bowlers) { Text($0.name).tag($0.id) }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        draft.isExplicit = true
                        app.statsFilter = draft
                        dismiss()
                    }
                    .disabled(!draft.canApply)
                }
            }
        }
        .task { bowlers = app.store.bowlers.bowlers() }
    }

    private var scopeBinding: Binding<StatsFilterDraft.Scope> {
        Binding {
            scope
        } set: { picked in
            scope = picked
            switch picked {
            case .competition: draft.filter.eventTypes = EventType.competition
            case .allGames: draft.filter.eventTypes = Set(EventType.allCases)
            case .custom: draft.filter.eventTypes.remove(.unknown)
            }
        }
    }

    private func typeBinding(_ type: EventType) -> Binding<Bool> {
        Binding {
            draft.filter.eventTypes.contains(type)
        } set: { isOn in
            if isOn { draft.filter.eventTypes.insert(type) } else { draft.filter.eventTypes.remove(type) }
        }
    }

    private var bowlerBinding: Binding<BowlerID> {
        Binding {
            draft.filter.bowlerID
        } set: { id in
            guard let bowler = bowlers.first(where: { $0.id == id }),
                  let owner = app.store.bowlers.owner() else { return }
            draft = draft.changingBowler(to: bowler, owner: owner, in: app.store)
            scope = draft.scope
        }
    }
}

#if DEBUG
private struct StatsFilterSheetPreview: View {
    @State private var app = AppModel.preview()

    var body: some View {
        let draft = StatsFilterDraft.current(nil, in: app.store)!
        StatsFilterSheet(draft: draft)
            .environment(app)
    }
}

#Preview("Light") { StatsFilterSheetPreview() }
#Preview("Dark") { StatsFilterSheetPreview().preferredColorScheme(.dark) }
#Preview("AX5") { StatsFilterSheetPreview().dynamicTypeSize(.accessibility5) }
#endif
