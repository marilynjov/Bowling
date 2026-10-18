# Shared Components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `PinDeckView`, `ScorecardStrip`, `StatTile`, and `LeaveDiagramView` in
`Bowling/Components/`, in the D1 style, with every piece of logic in a tested helper.

**Architecture:** Views take BowlingCore value types (`PinSet`, `FrameScore`,
`Scorecard`, `Leave`, `Rate`, `Mean`) and never read the store. Five plain Swift helpers
own the decisions: `FrameText`, `AccessibilityText`, `StatFormat`, `PinDeckLayout`, and
`PinMarking`. They are tested with Swift Testing. The views only draw and are checked in
previews built from `BowlingFixtures`.

**Tech Stack:** SwiftUI, Swift Testing, BowlingCore, BowlingFixtures (Debug previews).

**Spec:** `docs/superpowers/specs/2026-10-16-shared-components-design.md`. Also read
`docs/superpowers/specs/2026-10-14-visual-style-design.md` for colors and text styles.

## Global Constraints

- iOS 18.0 minimum. Glass only through `glassBackground(in:)`, and no component uses it.
- App target settings: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and member import
  visibility, so every file imports the module of each type it uses (`BowlingCore`,
  `SwiftUI`, `Foundation`, `CoreGraphics`). Test-argument statics are `nonisolated`.
- Colors only from asset symbols (`.surface`, `.pinStanding`, ...) and `Theme.color(for:)`.
  No hex values in code.
- Text only through text styles (`Font.pinNumber`, `.frameMark`, `.frameTotal`,
  `.tileValue`, `.figure`, `.monoLabel()`), so Dynamic Type works.
- Every user-visible string goes through `String(localized:)` or `LocalizedStringKey`.
- No third-party dependencies.
- Test runs use the iPhone 18 Pro Max simulator, id `2C568C51-3721-4FB2-90EE-D54EB3308C03`.
  Never use the user's iPhone 18 Pro debug simulator. Run with
  `-parallel-testing-enabled NO`, because parallel clones have timed out here.
- Views have no unit tests (TDD covers the helpers). Each view task's gate is: the app
  builds, the full suite passes, and the previews compile.
- `BowlingTests/` and `Bowling/` are synchronized folders, so new files need no project
  edits.
- The user makes every commit. Commit steps list the files to stage and the message, and
  the executor hands them over instead of running `git commit`.

## Review Focus

1. **Percent rounding near 100%.** 199 of 200 rounds to "100%", which claims perfection.
   Expect "99%", with "100%" only when hits equal attempts. Test in Task 3.
2. **A drag that starts on a down pin or in a gap.** The first *available* pin the finger
   reaches decides the new state. Test in Task 5.
3. **`standing` holding pins outside `available`** (a caller bug). The deck must
   intersect them, never show an unavailable pin standing. Test in Task 5.
4. **Split circle in the 10th frame.** X then a 7-10 split puts the circle on box 2, not
   box 1. Test in Task 1.
5. **The strip at AX3 text size.** Frames widen and the current frame still scrolls into
   view. This is checked in the Task 8 preview, since it's visual.

---

### Task 1: FrameText

**Files:**
- Create: `Bowling/Components/FrameText.swift`
- Test: `BowlingTests/Components/FrameTextTests.swift`

