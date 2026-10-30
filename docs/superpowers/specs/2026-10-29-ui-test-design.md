# UI test: full pin-by-pin game — design

Issue #15 · Phase 1a · owner:frontend · branch `feat/15-ui-test`

## Goal

One UI test drives the real app through a full pin-by-pin game. It starts a session, enters
every roll with the real controls and checks the final score on the summary sheet. Done when
it passes on CI.

## Setup

- **Target:** `BowlingUITests`, an iOS UI Testing Bundle (XCTest) that tests `Bowling`. Marilyn
  creates it in Xcode. It is added to the shared `Bowling` scheme's Test action, so the
  existing CI step (`xcodebuild build test -scheme Bowling`) runs it with no workflow change.
  Xcode's template files are replaced by the test below.
- **Launch mode:** in Debug builds only (`#if DEBUG`), the launch argument `-uiTesting` makes
  the app:
  - open `BowlingStore(inMemory: true)`, seeded with an owner named "Sam" (league profile),
    so Home is the first screen and first launch is skipped;
  - use a throwaway `UserDefaults(suiteName:)`, cleared on launch, for `SessionDefaultsStore`
    and `ScoringSettings`. The defaults are then: pin entry "Tap standing", nothing
    remembered from a previous run.

  A normal launch is unchanged. The decision lives in `StoreLoader` and `BowlingApp`, and
  Release builds never contain it.
- **Accessibility identifiers:** added only where the test taps or reads. VoiceOver labels and
  traits do not change.

  | Identifier | Element |
  |---|---|
  | `home.startSession` | Home's Start session button |
  | `newSession.start` | New session sheet's Start button |
  | `pin.1` … `pin.10` | Each pin in the pin deck |
  | `scoring.next` | Next (records the ball) |
  | `scoring.strike` | Strike shortcut |
  | `scoring.spare` | Spare shortcut |
  | `scoring.miss` | Miss shortcut |
  | `summary.score` | Final score on the game summary sheet |

  The sheet's Scoring picker defaults to Pin by pin, so the test does not touch it.

## The test

`BowlingUITests/PinByPinGameUITests.swift`, test `testFullGameShowsTheFinalScore`:
launch with `-uiTesting`, then Home › Start session › Start, then one game.

| Frame | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Rolls | X | 7 / | 9 – | X | X | 8 / | 9 / | X | 7 2 | X X X |
| Total | 20 | 39 | 48 | 76 | 96 | 115 | 135 | 154 | 163 | **193** |

Entry, with "Tap standing" (tap the pins left standing, then Next):

- Strikes, including the three in the tenth: Strike.
- Frame 2: pins 4, 7, 10, Next, then Spare.
- Frame 3: pin 10, Next, then Miss.
- Frame 6: pins 7, 10, Next (the 7-10 split), then Spare.
- Frame 7: pin 10, Next, then Spare.
- Frame 9: pins 4, 7, 10, Next, then pin 10, Next.

The game covers tapping pins, Next, the Strike, Spare and Miss shortcuts, an open frame, a miss, a split and the
tenth frame's fill balls. The summary sheet opens on its own when the game ends. The test
waits for `summary.score` and asserts its label reads 193.

A unit test in `BowlingTests` (`UITestGameTests.scoresOneNinetyThree`) feeds the same rolls to
`Scorer`, so the expected 193 is checked independently of the UI.
Both tests carry the same frame table in a comment.

## Not in scope

More UI tests, screenshots, launch-performance tests, and the accessibility pass (#14).
