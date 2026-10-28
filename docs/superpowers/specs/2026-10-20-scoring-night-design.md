# Scoring: the night around one game (#95)

#8 scores one game. This adds what a night of several bowlers and games needs, from the
Phase 1 spec (§7, Scoring; §8 for edits): the bowler strip and rotation, editing a
finished frame, and the game summary with Next game and End session. Split from #8 on
2026-10-19.

Uses only the existing contract (`GameRepository`: `replaceRoll`, `startNextGame`, plus
#8's calls; `SessionRepository.session`; BowlingCore `Scorer`, `StatsEngine.report`,
`FrameScore.leave`). No package changes. Builds on #8, so the branch
`feat/95-scoring-night` starts from `feat/8-scoring`.

**Done when:** a full three-game night for two bowlers can be scored one-handed, pin by
pin and in count mode, offline.

## Structure

| Unit | Does |
|---|---|
| `Rotation` | Pure. Whose turn it is, from each bowler's game and the rotation toggle. |
| `GameSummary` | Pure. One bowler's card: score, strikes, spares, opens, leaves, series so far. |
| `SessionScoringModel` | `@Observable`, one per open Scoring cover. Holds the session and one #8 `ScoringModel` per bowler for the current game number, and whose turn it is. |
| `ScoringModel` (#8) | Gains frame editing. Otherwise unchanged. |
| `BowlerStrip`, `FrameEditBar`, `ClearedFramesNotice`, `GameSummarySheet` | The new views. |
| `ScoringScreen` (#8) | Shows the current bowler's `ScoringModel` from the session model. |

The screen shows one scorecard at a time: the current bowler's. The title ("Game 2 ·
Alex"), the entry-mode menu and the ball chip follow the current bowler.

## 1. Bowler strip and rotation

### Bowler strip

Shown when the session has two or more bowlers, above the scorecard strip.

- **Each chip:** the bowler's name and current score (the last known running total, or
  the typed score for final score). The current bowler is highlighted; a finished game
  shows a checkmark.
- **Tapping a chip** makes that bowler current, for someone bowling out of turn.
- **Lineup order**, from `SessionDetail.bowlers`.
- **At accessibility sizes** the strip scrolls sideways instead of truncating.
- **VoiceOver:** "Alex, 64, current turn" / "Sam, 87" / "Sam, 201, finished".

### Rotation

The lane console's rule: the current bowler is the first in lineup order, among unfinished
games, with the fewest finished frames.

- **Finished frames:** `Scorer.nextRoll`'s frame minus 1. Frame 10 counts only when the
  game is complete, so fill balls stay with the same bowler. A final-score game counts 0
  until its score is saved, then 10.
- **When it runs:** only when the current bowler's finished frames go up (a frame ended)
  or their game becomes complete. Never mid-frame, so a bowler picked out of turn
  finishes their frame first.
- **Undo, Clear rolls, edits and mode changes** stay on the current bowler and never run
  rotation.
- **Rotation off:** the current bowler keeps the turn until their game is complete; then
  the rule picks the next one.
- **Everyone finished:** the game summary (section 3).

### Rotation toggle

A toolbar button, "Rotate bowlers", shown with two or more bowlers. It is not saved per
session: each Scoring cover starts it from a new on-device setting
`scoring.rotateBowlers` (default **true**) in `ScoringSettings`, next to #8's two. #13
adds its switch in Settings.

### Opening Scoring

The cover still opens on a `ScoringTarget` (session and game). The session model loads
that game's number for every bowler.

- **The target game is unfinished** (Start, Resume): with rotation on, the current bowler
  is the rule's pick. This fixes #11's Resume, which could open your game 2 while a
  friend's was behind. With rotation off, it is the target's bowler.
- **The target game is complete** (History later): the target's bowler, showing the
  Complete panel.

## 2. Editing a finished frame

### Starting

- **Tap a finished frame** on the current bowler's scorecard (`ScorecardStrip`'s
  `onSelectFrame`; it already ignores the current frame and empty ones). To fix another
  bowler's frame, tap their chip first.
- **The bar:** "Editing frame 3 · ball 1" with **Cancel**, above the entry area.
- **The entry area** is that ball's rack (the rack before it, as `replaceRoll` sees it):
  - **Pin by pin:** the deck shows the ball as recorded: the pins it left standing, or with
    Tap what fell, the rack's standing pins with the ones it knocked down marked. A foul
    shows nothing knocked down.
  - **Count:** the pad highlights the old count.
  - **Ball chip:** the roll's own ball, changeable for this roll.
- **Buttons:** Next reads **Replace**. Strike, Spare, Miss and Foul replace that ball. Undo
  is hidden. Auto-advance is off while editing.

### After each replace

