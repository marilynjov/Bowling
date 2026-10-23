import BowlingCore
import Foundation

/// One recorded roll being replaced: a finished frame's ball, picked from the scorecard
/// (spec §2, Editing a finished frame).
struct FrameEdit: Hashable {
    let frameIndex: Int
    let rollIndex: Int

    /// The recorded roll, or nil once it is gone (Clear rolls, a mode change).
    func roll(in game: GameRecord) -> RollRecord? {
        game.frames.first { $0.frameIndex == frameIndex }?.rolls.first { $0.rollIndex == rollIndex }
    }

    /// The rack this roll faced, as `replaceRoll` sees it: the game's next roll with only
    /// the rolls before this one.
    func position(in game: GameRecord) -> RollPosition? {
        var before = game
        before.frames = game.frames.compactMap { frame in
            guard frame.frameIndex <= frameIndex else { return nil }
            let rolls = frame.frameIndex < frameIndex ? frame.rolls : frame.rolls.filter { $0.rollIndex < rollIndex }
            return rolls.isEmpty ? nil : FrameRecord(frameIndex: frame.frameIndex, rolls: rolls)
        }
        return Scorer.nextRoll(in: before)
    }

    /// The same frame's next recorded ball, or nil when this was its last.
    func next(in game: GameRecord) -> FrameEdit? {
        let next = FrameEdit(frameIndex: frameIndex, rollIndex: rollIndex + 1)
        return next.roll(in: game) == nil ? nil : next
    }

    /// "Frame 4 was cleared. Enter it again." / "Frames 4 and 5 were cleared. Enter them
    /// again."; nil when nothing was cleared.
    static func clearedText(_ frames: [Int]) -> String? {
        guard let last = frames.last else { return nil }
        guard frames.count > 1 else { return String(localized: "Frame \(last) was cleared. Enter it again.") }
        let list = frames.dropLast().map(String.init).joined(separator: ", ")
        return String(localized: "Frames \(list) and \(last) were cleared. Enter them again.")
    }
}

/// What a `ScoringModel` write did, for the session model's rotation and summary.
enum ScoringWrite {
    /// A roll or a typed score.
    case roll
    /// A replaced roll.
    case edit
    /// Undo, Clear rolls, or an entry mode change.
    case other
}
