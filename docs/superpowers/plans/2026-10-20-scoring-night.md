# Scoring night (#95) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Score a whole night on one Scoring cover: several bowlers taking turns, fixing a finished frame, and a game summary with Next game and End session.

**Architecture:**
- **Pure rules:** `Rotation` picks whose turn it is. `GameSummary` builds one bowler's summary card. `FrameEdit` works out the rack a recorded roll faced.
- **#8's `ScoringModel`** gains frame editing, plus a callback that tells its owner what kind of write just worked.
- **New `SessionScoringModel`:** holds one `ScoringModel` per bowler for the current game number. It runs rotation and decides when the summary shows.
- **`ScoringScreen`** renders the current bowler's model.

**Tech Stack:** SwiftUI, Swift Testing, BowlingData (`GameRepository.replaceRoll`, `startNextGame`, `SessionRepository.session`), BowlingCore (`Scorer`, `StatsEngine`, `Leave`), #8's Scoring views.

**Spec:** `docs/superpowers/specs/2026-10-20-scoring-night-design.md`

## Global Constraints

- **Platform:** iOS 18 minimum. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and member import visibility, so import BowlingCore/BowlingData in every file that uses their types or members.
- **Contract only, no package changes.** On top of #8's calls, use:
  - `games.replaceRoll(frameIndex:rollIndex:with:ballID:in:) -> RollEditOutcome(game, clearedFrames)`
  - `games.startNextGame(in:) -> [GameID]`
  - `sessions.session(_:) -> SessionDetail`
  - `StatsEngine.report(games:filter:)`
- **Contract facts the plan relies on:**
  - `SessionDetail.bowlers` is in lineup order, and each bowler's `games` are sorted by `gameIndex`.
  - `startNextGame` copies the entry mode, default ball and lineup.
  - `replaceRoll` throws `.invalidGame` for a roll that can't be recorded there. It keeps later rolls while they stay valid and reports the frames it dropped.
  - `RollRecord.ballID == nil` means the game's default ball.
  - `StatsEngine.report` only counts complete games, and uses only the games it is given.
- **Copy, exactly as the spec:**
  - Toolbar: "Rotate bowlers".
  - Edit bar: "Editing frame <f> · ball <b>" and "Cancel". Next reads "Replace" while editing.
  - Cleared notice: "Frame 4 was cleared. Enter it again." / "Frames 4 and 5 were cleared. Enter them again." / "Frames 4, 5 and 6 were cleared. Enter them again."
  - Summary: the title "Game <n>"; "<s> strikes · <p> spares · <o> open"; "Enter pins to see leaves"; "No leaves"; "Series <n>".
  - Summary buttons: "Next game", "End session". On the Complete panel: "Summary".
  - VoiceOver: chips read "Alex, 64, current turn" / "Sam, 87" / "Sam, 201, finished". A turn change is announced as "Alex's turn".
- **Setting:** `scoring.rotateBowlers`, on-device `UserDefaults`, default **true**.
- **Colors:** D1 asset symbols only (`.canvas`, `.surface`, `.hairline`, `.ink`, `.inkMuted`, `.accent`, `.accentText`). Tap targets are at least 48 pt. Previews are `#if DEBUG`, in light, dark and AX5.
- **Tests:**
  - Run on iPhone 18 Pro Max (`id=2C568C51-3721-4FB2-90EE-D54EB3308C03`) with `-parallel-testing-enabled NO`, never on the iPhone 18 Pro.
  - Use `BowlingStore(inMemory: true)`, `UserDefaults(suiteName: "test.\(UUID())")!`, and the `TestClock` from `ScoringModelTests.swift` (`now: clock.tick`).
  - Never `pkill -f` a pattern that matches your own command line. To stop a hung xcodebuild, kill its PID from `pgrep -x xcodebuild`.
- **Commits:** the user runs every commit. Give them the `git add` / `git commit` commands and wait. No `Co-Authored-By` line.

Test command (whole suite): `xcodebuild test -scheme Bowling -destination 'id=2C568C51-3721-4FB2-90EE-D54EB3308C03' -parallel-testing-enabled NO`. For one suite, add `-only-testing:BowlingTests/<Suite>`. Send the output to a log in the workspace and read its tail.

## Rulings (gaps in the spec, decided here)

