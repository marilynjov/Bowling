import BowlingData
import SwiftUI

/// Past bowlers not in the lineup yet, plus Add "<name>" for someone new. Picking or adding
/// puts them in the lineup and goes back to the form.
struct AddBowlerPicker: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    let choices: AddBowlerChoices
    let onPick: (BowlerRecord) -> Void
    /// Creates a bowler from a trimmed name.
    let create: (String) throws -> BowlerRecord

    var body: some View {
        List {
            ForEach(NameSearch.filter(choices.candidates, by: search, name: \.name)) { bowler in
                PickerRow(name: bowler.name, isPicked: false) { pick(bowler) }
            }
            if let name = choices.addName(for: search) {
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
}

#if DEBUG
private struct AddBowlerPickerPreview: View {
    @State private var app = AppModel.preview()

    var body: some View {
        NavigationStack {
            let _ = app.revision
            let bowlers = app.store.bowlers.bowlers()
            AddBowlerPicker(
                choices: AddBowlerChoices(candidates: bowlers.filter { !$0.isOwner }, names: bowlers.map(\.name)),
                onPick: { _ in }
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
#endif
