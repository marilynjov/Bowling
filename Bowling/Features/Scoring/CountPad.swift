import SwiftUI

/// Count entry: 1 through 9 in three columns, then 0 and 10. Numbers above what is
/// standing are disabled. A tap records the roll.
struct CountPad: View {
    let model: ScoringModel
    let pad: RollPad

    private static let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [0, 10]]

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Self.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { pins in
                        button(pins)
                            .gridCellColumns(row.count == 2 && pins == 10 ? 2 : 1)
                    }
                }
            }
        }
    }

    /// The edited roll's old count is highlighted.
    @ViewBuilder private func button(_ pins: Int) -> some View {
        let button = Button { model.count(pins) } label: {
            Text("\(pins)")
                .font(.tileValue)
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .disabled(!pad.countChoices.contains(pins))
        if model.editedCount == pins {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