1. **Cleared notice:** it lists `clearedFrames` without the edited frame itself. If you change a 7–2 to a strike, `replaceRoll` drops that frame's ball 2. The frame isn't for entering again, so naming it would mislead.
2. **Edits and rotation:** an edit never moves the turn, even when it completes a game. It can still bring up the summary, as the spec says.
3. **The Complete panel's primary button:**
   - **Summary**, when every bowler's game of this number is finished.
   - **No primary button otherwise.** This happens when you tap a finished bowler's chip mid-game. The night goes on through the chips, and Close is still there.
   - Done goes away for good.
4. **Errors from the summary sheet:** `ErrorPresenter` gains `.gameSummary` and `AppModel` gains `isShowingGameSummary`, so a `startNextGame` failure shows its alert on the sheet. A cover's alert can't present over a sheet. `closeScoring()` resets the flag.
5. **Leaves in a final-score game:** the summary shows no leaves line at all, just like the counts line.
6. **The chip's score:** the last frame with a running total, or 0 before any. For final score, the typed score, or 0 before it's saved.

## Review Focus

1. **A replace that doesn't fit** (in count mode, ball 2 of a 7–2 replaced with 5) shows the alert and keeps the edit open on the same ball. Task 3: `aRefusedReplaceKeepsTheEdit`.
2. **Editing a tenth-frame fill ball** replaces it, and the game stays complete. Task 3: `editingAFillBallKeepsTheGameComplete`.
3. **Undo after the summary showed:** the game reopens, and finishing it again shows the summary again. Task 4: `undoThenFinishShowsTheSummaryAgain`.
4. **Clear rolls during an edit** ends the edit, so entry doesn't point at a roll that's gone. Task 3: `clearRollsEndsTheEdit`.
5. **End session from the summary** leaves no stale summary flag behind, so the next error still shows. Task 4: `closingResetsTheSummaryPresenter`.

---

### Task 1: Rotation and the rotate setting

**Files:**
- Modify: `Bowling/Features/Scoring/ScoringSettings.swift`
- Create: `Bowling/Features/Scoring/Rotation.swift`
- Test: `BowlingTests/Scoring/ScoringSettingsTests.swift`, `BowlingTests/Scoring/RotationTests.swift`

**Interfaces:**
- Produces:
  - `ScoringSettings.rotateBowlers: Bool { get nonmutating set }`, key `scoring.rotateBowlers`, default true (`defaults.object(forKey:) as? Bool ?? true`).
  - `enum Rotation`:
    - `static func isFinished(_ game: GameRecord) -> Bool`: final only → `game.isComplete`; otherwise `Scorer.nextRoll(in: game) == nil`.
    - `static func finishedFrames(_ game: GameRecord) -> Int`:
      - finished → 10
      - final only and not finished → 0
      - otherwise `Scorer.nextRoll(in:)!.frameIndex - 1`
    - `static func current(after current: Int?, games: [GameRecord], rotates: Bool) -> Int?`: an index into `games`, which are in lineup order.
      - If `!rotates`, and `current` is set and not finished, it returns `current`.
      - Otherwise it returns the first unfinished game with the fewest `finishedFrames`, or nil when every game is finished.

- [ ] **Step 1: Write the failing tests.**
  - In `ScoringSettingsTests`:
    - Extend `defaultsAreOff` with `#expect(settings.rotateBowlers == true)` and rename it `defaults`.
    - Extend `readsSavedValues` with `suite.set(false, forKey: "scoring.rotateBowlers")` and `#expect(settings.rotateBowlers == false)`.
  - New `RotationTests`. Games are built with the store (in-memory, one bowler per game via `startSession`, rolls via `recordRoll`). Its helpers are `game(_ mode: EntryMode, rolls: [RollInput]) -> GameRecord` and `strikes(n)`. The tests:
    - `alternatesAfterEachFrame`: games [1 frame finished, 0] → `current(after: 0, …, rotates: true) == 1`. Games [1, 1] → `0`.
    - `fillBallsStayWithTheBowler`: game A has 9 strikes then a strike in frame 10 (frame 10 not complete); game B has 9 frames. `finishedFrames(A) == 9` and `current(after: 0, games: [A, B], rotates: true) == 0`.
    - `outOfTurnBowlerFinishesThenFewestIsNext`: [Alex 2 frames, Sam 3 frames] → `current(after: 1, …, rotates: true) == 0`.
    - `rotationOffKeepsTheBowlerUntilComplete`: [2, 1] → `current(after: 0, …, rotates: false) == 0`. With games[0] a 300 game → `== 1`.
    - `finalScoreCountsZeroThenTen`: a final-only game is `0` before `setFinalScore(180, …)` and `10` after.
    - `everyoneFinishedGivesNoBowler`: two 300 games → `current(after: 0, …, rotates: true) == nil`.

