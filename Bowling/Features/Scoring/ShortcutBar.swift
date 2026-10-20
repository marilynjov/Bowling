import SwiftUI

/// Strike or Spare, Miss, Foul, Undo and the ball chip. One row, or two at accessibility
/// sizes. Every button but Undo records the roll and advances.
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
        if pad.offersStrike { shortcut("Strike", action: model.strike) }
        if pad.offersSpare { shortcut("Spare", action: model.spare) }
        shortcut("Miss", action: model.miss)
        shortcut("Foul", action: model.foul)
    }

    @ViewBuilder private var tools: some View {
        shortcut("Undo", action: model.undo)
            .disabled(!model.canUndo)
        BallChip(model: model)
    }

    private func shortcut(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
    }
}
