import BowlingCore
import BowlingData
import SwiftUI

/// This roll's ball. The menu picks an active ball for this roll only, or No ball on a game
/// without a default ball; after the roll it goes back to the game's default.
struct BallChip: View {
    let model: ScoringModel

    var body: some View {
        Menu {
            if model.offersNoBall {
                pick("No ball", id: nil)
            }
            ForEach(model.balls) { ball in
                pick(BallPicker.label(ball), id: ball.id)
            }
        } label: {
            Text(name)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Ball, \(name)")
    }

    /// The ball's name, or "No ball" (also for a ball no longer active).
    private var name: String {
        model.balls.first { $0.id == model.rollBallID }?.name ?? "No ball"
    }

    private func pick(_ title: String, id: BallID?) -> some View {
        Button { model.pickBall(id) } label: {
            if model.rollBallID == id {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
