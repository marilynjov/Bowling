import BowlingCore
import BowlingData
import SwiftUI

/// Resume, Start session, Quick score, the Home tiles, and the three newest sessions.
struct HomeScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var data = HomeData()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let resume = data.resume {
                    ResumeCardView(card: resume) { app.resume(resume.target) }
                }
                actions
                tiles
                recent
            }
            .padding(16)
        }
        .background(Color.canvas)
        .navigationTitle("Home")
        .toolbar {
            NavigationLink {
                SettingsScreen()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .overlay(alignment: .bottom) {
            if let saved = app.savedQuickScore {
                UndoBanner(saved: saved)
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: app.savedQuickScore)
        .task(id: app.revision) { data = HomeData.load(from: app.store) }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button { app.isStartingSession = true } label: {
                Text("Start session").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            Button { app.isQuickScoring = true } label: {
                Text("Quick score").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.accentText)
        }
        .controlSize(.large)
    }

    private var tiles: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(data.tiles) { tile in
                StatTile(title: tile.title, value: tile.value, sample: tile.sample, progress: tile.progress)
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent sessions").monoLabel()
            if data.recent.isEmpty {
                Text("Your sessions show up here.")
                    .foregroundStyle(Color.inkMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(data.recent) { row in
                        Button { app.openSession(row.id) } label: {
                            RecentSessionRow(row: row)
                        }
                        .buttonStyle(.plain)
                        if row.id != data.recent.last?.id {
                            Divider().overlay(Color.hairline)
                        }
                    }
                }
                .background(Color.surface, in: .rect(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.hairline))
            }
        }
    }
}

#if DEBUG
private struct HomeScreenPreview: View {
    @State private var app: AppModel

    /// `empty`: an owner with no sessions yet.
    init(empty: Bool = false) {
        guard empty else { _app = State(initialValue: .preview()); return }
        let store = try! BowlingStore(inMemory: true)
        _ = try! store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        _app = State(initialValue: AppModel(store: store))
    }

    var body: some View {
        NavigationStack { HomeScreen() }
            .environment(app)
    }
}

#Preview("Light") { HomeScreenPreview() }
#Preview("Dark") { HomeScreenPreview().preferredColorScheme(.dark) }
#Preview("AX5") { HomeScreenPreview().dynamicTypeSize(.accessibility5) }
#Preview("Empty, light") { HomeScreenPreview(empty: true) }
#Preview("Empty, dark") { HomeScreenPreview(empty: true).preferredColorScheme(.dark) }
#Preview("Empty, AX5") { HomeScreenPreview(empty: true).dynamicTypeSize(.accessibility5) }
#endif
