import BowlingCore
import BowlingData
import SwiftUI

/// A night of scoring (spec §7, Scoring): the current bowler's game, scored pin by pin, by
/// count, or as a final score, with the bowler strip, frame editing, and the game summary.
/// Shown in the root's full-screen cover. Every roll is saved as it is recorded.
struct ScoringScreen: View {
    @Environment(AppModel.self) private var app
    let target: ScoringTarget
    @State private var session: SessionScoringModel?
    @State private var failed = false

    var body: some View {
        Group {
            if let session {
                ScoringSessionView(session: session)
            } else {
                NavigationStack {
                    Group {
                        if failed {
                            Text("This game couldn't be opened.")
                                .foregroundStyle(Color.inkMuted)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.canvas
                        }
                    }
                    .background(Color.canvas)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark", action: app.closeScoring)
                                .frame(minWidth: 48, minHeight: 48)
                        }
                    }
                }
            }
        }
        .task(id: target) { load() }
    }

    /// A failure stays in the cover, whose alert shows it, with Close to leave.
    private func load() {
        session = SessionScoringModel.open(target, app: app)
        failed = session == nil
    }
}

/// The loaded night: toolbar, strips, entry area, and the summary sheet.
struct ScoringSessionView: View {
    @Environment(AppModel.self) private var app
    @Bindable var session: SessionScoringModel