**Interfaces:**
- Produces:
  - `enum FrameText`
  - `static func symbol(for mark: Mark) -> String`
  - `static func boxes(for frame: FrameScore) -> [Mark?]`: 2 boxes for frames 1 to 9,
    3 for frame 10. nil is an empty box.
  - `static func splitBox(for frame: FrameScore) -> Int?`
  - `static func total(for frame: FrameScore) -> String`: "" when `runningTotal` is nil.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct FrameTextTests {
    private func text(_ marks: [Mark], frame: Int = 1) -> [String] {
        FrameText.boxes(for: FrameScore(frameIndex: frame, marks: marks, runningTotal: nil))
            .map { $0.map(FrameText.symbol(for:)) ?? "" }
    }

    @Test func symbols() {
        #expect([Mark.strike, .spare, .foul, .gutter, .count(7)].map(FrameText.symbol(for:)) == ["X", "/", "F", "-", "7"])
    }
    @Test func strikeSitsInTheSecondBox() { #expect(text([.strike]) == ["", "X"]) }
    @Test func spareAfterCount() { #expect(text([.count(9), .spare]) == ["9", "/"]) }
    @Test func foulThenCount() { #expect(text([.foul, .count(7)]) == ["F", "7"]) }
    @Test func unbowledFrame() { #expect(text([]) == ["", ""]) }
    @Test func tenthFrameShapes() {
        #expect(text([.strike, .strike, .strike], frame: 10) == ["X", "X", "X"])
        #expect(text([.count(9), .spare, .strike], frame: 10) == ["9", "/", "X"])
        #expect(text([.count(8), .count(1)], frame: 10) == ["8", "1", ""])
    }
    @Test func splitBoxIsTheLeavesFirstBall() {
        let split = LeaveClassifier.classify(PinSet(pins: [7, 10]))
        #expect(FrameText.splitBox(for: FrameScore(frameIndex: 3, marks: [.count(8), .count(1)], leave: split, runningTotal: 50)) == 0)
        #expect(FrameText.splitBox(for: FrameScore(frameIndex: 10, marks: [.strike, .count(8), .count(1)], leave: split, runningTotal: 150)) == 1)
        let makeable = LeaveClassifier.classify(PinSet(pins: [3, 6, 10]))
        #expect(FrameText.splitBox(for: FrameScore(frameIndex: 3, marks: [.count(7), .spare], leave: makeable, runningTotal: 50)) == nil)
    }
    @Test func blankTotalUntilKnown() {
        #expect(FrameText.total(for: FrameScore(frameIndex: 1, marks: [.strike], runningTotal: nil)) == "")
        #expect(FrameText.total(for: FrameScore(frameIndex: 1, marks: [.strike], runningTotal: 20)) == "20")
    }
}
```

- [ ] **Step 2: Run, expect FAIL**: "cannot find 'FrameText' in scope".

Run: `xcodebuild test -scheme Bowling -destination 'id=2C568C51-3721-4FB2-90EE-D54EB3308C03' -parallel-testing-enabled NO -only-testing:BowlingTests/FrameTextTests`

- [ ] **Step 3: Implement `FrameText`**
  - `boxes`: frames 1 to 9 put a lone strike in box 2 and pad to 2. Frame 10 pads to 3.
  - `splitBox`: nil unless `leave?.kind == .split`. For frames 1 to 9, return 0. For
    frame 10, return the count of leading `.strike` marks.

- [ ] **Step 4: Run the same command, expect PASS** (8 tests).

- [ ] **Step 5: Commit**: `Bowling/Components/FrameText.swift`,
  `BowlingTests/Components/FrameTextTests.swift`. Message: "Add FrameText for scorecard
  marks (#5)".

### Task 2: AccessibilityText

**Files:**
- Create: `Bowling/Components/AccessibilityText.swift`
- Test: `BowlingTests/Components/AccessibilityTextTests.swift`

**Interfaces:**
- Produces:
  - `enum AccessibilityText`
  - `static func pin(_ number: Int, standing: Bool) -> String`
  - `static func deckSummary(standing: PinSet) -> String`
  - `static func frame(_ frame: FrameScore) -> String`
  - `static func leave(_ leave: Leave) -> String`
  - `static func statTile(title: String, value: String, sample: String?) -> String`
- All strings go through `String(localized:)`. Plurals use separate English branches,
  like `ErrorText`.

- [ ] **Step 1: Write the failing tests** (exact copy):

```swift
@Suite struct AccessibilityTextTests {
    @Test func pins() {
        #expect(AccessibilityText.pin(7, standing: true) == "Pin 7, standing")
        #expect(AccessibilityText.pin(7, standing: false) == "Pin 7, down")
    }
    @Test func deckSummary() {
        #expect(AccessibilityText.deckSummary(standing: []) == "No pins standing")
        #expect(AccessibilityText.deckSummary(standing: .all) == "All 10 pins standing")
        #expect(AccessibilityText.deckSummary(standing: .pin10) == "1 pin standing: 10")
        #expect(AccessibilityText.deckSummary(standing: PinSet(pins: [4, 7, 8, 9, 10])) == "5 pins standing: 4, 7, 8, 9, 10")
    }
    @Test func frames() {
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 6, marks: [.foul, .count(7)], runningTotal: 105)) == "Frame 6: foul, 7, total 105")
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 1, marks: [.strike], runningTotal: 20)) == "Frame 1: strike, total 20")
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 2, marks: [.count(9), .spare], runningTotal: nil)) == "Frame 2: 9, spare")
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 4, marks: [.gutter, .count(3)], runningTotal: 60)) == "Frame 4: gutter, 3, total 60")
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 8, marks: [], runningTotal: nil)) == "Frame 8: not bowled")
    }
    @Test func leaves() {
        #expect(AccessibilityText.leave(LeaveClassifier.classify(PinSet(pins: [3, 6, 10]))) == "Leave 3, 6, 10, makeable")
        #expect(AccessibilityText.leave(LeaveClassifier.classify(PinSet(pins: [7, 10]))) == "Leave 7, 10, split")
        #expect(AccessibilityText.leave(LeaveClassifier.classify(.pin10)) == "Leave 10, single pin")
        #expect(AccessibilityText.leave(LeaveClassifier.classify(PinSet(pins: [1, 2, 10]))) == "Leave 1, 2, 10, washout")
        #expect(AccessibilityText.leave(LeaveClassifier.classify([])) == "No leave, strike")
    }
    @Test func statTile() {
        #expect(AccessibilityText.statTile(title: "Strike %", value: "41%", sample: "216 frames") == "Strike %, 41%, 216 frames")
        #expect(AccessibilityText.statTile(title: "Average", value: "–", sample: nil) == "Average, –")
    }
}
```

- [ ] **Step 2: Run** `-only-testing:BowlingTests/AccessibilityTextTests`. Expect FAIL:
  "cannot find 'AccessibilityText'".

- [ ] **Step 3: Implement `AccessibilityText`.** Mark words are "strike", "spare",
  "foul", "gutter", and the count. `isWashout` takes precedence over the kind word.

- [ ] **Step 4: Run again, expect PASS** (5 tests).

- [ ] **Step 5: Commit**: both files. Message: "Add the VoiceOver text for the shared
  components (#5)".

### Task 3: StatFormat

**Files:**
- Create: `Bowling/Components/StatFormat.swift`
- Test: `BowlingTests/Components/StatFormatTests.swift`

**Interfaces:**
- Produces:
  - `enum StatFormat`
  - `enum Unit { case games, frames, chances }`
  - `static func percent(_ rate: Rate) -> String`: "–" when `value` is nil.
  - `static func average(_ mean: Mean) -> String`: "–" when nil. Up to one decimal, no
    trailing ".0".
  - `static func sample(_ count: Int, _ unit: Unit) -> String`

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct StatFormatTests {
    @Test func percents() {
        #expect(StatFormat.percent(Rate(hits: 89, attempts: 216)) == "41%")
        #expect(StatFormat.percent(Rate(hits: 0, attempts: 0)) == "–")
        #expect(StatFormat.percent(Rate(hits: 199, attempts: 200)) == "99%")   // Review Focus 1
        #expect(StatFormat.percent(Rate(hits: 200, attempts: 200)) == "100%")
    }
    @Test func averages() {
        #expect(StatFormat.average(Mean(total: 4464, count: 24)) == "186")
        #expect(StatFormat.average(Mean(total: 373, count: 2)) == "186.5")
        #expect(StatFormat.average(Mean(total: 0, count: 0)) == "–")
    }
    @Test func samples() {
        #expect(StatFormat.sample(1, .games) == "1 game")
        #expect(StatFormat.sample(24, .games) == "24 games")
        #expect(StatFormat.sample(216, .frames) == "216 frames")
        #expect(StatFormat.sample(1, .chances) == "1 chance")
        #expect(StatFormat.sample(0, .games) == "No games yet")
    }
}
```

