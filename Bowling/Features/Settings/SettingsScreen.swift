import BowlingCore
import BowlingData
import SwiftUI

/// Settings (spec §1), pushed from Home's toolbar. The style and default games save as soon
/// as they are picked; the scoring toggles stay on this phone.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var owner: BowlerRecord?
    @State private var scoring = ScoringValues()
    @State private var isConfirmingDelete: Bool
    @State private var isConfirmingAgain = false

    /// UserDefaults isn't observable, so the toggles read from and write through this copy.
    private struct ScoringValues: Hashable {
        var tapWhatFell = false
        var autoAdvanceOnSpare = false
        var rotateBowlers = true
    }

    /// `confirmingDelete` opens on the first delete prompt, for previews.
    init(confirmingDelete: Bool = false) {
        _isConfirmingDelete = State(initialValue: confirmingDelete)
    }

    var body: some View {
        Form {
            if let owner {
                let rows = SettingsRows(owner: owner)
                profileSection(rows, owner: owner)
                statsSection(rows)
            }
            scoringSection
            Section {
                LabeledContent("iCloud sync", value: String(localized: "Coming soon"))
            }
            Section("About") {
                LabeledContent("Version", value: Self.version)
            }
            Section {
                Button("Delete all data", role: .destructive) { isConfirmingDelete = true }
            }
        }
        .navigationTitle("Settings")
        .task(id: app.revision) {
            owner = app.store.bowlers.owner()
            let settings = app.scoringSettings
            scoring = ScoringValues(tapWhatFell: settings.tapWhatFell,
                                    autoAdvanceOnSpare: settings.autoAdvanceOnSpare,
                                    rotateBowlers: settings.rotateBowlers)
        }
        .confirmationDialog("Delete all data?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) { isConfirmingAgain = true }
        } message: {
            Text("This deletes every session, game, ball and your profile from this iPhone.")
        }
        .alert("This can't be undone.", isPresented: $isConfirmingAgain) {
            Button("Delete everything", role: .destructive) {
                do { try app.deleteAllData() } catch { app.error = error }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func profileSection(_ rows: SettingsRows, owner: BowlerRecord) -> some View {
        Section {
            NavigationLink(rows.profileSummary) { ProfileScreen(owner: owner) }
            Picker("Bowling style", selection: Binding(get: { rows.style }, set: setStyle)) {
                ForEach(SettingsRows.styles, id: \.self) { style in
                    Text(SettingsRows.title(style)).tag(Optional(style))
                }
            }
        } header: {
            Text("Profile")
        } footer: {
            Text("Decides which stats you see first.")
        }
    }

    private func statsSection(_ rows: SettingsRows) -> some View {
        Section {
            Picker("Default games", selection: Binding(get: { rows.defaultGames }, set: setDefaultGames)) {
                ForEach(SettingsRows.DefaultGames.allCases, id: \.self) { games in
                    Text(rows.title(games)).tag(games)
                }
            }
        } header: {
            Text("Stats")
        } footer: {
            Text("Where Stats and Home start. You can still change it on Stats.")
        }
    }

    private var scoringSection: some View {
        Section {
            Picker("Pin entry", selection: scoringBinding(\.tapWhatFell) { $0.tapWhatFell = $1 }) {
                Text("Tap standing").tag(false)
                Text("Tap what fell").tag(true)
            }
            if scoring.tapWhatFell {
                Toggle("Auto-advance on spares", isOn: scoringBinding(\.autoAdvanceOnSpare) { $0.autoAdvanceOnSpare = $1 })
            }
            Toggle("Rotate bowlers", isOn: scoringBinding(\.rotateBowlers) { $0.rotateBowlers = $1 })
        } header: {
            Text("Scoring")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if scoring.tapWhatFell { Text("Records the second ball once it makes a spare.") }
                Text("Each night starts with this. You can still switch it in Scoring.")
            }
        }
    }

    /// Writes the copy and the stored setting together.
    private func scoringBinding(_ value: WritableKeyPath<ScoringValues, Bool>,
                                store: @escaping (ScoringSettings, Bool) -> Void) -> Binding<Bool> {
        Binding {
            scoring[keyPath: value]
        } set: { newValue in
            scoring[keyPath: value] = newValue
            store(app.scoringSettings, newValue)
        }
    }

    private func setStyle(_ style: StatsProfile?) {
        guard let style else { return }
        do { try app.write { try $0.bowlers.setStatsProfile(style) } } catch { app.error = error }
    }

    private func setDefaultGames(_ games: SettingsRows.DefaultGames) {
        do { try app.write { try $0.bowlers.setStatsScope(games.scope) } } catch { app.error = error }
    }

    /// "1.0 (12)".
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }
}

#if DEBUG
private struct SettingsScreenPreview: View {
    @State private var app = AppModel.preview()
    var tapWhatFell = false
    var confirmingDelete = false

    var body: some View {
        NavigationStack { SettingsScreen(confirmingDelete: confirmingDelete) }
            .environment(app)
            .onAppear { app.scoringSettings.tapWhatFell = tapWhatFell }
    }
}

#Preview("Light") { SettingsScreenPreview() }
#Preview("Dark") { SettingsScreenPreview().preferredColorScheme(.dark) }
#Preview("AX5") { SettingsScreenPreview().dynamicTypeSize(.accessibility5) }
#Preview("Tap what fell") { SettingsScreenPreview(tapWhatFell: true) }
#Preview("Delete, light") { SettingsScreenPreview(confirmingDelete: true) }
#Preview("Delete, dark") { SettingsScreenPreview(confirmingDelete: true).preferredColorScheme(.dark) }
#Preview("Delete, AX5") { SettingsScreenPreview(confirmingDelete: true).dynamicTypeSize(.accessibility5) }
#endif