    var body: some View {
        NavigationStack {
            // A new identity per game, so the typed score field doesn't carry over to the
            // next bowler.
            ScoringContent(session: session, model: session.current)
                .id(session.current.target.gameID)
                .background(Color.canvas)
                .navigationTitle(session.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark", action: app.closeScoring)
                            .frame(minWidth: 48, minHeight: 48)
                    }
                    if session.bowlers.count > 1 {
                        ToolbarItem(placement: .topBarTrailing) {
                            Toggle(isOn: $session.rotates) {
                                Label("Rotate bowlers", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .toggleStyle(.button)
                            .frame(minWidth: 48, minHeight: 48)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        EntryModeMenu(model: session.current)
                    }
                }
        }
        .sheet(isPresented: $session.isShowingSummary) {
            GameSummarySheet(session: session)
                .sharedErrorAlert(in: .gameSummary)
        }
        .onChange(of: session.currentIndex) {
            guard session.bowlers.count > 1 else { return }
            AccessibilityNotification.Announcement(AccessibilityText.turn(session.current.bowlerName)).post()
        }
    }
}

/// The bowler strip, the current bowler's scorecard, then the entry area for the game's
/// mode, an edit, or the Complete panel.
private struct ScoringContent: View {
    let session: SessionScoringModel
    let model: ScoringModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if session.bowlers.count > 1 {
                    BowlerStrip(session: session)
                }
                ScorecardStrip(
                    scorecard: model.scorecard,
                    currentFrame: model.edit?.frameIndex ?? model.pad?.position.frameIndex,
                    onSelectFrame: selectFrame
                )
                if let edit = model.edit {
                    FrameEditBar(model: model, edit: edit)
                }
                if let cleared = FrameEdit.clearedText(model.clearedFrames) {
                    ClearedFramesNotice(text: cleared)
                }
                entry
            }
            .padding(16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Tapping a finished frame edits it; a final-score game has no frames to edit.
    private var selectFrame: ((Int) -> Void)? {
        guard model.game.entryMode != .finalOnly else { return nil }
        return { [model] frame in model.beginEdit(frame: frame) }
    }

    @ViewBuilder private var entry: some View {
        if model.game.entryMode == .finalOnly, !model.isComplete || model.isEditingFinalScore {
            FinalScoreEntry(model: model)
        } else if model.isComplete, model.edit == nil {
            GameCompletePanel(model: model, session: session)
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
                    Text(model.edit == nil ? "Next" : "Replace").frame(maxWidth: .infinity, minHeight: 48)
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
/// A two-bowler night from the demo store: Sam (the owner) and Alex, each game in its own
/// mode with its rolls recorded, then `act` run on the model (an edit, a chip tap).
private struct NightPreview<Content: View>: View {
    @State private var app: AppModel
    @State private var session: SessionScoringModel
    private let content: (SessionScoringModel) -> Content

    init(
        sam: (EntryMode, [RollInput]), alex: (EntryMode, [RollInput]),
        act: (SessionScoringModel) -> Void = { _ in },
        @ViewBuilder content: @escaping (SessionScoringModel) -> Content
    ) {
        let app = AppModel.preview()
        let target = try! app.write { store in
            let owner = store.bowlers.owner()!
            let friend = try store.bowlers.createBowler(name: "Alex")
            let ball = store.balls.activeBalls().first?.id
            let session = try store.sessions.startSession(
                SessionMetadata(date: .now, eventType: .league), bowlers: [(owner.id, ball), (friend.id, nil)],
                entryMode: sam.0
            )
            let games = try store.sessions.session(session).bowlers.map { $0.games[0].id }
            try store.games.setEntryMode(alex.0, for: games[1])
            for (game, rolls) in zip(games, [sam.1, alex.1]) {
                for roll in rolls { _ = try store.games.recordRoll(roll, ballID: nil, in: game) }
            }
            return ScoringTarget(sessionID: session, gameID: games[0])
        }
        app.scoring = target
        let session = try! SessionScoringModel(target: target, app: app)
        act(session)
        _app = State(initialValue: app)
        _session = State(initialValue: session)
        self.content = content
    }

    var body: some View {
        content(session).environment(app)
    }
}

private let nines = [RollInput]((0..<10).flatMap { _ in [RollInput.count(9), .count(0)] })
private let leaves: [RollInput] = [.pinsLeft(PinSet(pins: [7, 10])), .pinsLeft([]), .pinsLeft(PinSet(pins: [4])), .pinsLeft(PinSet(pins: [4]))]
    + (3...10).flatMap { _ in [RollInput.pinsLeft(PinSet(pins: [10])), .pinsLeft(PinSet(pins: [10]))] }

private func night() -> some View {
    NightPreview(sam: (.pinByPin, midGame), alex: (.countOnly, [.count(9), .count(1), .count(8)])) {
        ScoringSessionView(session: $0)
    }
}

private func editing() -> some View {
    NightPreview(sam: (.pinByPin, midGame), alex: (.countOnly, [.count(9)]), act: {
        $0.select(0)
        $0.current.beginEdit(frame: 2)
    }) {
        ScoringSessionView(session: $0)
    }
}

/// A strike changed to 7 drops frame 2, so the notice asks for it again.
private func cleared() -> some View {
    NightPreview(sam: (.countOnly, [.count(10), .count(3), .count(4)]), alex: (.countOnly, []), act: {
        $0.select(0)
        $0.current.beginEdit(frame: 1)
        $0.current.count(7)
    }) {
        ScoringSessionView(session: $0)
    }
}

private func summary() -> some View {
    NightPreview(sam: (.pinByPin, leaves), alex: (.countOnly, nines)) {
        GameSummarySheet(session: $0)
    }
}

#Preview("Night, light") { night() }
#Preview("Night, dark") { night().preferredColorScheme(.dark) }
#Preview("Night, AX5") { night().dynamicTypeSize(.accessibility5) }
#Preview("Edit, light") { editing() }
#Preview("Edit, dark") { editing().preferredColorScheme(.dark) }
#Preview("Edit, AX5") { editing().dynamicTypeSize(.accessibility5) }
#Preview("Cleared, light") { cleared() }
#Preview("Cleared, dark") { cleared().preferredColorScheme(.dark) }
#Preview("Cleared, AX5") { cleared().dynamicTypeSize(.accessibility5) }
#Preview("Summary, light") { summary() }
#Preview("Summary, dark") { summary().preferredColorScheme(.dark) }
#Preview("Summary, AX5") { summary().dynamicTypeSize(.accessibility5) }
#endif
