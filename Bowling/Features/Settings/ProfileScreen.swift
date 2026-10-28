import BowlingCore
import BowlingData
import SwiftUI

/// The owner's name and hand (spec §2), pushed from Settings.
struct ProfileScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfileDraft

    init(owner: BowlerRecord) {
        _draft = State(initialValue: ProfileDraft(owner: owner))
    }

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
                .textContentType(.name)
            Picker("Hand", selection: $draft.handedness) {
                Text("Left").tag(Optional(Handedness.left))
                Text("Right").tag(Optional(Handedness.right))
            }
            .pickerStyle(.segmented)
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        try app.write { try draft.save(to: $0.bowlers) }
                        dismiss()
                    } catch {
                        app.error = error
                    }
                }
                .disabled(!draft.canSave)
            }
        }
    }
}

#if DEBUG
private struct ProfileScreenPreview: View {
    @State private var app = AppModel.preview()

    var body: some View {
        NavigationStack { ProfileScreen(owner: app.store.bowlers.owner()!) }
            .environment(app)
    }
}

#Preview("Light") { ProfileScreenPreview() }
#Preview("Dark") { ProfileScreenPreview().preferredColorScheme(.dark) }
#Preview("AX5") { ProfileScreenPreview().dynamicTypeSize(.accessibility5) }
#endif
