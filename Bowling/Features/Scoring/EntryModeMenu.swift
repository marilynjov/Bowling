import BowlingCore
import SwiftUI

/// Pin by pin, Count or Final score. Fixed once the game has a roll, with Clear rolls to
/// unlock it; leaving a typed score asks first, because it is discarded.
struct EntryModeMenu: View {
    let model: ScoringModel
    @State private var isConfirmingClear = false
    @State private var discardingFor: EntryMode?

    private static let modes: [(mode: EntryMode, title: String)] = [
        (.pinByPin, "Pin by pin"), (.countOnly, "Count"), (.finalOnly, "Final score"),
    ]

    var body: some View {
        Menu {
            ForEach(Self.modes, id: \.mode) { entry in
                Button { pick(entry.mode) } label: {
                    if model.game.entryMode == entry.mode {
                        Label(entry.title, systemImage: "checkmark")
                    } else {
                        Text(entry.title)
                    }
                }
                .disabled(!model.canChangeEntryMode)
            }
            if !model.canChangeEntryMode {
                Divider()
                Button("Clear rolls…", role: .destructive) { isConfirmingClear = true }
            }
        } label: {
            Label("Entry mode", systemImage: "slider.horizontal.3")
                .frame(minWidth: 48, minHeight: 48)
        }
        .confirmationDialog("Clear all rolls in this game?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear rolls", role: .destructive, action: model.clearRolls)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Discard the score of \(model.game.finalScore)?",
            isPresented: Binding(get: { discardingFor != nil }, set: { if !$0 { discardingFor = nil } }),
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                if let mode = discardingFor { model.setEntryMode(mode) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func pick(_ mode: EntryMode) {
        guard mode != model.game.entryMode else { return }
        if model.discardsTypedScore {
            discardingFor = mode
        } else {
            model.setEntryMode(mode)
        }
    }
}
