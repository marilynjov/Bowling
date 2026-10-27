import BowlingCore
import BowlingData
import SwiftUI

/// The Arsenal tab, 1a (spec §1): active balls and Add ball. Rows are display only until
/// ball detail (#30).
struct ArsenalScreen: View {
    @Environment(AppModel.self) private var app
    @State private var list: ArsenalList?

    var body: some View {
        @Bindable var app = app
        // The canvas is always there, so `.task` runs before the first load fills `list`.
        ZStack {
            Color.canvas.ignoresSafeArea()
            if let list {
                if list.rows.isEmpty {
                    empty
                } else {
                    rows(list.rows)
                }
            }
        }
        .navigationTitle("Arsenal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { app.isAddingBall = true } label: {
                    Label("Add ball", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $app.isAddingBall) {
            AddBallSheet()
                .sharedErrorAlert(in: .addBall)
        }
        .task(id: app.revision) {
            list = ArsenalList.load(from: app.store)
        }
    }

    private func rows(_ rows: [ArsenalList.Row]) -> some View {
        List(rows) { row in
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(.headline)
                Group {
                    Text(row.detail)
                    Text(row.games)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No balls yet.", systemImage: "circle.circle")
        } actions: {
            Button("Add ball") { app.isAddingBall = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

#if DEBUG
private struct ArsenalScreenPreview: View {
    @State private var app: AppModel

    /// `empty`: an owner with no balls yet.
    init(empty: Bool = false) {
        guard empty else { _app = State(initialValue: .preview()); return }
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