- [ ] **Step 2: Run them to verify they fail.** Run with `-only-testing:BowlingTests/RotationTests -only-testing:BowlingTests/ScoringSettingsTests`.
  Expected: build failure on `Rotation` / `rotateBowlers` missing. Then add a stub, `Rotation` with each function returning `false` / `0` / `nil` and `rotateBowlers` returning false, and rerun. Expected: the tests fail on their assertions.

- [ ] **Step 3: Implement `rotateBowlers` and `Rotation`** as in Interfaces. Update the `ScoringSettings` doc comment, which says there are two settings, to say three.

- [ ] **Step 4: Run them to verify they pass.** Same command. Expected: all pass.

- [ ] **Step 5: Commit (the user runs it).**
  ```sh
  git add Bowling/Features/Scoring/ScoringSettings.swift Bowling/Features/Scoring/Rotation.swift BowlingTests/Scoring/ScoringSettingsTests.swift BowlingTests/Scoring/RotationTests.swift
  git commit -m "feat: bowler rotation rule and its setting (#95)"
  ```

### Task 2: GameSummary

**Files:**
- Create: `Bowling/Features/Scoring/GameSummary.swift`
- Test: `BowlingTests/Scoring/GameSummaryTests.swift`

**Interfaces:**
- Produces `struct GameSummary: Hashable, Identifiable`:
  - **Properties:**
    - `id: BowlerID`
    - `name: String`
    - `score: Int`: `Scorer.scorecard(for:).finalScore ?? game.finalScore`
    - `counts: Counts?`, where `struct Counts: Hashable { strikes, spares, opens: Int }`. It comes from `StatsEngine.report(games: [game], filter: StatsFilter(bowlerID: id))`, using `strikes.hits`, `spares.hits` and `openFrames.hits`. Nil for final only.
    - `leaves: Leaves`, where `enum Leaves: Hashable { case diagrams([Leave]), enterPins, none, hidden }`:
      - pin by pin: `.diagrams` of every frame's non-nil `leave` in frame order, or `.none` when there are none
      - count only: `.enterPins`
      - final only: `.hidden`
    - `series: Int?`: the sum of `score` over the bowler's games with `gameIndex <= gameIndex`, nil when `gameIndex == 1`. The series uses each game's `Scorer.scorecard(for:).finalScore ?? finalScore`.
  - **Init:** `init?(_ bowler: SessionBowler, gameIndex: Int)` is nil when the bowler has no game of that number.
  - **Copy:**
    - `var countsText: String?`: "6 strikes · 3 spares · 1 open"
    - `var seriesText: String?`: "Series 388"
    - The singular/plural and "open" wording are exact copy: the spec fixes "1 open", so the open word is always "open". Use "1 strike" / "1 spare" for one.

- [ ] **Step 1: Write the failing tests** in `GameSummaryTests`. Each game is built with the store and read back through `sessions.session(_:)`. The tests:
  - `perfectGame`: 12 strikes → `score == 300`, `counts == Counts(strikes: 12, spares: 0, opens: 0)`, `leaves == .none`, `series == nil`, `countsText == "12 strikes · 0 spares · 0 open"`.
  - `openFramesWithLeaves`: frame 1 leaves [7, 10] and makes the spare. Frame 2 leaves [4] and misses it (`.pinsLeft([4])` twice). Frames 3–10 are 9 then 0, from pins. → `counts?.spares == 1` and `counts?.opens == 9`. `leaves` is `.diagrams` whose first two pins are `PinSet(pins: [7, 10])` and `PinSet(pins: [4])`.
  - `countGameAsksForPins`: a full count game → `leaves == .enterPins`, with `counts` set.
  - `finalScoreGame`: final only, score 187 → `score == 187`, `counts == nil`, `countsText == nil`, `leaves == .hidden`.
  - `seriesFromGame2`: game 1 is 300. After `startNextGame`, game 2 is a full count game of 9s and 0s (90) → `GameSummary(bowler, gameIndex: 2)?.series == 390` and `seriesText == "Series 390"`.

