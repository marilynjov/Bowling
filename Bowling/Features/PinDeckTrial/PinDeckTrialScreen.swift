#if DEBUG
import BowlingCore
import SwiftUI

/// The pin deck test for real bowlers (#3), in debug builds only: both deck styles, tap
/// fallen or tap standing, and Strike/Spare, Miss, Foul. Nothing is saved; leaving the
/// screen throws the game away. Reached from Settings.
struct PinDeckTrialScreen: View {
    enum Entry: String, CaseIterable, Identifiable {
        case tapFallen = "Tap fallen"
        case tapStanding = "Tap standing"
        var id: Self { self }
    }

    @State private var trial = PinDeckTrial()
    @State private var standing: PinSet = .all
    @State private var style: PinDeckStyle = .pins
    @State private var entry: Entry = .tapFallen

    private var position: RollPosition? { trial.position }
    private var available: PinSet { position?.standingPins ?? [] }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScorecardStrip(scorecard: trial.scorecard, currentFrame: position?.frameIndex)
                Picker("Deck", selection: $style) {
                    Text("Pins").tag(PinDeckStyle.pins)
                    Text("Circles").tag(PinDeckStyle.circles)
                }
                .pickerStyle(.segmented)
                Picker("Entry", selection: $entry) {
                    ForEach(Entry.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                deck
                buttons
            }
            .padding(16)
        }
        .background(.canvas)
        .navigationTitle("Pin deck test")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Undo", systemImage: "arrow.uturn.backward") { trial.undo() }
                Button("New game", systemImage: "arrow.counterclockwise") { trial = PinDeckTrial() }
            }
        }
        .onChange(of: position, initial: true) { resetDeck() }
        .onChange(of: entry) { resetDeck() }
    }

    private var deck: some View {
        VStack(spacing: 12) {
            Text(prompt)
                .font(.headline)
                .foregroundStyle(.ink)
            PinDeckView(available: available, standing: $standing, style: style)
                .disabled(position == nil)
        }
        .padding(14)
        .background(.surface, in: .rect(cornerRadius: 14, style: .continuous))
    }

    private var prompt: String {
        guard let position else { return "Game over: \(trial.scorecard.finalScore ?? 0)" }
        let action = entry == .tapFallen ? "tap the pins that fell" : "tap the pins left standing"
        return "Frame \(position.frameIndex), ball \(position.rollIndex): \(action)"
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(position?.isFreshRack == false ? "Spare" : "Strike") { trial.clearRack() }
                Button("Miss") { trial.miss() }
                Button("Foul") { trial.foul() }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            Button {
                trial.record(standing: standing)
            } label: {
                Text("Next ball").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .disabled(position == nil)
    }

    /// Tap fallen starts with every pin up; tap standing starts with the deck clear.
    private func resetDeck() {
        standing = entry == .tapFallen ? available : []
    }
}

#Preview("Pin deck test") {
    NavigationStack { PinDeckTrialScreen() }
}
#Preview("Pin deck test, dark") {
    NavigationStack { PinDeckTrialScreen() }.preferredColorScheme(.dark)
}
#endif
