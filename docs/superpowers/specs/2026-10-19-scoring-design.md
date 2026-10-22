# Scoring: score one game (#8)

Replaces the Scoring placeholder with the Phase 1 spec's Scoring screen (§7, Scoring) for
one game: the scorecard strip, the pin deck, the count pad, final-score entry, the
Strike / Spare / Miss / Foul / Undo shortcuts, the ball chip, and the tenth frame. The
night around it (bowler strip and rotation, editing a finished frame, the game summary
with Next game and End session) is #95, split from #8 on 2026-10-19.

Uses only the existing contract (`GameRepository`: `game`, `recordRoll`, `undoLastRoll`,
`setEntryMode`, `clearRolls`, `setFinalScore`; `BallRepository.activeBalls()`;
`SessionRepository.session`; BowlingCore `Scorer.scorecard(for:)`, `Scorer.nextRoll(in:)`).
No package changes. Builds on #5 (`PinDeckView`, `ScorecardStrip`), #7, and #11, so the
branch `feat/8-scoring` starts from `feat/11-home`.

**Done when:** one game can be scored one-handed, pin by pin, in count mode and as a final
score, offline, and survives the app being killed.

## Screen

The root's full-screen cover, opened on a `ScoringTarget` (from Start, Resume, or later
History). Top to bottom:

### 1. Toolbar

- **Close** (leading). Closing a session with no rolls still discards it
  (`AppModel.closeScoring()`, spec §8).
- **Title**: "Game <n> · <bowler name>".
- **Entry mode menu** (trailing): Pin by pin, Count, Final score, with a checkmark on the
  current one.
  - **Before the first roll:** picking one calls `setEntryMode`.
  - **After the first roll:** the menu shows the modes disabled and a **Clear rolls…**
    item. It asks "Clear all rolls in this game?", with **Clear rolls** (destructive) and
    Cancel, then calls `clearRolls(in:)`. The mode can be changed after that.
  - **A final-only game with a typed score:** it is complete and has no rolls, so the
    menu is enabled. Picking another mode first asks "Discard the score of <n>?", and on
    confirm calls `setEntryMode` (spec §8).

### 2. Scorecard strip

`ScorecardStrip` from `Scorer.scorecard(for:)`, with the current frame (the next roll's
frame) highlighted. Tapping a frame does nothing in #8; editing is #95. A final-only game
shows the strip empty with its total.

### 3. Entry area

- **Pin by pin:** `PinDeckView` fills the width. Pins already down on this rack are
  dimmed and disabled.
  - **By default** you tap the pins **left standing**; untapped pins count as down.
  - **With "Tap what fell" on,** the deck starts with every available pin standing and
    you tap the ones that fell.
- **Count:** a 0–10 pad, 3 columns, with buttons above the rack's `standingCount`
  disabled.
- **Final score:** a large number-pad field and **Save**, enabled for 0–300 by the
  Quick score rule (`QuickScoreEntry.score`). Save calls `setFinalScore`.

### 4. Shortcuts

A row under the entry area (two rows at accessibility sizes):

- **Strike:** only on a fresh rack, which includes frame 10's fill balls after a strike
  or spare.
- **Spare:** only on a second ball at a rack, knocking down everything standing.
- **Miss:** knocks down nothing.
- **Foul:** a foul delivery.
- **Undo:** `undoLastRoll`, disabled before the first roll.
- **Ball chip:** shows the roll's ball, the game's default ball, or "No ball".
  - Tapping it opens a menu of `activeBalls()` to pick the ball for this roll only, plus
    "No ball" when the game has no default ball. After the roll it goes back to the default.
  - It doesn't appear in final-only games.

Strike, Spare, Miss, Foul, and each count button record the roll and advance at once.

### 5. Next

A large prominent button (pin by pin only) that records the deck as marked and advances.

- **With "Auto-advance on spare" on and "Tap what fell" on,** a second ball records by
  itself once every standing pin is marked down.
- **With "Tap what fell" off,** the setting does nothing: an untouched deck already means
  every pin fell, so it would fire before any tap.

### 6. Game complete

When `Scorer.nextRoll` returns nil (the game is complete), the entry area, shortcuts, and
Next are replaced by **"Game complete"** with the final score and **Done**, which closes
Scoring. Undo stays available under it and reopens the last roll. A final-only game
shows the same once its score is saved, with **Change score** instead of Undo (it has no
rolls to undo), which shows the score field again, prefilled. #95 replaces Done with the game summary.

### Saving

Every roll is saved as it is recorded (`recordRoll` saves), so a game survives the app
being killed. Opening an unfinished game starts at its next roll.

## Settings

