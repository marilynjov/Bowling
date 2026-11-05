import SwiftUI

/// Strike or Spare, Miss, Foul, Undo and the ball chip. One row, or two at accessibility
/// sizes. Every button but Undo records the roll and advances; while a frame is edited they
/// replace its ball, and Undo is hidden.
struct ShortcutBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: ScoringModel
    let pad: RollPad

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                HStack(spacing: 8) { marks }
                HStack(spacing: 8) { tools }
            }
        } else {
            HStack(spacing: 8) {
                marks
                tools
            }
        }
    }

    @ViewBuilder private var marks: some View {
        if pad.offersStrike { shortcut(String(localized: "Strike"), id: "scoring.strike", action: model.strike) }
        if pad.offersSpare { shortcut(String(localized: "Spare"), id: "scoring.spare", action: model.spare) }
        shortcut(String(localized: "Miss"), id: "scoring.miss", action: model.miss)
        shortcut(String(localized: "Foul"), id: "scoring.foul", action: model.foul)
    }

    @ViewBuilder private var tools: some View {
        if model.edit == nil {
            shortcut(String(localized: "Undo"), id: "scoring.undo", action: model.undo)
                .disabled(!model.canUndo)
        }
        BallChip(model: model)
    }

    /// `id` is the UI tests' fixed identifier, so it never changes with the title's language.
    private func shortcut(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(id)
    }
}
