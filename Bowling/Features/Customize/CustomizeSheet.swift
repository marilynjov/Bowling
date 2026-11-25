import BowlingCore
import BowlingData
import SwiftUI

/// Customize for the Stats tab or Home: the cards in the owner's layout (reorder, remove),
/// the cards still available by group (add), and Reset to preset. Save writes the whole
/// layout; a refused save keeps the sheet and shows the shared error alert.
struct CustomizeSheet: View {
    @Environment(AppModel.self) private var app
    let destination: LayoutDestination
    @State private var draft: LayoutDraft?
    @State private var isConfirmingReset = false

    init(destination: LayoutDestination) {
        self.destination = destination
    }

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    content(draft)
                } else {
                    Color.canvas
                }
            }
            .navigationTitle(destination == .stats ? "Customize Stats" : "Customize Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { app.customizing = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!(draft?.canSave ?? false))
                }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Content

    private func content(_ current: LayoutDraft) -> some View {
        List {
            Section {
                ForEach(current.cards, id: \.self) { card in
                    layoutRow(card, in: current)
                }
                .onMove { draft?.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { draft?.remove(atOffsets: $0) }
            } header: {
                Text("In your layout")
            } footer: {
                if !current.canSave {
                    Text("Add at least one card.")
                }
            }
            .listRowBackground(Color.surface)
            ForEach(current.catalog) { group in
                Section(StatsCardText.title(group.group)) {
                    ForEach(group.cards, id: \.self) { card in
                        Button { draft?.add(card) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentText)
                                    .accessibilityHidden(true)
                                titleAndDescription(card)
                            }
                        }
                        .accessibilityLabel("Add \(StatsCardText.title(card))")
                    }
                }
                .listRowBackground(Color.surface)
            }
            Section {
                Button("Reset to preset", role: .destructive) { isConfirmingReset = true }
                    .disabled(!current.isCustomized)
            }
            .listRowBackground(Color.surface)
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .confirmationDialog(
            "Go back to the cards for your bowling style?",
            isPresented: $isConfirmingReset, titleVisibility: .visible
        ) {
            Button("Reset to preset", role: .destructive, action: reset)
        }
    }

    private func layoutRow(_ card: StatsCardID, in current: LayoutDraft) -> some View {
        let index = current.cards.firstIndex(of: card) ?? 0
        return titleAndDescription(card)
            .accessibilityActions {
                if index > 0 {
                    Button("Move up") { draft?.move(fromOffsets: [index], toOffset: index - 1) }
                }
                if index < current.cards.count - 1 {
                    Button("Move down") { draft?.move(fromOffsets: [index], toOffset: index + 2) }
                }
            }
    }

    private func titleAndDescription(_ card: StatsCardID) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(StatsCardText.title(card))
                .foregroundStyle(Color.ink)
            Text(StatsCardText.description(card))
                .font(.footnote)
                .foregroundStyle(Color.inkMuted)
        }
    }

    // MARK: Actions

    private func load() {
        guard draft == nil else { return }
        guard let owner = app.store.bowlers.owner() else { return app.customizing = nil }
        draft = LayoutDraft(destination: destination, owner: owner)
    }

    private func save() {
        guard let cards = draft?.cards else { return }
        do {
            try app.write {
                switch destination {
                case .stats: try $0.bowlers.setStatsLayout(cards)
                case .home: try $0.bowlers.setHomeLayout(cards)
                }
            }
            app.customizing = nil
        } catch {
            app.error = error
        }
    }

    private func reset() {
        do {
            try app.write {
                switch destination {
                case .stats: try $0.bowlers.resetStatsLayout()
                case .home: try $0.bowlers.resetHomeLayout()
                }
            }
            app.customizing = nil
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
private struct CustomizeSheetPreview: View {
    @State private var app = AppModel.preview()
    var destination: LayoutDestination

    var body: some View {
        CustomizeSheet(destination: destination)
            .environment(app)
    }
}

#Preview("Stats, light") { CustomizeSheetPreview(destination: .stats) }
#Preview("Home, dark") { CustomizeSheetPreview(destination: .home).preferredColorScheme(.dark) }
#Preview("Stats, AX5") { CustomizeSheetPreview(destination: .stats).dynamicTypeSize(.accessibility5) }
#endif
