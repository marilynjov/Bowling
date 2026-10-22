import BowlingCore
import BowlingData
import SwiftUI

/// One game, scored pin by pin, by count, or as a final score (spec §7, Scoring). Shown in
/// the root's full-screen cover. Every roll is saved as it is recorded.
struct ScoringScreen: View {
    @Environment(AppModel.self) private var app
    let target: ScoringTarget
    @State private var model: ScoringModel?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    ScoringContent(model: model)
                } else if failed {
                    Text("This game couldn't be opened.")
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.canvas
                }
            }
            .background(Color.canvas)
            .navigationTitle(model.map { "Game \($0.game.gameIndex) · \($0.bowlerName)" } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", action: app.closeScoring)
                        .frame(minWidth: 48, minHeight: 48)
                }
                if let model {
                    ToolbarItem(placement: .primaryAction) {
                        EntryModeMenu(model: model)
                    }
                }
            }
        }
        .task(id: target) { load() }
    }

    /// A failure stays in the cover, whose alert shows it, with Close to leave.
    private func load() {
        model = ScoringModel.open(target, app: app)
        failed = model == nil
    }
}

/// The strip, then the entry area for the game's mode, or the Complete panel.
private struct ScoringContent: View {
    let model: ScoringModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScorecardStrip(scorecard: model.scorecard, currentFrame: model.pad?.position.frameIndex)
                entry
            }
            .padding(16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder private var entry: some View {
        if model.game.entryMode == .finalOnly, !model.isComplete || model.isEditingFinalScore {
            FinalScoreEntry(model: model)
        } else if model.isComplete {
            GameCompletePanel(model: model)
        } else if let pad = model.pad {
            if pad.entryMode == .countOnly {
                CountPad(model: model, pad: pad)
            } else {
                PinDeckView(
                    available: pad.position.standingPins,
                    standing: Binding(get: { model.pad?.shown ?? [] }, set: model.setShown)
                )
            }
            ShortcutBar(model: model, pad: pad)
            if pad.entryMode != .countOnly {
                Button(action: model.next) {
                    Text("Next").frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

#if DEBUG
/// A demo-store game in `mode` with `rolls` recorded (and `score` typed for final score).
private struct ScoringScreenPreview: View {
    @State private var app: AppModel
    private let target: ScoringTarget

    init(_ mode: EntryMode, rolls: [RollInput] = [], score: Int? = nil) {
        let app = AppModel.preview()
        target = try! app.write { store in
            let owner = store.bowlers.owner()!
            let ball = store.balls.activeBalls().first?.id
            let session = try store.sessions.startSession(
                SessionMetadata(date: .now, eventType: .league), bowlers: [(owner.id, ball)], entryMode: mode
            )
            let game = try store.sessions.session(session).bowlers[0].games[0].id
            for roll in rolls { _ = try store.games.recordRoll(roll, ballID: ball, in: game) }
            if let score { try store.games.setFinalScore(score, for: game) }
            return ScoringTarget(sessionID: session, gameID: game)
        }
        app.scoring = target
        _app = State(initialValue: app)
    }

    var body: some View {
        ScoringScreen(target: target).environment(app)
    }
}

private let midGame: [RollInput] = [.pinsLeft([]), .pinsLeft(PinSet(pins: [7, 10])), .pinsLeft([]), .pinsLeft(PinSet(pins: [4]))]
private let perfect = [RollInput](repeating: .pinsLeft([]), count: 12)

#Preview("Pins, light") { ScoringScreenPreview(.pinByPin, rolls: midGame) }
#Preview("Pins, dark") { ScoringScreenPreview(.pinByPin, rolls: midGame).preferredColorScheme(.dark) }
#Preview("Pins, AX5") { ScoringScreenPreview(.pinByPin, rolls: midGame).dynamicTypeSize(.accessibility5) }
#Preview("Count, light") { ScoringScreenPreview(.countOnly, rolls: [.count(7)]) }
#Preview("Count, dark") { ScoringScreenPreview(.countOnly, rolls: [.count(7)]).preferredColorScheme(.dark) }
#Preview("Count, AX5") { ScoringScreenPreview(.countOnly, rolls: [.count(7)]).dynamicTypeSize(.accessibility5) }
#Preview("Final, light") { ScoringScreenPreview(.finalOnly) }
#Preview("Final, dark") { ScoringScreenPreview(.finalOnly).preferredColorScheme(.dark) }
#Preview("Final, AX5") { ScoringScreenPreview(.finalOnly).dynamicTypeSize(.accessibility5) }
#Preview("Complete, light") { ScoringScreenPreview(.pinByPin, rolls: perfect) }
#Preview("Complete, dark") { ScoringScreenPreview(.pinByPin, rolls: perfect).preferredColorScheme(.dark) }
#Preview("Complete, AX5") { ScoringScreenPreview(.pinByPin, rolls: perfect).dynamicTypeSize(.accessibility5) }
#Preview("Typed, complete") { ScoringScreenPreview(.finalOnly, score: 187) }
#endif
