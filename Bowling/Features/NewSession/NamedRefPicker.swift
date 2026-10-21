import BowlingData
import Foundation
import SwiftUI

/// Center, league, or oil pattern: a searchable list with None and an Add "<text>" row.
/// Picking or adding goes back to the form.
struct NamedRefPicker: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    let title: String
    let items: [NamedRef]
    @Binding var selection: UUID?
    /// Creates an item from a trimmed name and returns its ID.
    let create: (String) throws -> UUID

    var body: some View {
        List {
            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                row("None", isPicked: selection == nil) { pick(nil) }
            }
            ForEach(NameSearch.filter(items, by: search, name: \.name)) { item in
                row(item.name, isPicked: selection == item.id) { pick(item.id) }
            }
            if let name = NameSearch.addName(for: search, existing: items.map(\.name)) {
                AddRow(name: name) { add(name) }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ name: String, isPicked: Bool, action: @escaping () -> Void) -> some View {
        PickerRow(name: name, isPicked: isPicked, action: action)
    }

    private func pick(_ id: UUID?) {
        selection = id
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

/// A row with an accent checkmark when it's the current pick.
struct PickerRow: View {
    let name: String
    let isPicked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .foregroundStyle(Color.ink)
                Spacer()
                if isPicked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentText)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .listRowBackground(Color.surface)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

/// The last row of a searchable picker: creates what was typed.
struct AddRow: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add \u{201C}\(name)\u{201D}", systemImage: "plus.circle.fill")
                .foregroundStyle(Color.accentText)
        }
        .listRowBackground(Color.surface)
    }
}

#if DEBUG
private struct NamedRefPickerPreview: View {
    @State private var app = AppModel.preview()
    @State private var selection: UUID?

    var body: some View {
        NavigationStack {
            let _ = app.revision
            NamedRefPicker(title: "Center", items: app.store.sessions.centers(), selection: $selection) { name in
                try app.write { try $0.sessions.createCenter(name: name) }
            }
        }
        .environment(app)
        .task {
            for name in ["AMF Bowl", "Café Lanes", "Sunset Lanes"] {
                _ = try? app.write { try $0.sessions.createCenter(name: name) }
            }
        }
    }
}

#Preview("Light") { NamedRefPickerPreview() }
#Preview("Dark") { NamedRefPickerPreview().preferredColorScheme(.dark) }
#Preview("AX5") { NamedRefPickerPreview().dynamicTypeSize(.accessibility5) }
#endif