- [ ] **Step 2: Run** `-only-testing:BowlingTests/StatFormatTests`. Expect FAIL.

- [ ] **Step 3: Implement.**
  - **Percent:** a whole percent rounded to nearest, then capped at 99 unless
    `hits == attempts`. Format through `.formatted(.percent.precision(.fractionLength(0)))`.
  - **Average:** `.formatted(.number.precision(.fractionLength(0...1)))`.
  - **Sample:** zero of any unit returns "No games yet".

- [ ] **Step 4: Run again, expect PASS** (3 tests).

- [ ] **Step 5: Commit**: both files. Message: "Add stat formatting for tiles (#5)".

### Task 4: PinDeckLayout

**Files:**
- Create: `Bowling/Components/PinDeckLayout.swift`
- Test: `BowlingTests/Components/PinDeckLayoutTests.swift`

**Interfaces:**
- Produces:
  - `struct PinDeckLayout`
  - `init(width: CGFloat)`
  - `let spacing: CGFloat`: `width / 4`, the center-to-center distance.
  - `let pinDiameter: CGFloat`: `spacing * 0.78`.
  - `var height: CGFloat`
  - `func center(of pin: Int) -> CGPoint`
  - `func pin(at point: CGPoint) -> Int?`
  - `static let rows: [[Int]] = [[7, 8, 9, 10], [4, 5, 6], [2, 3], [1]]`
