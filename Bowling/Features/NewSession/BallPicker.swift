import BowlingCore
import BowlingData
import SwiftUI

/// The owner's ball for the session: No ball, or one of the active balls.
struct BallPicker: View {
    @Environment(\.dismiss) private var dismiss

    let balls: [BallSummary]
    @Binding var selection: BallID?

    var body: some View {
        List {
            Section {
                PickerRow(name: "No ball", isPicked: selection == nil) { pick(nil) }
            } footer: {
                if balls.isEmpty {
                    Text("No balls yet. Add them in Arsenal.")
                        .foregroundStyle(Color.inkMuted)
                }
            }
            if !balls.isEmpty {
                Section {
                    ForEach(balls) { ball in
                        PickerRow(name: Self.label(ball), isPicked: selection == ball.id) { pick(ball.id) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .navigationTitle("Ball")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "Phaze · 15 lb"
    static func label(_ ball: BallSummary) -> String {
        "\(ball.name) · \(ball.weightPounds) lb"
    }

    private func pick(_ id: BallID?) {
        selection = id
        dismiss()
    }
}

#if DEBUG
private struct BallPickerPreview: View {
    @State private var app = AppModel.preview()
    @State private var selection: BallID?
    var empty = false

    var body: some View {
        NavigationStack {
            BallPicker(balls: empty ? [] : app.store.balls.activeBalls(), selection: $selection)
        }
    }
}

#Preview("Light") { BallPickerPreview() }
#Preview("Dark") { BallPickerPreview().preferredColorScheme(.dark) }
#Preview("AX5") { BallPickerPreview().dynamicTypeSize(.accessibility5) }
#Preview("Empty arsenal") { BallPickerPreview(empty: true) }
#endif
