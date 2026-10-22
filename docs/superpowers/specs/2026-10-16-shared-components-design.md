# Shared components (#5)

Status: proposed, awaiting review.

Four reusable views in `Bowling/Components/`, built in the D1 style from #72:
`PinDeckView`, `ScorecardStrip`, `StatTile`, and `LeaveDiagramView`. Every Phase 1a
screen uses them (#6 to #13), and the real `PinDeckView` is what bowlers try in the #3
test.

Spec references:
- Phase 1 design §7: Scoring, Stats, and leave diagrams.
- Phase 1 design §10: accessibility.
- Style doc: `2026-10-14-visual-style-design.md`.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Pin deck timing | Build the real `PinDeckView` now; #3 tests it | Bowler feedback adjusts a real component, not throwaway code |
| Scorecard fit | Scrolling strip, about 44 pt frames, current frame kept in view | Roomier and easier to read and tap than squeezing ten frames into one row |
| Pin input | Tap and drag | Marking a big leave is one swipe; #3 shows whether bowlers use the drag |
| Data in | Contract value types; logic in plain Swift helpers | Helpers are tested with Swift Testing; views stay thin and are checked in previews |

Components never read the store. They take what the packages already return:
- `PinSet` and `RollPosition`
- `FrameScore` and `Scorecard`
- `Leave` and `LeaveKind`
- `Rate` and `Mean`

## Files

```
Bowling/Components/
  PinDeckView.swift        the deck view
  PinDeckLayout.swift      pin centers and hit testing
  PinMarking.swift         tap and drag rules
  ScorecardStrip.swift     the strip view
  FrameText.swift          mark symbols for a frame
  StatTile.swift           the tile view
  StatFormat.swift         Rate and Mean formatting
  LeaveDiagramView.swift   the leave diagram view
  AccessibilityText.swift  every VoiceOver string from §10
BowlingTests/Components/
  one suite per helper (see Testing)
```

The branch `feat/5-shared-components` is stacked on `feat/72-visual-style`, because it
uses the theme.

## PinDeckView

```swift
PinDeckView(available: PinSet, standing: Binding<PinSet>)
```

**Inputs**
- `available`: the pins that can be marked, from `RollPosition.standingPins`.
- `standing`: what the deck shows as standing. It is always a subset of `available`.

**Look**

| Pin state | Drawn as |
|---|---|
| Standing | Filled PinStanding, number in OnPinStanding |
| Available and marked down | Outlined PinOutline, number in InkMuted |
| Down on an earlier roll (not in `available`) | Outlined and dimmed, can't be tapped |

**Size**
- The deck fills the width it is given.
- Pin diameter comes from that width and is never below 48 pt (spec §7). The deck is at
  least `PinDeckLayout.minimumWidth` (247 pt) wide, so a narrower container (next to
  buttons, iPad split view) can't shrink the pins; a 320 pt phone has room for it.
- Pin numbers use `Font.pinNumber` and grow with Dynamic Type up to the size the circle
  holds. The circle size doesn't depend on the text size, and VoiceOver carries the
  rest.

**Input**
- **Touch:** one `DragGesture(minimumDistance: 0)` over the whole deck. The first
  available pin touched flips. Every available pin the finger then passes takes that
  same new state.
- **Tap:** a tap is a drag that touches one pin.
- **Unavailable pins:** passing over them does nothing.
- **Passing a pin twice:** within one drag it doesn't flip back.
- **Haptics:** each change plays `.sensoryFeedback(.selection)`.

**Entry modes.** Tap standing and tap fallen use the same deck. The caller sets the
starting value of `standing`:
- Tap standing, the default: empty.
- Tap fallen: equal to `available`.

The deck doesn't know which mode is on.

**VoiceOver**
- Each pin is a button labeled "Pin 7, standing" or "Pin 7, down". Activating it toggles
  the pin.
- Unavailable pins read "Pin 7, down" and are not buttons.
- The deck as a whole reads a summary, for example "6 pins standing: 4, 7, 8, 9, 10".

## ScorecardStrip

```swift
ScorecardStrip(scorecard: Scorecard, currentFrame: Int?, onSelectFrame: ((Int) -> Void)?)
```

**Each frame**
- **Layout:** an Inset box with three parts: the frame number in `.figure` and InkMuted,
  a Surface band with the marks in `Font.frameMark`, and the running total in
  `Font.frameTotal`.
- **Width:** frames 1 to 9 are about 44 pt wide, and the 10th is wider to fit three
  marks. Widths use `@ScaledMetric`, so frames widen with Dynamic Type instead of
  truncating.
- **Marks:** each mark takes its color from `Theme.color(for:)`.
- **Split:** when `frame.leave?.kind == .split`, the first-ball count gets a circle in
  CautionText.
- **Running total:** blank while `runningTotal` is nil, like a lane monitor.

**The strip**
- **Scrolling:** it scrolls horizontally inside a `ScrollViewReader` and scrolls
  `currentFrame` into view when that changes.
- **Current frame:** outlined with a 2 pt AccentColor border.
- **Taps:** frames that have marks, other than the current one, are buttons that call
  `onSelectFrame(frameIndex)`. With `onSelectFrame` nil, the strip is read-only, as
  History uses it.

**VoiceOver.** Each frame is one element: "Frame 6: foul, 7, total 105". A strike reads
"strike", a spare "spare", and a gutter "gutter". A blank total is left out, so the
frame reads "Frame 7: 7".

## StatTile

```swift
StatTile(title: LocalizedStringKey, value: String, sample: String?, progress: Double?)
StatTile(title: LocalizedStringKey, rate: Rate, unit: StatFormat.Unit)  // "41%", "216 frames"
StatTile(title: LocalizedStringKey, mean: Mean)                         // "186", "24 games"
```

**Look.** The D1 card, from top to bottom:
1. The title, with `.monoLabel()`.
2. The value, in `Font.tileValue` with `.monospacedDigit()`.
3. An optional progress bar, AccentColor on an Inset track. Rates show it and means
   don't.
4. The sample size, in `.figure` and InkMuted.

**No data.** A nil `Rate.value` or `Mean.value` shows "–" with "No games yet", "No frames
yet", or "No chances yet", matching the tile's unit. A bowler with 30 games and no split
chances shouldn't read "No games yet".

**VoiceOver.** The tile is one element, for example "Strike percentage, 41 percent,
216 frames".

## LeaveDiagramView

```swift
LeaveDiagramView(leave: Leave, size: LeaveDiagramView.Size = .regular)  // .small, .regular
```

**Look**
- A small deck that can't be tapped. Standing pins are filled PinStanding, the same as
  the pin deck, and down pins are outlined PinOutline.
- The caption below is `leave.name`, for example "3-6-10", in `.figure`.
- `.small` is for table rows and `.regular` is for cards and detail screens.

**Splits and washouts**
- **Split:** the standing pins are filled Caution, and the caption gets a "Split" tag in
  CautionText on CautionSoft.
- **Washout:** gets a "Washout" tag.
- Color is never the only signal.

**VoiceOver.** The diagram is one element: "Leave 3, 6, 10, makeable", "Leave 7, 10,
split", "Leave 10, single pin", or "Leave 1, 2, 10, washout".

## Helpers

Each helper is plain Swift with no SwiftUI views, so it runs in unit tests.

| Helper | Owns |
|---|---|
| `FrameText` | The symbol for each mark: X, /, F, -, and 1 to 9. The marks of a frame in order, including the 10th's three-box shapes. |
| `AccessibilityText` | Every VoiceOver string above, through `String(localized:)` for the String Catalog (§10) |
| `StatFormat` | `Rate` and `Mean` values ("41%", "186", "186.5") and sample text ("1 game", "24 games", "216 frames") |
| `PinDeckLayout` | Pin centers in the 7-8-9-10 / 4-5-6 / 2-3 / 1 triangle for a given width; `pin(at:)` hit testing within each pin's circle |
| `PinMarking` | Applying a drag's sequence of touched pins to `standing`, under the rules in PinDeckView |

## Testing

Swift Testing, test first, one suite per helper in `BowlingTests/Components/`:

| Suite | What it checks |
|---|---|
| `FrameTextTests` | Every `Mark` case. Spares after counts ("9 /"), a foul then a count ("F 7"), and the 10th-frame shapes X X X, 9 / X, and 8 1. |
| `AccessibilityTextTests` | Pin labels. The deck summary, including "No pins standing" and "All 10 pins standing". Frame labels, including foul and a blank total. Leave labels for each `LeaveKind` and for washouts. |
| `PinMarkingTests` | A tap toggles one pin. A drag sets every passed pin to the first pin's new state. Unavailable pins never change. A pin passed twice doesn't flip back. |
| `PinDeckLayoutTests` | Centers follow the triangle. Hit testing finds each pin and returns nil in the gaps. At `minimumWidth`, pins are at least 48 pt, and 1 pt narrower they would be under. |
| `StatFormatTests` | Rate and Mean formatting, the no-data case, and singular and plural sample text. |

The views get no unit tests. They are checked in previews.

## Previews

**Data.** Demo data from `BowlingStore.demo()` and the `BowlingFixtures` games (linked
into the app in #71). It is turned into real `Scorecard`, `Leave`, and `StatsReport`
values.

**Variants.** Each component has light, dark, and AX3 text size previews, plus edge
cases:

| Component | Edge cases |
|---|---|
| `PinDeckView` | A fresh rack, a second ball with 3 pins left, and all pins down |
| `ScorecardStrip` | A game in progress, a 300, and a three-ball 10th frame |
| `StatTile` | A tile with no data |
| `LeaveDiagramView` | A split, a washout, and a single pin |

## The #3 test screen (after #5)

#3 runs after #5 and is not part of it. It gets a small `#if DEBUG` screen with:
- a `PinDeckView`
- Strike, Spare, Miss, and Foul buttons
- a running `ScorecardStrip`

Nothing is saved, so bowlers can try the real deck. #5 only has to make the deck easy to
drop in: its two inputs above are all it needs.

## Out of scope

- The Scoring screen's layout, buttons, and Next behavior (#8).
- Count mode's number pad (#8).
- The game summary sheet (#8).
- Charts. The trend card is part of #10.

## Done when

- Every helper test passes.
- Each component has light, dark, and AX3 previews from demo data.
- VoiceOver strings match §10.
- The colors come only from the asset catalog, so `ThemeTests` keeps covering contrast.