- Geometry:
  - Rows go from the back (7-10) at the top to the 1 pin at the bottom.
  - Row r is at `y = pinDiameter / 2 + r * spacing * 0.866`.
  - Pins in a row are centered on `width / 2`, `spacing` apart.
  - `height = 3 * spacing * 0.866 + pinDiameter`.
  - No minimum is enforced in the layout, because `LeaveDiagramView` reuses it at small
    widths.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct PinDeckLayoutTests {
    let layout = PinDeckLayout(width: 288)   // a 320 pt phone minus 16 pt margins

    @Test func pinsAreAtLeast48PointsOnTheSmallestPhone() { #expect(layout.pinDiameter >= 48) }
    @Test func triangleOrder() {
        #expect(layout.center(of: 7).y == layout.center(of: 10).y)
        #expect(layout.center(of: 7).x < layout.center(of: 8).x)
        #expect(layout.center(of: 1).y > layout.center(of: 2).y)
        #expect(abs(layout.center(of: 1).x - 144) < 0.001)
        #expect(abs(layout.center(of: 5).x - 144) < 0.001)
    }
    @Test func hitTestingFindsEveryPin() {
        for pin in 1...10 { #expect(layout.pin(at: layout.center(of: pin)) == pin) }
    }
    @Test func gapsHitNothing() {
        let a = layout.center(of: 7), b = layout.center(of: 8)
        #expect(layout.pin(at: CGPoint(x: (a.x + b.x) / 2, y: a.y)) == nil)
        #expect(layout.pin(at: CGPoint(x: -10, y: -10)) == nil)
    }
}
```

- [ ] **Step 2: Run** `-only-testing:BowlingTests/PinDeckLayoutTests`. Expect FAIL.
- [ ] **Step 3: Implement.** `pin(at:)` returns the pin whose center is within
  `pinDiameter / 2`.
- [ ] **Step 4: Run again, expect PASS** (4 tests).
- [ ] **Step 5: Commit**: both files. Message: "Add the pin deck layout and hit testing
  (#5)".

### Task 5: PinMarking

**Files:**
- Create: `Bowling/Components/PinMarking.swift`
- Test: `BowlingTests/Components/PinMarkingTests.swift`

**Interfaces:**
- Produces:
  - `struct PinMarking`: one per gesture.
  - `init(available: PinSet, standing: PinSet)`: stores `standing ∩ available`.
  - `private(set) var standing: PinSet`
  - `mutating func touch(_ pin: Int)`
- Rules:
  - The first available pin touched flips, and its new state becomes the target.
  - Every later, not-yet-touched available pin is set to the target.
  - Unavailable pins are ignored and don't set the target.
  - A pin already touched in this gesture is ignored.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct PinMarkingTests {
    @Test func tapTogglesOnePin() {
        var m = PinMarking(available: .all, standing: [])
        m.touch(7)
        #expect(m.standing == .pin7)
    }
    @Test func dragSetsPassedPinsToTheFirstPinsNewState() {
        var m = PinMarking(available: .all, standing: .pin8)
        for pin in [7, 8, 9] { m.touch(pin) }   // 7 goes up, so 8 stays up and 9 goes up
        #expect(m.standing == PinSet(pins: [7, 8, 9]))
    }
    @Test func dragCanKnockDown() {
        var m = PinMarking(available: .all, standing: .all)
        for pin in [4, 5, 6] { m.touch(pin) }
        #expect(m.standing == PinSet.all.subtracting(PinSet(pins: [4, 5, 6])))
    }
    @Test func unavailablePinsNeverChangeOrSetTheTarget() {   // Review Focus 2
        var m = PinMarking(available: PinSet(pins: [3, 6, 10]), standing: .pin3)
        for pin in [5, 6, 10] { m.touch(pin) }   // 5 is down from roll 1; 6 sets the target "standing"
        #expect(m.standing == PinSet(pins: [3, 6, 10]))
    }
    @Test func passingAPinTwiceDoesNotFlipItBack() {
        var m = PinMarking(available: .all, standing: [])
        for pin in [7, 8, 7] { m.touch(pin) }
        #expect(m.standing == PinSet(pins: [7, 8]))
    }
    @Test func standingOutsideAvailableIsDropped() {   // Review Focus 3
        let m = PinMarking(available: PinSet(pins: [3, 6, 10]), standing: .all)
        #expect(m.standing == PinSet(pins: [3, 6, 10]))
    }
}
```

- [ ] **Step 2: Run** `-only-testing:BowlingTests/PinMarkingTests`. Expect FAIL.
- [ ] **Step 3: Implement** with a `touched: PinSet` and `target: Bool?`.
- [ ] **Step 4: Run again, expect PASS** (6 tests).
- [ ] **Step 5: Commit**: both files. Message: "Add tap-and-drag pin marking (#5)".

### Task 6: Preview data and LeaveDiagramView

**Files:**
- Create: `Bowling/Components/PreviewData.swift`, wrapped in `#if DEBUG`.
- Create: `Bowling/Components/LeaveDiagramView.swift`

**Interfaces:**
- Consumes: `PinDeckLayout` (Task 4), `AccessibilityText.leave` (Task 2).
- Produces:
  - `enum PreviewData` (DEBUG only), with:
    - `static let games: [GameRecord]`: `DemoFixture.games(relativeTo: DemoFixture.referenceDate)`.
    - `static func scorecard(_ game: DemoGame) -> Scorecard`, through `Scorer.scorecard(for:)`.
    - `static let report: StatsReport`: `StatsEngine.report` over the owner's games with
      `StatsFilter(bowlerID: DemoBowler.owner.id)`.
    - `static func leave(_ pins: Int...) -> Leave`: `LeaveClassifier.classify`.
  - `struct LeaveDiagramView: View`
  - `init(leave: Leave, size: Size = .regular)`
  - `enum Size { case small, regular }`: the deck is 44 pt or 72 pt wide.

- [ ] **Step 1: Implement `PreviewData`.**
- [ ] **Step 2: Implement `LeaveDiagramView`** per the spec section of the same name:
  - Pins are placed with `PinDeckLayout(width:)`.
  - Standing pins are filled `.ink`, or `.caution` for splits. Down pins are outlined
    `.pinOutline`.
  - The caption is `leave.name` in `.figure`. A "Split" or "Washout" tag is in
    `.cautionText` on `.cautionSoft`, with a 6 pt radius.
  - `.accessibilityElement(children: .ignore)` with `AccessibilityText.leave`.
- [ ] **Step 3: Add previews.** Previews: light, dark, and AX3, each showing 3-6-10, 7-10
  (split), 10 (single pin), and 1-2-10 (washout), in both sizes.
- [ ] **Step 4: Verify.** Run the full suite (`xcodebuild test … -parallel-testing-enabled
  NO`). Expect TEST SUCCEEDED and the previews compile.
- [ ] **Step 5: Commit**: both files. Message: "Add LeaveDiagramView and preview data
  (#5)".

### Task 7: StatTile

**Files:**
- Create: `Bowling/Components/StatTile.swift`

**Interfaces:**
- Consumes: `StatFormat` (Task 3), `AccessibilityText.statTile` (Task 2).
- Produces:
  - `struct StatTile: View`
  - `init(title: String, value: String, sample: String?, progress: Double? = nil)`
  - `init(title: String, rate: Rate, unit: StatFormat.Unit)`: the value is
    `percent`, the sample is `sample(rate.attempts, unit)`, and the progress is
    `rate.value`.
  - `init(title: String, mean: Mean)`: the value is `average`, the sample is
    `sample(mean.count, .games)`, and there is no progress.
  - Callers pass an already-localized title, for example `String(localized: "Strike %")`,
    so the same string serves the label and VoiceOver.

- [ ] **Step 1: Implement** per the spec's StatTile section:
  - The D1 card: `.surface` fill, 14 pt continuous radius, a `.hairline` stroke, and
    12/14 pt padding.
  - The progress bar is 6 pt tall, `.accent` on `.inset`.
  - The tile is one accessibility element.
- [ ] **Step 2: Add previews.** A 2×2 grid from `PreviewData.report`: average, high game
  (value from `highGame?.score`), strike %, and spare %. Also an empty `Rate(0, 0)`
  tile. Light, dark, and AX3.
- [ ] **Step 3: Verify.** Run the full suite and expect it to pass.
- [ ] **Step 4: Commit**: `Bowling/Components/StatTile.swift`. Message: "Add StatTile
  (#5)".

### Task 8: ScorecardStrip

**Files:**
- Create: `Bowling/Components/ScorecardStrip.swift`

**Interfaces:**
- Consumes: `FrameText` (Task 1), `AccessibilityText.frame` (Task 2), `Theme.color(for:)`.
- Produces:
  - `struct ScorecardStrip: View`
  - `init(scorecard: Scorecard, currentFrame: Int?, onSelectFrame: ((Int) -> Void)? = nil)`

- [ ] **Step 1: Implement** per the spec's ScorecardStrip section:
  - **Widths:** `@ScaledMetric` widths of 44 for frames 1 to 9 and 62 for frame 10.
  - **Scrolling:** a horizontal `ScrollView` in a `ScrollViewReader`, with
    `.onChange(of: currentFrame)` and `.onAppear` scrolling to it.
  - **Current frame:** a 2 pt `.accent` border.
  - **Split circle:** on `FrameText.splitBox`, a `Circle().stroke(.cautionText)` behind
    that box.
  - **Taps:** frames that have marks, other than the current one, are `Button`s only
    when `onSelectFrame` is non-nil.
  - **VoiceOver:** each frame is one accessibility element.
- [ ] **Step 2: Add previews.**
  - `DemoGame.practiceInProgress` with its next frame current.
  - `DemoGame.tournament1` (300).
  - `DemoGame.earlyLeague1` (all spares).
  - Each in light, dark, and AX3. Check Review Focus 5 at AX3.
- [ ] **Step 3: Verify.** Run the full suite and expect it to pass.
- [ ] **Step 4: Commit**: `Bowling/Components/ScorecardStrip.swift`. Message: "Add
  ScorecardStrip (#5)".

### Task 9: PinDeckView

**Files:**
- Create: `Bowling/Components/PinDeckView.swift`

**Interfaces:**
- Consumes: `PinDeckLayout` (Task 4), `PinMarking` (Task 5), `AccessibilityText.pin` and
  `deckSummary` (Task 2).
- Produces:
  - `struct PinDeckView: View`
  - `init(available: PinSet, standing: Binding<PinSet>)`

- [ ] **Step 1: Implement** per the spec's PinDeckView section.

  **Layout**
  - A `GeometryReader` builds `PinDeckLayout(width:)`, and the view's height is
    `layout.height`.

  **Pins**
  - Standing: `.pinStanding` fill, with the number in `.onPinStanding`.
  - Marked down: `.pinOutline` 1.5 pt stroke, with the number in `.inkMuted`.
  - Unavailable: the same, at 0.35 opacity.
  - Numbers use `.pinNumber`, with `.dynamicTypeSize(...DynamicTypeSize.accessibility2)`
    so they stay inside the circle.

  **Gesture**
  - One `DragGesture(minimumDistance: 0)`.
  - `onChanged`: create a `PinMarking` on the first event, call
    `touch(layout.pin(at: location))` for each non-nil pin, and write
    `marking.standing` to the binding when it changes.
  - `onEnded`: drop the marking.
  - `.sensoryFeedback(.selection, trigger: standing)`.

  **VoiceOver**
  - Available pins are buttons labeled with `AccessibilityText.pin`. Activating one
    toggles it in the binding.
  - Unavailable pins are static text.
  - The container gets `.accessibilityElement(children: .contain)` and a label with
    `AccessibilityText.deckSummary`.
- [ ] **Step 2: Add previews.** An interactive wrapper with `@State` holding `standing`:
  - a fresh rack, with `available: .all` and `standing: []`
  - a second ball, with `available: 3-6-10`
  - all pins down, with `available: []`

  Each in light, dark, and AX3.
- [ ] **Step 3: Verify.** Run the full suite and expect TEST SUCCEEDED, then try tap and
  drag in the live preview.
- [ ] **Step 4: Commit**: `Bowling/Components/PinDeckView.swift`. Message: "Add
  PinDeckView with tap and drag (#5)".
