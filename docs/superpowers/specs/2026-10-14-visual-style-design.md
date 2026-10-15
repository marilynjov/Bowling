# Visual style: D1 Teal & Crimson (#72)

Status: proposed, awaiting review. Chosen 2026-10-14 from the mockups in the
[Bowling Visual Style canvas](https://claude.ai/artifact/P5USnQhXsrZ9nYiAgDSsf7)
(boards D1 to D4; earlier directions A to C were set aside).

The look is a scorer's notebook, like a telemetry sheet. White cards sit on a light grey
canvas, each with a one-point hairline. Figures sit in grey insets. Labels are small,
uppercase and monospaced. Color is kept for meaning: teal for actions and spares, crimson
for strikes, fouls and trouble pins, and amber for leaves and splits.

Spec references: Phase 1 design §7 (screens, Liquid Glass) and §10 (accessibility).

## Colors

Each color is an asset catalog color set in `Bowling/Assets.xcassets`, with a light and
a dark variant. Code uses the generated symbols (`Color.surface`, `.foregroundStyle(.strikeText)`)
and never writes hex values.

| Token | Light | Dark | Use |
|---|---|---|---|
| Canvas | #F3F4F5 | #0A0F13 | Screen background |
| Surface | #FFFFFF | #121A20 | Cards, segmented control, tab bar on iOS 18 |
| Inset | #EEF0F2 | #1A232B | Figure boxes inside cards, scorecard frames |
| Hairline | #E1E4E8 | #24303A | Card outlines and dividers (decorative) |
| Ink | #0E1A24 | #E6EDF0 | Primary text, counts on the scorecard |
| InkMuted | #5C6773 | #8B98A3 | Labels, sample sizes, gutter marks |
| AccentColor | #1F5C50 | #3BAF96 | App tint, Spare button, selected chip and segment |
| AccentText | #1F5C50 | #5DD3B6 | Teal text: spare marks, scores, links |
| AccentSoft | #DCF0EA | #0F2E28 | Teal tag background |
| OnAccent | #FFFFFF | #03140F | Text on AccentColor |
| Strike | #9F1D35 | #C93A52 | Strike button, trouble pin ring |
| StrikeText | #9F1D35 | #FF7A8D | Strike and foul marks, open frame counts |
| StrikeSoft | #FBE5E9 | #3A121B | Crimson tag background |
| OnStrike | #FFFFFF | #FFFFFF | Text on Strike |
| Caution | #B45309 | #E3A040 | Amber rings in the leave heat deck |
| CautionText | #9A4A08 | #F2B45C | Leave and split tags, split indicator |
| CautionSoft | #FDF2D0 | #33250C | Amber tag background |
| PinStanding | #0E1A2B | #E6EDF0 | A standing pin's fill |
| OnPinStanding | #FFFFFF | #0A0F13 | The number on a standing pin |
| PinOutline | #7D8691 | #64717E | Outline of a down pin (still tappable) |

Three values differ from the mockup to pass contrast:
- PinOutline was #C5CCD4 / #3A4651 (1.6:1 and 1.8:1). A down pin can still be tapped,
  so its outline needs 3:1 on both Surface and Inset.
- Dark Strike was #D9435B. White text on it was 4.3:1.

### Marks

`Theme.color(for:)` maps BowlingCore's `Mark` and `LeaveKind`, so every screen colors
marks the same way.

| Mark | Color |
|---|---|
| Strike (X), foul (F) | StrikeText |
| Spare (/) | AccentText |
| Count 1 to 9 | Ink |
| Gutter (-) | InkMuted |
| Split leave | CautionText, with the split circle |
| Other leaves | Ink |

Color is never the only signal. Marks keep their symbols, splits keep their circle, and
the trouble pin also has a "!" badge.

### Contrast

All pairs meet WCAG AA in both appearances: 4.5:1 for text, 3:1 for pins, button fills
and other controls. `BowlingTests/ThemeTests.swift` checks the asset values, so a color
change that breaks contrast fails CI. Hairline is decorative and not checked: cards are
also set apart by the Surface fill.

## Typography

System fonts only: SF Pro for text and SF Mono for labels and figures. The mockups used
JetBrains Mono, but there are no third-party dependencies. Every style is built from a
text style, so Dynamic Type works.

| Name | Definition | Use |
|---|---|---|
| `Font.scoreHero` | largeTitle, heavy | Game score, average card |
| `Font.tileValue` | title, heavy | Stat tile values |
| `Font.frameMark` | body, monospaced, bold | X, /, F and counts in a frame |
| `Font.frameTotal` | subheadline, monospaced, bold | Running total in a frame |
| `Font.figure` | caption, monospaced | Sample sizes, small figures |
| `Font.pinNumber` | headline, bold | Pin numbers |
| `.monoLabel()` | caption, monospaced, medium, uppercase, 0.6 tracking, InkMuted | Card labels |

Titles use the system styles (`.largeTitle` for screen titles, `.headline` for card
titles). Numbers that change in place (scores, totals) also take `.monospacedDigit()`,
so they don't shift as they update.

## Shapes and spacing

- Cards: 14 pt continuous corner radius, 12 pt vertical and 14 pt horizontal padding, a
  1 pt Hairline stroke.
- Insets: 10 pt radius, about 10 pt padding.
- Tags: 6 pt radius, monospaced caption, uppercase.
- Filter chips and the Add button: capsules.
- Buttons: 12 pt radius. Strike and Spare are 54 pt tall; Miss and Foul are 44 pt.
- Pins: 48 pt minimum, as spec §7 requires.
- 16 pt screen margins, and 8 to 10 pt between cards.

## Glass and materials

Content stays solid, and glass is only for controls that float over it:

- **Tab bar and toolbars:** system Liquid Glass on iOS 26 and later.
- **`glassBackground(in:)`:** only for floating controls, such as the Scoring close
  button and any bar pinned over scrolling content.
- **Not glass:** cards, stat tiles, the scorecard and the pin deck. They use Surface,
  because numbers and pins must stay readable over anything behind them.

## App icon

Not part of this doc's first review. A first version for TestFlight (#2) follows on this
branch once the colors are approved. The concept is a white pin-deck triangle on teal
(AccentColor), with the 10 pin in crimson.

## Out of scope

- Component layouts. These belong to #5, which uses these tokens.
- Pin deck feel. This comes from the #3 prototype.
- Screen layouts. These come from #6 to #13.