Each replace saves through `replaceRoll(frameIndex:rollIndex:with:ballID:in:)`.

- **The frame has another recorded ball:** the edit moves to it ("ball 2").
- **Otherwise the edit ends** and entry continues at the game's next roll. That can be in
  the edited frame: a strike changed to 7 asks for ball 2 of that frame.
- **Cancel** ends the edit. Balls already replaced stay replaced.
- **A refused replace** (`.invalidGame`) shows the alert and keeps the edit open.

### Cleared frames

When `clearedFrames` is not empty, a notice above the entry area reads "Frame 4 was
cleared. Enter it again." or "Frames 4 and 5 were cleared. Enter them again." (three or
more: "Frames 4, 5 and 6 …"). VoiceOver announces it. It goes away with the next roll or
edit. The turn stays with this bowler.

### Finished games

- **Pin by pin and count:** frames can be edited from the Complete state too (the strip is
  tappable there). If an edit leaves the game unfinished, the Complete panel goes away
  and entry resumes.
- **Final score:** no frames; Change score (#8) stays the way to fix it.

## 3. Game summary

### When it shows

A sheet, when the last unfinished game of the current game number becomes complete
(through a roll, a typed score, or an edit). With one bowler, when their game completes.
It is not shown on opening a game that was already complete.

### Content

"Game 2" as the title, then a card per bowler in lineup order:

- **Name and score** (`.scoreHero`).
- **Strikes, spares, opens:** "6 strikes · 3 spares · 1 open", from
  `StatsEngine.report(games: [game], filter: StatsFilter(bowlerID:))` (`strikes.hits`,
  `spares.hits`, `openFrames.hits`), so they match Stats. A final-score game shows none of
  this line.
- **Leaves:** `LeaveDiagramView(.small)` for each frame with a `leave`, in frame order. A
  count game reads "Enter pins to see leaves"; no leaves reads "No leaves".
- **Series so far** from game 2 on: "Series 388", the sum of that bowler's games up to this
  one.

### Buttons

Pinned at the bottom:

- **Next game** (prominent): `startNextGame(in:)`, then the session model loads the new
  game number and rotation picks the first bowler. Each bowler keeps their entry mode and
  default ball (the contract copies them).
- **End session:** closes Scoring (`app.closeScoring()`). The session is complete because
  its games are.

### Dismissing

Swiping the sheet away leaves the current bowler's Complete panel, where **Summary**
replaces #8's Done and reopens the sheet. Undo (or Change score) stays. Undoing reopens
that game, and the summary shows again when it completes.

## Saving and errors

Every roll and replace saves as it happens, so a night survives the app being killed.
Errors go to `app.error` through the `.scoring` presenter, as in #8. A `startNextGame`
failure keeps the sheet up.

## Accessibility

- Chips, the edit bar's Cancel, Replace and the summary buttons are at least 48 pt.
- The cleared-frames notice and a turn change are announced ("Alex's turn").
- At accessibility sizes the strip scrolls; summary cards stack the leaves in rows.

## Testing

On the iPhone 18 Pro Max test simulator, against an in-memory store.

- **RotationTests:**
  - Two bowlers alternate after each frame.
  - The tenth frame's fill balls stay with the bowler.
  - A bowler picked out of turn finishes the frame, then the fewest-frames bowler is next.
  - Rotation off keeps the bowler until their game is complete.
  - A final-score game counts 0 then 10.
  - Everyone finished gives no current bowler.
- **GameSummaryTests:** a 300 game, an open-frame game with leaves, a count game (no
  leaves), a final-score game, and the series on game 2.
- **SessionScoringModelTests:**
  - Opening an unfinished session lands on the rule's bowler.
  - A frame ending switches bowler; Undo doesn't.
  - Tapping a chip switches.
  - The last game completing shows the summary; one bowler too.
  - Next game creates game 2 for both with the same balls, and opens the first bowler.
  - Opening a complete game shows no summary.
- **Frame edit tests (ScoringModel):**
  - Replacing ball 1 moves to ball 2.
  - A strike changed to 7 ends the edit and asks for ball 2.
  - An edit that clears later frames reports them.
  - Cancel keeps replaced balls.
  - Editing a complete game can reopen it.
- **Previews:** light, dark and AX5 for the strip, the edit bar with a cleared notice, and
  the summary with two bowlers.
- **Manual (the user):** a three-game night for two bowlers, one pin by pin and one count;
  a frame edit that clears later frames; rotation off; killing the app mid-game and
  resuming on the right bowler; AX5.

## Not done here

- The rotation-default switch in Settings (#13).
- Opening a session or game from History (#12).
- Adding or removing bowlers during a session, and per-bowler mode changes for the next
  game.