- [ ] **Step 2: Run them to verify they fail.** Run with `-only-testing:BowlingTests/GameSummaryTests`. Expected: build failure, then add a stub returning zeroes and nils. Expected: assertion failures.

- [ ] **Step 3: Implement `GameSummary`** as in Interfaces.

- [ ] **Step 4: Run them to verify they pass.** Expected: 5/5.

- [ ] **Step 5: Commit (the user runs it).**
  ```sh
  git add Bowling/Features/Scoring/GameSummary.swift BowlingTests/Scoring/GameSummaryTests.swift
  git commit -m "feat: game summary card data (#95)"
  ```

### Task 3: Frame editing in ScoringModel

**Files:**
- Create: `Bowling/Features/Scoring/FrameEdit.swift`
- Modify: `Bowling/Features/Scoring/ScoringModel.swift`
- Test: `BowlingTests/Scoring/ScoringModelEditTests.swift`, with the same fixture as `ScoringModelTests`: copy its `init`, `target` and `start`.

**Interfaces:**
- Produces:
  - `struct FrameEdit: Hashable { let frameIndex: Int; let rollIndex: Int }`, with:
    - `func roll(in game: GameRecord) -> RollRecord?`
    - `func position(in game: GameRecord) -> RollPosition?`: `Scorer.nextRoll` of a copy of `game` whose `frames` keep only the rolls before this one, with empty frames dropped
    - `func next(in game: GameRecord) -> FrameEdit?`: the same frame's `rollIndex + 1` when that roll exists
    - `static func clearedText(_ frames: [Int]) -> String?`: nil for []. Otherwise the exact copy from Global Constraints, joining 3+ as "4, 5 and 6".
  - `enum ScoringWrite { case roll, edit, other }`
  - `ScoringModel` gains:
    - `private(set) var edit: FrameEdit?`
    - `private(set) var clearedFrames: [Int]`: from the last replace, without the edited frame (Ruling 1). Emptied by the next successful write of any kind and by `beginEdit`.
    - `@ObservationIgnored var onWrite: ((ScoringWrite) -> Void)?`. It is called after every successful write: `.roll` for record and `saveFinalScore`, `.edit` for a replace, `.other` for undo, clear rolls and entry mode.
    - `var editedCount: Int?`: the edited roll's `pinCount`, nil for a foul or when not editing
    - `var currentScore: Int` (Ruling 6)
    - `func beginEdit(frame: Int)`: ignored for final only or a frame with no rolls. It sets `edit = FrameEdit(frameIndex: frame, rollIndex: 1)` and rebuilds the pad.
    - `func cancelEdit()`
- Changed behaviour:
  - **While `edit != nil`:**
    - `pad` is built from `edit.position(in: game)`.
    - The deck is prefilled with `setShown(standingPins.subtracting(roll.pinsDown))`, or `standingPins` for a foul or a roll without pins.
    - `rollBallID` is the override when one was picked, else `roll.ballID ?? game.defaultBallID`.
    - `record` calls `replaceRoll(frameIndex:rollIndex:with:ballID:in:)` instead of `recordRoll`. On success, `edit = edit.next(in: outcome.game)`. On failure the edit stays.
    - `setShown` never auto-advances. `undo()` does nothing.
  - **`reload()`:** sets `edit = nil` when `edit?.roll(in: game) == nil`. This covers Clear rolls and an entry mode change.
  - **The tap lockout** applies to replace too, since it uses the same `record` path.

