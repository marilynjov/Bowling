import BowlingData
import SwiftUI

/// Past bowlers not in the lineup yet, plus Add "<name>" for someone new, or Unarchive
/// "<name>" when that name is an archived friend. Picking, adding or unarchiving puts them in
/// the lineup and goes back to the form.
struct AddBowlerPicker: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    /// Starts empty; previews pass a name.
    @State var search = ""

    let choices: AddBowlerChoices
    let onPick: (BowlerRecord) -> Void
    /// Brings an archived friend back, keeping their past games.
    let unarchive: (BowlerRecord) throws -> Void
    /// Creates a bowler from a trimmed name.
    let create: (String) throws -> BowlerRecord

    var body: some View {
        List {
            ForEach(NameSearch.filter(choices.candidates, by: search, name: \.name)) { bowler in
                PickerRow(name: bowler.name, isPicked: false) { pick(bowler) }
            }
            if let bowler = choices.archivedMatch(for: search) {
                UnarchiveRow(name: bowler.name) { restore(bowler) }
            } else if let name = choices.addName(for: search) {
                AddRow(name: name) { add(name) }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name")
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .navigationTitle("Add bowler")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pick(_ bowler: BowlerRecord) {
        onPick(bowler)
        dismiss()
    }

    private func add(_ name: String) {
        do {
            pick(try create(name))
        } catch {
            app.error = error
        }
    }

    private func restore(_ bowler: BowlerRecord) {
        do {
            try unarchive(bowler)
            pick(bowler)
        } catch {
            app.error = error
        }
    }
}

private struct UnarchiveRow: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Unarchive \u{201C}\(name)\u{201D}", systemImage: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(Color.accentText)
        }
        .listRowBackground(Color.surface)
    }
}

#if DEBUG
private struct AddBowlerPickerPreview: View {
    @State private var app: AppModel
    private let search: String

    /// `showsUnarchive` archives the first friend and searches for them.
    init(showsUnarchive: Bool = false) {
        let app = AppModel.preview()
        let friend = showsUnarchive ? app.store.bowlers.bowlers().first : nil
        if let friend { try? app.write { try $0.bowlers.setArchived(true, for: friend.id) } }
        _app = State(initialValue: app)
        search = friend?.name ?? ""
    }

    var body: some View {
        NavigationStack {
            let _ = app.revision
            let bowlers = app.store.bowlers.bowlers(includingArchived: true)
            AddBowlerPicker(
                search: search,
                choices: AddBowlerChoices(
                    candidates: bowlers.filter { !$0.isOwner && !$0.isArchived }, names: bowlers.map(\.name),
                    archived: bowlers.filter(\.isArchived)
                ),
                onPick: { _ in },
                unarchive: { bowler in try app.write { try $0.bowlers.setArchived(false, for: bowler.id) } }
            ) { name in
                try app.write { try $0.bowlers.createBowler(name: name) }
            }
        }
        .environment(app)
    }
}

#Preview("Light") { AddBowlerPickerPreview() }
#Preview("Dark") { AddBowlerPickerPreview().preferredColorScheme(.dark) }
#Preview("AX5") { AddBowlerPickerPreview().dynamicTypeSize(.accessibility5) }
#Preview("Unarchive") { AddBowlerPickerPreview(showsUnarchive: true) }
#endif
