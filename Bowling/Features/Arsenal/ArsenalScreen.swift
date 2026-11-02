import BowlingCore
import BowlingData
import SwiftUI

/// The Arsenal tab (spec §7, Arsenal 1b): active balls, a collapsed Retired group, and Add
/// ball. Rows are display only until ball detail (#30); Compare arrives with its table (#31).
struct ArsenalScreen: View {
    @Environment(AppModel.self) private var app
    @State private var list: ArsenalList?
    @State private var showsRetired = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        @Bindable var app = app
        // The canvas is always there, so `.task` runs before the first load fills `list`.
        ZStack {
            Color.canvas.ignoresSafeArea()
            if let list {
                if list.isEmpty {
                    empty
                } else {
                    rows(list)
                }
            }
        }
        .navigationTitle("Arsenal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { app.ballForm = .add } label: {
                    Label("Add ball", systemImage: "plus")
                }
            }
        }
        .sheet(item: $app.ballForm) { target in
            BallFormSheet(target: target, store: app.store)
                .sharedErrorAlert(in: .ballForm)
        }
        .task(id: app.revision) {
            list = ArsenalList.load(from: app.store)
        }
    }

    private func rows(_ list: ArsenalList) -> some View {
        List {
            Section {
                ForEach(list.active, content: row)
            }
            if !list.retired.isEmpty {
                Section(isExpanded: $showsRetired) {
                    ForEach(list.retired, content: row)
                } header: {
                    Text("Retired (\(list.retired.count))")
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private func row(_ row: ArsenalList.Row) -> some View {
        // At accessibility sizes the photo goes above the text, so names and the badge get
        // the full width instead of breaking mid-word beside it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        // Opens Edit until ball detail (#30) takes the tap.
        return Button { app.ballForm = .edit(row.id) } label: {
            layout {
                BallThumbnail(id: row.id, hasPhoto: row.hasPhoto, placeholder: row.placeholder)
                    .saturation(row.isRetired ? 0 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name).font(.headline)
                    Group {
                        Text(row.detail)
                        Text(row.games)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if row.isResurfaceDue {
                        ResurfaceDueBadge()
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .listRowBackground(Color.surface)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No balls yet.", systemImage: "circle.circle")
        } actions: {
            Button("Add ball") { app.ballForm = .add }
                .buttonStyle(.borderedProminent)
        }
    }
}

/// "Resurface due" on an Arsenal row (spec §7).
private struct ResurfaceDueBadge: View {
    var body: some View {
        Text("Resurface due")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.cautionText)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.cautionSoft, in: .capsule)
    }
}

#if DEBUG
private struct ArsenalScreenPreview: View {
    @State private var app: AppModel

    /// `empty`: an owner with no balls yet. Otherwise the demo arsenal, with its most-used
    /// ball due for a resurface and a retired ball.
    init(empty: Bool = false) {
        guard empty else {
            let app = AppModel.preview()
            let balls = app.store.balls
            if let used = balls.activeBalls().max(by: { $0.gamesBowled < $1.gamesBowled }) {
                var fields = try! balls.detail(for: used.id).fields
                fields.resurfaceIntervalGames = 1
                _ = try! balls.updateBall(used.id, with: fields)
            }
            let old = try! balls.addBall(name: "Hammer Black Widow", weightPounds: 15, intendedRole: .strike, brand: "Hammer")
            try! balls.setRetired(true, for: old.id)
            _app = State(initialValue: app)
            return
        }
        let store = try! BowlingStore(inMemory: true)
        _ = try! store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        _app = State(initialValue: AppModel(store: store))
    }

    var body: some View {
        NavigationStack { ArsenalScreen() }
            .environment(app)
    }
}

#Preview("Light") { ArsenalScreenPreview() }
#Preview("Dark") { ArsenalScreenPreview().preferredColorScheme(.dark) }
#Preview("AX5") { ArsenalScreenPreview().dynamicTypeSize(.accessibility5) }
#Preview("Empty, light") { ArsenalScreenPreview(empty: true) }
#Preview("Empty, dark") { ArsenalScreenPreview(empty: true).preferredColorScheme(.dark) }
#Preview("Empty, AX5") { ArsenalScreenPreview(empty: true).dynamicTypeSize(.accessibility5) }
#endif