- [ ] **Step 1: Write the failing tests** in `ScoringModelEditTests`:
  - `editPrefillsTheDeck`: pin by pin, frame 1 `.pinsLeft(PinSet(pins: [7, 10]))` then `.pinsLeft([])`. `beginEdit(frame: 1)` → `edit == FrameEdit(frameIndex: 1, rollIndex: 1)` and `pad?.shown == PinSet(pins: [7, 10])`.
  - `replacingBall1MovesToBall2`: count mode, frame 1 `count(7), count(1)`, frame 2 a strike. `beginEdit(frame: 1)` → `editedCount == 7`. `count(8)` → `edit == FrameEdit(frameIndex: 1, rollIndex: 2)`, `editedCount == 1`, `scorecard.frames[0].marks == [.count(8), .count(1)]`, `clearedFrames.isEmpty`.
  - `strikeChangedTo7EndsTheEditAndAsksForBall2`: count mode, frame 1 `count(10)`, frame 2 `count(3), count(4)`. Then `beginEdit(frame: 1)`, `count(7)` → `edit == nil`, `pad?.position.frameIndex == 1`, `pad?.position.rollIndex == 2`, `clearedFrames == [2]`.
  - `clearedTextWording`: `FrameEdit.clearedText([4]) == "Frame 4 was cleared. Enter it again."`, `[4, 5]` → "Frames 4 and 5 were cleared. Enter them again.", `[4, 5, 6]` → "Frames 4, 5 and 6 were cleared. Enter them again.", `[]` → nil.
  - `cancelKeepsReplacedBalls`: count mode, frame 1 `count(7), count(1)`. `beginEdit(frame: 1)`, `count(8)`, `cancelEdit()` → `edit == nil` and `scorecard.frames[0].marks == [.count(8), .count(1)]`.
  - `editingACompleteGameCanReopenIt`: pin by pin, 12 strikes. `beginEdit(frame: 10)`, `setShown(PinSet(pins: [7]))`, `next()` → `edit == nil` and `!isComplete`. The strike after a 9 no longer fits, so frame 10 asks for ball 2 (`pad?.position.rollIndex == 2`).
  - `editKeepsTheRollsBall`: a game with default `ballA`, roll 1 recorded after `pickBall(ballB.id)`. `beginEdit(frame: 1)` → `rollBallID == ballB.id`.
  - `aRefusedReplaceKeepsTheEdit` (Review Focus 1): count mode, `count(7), count(2)`. `beginEdit(frame: 1)`, `count(8)` → edit moves to ball 2. Then `count(5)` (8 + 5 > 10) → `app.error != nil` and `edit == FrameEdit(frameIndex: 1, rollIndex: 2)`.
  - `editingAFillBallKeepsTheGameComplete` (Review Focus 2): 12 strikes, `beginEdit(frame: 10)`, `strike()` twice → edit on ball 3. Then `setShown(PinSet(pins: [10]))` and `next()` → `edit == nil`, `isComplete`, `scorecard.finalScore == 299`.
  - `clearRollsEndsTheEdit` (Review Focus 4): pin by pin, a strike, `beginEdit(frame: 1)`, `clearRolls()` → `edit == nil` and `pad?.position.frameIndex == 1`.
  - `undoDoesNothingWhileEditing`: a strike, then a strike, `beginEdit(frame: 1)`, `undo()` → the frames are unchanged (`scorecard.frames[1].marks == [.strike]`).
  - `writesReportTheirKind`: record `onWrite` into an array. `strike()`, then `beginEdit(frame: 1)` and `strike()`, then `undo()` → `[.roll, .edit, .other]`.
  - `currentScoreIsTheLastRunningTotal`: count `count(7), count(2), count(10)` → `currentScore == 9`. A final-only game → 0, and after `saveFinalScore("187")` → 187.

  Each test advances the clock between taps, as `TestClock.tick` does by itself.

- [ ] **Step 2: Run them to verify they fail.** Run with `-only-testing:BowlingTests/ScoringModelEditTests`. Expected: build failure. Add stubs: `edit` stays nil, `beginEdit` / `cancelEdit` are empty, `clearedText` returns nil, `currentScore` returns 0, and `onWrite` is never called. Rerun. Expected: assertion failures.

- [ ] **Step 3: Implement `FrameEdit` and the `ScoringModel` changes** as in Interfaces. `update(_:)` passes the kind through, as `update(_ kind: ScoringWrite, _ body:)`, and calls `onWrite?(kind)` only on success, after `reload()`. A replace keeps its outcome's `clearedFrames` through the `reload()` that follows it, so set it after reload.

- [ ] **Step 4: Run them, then all `Scoring*` suites.** Run with `-only-testing:BowlingTests/ScoringModelEditTests -only-testing:BowlingTests/ScoringModelTests -only-testing:BowlingTests/ScoringModelEntryTests`. Expected: all pass, with #8's 24 unchanged.

