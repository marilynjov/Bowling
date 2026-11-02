# VoiceOver-only scoring checklist

Run once on an iPhone before merging an accessibility change (#14), and after changes to
Scoring, the pin deck or the scorecard. The pass condition: a full game can be scored by
ear, without looking at the screen.

The phrases below come from `AccessibilityText`:
- `BowlingTests/Scoring/UITestGameTests.swift` asserts every frame phrase and deck summary
  quoted for this game.
- `BowlingTests/Components/AccessibilityTextTests.swift` checks the general formats
  ("Pin 7, standing", "Frame 8: not bowled").

If either test's wording changes, update this page in the same PR.

## Setup

1. Turn VoiceOver on: Settings › Accessibility › VoiceOver. A triple-click of the side
   button also works if the Accessibility Shortcut is set to VoiceOver.
2. Start from a fresh profile: Settings › Delete all data in the app, then onboard as
   "Sam", right-handed, League.
3. Gestures:
   - Swipe right or left to move between elements.
   - Double-tap to activate.
   - Rotor and two-finger scrub aren't needed.
4. Pin entry is "Tap standing", the default: you mark the pins left standing, then
   choose Next.

## The game, frame by frame

**Start.** On Home, find "Start session" and double-tap. On the New session sheet, find
"Start" and double-tap. Scoring opens on frame 1.

**How to read a ball:**
- Each pin reads "Pin 7, down" until you mark it. After a double-tap it reads
  "Pin 7, standing".
- The deck reads its summary, for example "3 pins standing: 4, 7, 10". With nothing
  marked it reads "No pins standing".
- A finished frame reads like "Frame 1: strike, total 20".

| Frame | Rolls | What to do | What to hear afterwards on the scorecard |
|---|---|---|---|
| 1 | X | Double-tap **Strike** | "Frame 1: strike, total 20" |
| 2 | 7 / | Mark pins 4, 7 and 10, hear "3 pins standing: 4, 7, 10", double-tap **Next**, then **Spare** | "Frame 2: 7, spare, total 39" |
| 3 | 9 - | Mark pin 10, hear "1 pin standing: 10", **Next**, then **Miss** | "Frame 3: 9, gutter, total 48" |
| 4 | X | **Strike** | "Frame 4: strike, total 76" |
| 5 | X | **Strike** | "Frame 5: strike, total 96" |
| 6 | 8 / | Mark pins 7 and 10 (the 7-10 split), **Next**, then **Spare** | "Frame 6: 8, spare, total 115" |
| 7 | 9 / | Mark pin 10, **Next**, then **Spare** | "Frame 7: 9, spare, total 135" |
| 8 | X | **Strike** | "Frame 8: strike, total 154" |
| 9 | 7 2 | Mark pins 4, 7 and 10, **Next**; then mark pin 10, **Next** | "Frame 9: 7, 2, total 163" |
| 10 | X X X | **Strike** three times | "Frame 10: strike, strike, strike, total 193" |

**Undo.** Once during the game, for example after frame 2's first ball, double-tap
**Undo**. The deck should read the pins as they were before that ball, and frame 2 should
read "Frame 2: not bowled". Enter the ball again.

**A frame not reached yet** reads "Frame 8: not bowled", for example.

## Finish

1. After the tenth frame the game summary opens. The score reads "193".
2. Double-tap **End session**. You're back on Home.

## Result

| Device | iOS version | Date | Result | Notes |
|---|---|---|---|---|
| | | | Pass / Fail | |

Anything that doesn't read as written above is a failure. Fix it on the branch and run the
checklist again.

## Rule for later

- **Build in Xcode before committing new copy**, so `Localizable.xcstrings` picks it up.
  `StringCatalogTests.noKeyIsStale` catches stale keys, but not missing ones.
- **A string passed into a `String` parameter never reaches the catalog.** Wrap it in
  `String(localized:)` at the call site.