`ScoringSettings` reads two on-device values from an injected `UserDefaults` (not
synced). #13 Settings adds their toggles.

| Key | Default | Meaning |
|---|---|---|
| `scoring.tapWhatFell` | false | The deck starts all standing and you tap what fell. |
| `scoring.autoAdvanceOnSpare` | false | Record a second ball once it makes a spare (with Tap what fell only). |

## Code (`Bowling/Features/Scoring/`)

| Unit | Does |
|---|---|
| `RollPad` | Pure. One roll's entry rules, from a `RollPosition`, the entry mode, and the settings. |
| `ScoringModel` | `@Observable`, one per open game. Holds the game and its pad, and records through `app.write`. |
| `ScoringSettings` | The two settings in an injected `UserDefaults`. |
| `ScoringScreen` | The layout above; replaces `ScoringPlaceholder`. |
| `CountPad`, `FinalScoreEntry`, `ShortcutBar`, `BallChip`, `EntryModeMenu`, `GameCompletePanel` | The pieces. |

**`RollPad`** has:

- `shown: PinSet`: the deck's standing pins after the roll. It starts empty, or as
  `standingPins` with Tap what fell.
- `nextInput`: always `.pinsLeft(shown)`.
- `offersStrike` (fresh rack) and `offersSpare` (not fresh).
- `strikeInput`, `spareInput`, and `missInput`:
  - pin by pin: `.pinsLeft([])`, `.pinsLeft([])`, `.pinsLeft(standingPins)`
  - count: `.count(10)`, `.count(standingCount)`, `.count(0)`
- `countChoices`: `0...standingCount`.
- `autoAdvances`: Tap what fell, auto-advance on, a second ball, and `shown` is empty
  after the user changed it.

**`ScoringModel`** has:

- **State:** `game: GameRecord`, `scorecard`, `pad: RollPad?` (nil when complete),
  `balls`, `bowlerName`, `ballOverride: BallID?`.
- **Actions:** `next()`, `strike()`, `spare()`, `miss()`, `foul()`, `count(_:)`,
  `undo()`, `setEntryMode(_:)`, `clearRolls()`, `saveFinalScore(_:)`,
  `pickBall(_:)`.
- **Ball:** the chip shows `ballOverride ?? game.defaultBallID`, but a roll stores only an
  override: its `ballID` is the picked ball when it differs from the game's default, and
  nil means the default ball (contract §3.2). "No ball" is offered only on a game without
  a default ball.
- **After each write:** the model reloads the game, rebuilds the pad, and clears
  `ballOverride`.
- **Errors** go to `app.error` and show in the Scoring cover's alert.

`AppModel` gains `let scoringSettings: ScoringSettings`, injected like
`sessionDefaults`.

## Accessibility

- **Pins:** read "Pin 7, standing" / "Pin 7, down" (already in `PinDeckView`).
- **Buttons:** count buttons read their number. Shortcut buttons read their name; the
  ball chip reads "Ball, <name>".
- **Tap targets:** at least 48 points.
- **At accessibility sizes,** the shortcuts wrap to two rows and the scorecard scrolls
  instead of truncating.

## Testing

On the iPhone 18 Pro Max test simulator, against an in-memory store.

- **RollPadTests:**
  - The starting deck for each setting.
  - Next records `.pinsLeft(shown)`.
  - Strike only on a fresh rack (frame 1 ball 1, frame 10 ball 2 after a strike, frame 10
    ball 3 after a spare); Spare only on a second ball.
  - Count inputs and `countChoices`.
  - `autoAdvances` only with Tap what fell, on a second ball, once every pin is marked
    down.
- **ScoringSettingsTests:** the defaults, and reading saved values.
- **ScoringModelTests:**
  - A strike advances to frame 2.
  - A spare.
  - A first-ball foul, then all ten, scores a spare.
  - Undo reopens the last roll, including from the complete state.
  - Twelve strikes reach 300 and the complete state.
  - A full count-mode game.
  - Saving a final score completes the game, and a bad score is refused.
  - The entry mode changes before the first roll; after it the change is refused with an
    alert, and `clearRolls` unlocks it.
  - A picked ball goes on one roll, then the default comes back.
  - Reopening an unfinished game starts at its next roll.
  - Each write bumps `app.revision`.
- **Previews:** light, dark, and AX5 for pin by pin, count, final score, and game complete.
- **Manual (the user):**
  - a pin-by-pin game and a count game one-handed
  - kill the app mid-game and reopen
  - the deck and shortcuts at AX5

## Not done here (#95)

- The bowler strip and rotation.
- Editing a finished frame.
- The game summary with Next game and End session.

In a multi-bowler session, #8 scores the game Scoring opened on.