- [ ] **Step 5: Commit (the user runs it).**
  ```sh
  git add Bowling/Features/Scoring/FrameEdit.swift Bowling/Features/Scoring/ScoringModel.swift BowlingTests/Scoring/ScoringModelEditTests.swift
  git commit -m "feat: edit a finished frame in scoring (#95)"
  ```

### Task 4: SessionScoringModel

**Files:**
- Create: `Bowling/Features/Scoring/SessionScoringModel.swift`
- Modify: `Bowling/App/AppModel.swift`: `isShowingGameSummary`, `ErrorPresenter.gameSummary`, `showsError`, `closeScoring`
- Test: `BowlingTests/Scoring/SessionScoringModelTests.swift`. Its fixture: Sam (owner) and Alex (`createBowler`), `ballA`, and a `start(_ mode:, lineup:)` that returns the model opened on Sam's game 1.

**Interfaces:**
- Consumes: `Rotation` (Task 1), `GameSummary` (Task 2), `ScoringModel.onWrite` / `ScoringWrite` / `currentScore` (Task 3).
- Produces `@Observable final class SessionScoringModel`:
  - **Properties:**
    - `let sessionID: SessionID`
    - `private(set) var gameIndex: Int`
    - `private(set) var bowlers: [ScoringModel]`: lineup order, this game number. A bowler without a game of this number is left out.
    - `private(set) var currentIndex: Int`
    - `var current: ScoringModel { bowlers[currentIndex] }`
    - `var rotates: Bool`: starts from `app.scoringSettings.rotateBowlers`
    - `var isShowingSummary: Bool`: `didSet` mirrors it into `app.isShowingGameSummary`
    - `var allFinished: Bool`
    - `var summaries: [GameSummary]`: from a fresh `sessions.session(sessionID)`, in lineup order
    - `var title: String`: "Game \(gameIndex) · \(current.bowlerName)"
  - **Init:** `init(target: ScoringTarget, app: AppModel, now: @escaping () -> Date = Date.init) throws`:
    - It loads the target game's `gameIndex` and builds every bowler's `ScoringModel` for it.
    - If the target game is unfinished and `rotates` is on, the first bowler is `Rotation.current(after: nil, …)`. Otherwise it is the target's bowler.
    - It records whether everyone has finished, so opening a finished game number shows no summary.
  - `static func open(_:app:now:) -> SessionScoringModel?`: sets `app.error` on failure, like `ScoringModel.open`.
  - `func select(_ index: Int)`: tapping a chip.
  - `func nextGame()`:
    - It writes `startNextGame(in:)`, then rebuilds `bowlers` for `gameIndex + 1` and sets `currentIndex = Rotation.current(after: nil, …) ?? 0` and `isShowingSummary = false`.
    - On failure it sets `app.error` and the sheet stays.
  - `func showSummary()`: the Complete panel's Summary button.
