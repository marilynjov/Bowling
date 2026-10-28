import BowlingCore
import BowlingData

/// One roll's entry rules: what the deck starts as, what each button records, and when
/// Strike and Spare are offered. Pure, for a pin-by-pin or count game's next roll.
struct RollPad: Hashable {
    let position: RollPosition
    /// `.pinByPin` or `.countOnly`.
    let entryMode: EntryMode
    let tapWhatFell: Bool
    let autoAdvanceOnSpare: Bool
    /// Pins the deck shows standing after this roll. Empty, or the rack's standing pins
    /// with Tap what fell.
    private(set) var shown: PinSet
    /// The deck has been changed since the pad was made.
    private var touched = false

    init(position: RollPosition, entryMode: EntryMode, tapWhatFell: Bool, autoAdvanceOnSpare: Bool) {
        self.position = position
        self.entryMode = entryMode
        self.tapWhatFell = tapWhatFell
        self.autoAdvanceOnSpare = autoAdvanceOnSpare
        shown = tapWhatFell ? position.standingPins : []
    }

    init(position: RollPosition, entryMode: EntryMode, settings: ScoringSettings) {
        self.init(
            position: position, entryMode: entryMode,
            tapWhatFell: settings.tapWhatFell, autoAdvanceOnSpare: settings.autoAdvanceOnSpare
        )
    }

    /// The deck's binding setter. Pins already down on this rack are ignored.
    mutating func setShown(_ pins: PinSet) {
        shown = pins.intersection(position.standingPins)
        touched = true
    }

    private var counts: Bool { entryMode == .countOnly }

    /// Next records the deck as marked.
    var nextInput: RollInput { .pinsLeft(shown) }
    /// A fresh rack, including frame 10's fill balls after a strike or spare.
    var offersStrike: Bool { position.isFreshRack }
    var offersSpare: Bool { !position.isFreshRack }
    var strikeInput: RollInput { counts ? .count(10) : .pinsLeft([]) }
    var spareInput: RollInput { counts ? .count(position.standingCount) : .pinsLeft([]) }
    var missInput: RollInput { counts ? .count(0) : .pinsLeft(position.standingPins) }
    var countChoices: ClosedRange<Int> { 0...position.standingCount }

    /// A second ball records by itself once every standing pin is marked down. Only with
    /// Tap what fell: otherwise an untouched deck already means every pin fell.
    var autoAdvances: Bool {
        tapWhatFell && autoAdvanceOnSpare && !position.isFreshRack && touched && shown.isEmpty
    }
}