- Write handling (each model's `onWrite`, for the bowler that wrote):
  - **`.roll` by the current bowler:** if their `finishedFrames` went up since the last write, or their game is finished, then `currentIndex = Rotation.current(after: currentIndex, games:, rotates:) ?? currentIndex`.
  - **Every kind:** if `allFinished` is true now but wasn't before this write, `isShowingSummary = true`. Then remember `allFinished` and the current bowler's `finishedFrames`.
  - **`select`** also resets the remembered `finishedFrames` to the new current bowler's.
- `AppModel`:
  - `var isShowingGameSummary = false`
  - `showsError`: with `scoring != nil`, the topmost presenter is `.gameSummary` when `isShowingGameSummary`, else `.scoring`.
  - `closeScoring()` sets `isShowingGameSummary = false`.

- [ ] **Step 1: Write the failing tests** in `SessionScoringModelTests`:
  - `opensOnTheRulesBowler`: in count mode, Sam's frame 1 is recorded through the store first. Open on Sam → `current.bowlerName == "Alex"`.
  - `opensOnTheTargetWithRotationOff`: same setup, with `scoring.rotateBowlers` false in the suite → `"Sam"`.
  - `aFrameEndingSwitchesBowler`: count mode, open, `current.count(7)` → still Sam. `current.count(2)` → Alex.
  - `undoDoesNotSwitch`: `current.strike()` → Alex. `select(0)`, `current.undo()` → still Sam (`currentIndex == 0`).
  - `tappingAChipSwitches`: `select(1)` → Alex. A strike by Alex → `currentIndex == 0` (Sam has 0 frames).
  - `lastGameCompletingShowsTheSummary`: a final-only lineup. `current.saveFinalScore("180")` → Alex is current and no summary. `current.saveFinalScore("150")` → `isShowingSummary`, `app.isShowingGameSummary`, and `summaries.map(\.score) == [180, 150]`.
  - `oneBowlerShowsTheSummary`: lineup [Sam], final only, save 200 → `isShowingSummary`.
  - `nextGameStartsGame2ForBoth`: from the finished final-only night, `nextGame()` → `gameIndex == 2`, `bowlers.count == 2`, every `game.defaultBallID == ballA.id`, `currentIndex == 0`, and `!isShowingSummary`.
  - `openingACompleteGameShowsNoSummary`: both final-only games saved through the store, then open → `!isShowingSummary` and `allFinished`.
  - `undoThenFinishShowsTheSummaryAgain` (Review Focus 3):
    - Lineup [Sam], pin by pin, 12 strikes → summary.
    - Set `isShowingSummary = false`, then `current.undo()` and `current.strike()` → `isShowingSummary` again.
  - `closingResetsTheSummaryPresenter` (Review Focus 5):
    - Show the summary as above, set `app.scoring` to the target, call `app.closeScoring()` → `app.isShowingGameSummary == false`.
    - Then set `app.error` → `app.showsError(in: .root)`.
  - `aFailedNextGameKeepsTheSheet`: show the summary, delete the session through the store, then `nextGame()` → `app.error != nil`, `isShowingSummary`, `app.showsError(in: .gameSummary)`.

- [ ] **Step 2: Run them to verify they fail.** Run with `-only-testing:BowlingTests/SessionScoringModelTests`. Expected: build failure. Stub the class: the init builds `bowlers` and sets `currentIndex = 0`, and `nextGame` / `select` are empty. Rerun. Expected: assertion failures.

- [ ] **Step 3: Implement `SessionScoringModel` and the `AppModel` changes** as in Interfaces.

- [ ] **Step 4: Run them, plus `AppModelTests`.** Expected: all pass.

- [ ] **Step 5: Commit (the user runs it).**
  ```sh
  git add Bowling/Features/Scoring/SessionScoringModel.swift Bowling/App/AppModel.swift BowlingTests/Scoring/SessionScoringModelTests.swift
  git commit -m "feat: session scoring model with rotation and summary (#95)"
  ```

### Task 5: The night on screen

**Files:**
- Create in `Bowling/Features/Scoring/`: `BowlerStrip.swift`, `FrameEditBar.swift`, `ClearedFramesNotice.swift`, `GameSummarySheet.swift`
- Modify:
  - `ScoringScreen.swift`, `GameCompletePanel.swift`, `ShortcutBar.swift`, `CountPad.swift`
  - `Bowling/Components/AccessibilityText.swift`
- Test: `BowlingTests/Components/AccessibilityTextTests.swift`

**Interfaces:**
- Consumes: `SessionScoringModel` (Task 4), `ScoringModel.edit` / `beginEdit` / `cancelEdit` / `clearedFrames` / `editedCount` / `currentScore` (Task 3), `FrameEdit.clearedText` (Task 3), `GameSummary` (Task 2).
- Produces:
  - `AccessibilityText.bowlerChip(name: String, score: Int, isCurrent: Bool, isFinished: Bool) -> String`. The current turn wins over finished.
  - `AccessibilityText.turn(_ name: String) -> String`: "\(name)'s turn"

- [ ] **Step 1: Write the failing tests** in `AccessibilityTextTests`:
  - `bowlerChipReadsTheTurn`:
    - `bowlerChip(name: "Alex", score: 64, isCurrent: true, isFinished: false) == "Alex, 64, current turn"`
    - `("Sam", 87, false, false) == "Sam, 87"`
    - `("Sam", 201, false, true) == "Sam, 201, finished"`
  - `turnAnnouncement`: `turn("Alex") == "Alex's turn"`.

- [ ] **Step 2: Run them to verify they fail.** Run with `-only-testing:BowlingTests/AccessibilityTextTests`. Expected: build failure, then assertion failures on a stub.

- [ ] **Step 3: Implement the two strings, then the views.**
  - **`ScoringScreen`:**
    - It holds `@State var session: SessionScoringModel?`, loaded with `SessionScoringModel.open`. The failure text is unchanged.
    - The title is `session.title`. `EntryModeMenu(model: session.current)`.
    - With 2+ bowlers there is a `ToolbarItem(placement: .topBarTrailing)`: `Toggle(isOn: $session.rotates) { Label("Rotate bowlers", systemImage: "arrow.triangle.2.circlepath") }.toggleStyle(.button)`, at least 48 pt.
    - `.sheet(isPresented: $session.isShowingSummary) { GameSummarySheet(session:).sharedErrorAlert(in: .gameSummary) }`.
    - `.onChange(of: session.currentIndex)` posts `AccessibilityNotification.Announcement(AccessibilityText.turn(name))` when there are 2+ bowlers.
  - **`ScoringContent`:**
    - It takes the session. `BowlerStrip` sits above `ScorecardStrip` (2+ bowlers).
    - `ScorecardStrip` gets `currentFrame: model.edit?.frameIndex ?? model.pad?.position.frameIndex` and `onSelectFrame: model.game.entryMode == .finalOnly ? nil : model.beginEdit`.
    - Then `FrameEditBar` (when editing) and `ClearedFramesNotice` (when `clearedText` isn't nil).
    - The entry branch checks `model.edit != nil` before `isComplete`, so an edit on a complete game shows the pad.
  - **`BowlerStrip(session:)`:**
    - A horizontal `ScrollView` of chips, one per bowler: the name, `currentScore`, and `checkmark` when `Rotation.isFinished`.
    - The current chip uses `.borderedProminent`, the others `.bordered`. At least 48 pt.
    - `.accessibilityLabel(bowlerChip(...))`. A tap calls `select`.
  - **`FrameEditBar(model:)`:** "Editing frame \(f) · ball \(b)" and a Cancel button at least 48 pt, calling `cancelEdit`.
  - **`ClearedFramesNotice(text:)`:** the text on `.surface`. `.onAppear` and `.onChange(of: text)` post it as an announcement.
  - **`ShortcutBar`:** Undo is hidden while `model.edit != nil`.
  - **The Next button** reads "Replace" while editing.
  - **`CountPad`:** the button equal to `model.editedCount` uses `.borderedProminent`.
  - **`GameCompletePanel(model:session:)`:** the Done button is replaced by "Summary" (`session.showSummary`), shown only when `session.allFinished` (Ruling 3). Undo / Change score are unchanged.
  - **`GameSummarySheet(session:)`:**
    - A `NavigationStack` titled "Game \(gameIndex)".
    - A `ScrollView` of one card per `summaries` entry: name, score in `.scoreHero`, `countsText`, and the leaves.
      - `.diagrams` is a wrapping row of `LeaveDiagramView(leave:, size: .small)`: a `LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))])`, which stacks into rows at AX sizes.
      - `.enterPins` and `.none` show their text. `.hidden` shows nothing.
    - Then `seriesText`.
    - `.safeAreaInset(edge: .bottom)`: "Next game" (`.borderedProminent`, `session.nextGame`) and "End session" (`.bordered`, `app.closeScoring`), each full width and at least 48 pt.
  - **Previews:**
    - Replace `ScoringScreenPreview`'s single-bowler setup with an optional second bowler (`createBowler(name: "Alex")`).
    - Add light/dark/AX5 for: the strip mid-game with two bowlers, the edit bar with a cleared notice, and the summary with two bowlers.
    - For the edit bar and summary previews, use a small `@State` wrapper that calls `beginEdit`/`showSummary` in `.task`.
    - Keep #8's 13.

- [ ] **Step 4: Run the whole suite.**
  Expected: every test passes, about 190 (145 + the new ones), and the build shows no new warnings.

- [ ] **Step 5: Commit (the user runs it).**
  ```sh
  git add Bowling/Features/Scoring Bowling/Components/AccessibilityText.swift BowlingTests/Components/AccessibilityTextTests.swift
  git commit -m "feat: bowler strip, frame edit bar and game summary on screen (#95)"
  ```

- [ ] **Step 6: Manual check (the user, on the iPhone 18 Pro debug simulator).**
  1. A three-game night for two bowlers, one pin by pin and one in count mode.
  2. A frame edit that clears later frames.
  3. Rotation off.
  4. Kill the app mid-game and resume on the right bowler.
  5. AX5.
