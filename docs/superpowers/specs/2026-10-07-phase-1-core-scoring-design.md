# Phase 1 Design: Core Scoring and Stats, On Device

Date: 2026-10-07
Status: approved in conversation, pending written review
Roadmap: `2026-10-07-program-roadmap.md`
Matrix rows covered: 1, 2, 3, 5, 8, 9, 10, 11, 12, 13, 15, 18, 19, 28, 29, 30

## 1. Purpose

Let any bowler record games on an iPhone, offline, at the level of detail they have time
for, and see every statistic that can be computed from what they entered. Everything in
this phase runs on the device with no account and no network.

Success looks like: a league bowler enters a three-game night during league, including
which pins fell on every ball, in less time than it takes to walk back from the ball
return; a casual bowler types one final score in ten seconds; both open Stats the next
day and see numbers that are correct.

### In scope

- Frame-by-frame, pin-by-pin entry with automatic frame advance and tenth-frame handling.
- Per-ball count entry (how many pins fell, without which ones) and final-score-only entry.
- Sessions tagged practice, league, tournament, or casual, with center, league, oil
  pattern, lanes, and notes.
- Ball tagging per game with a per-roll override for spare balls.
- A personal arsenal with full ball specs, a photo, a maintenance log with resurface
  reminders, and a per-ball detail screen showing performance as a strike ball and as a
  spare ball, by oil pattern and center, over time, plus a side-by-side comparison of
  all balls.
- Multiple bowlers in one session on one phone, as local names. Their games live only on
  this phone in phase 1. Sending a game to the other bowler's own account by email
  invitation is a phase 7 feature; the schema reserves fields for it.
- Statistics: average, high game, high series, strike percentage, spare percentage over
  spare attempts, makeable spares versus splits, leaves by pin and conversion per leave,
  every missed spare listed with date and ball, strike rate and average by frame number,
  clean game rate, head pin rate, first-ball average, open frame rate, the "what if I made
  every single-pin spare" average, trend over time.
- Filters on every stats screen: date range with presets and custom, event type, bowler,
  ball, oil pattern, center, league.
- Editing and deleting past games and sessions.

### Out of scope for phase 1

iCloud sync (phase 2), sharing and CSV (phase 3), photo scan (phase 4), handicap,
standings and Baker (phase 5), practice tools (phase 6), anything with accounts (phase 7),
pattern and ball libraries (phase 8), monetization.

## 2. Architecture

Three layers, dependencies pointing downward only.

```
SwiftUI views and @Observable feature models        (app target, Features/)
        |
BowlingData: SwiftData models, repositories          (Packages/BowlingData)
        |
BowlingCore: value types, scoring, leaves, stats     (Packages/BowlingCore, pure Swift)
```

- **BowlingCore** has no dependency on SwiftData, SwiftUI, or Foundation beyond basics.
  It defines the value types (`PinSet`, `Roll`, `Frame`, `GameRecord`) and the three
  engines: `Scorer`, `LeaveClassifier`, `StatsEngine`. Every function is deterministic
  and unit tested.
- **BowlingData** defines the SwiftData `@Model` classes, the `ModelContainer` setup, and
  repositories that fetch models and convert them to BowlingCore value types for the
  engines. It also owns the demo fixture data used by previews and tests.
- **App target** contains only views, feature models, and navigation. Feature models are
  `@Observable` classes that hold screen state, call repositories, and run engines. Views
  never touch `ModelContext` directly except through `@Query` for simple lists.

Why a package for the engines: they must be tested exhaustively, they must not depend on
persistence, and phases 4 and 5 reuse them for scan verification and Baker scoring.

## 3. Domain model

All SwiftData models follow the roadmap rules: optional relationships, defaults on every
attribute, no unique constraints, UUID identities, additive-only schema. `remoteID:
String?` exists on every model for phase 7 publishing and is unused in phase 1.

### Bowler

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| name | String | |
| isOwner | Bool | Exactly one owner, created at first launch. Enforced in the repository, not the schema |
| handedness | enum right, left, unknown | Used by stats to label leaves |
| email | String? | Reserved for phase 7 game invitations. Not shown in phase 1 |
| createdAt | Date | |
| games | [Game]? | inverse of Game.bowler |

### Session

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| date | Date | Start of the outing |
| eventType | enum practice, league, tournament, casual | Default casual |
| center | BowlingCenter? | |
| league | League? | Only meaningful when eventType is league |
| oilPattern | OilPattern? | |
| lanes | String | Free text, for example "17-18" |
| notes | String | |
| games | [Game]? | ordered by Game.orderInSession |

A session's series total is the sum of its games' final scores for one bowler.

### Game

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| session | Session? | |
| bowler | Bowler? | |
| orderInSession | Int | 1-based |
| entryMode | enum pinByPin, countOnly, finalOnly | Fixed at creation; a game can be upgraded from countOnly to pinByPin by editing but never silently |
| defaultBall | Ball? | |
| finalScore | Int | Cached. Computed by the Scorer for pinByPin and countOnly; typed by the user for finalOnly |
| isComplete | Bool | True when all ten frames are finished or when finalOnly |
| frames | [Frame]? | Zero frames when finalOnly |
| createdAt, updatedAt | Date | |
| sourceImageData | Data? | Reserved for phase 4 |
| scanConfidence | Double? | Reserved for phase 4 |
| invitationStatus | enum none, sent, accepted, declined, expired | Default none. Reserved for phase 7 game invitations |
| scoredByName | String? | Reserved for phase 7. Set on the recipient's copy of an accepted invitation |

### Frame

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| game | Game? | |
| index | Int | 1 through 10 |
| rolls | [Roll]? | ordered by Roll.index |
| rotationSlot | Int? | Reserved for Baker in phase 5 |

### Roll

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| frame | Frame? | |
| index | Int | 1 through 3 |
| pinsDownMask | Int | Ten-bit mask, bit n-1 is pin n. For countOnly games this is 0 and `pinCount` carries the number |
| pinCount | Int | Pins knocked down on this roll. Always set, derived from the mask when pins are known |
| pinsKnown | Bool | True in pinByPin mode |
| ball | Ball? | Override for this roll. Nil means the game's default ball |

### Ball

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| name | String | |
| brand | String | |
| weightPounds | Int | 6 through 16 |
| coverstock | enum plastic, urethane, reactiveSolid, reactivePearl, reactiveHybrid, other | |
| coverstockName | String | Manufacturer's coverstock name, for example "SPEC Solid" |
| coreType | enum symmetric, asymmetric, pancake, unknown | Pancake is the plastic spare-ball core |
| coreName | String | Manufacturer's core name, for example "Shape-Lock HD" |
| rg | Double? | Radius of gyration from the manufacturer sheet, typically 2.4 to 2.6 |
| differential | Double? | Typically 0.00 to 0.06 |
| intermediateDifferential | Double? | Asymmetric cores only. Also called mass bias differential on spec sheets |
| intendedRole | enum strike, spare, both | Default strike. Drives which stats lead on the detail screen and which picker the ball appears in first |
| serialNumber | String | |
| colorDescription | String | Free text |
| imageData | Data? | Photo of the ball, downscaled on save |
| releaseDate | Date? | Manufacturer release date, month precision |
| purchaseDate | Date? | |
| factoryFinish | String | Out-of-box surface, for example "2000 Abralon". Current surface starts from this on add |
| surfaceGrit | String | Current surface, for example "2000 polished" |
| resurfaceIntervalGames | Int? | Reminder threshold. Nil means no reminder |
| isRetired | Bool | Retired balls stay for history but are hidden from pickers |
| notes | String | |
| maintenance | [MaintenanceEvent]? | cascade delete |

Drilling layout values and hand measurements (matrix row 43) are not fields in phase 1;
they go in `notes` until phase 8 adds them properly.

### MaintenanceEvent

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| ball | Ball? | |
| date | Date | |
| kind | enum resurface, polish, oilExtraction, plugAndRedrill, other | |
| surfaceGritAfter | String | Optional text, copied to Ball.surfaceGrit on save when non-empty |
| gamesOnBallAtTime | Int | Snapshot of games bowled when the event was logged |
| notes | String | |

Derived values, computed by the repository:

- **Games bowled** is the count of games where defaultBall is this ball, plus games where
  any roll overrides to it, counted once per game.
- **Games since last resurface** is games bowled since the most recent event of kind
  resurface, or since purchase if none.
- **Resurface due** is true when `resurfaceIntervalGames` is set and games since last
  resurface meets or exceeds it.

### BowlingCenter, League, OilPattern

Each has `id`, `name`, `notes`, and `createdAt`. BowlingCenter adds optional `city` and
optional `latitude` and `longitude` for the phase 8 map. League adds `center:
BowlingCenter?`, `seasonLabel: String`, and `gamesPerSession: Int` default 3. OilPattern
adds `lengthFeet: Int?` and `volumeMilliliters: Double?`, both optional, filled by the
phase 8 library.

### Deletion rules

- Deleting a Session deletes its Games, Frames, and Rolls (cascade).
- Deleting a Bowler who has games is refused with an explanation; the user can delete
  the games first. The owner can never be deleted.
- Deleting a Ball nullifies references on Games and Rolls and deletes its
  MaintenanceEvents. The user is warned with the count of affected games and offered
  "retire instead".
- Deleting a Center, League, or Pattern nullifies references and warns the same way.

## 4. Scoring rules (BowlingCore `Scorer`)

### Pins and masks

`PinSet` is an `OptionSet` over `UInt16` with members `pin1` through `pin10`. `PinSet.all`
is all ten. Pin layout for geometry:

```
      7   8   9   10        row 4
        4   5   6           row 3
          2   3             row 2
            1               row 1
```

### Entry modes

- **pinByPin**: each roll records the exact `PinSet` that fell.
- **countOnly**: each roll records only `pinCount`.
- **finalOnly**: no frames, the user types `finalScore` in 0 through 300.

The Scorer operates on `pinCount` so it works identically for the first two modes.
`LeaveClassifier` and pin-level stats require `pinsKnown`.

### Frame rules, frames 1 through 9

- Roll 1: 0 through 10 pins. 10 is a strike; the frame is finished.
- Roll 2: 0 through (10 minus roll 1). Total of 10 is a spare. In pinByPin mode roll 2's
  `PinSet` must be a subset of the pins left standing after roll 1.

### Frame 10

- Roll 1 strike: roll 2 is on a fresh rack. If roll 2 is also a strike, roll 3 is on a
  fresh rack; otherwise roll 3 is limited to the pins roll 2 left standing.
- Roll 1 not a strike: roll 2 is limited to the pins left. If rolls 1 and 2 make a spare,
  roll 3 is on a fresh rack. Otherwise the frame ends after roll 2.
- Frame 10 pins total at most 30.

### Score computation

Frame score is the frame's pin count plus bonuses: a strike adds the next two rolls, a
spare adds the next one roll, in roll order across frames. Frame 10 has no bonus beyond
its own rolls. A frame's running total is `nil` until its bonus rolls exist, and the UI
shows a blank for pending frames exactly like a lane monitor does. Final score is the
tenth frame's running total; maximum 300.

### Validation

`Scorer.validate(_ game: GameRecord) -> [ScoringError]` returns every violation: a roll
over the pins available, a roll 2 subset violation in pinByPin mode, frames out of order,
a frame 10 third roll that is not earned, a frame with rolls after a strike in frames 1
through 9. Repositories refuse to save invalid games. The scoring UI prevents the user
from entering an invalid roll in the first place by disabling pins that are already down.

### Marks for display

Per roll, `Mark` is one of `strike`, `spare`, `count(Int)`, or `gutter` (zero on a roll
where pins were available). Fouls are not modeled in phase 1; a foul is entered as a zero.
Split leaves show the count with a split indicator when pins are known.

## 5. Leave classification (BowlingCore `LeaveClassifier`)

Input: the `PinSet` left standing after a first ball. Output: a `Leave` value with
`pins`, `name`, `kind` (`strike` for an empty set, `singlePin`, `makeable`, `split`), and
`isWashout`.

Rules, applied in order:

1. Empty set: strike, no leave.
2. One pin: `singlePin`, named by its number, for example "10".
3. Head pin (pin 1) standing with two or more pins: never a split. Named by pins, for
   example "1-2-10". `isWashout` is true for the recognized washouts 1-2-10, 1-2-4-10,
   1-3-7, 1-3-6-7, 1-2-8-10, 1-3-7-9.
4. Head pin down with two or more pins. The leave is a `split` when either holds:
   - the standing pins are not connected under physical adjacency, where adjacent pairs
     are 1-2, 1-3, 2-3, 2-4, 2-5, 3-5, 3-6, 4-5, 5-6, 4-7, 4-8, 5-8, 5-9, 6-9, 6-10, 7-8,
     8-9, 9-10; or
   - a down pin stands directly in front of two standing pins, using the pairs 1 in front
     of 2 and 3, 2 of 4 and 5, 3 of 5 and 6, 4 of 7 and 8, 5 of 8 and 9, 6 of 9 and 10.
   Otherwise `makeable`.

The second clause follows USBC Rule 2's example that the 4-5 is a split when the 2 pin
is down. It also classifies the 7-8, 8-9, 9-10, and 2-3 as splits when the pin in front
is down. If real bowlers disagree with any case, the adjacency and in-front tables are
the only thing to edit, and the test suite pins every two-pin and three-pin combination.

Names use ascending pin numbers joined by hyphens: "7-10", "4-7-10", "3-6-10".

## 6. Statistics (BowlingCore `StatsEngine`)

Input: `[GameRecord]` already filtered, plus the filter description for labeling. Output:
`StatsReport`, a value type with every number below and the sample size each number was
computed from. Every figure shows its denominator in the UI, for example "63% of 41
attempts", because bowlers distrust percentages without counts.

### Which games count for what

| Stat group | finalOnly | countOnly | pinByPin |
|---|---|---|---|
| Average, high game, high series, trend | yes | yes | yes |
| Strike %, spare %, open %, clean game, by-frame stats, first-ball average | no | yes | yes |
| Leaves, split and makeable rates, head pin rate, missed-spare list, what-if | no | no | yes |

Each section of the Stats screen states how many games it is based on.

### Definitions

- **Average**: sum of final scores divided by games. Also shown for the last 10, 30, and
  all games in the filter.
- **High game**: maximum final score, with date and session.
- **High series**: for each session and bowler, sum of final scores. Reported per game
  count (three-game series, four-game series) and the default display is the count that
  matches the league's `gamesPerSession` when a league filter is set, otherwise three.
- **Trend**: average per session over time, charted, with a rolling average of the last
  nine games overlaid.
- **First balls**: every roll 1 in frames 1 through 9, roll 1 in frame 10, and any frame 10
  roll on a fresh rack. A game has 10 to 12 first balls.
- **Strike %**: strikes divided by first balls.
- **Spare attempts**: first balls that left pins standing and were followed by a second
  roll on the same rack.
- **Spare %**: spares divided by spare attempts. This is the attempts-only definition
  from matrix row 12 and is the only spare percentage shown.
- **Split %**: spare attempts classified split divided by spare attempts. **Split
  conversion %**: splits converted divided by splits.
- **Makeable conversion %**: makeable and single-pin leaves converted divided by their
  count. **Single-pin conversion %** reported separately.
- **Open frame %**: frames 1 through 10 with neither strike nor spare divided by frames.
- **Clean game %**: games with zero open frames divided by games.
- **Head pin rate**: first balls where pin 1 fell divided by first balls.
- **First-ball average**: mean pin count on first balls.
- **Leaves table**: for each distinct `Leave`, count, conversions, conversion rate, sorted
  by count. Tapping a leave lists every occurrence with date, session, frame number, and
  the ball used on the spare attempt, which satisfies matrix row 18. A "left most, made
  least" callout highlights the leave with the highest count times miss rate.
- **By frame number**: for frames 1 through 10, strike rate on roll 1 and mean pins in the
  frame excluding bonuses.
- **What if I made every single-pin spare**: for each pinByPin game, rewrite every missed
  single-pin leave as a converted spare, rescore with `Scorer`, and report the resulting
  average next to the real one with the difference. Matrix row 30.
- **Ball stats**: when a ball filter is set on the Stats screen, all of the above for
  games or rolls using that ball.

### Ball report

`StatsEngine.ballReport(for ball: BallID, games: [GameRecord]) -> BallReport` powers the
ball detail screen. A ball has two roles in the data: the ball a first ball was thrown
with, and the ball a spare attempt was thrown with. Every roll resolves its ball as the
roll override if present, otherwise the game's default ball, so the report is exact even
when a bowler switches balls mid-game.

- **Usage**: games bowled, first balls thrown, spare attempts thrown, first and last date
  used, games since last resurface, resurface due flag.
- **As a strike ball**, over first balls thrown with it: strike %, first-ball average,
  head pin rate, and the average of games where it was the default ball. The average is
  labeled "games with this ball as main ball" because spares may have used another ball.
- **As a spare ball**, over spare attempts thrown with it: spare conversion %,
  single-pin conversion %, split conversion %, and the leaves table restricted to those
  attempts, with the same tap-through to occurrences.
- **By condition**: strike % and first-ball average grouped by oil pattern, and
  separately by center. A group displays only when it has at least 10 first balls;
  smaller groups are summed into "Other" so the user sees why a pattern is missing.
  This answers matrix row 11's "how do I score with this ball on this pattern".
- **Over time**: strike % per session since purchase, charted, with maintenance events
  drawn as markers on the date axis. This is how a bowler sees reaction fade and whether
  a resurface brought it back.
- **Comparison**: `StatsEngine.compareBalls(games:) -> [BallComparisonRow]` returns, for
  every non-retired ball, games bowled, average as main ball, strike %, first-ball
  average, and spare conversion %, each with its sample size, for a sortable table.

The ball report honors the global stats filter for date range, bowler, event type,
center, league, and pattern, so a bowler can ask "this ball, this league, this season".

### Filters

`StatsFilter` has date range (presets this week, this month, last 30 days, this season
which is league-defined or the last 9 months, all time, custom start and end), event
types, bowler, ball, oil pattern, center, league. The repository applies filters as
SwiftData predicates where possible and the rest in memory. Ball filter matches a game if
its default ball or any roll override is the ball.

## 7. Screens

Root is a `TabView` with Home, History, Stats, Arsenal. Settings is reachable from Home's
toolbar. On iOS 26 and later the tab bar is Liquid Glass automatically. Custom components
use `glassEffect` behind an availability check and a thin material otherwise.

### Home

- Headline tiles: average (all time and last 30 days), high game, high series, strike %,
  spare %, with sample sizes.
- Large "Start session" button, and "Quick score" for a final-score-only game.
- Recent sessions list, three rows, linking into History.
- Empty state on first launch asks for the owner's name and handedness, then shows a
  short explanation of the three entry modes.

### New session

A form: date defaults to now, event type segmented control, center picker with inline
create, league picker shown only for league type, oil pattern picker with inline create,
lanes text field, bowlers (owner preselected, add others by name), default ball per
bowler, entry mode default pinByPin. "Start" creates the session and the first game for
each bowler and opens Scoring. The last-used center, league, pattern, and ball are
remembered per event type.

### Scoring

The core screen. Layout top to bottom:

1. **Bowler strip** when the session has more than one bowler, showing each name and
   current score. The app rotates to the next bowler after each frame like a lane
   console; a toggle in the toolbar turns rotation off so one bowler can finish alone.
2. **Scorecard strip**: ten frames in a horizontal row, each showing marks and running
   total, the current frame highlighted. Tapping a finished frame enters edit mode on it.
3. **Pin deck**: ten pins in the triangle, large tap targets. Pins already down on this
   rack are dimmed and disabled. Tapping toggles a pin between standing and fallen.
   Default on each roll is all available pins standing, so the bowler taps what fell. A
   setting flips this so the bowler taps what is left standing, which many prefer for
   spares.
4. **Shortcuts**: Strike, Spare (fills all remaining), Miss (zero), Undo, and the ball
   chip showing the current ball with a tap to override for this roll.
5. **Next**: records the pins currently marked as fallen and advances to the next roll.
   Strike, Spare, and Miss record and advance immediately without needing "Next". A
   setting makes a tapped pin deck auto-advance when the marked count makes a spare.

Count mode replaces the pin deck with a 0 through 10 numeric pad limited to pins
available. The user can switch a game from count to pin mode before any roll is entered.

Tenth frame shows a third roll box only when earned. Finishing frame 10 for the last
bowler shows a game summary sheet: score, strikes, spares, opens, leaves, with "Next game"
and "End session". "Next game" creates game `orderInSession + 1` for every bowler with the
same default balls.

Scoring must work with the phone in one hand. Pin targets are at least 48 points and the
deck fills the width of the screen.

### History

Sessions grouped by month, each row showing date, event type, center, bowler count, and
scores. Session detail shows its games as scorecards per bowler with the series total,
and allows editing session metadata. Game detail shows the full scorecard, the leaves in
each frame with split indicators, the balls used, and an Edit button that opens Scoring
on that game. Swipe to delete with confirmation at both levels.

### Stats

Filter bar at the top, always visible, showing active filters as chips with a sheet to
edit them. Sections, each with its sample size:

1. Overview tiles.
2. Trend chart.
3. Strikes and spares: strike %, spare %, open %, clean game %, first-ball average, head
   pin rate.
4. Leaves: the leaves table and the "left most, made least" callout. Split and makeable
   and single-pin conversion. Tap a leave for the occurrence list.
5. By frame: a bar chart of strike rate and a bar chart of mean pins per frame.
6. What if: real average beside the single-pin what-if average.

Sections that do not apply to the current filter's games show a short explanation, for
example "Enter pins to see leaves".

### Arsenal

**List.** Active balls, then a collapsed "Retired" group. Each row shows the photo or a
colored placeholder, name, brand, weight, intended role, games bowled, and a "Resurface
due" badge when applicable. A toolbar button opens **Compare**, a sortable table built
from the comparison rows in section 6 with a column picker for small screens. Another
opens the add form.

**Ball detail.** Sections top to bottom:

1. **Header**: photo, name, brand, weight, coverstock and core type, intended role,
   current surface, serial number, and an Edit button.
2. **Specs**: coverstock name, core name, RG, differential, intermediate differential,
   factory finish, release date, purchase date, color, notes.
   Empty optional values are hidden rather than shown as blanks.
3. **Maintenance**: games since last resurface against the interval with a progress bar,
   the maintenance log newest first, and a "Log maintenance" button. Logging a resurface
   or polish with a grit value updates the ball's current surface.
4. **Performance**: the ball report from section 6. The strike-ball block leads when the
   intended role is strike, the spare-ball block leads when it is spare, both show
   regardless. A filter chip row at the top of this section mirrors the Stats filter so
   the user can narrow by date range, league, pattern, or center without leaving the ball.
5. **By condition**: two small tables, by pattern and by center.
6. **Over time**: the strike % chart with maintenance markers.
7. **Recent games**: the last ten games using this ball, linking into History.

Retire and delete live in the Edit form, with the warnings in the deletion rules.

**Add and edit form.** Fields from section 3 grouped as Identity (name, brand, weight,
color, serial, photo), Construction (coverstock, coverstock name, core type, core name, RG,
differential, intermediate differential, factory finish, release date), Use (intended
role, purchase date, current surface, resurface interval), and Notes. Only name and weight are required.

### Settings

Owner profile, pin entry default (tap fallen or tap standing), auto-advance on marks,
bowler rotation default, data management (delete all data with double confirmation),
about and version. A placeholder row for iCloud sync says "Coming soon" so phase 2 has a
home.

## 8. Error handling and edge cases

- Invalid roll input is impossible through the UI and rejected by the repository if it
  arrives any other way.
- An unfinished game is saved after every roll so nothing is lost if the app is killed.
  Home shows "Resume session" when an incomplete session exists.
- Editing an earlier frame rescoring: later rolls are re-validated. Any later roll that
  becomes invalid (for example a second roll that now exceeds the pins available) is
  cleared from that roll onward and the user is told which frames need re-entry.
- Changing a game from countOnly to pinByPin after rolls exist is refused; the user is
  offered to clear the game's rolls first.
- A session with no games is deleted automatically if the user backs out before any roll.
- Stats on zero games show empty-state copy, never NaN or division by zero.
- Dates use the device calendar and time zone; stats filters compare by calendar day.

## 9. Testing

- **BowlingCore**: Swift Testing with parameterized cases. Scorer: perfect game 300, all
  spares with 5 count 150, all gutters 0, all nines 90, alternating strikes and spares,
  every tenth-frame branch, pending running totals, each validation error. LeaveClassifier:
  every one-pin, two-pin, and three-pin combination with head pin down is asserted against
  a fixture table, plus the washouts and a sample of larger leaves. StatsEngine: a fixture
  set of about twenty games across the three entry modes with hand-computed expected
  values for every stat, including the what-if recomputation and the applicability rules.
  Ball report: a fixture where one ball is the default and another overrides on spare
  attempts, asserting that first balls and spare attempts are attributed to the right
  ball, that groups under 10 first balls fold into "Other", and that games since last
  resurface counts only games after the latest resurface event.
- **BowlingData**: in-memory `ModelContainer` tests for repositories, deletion rules,
  conversion to and from BowlingCore value types, filter predicates, and the owner-bowler
  invariant.
- **App target**: a UI test that creates a session, enters a full pin-by-pin game, and
  checks the final score on the summary sheet. Snapshot-free; assertions on accessibility
  identifiers.
- **Previews**: every screen has a preview backed by the demo fixture data.

## 10. Accessibility and localization

- Every pin is an accessibility element labeled "Pin 7, standing" or "Pin 7, down", and
  the deck exposes a summary like "6 pins standing: 4, 7, 8, 9, 10".
- Scorecard frames are labeled with frame number, marks, and running total.
- All text uses text styles so Dynamic Type works; the pin deck and scorecard adapt layout
  at accessibility sizes rather than truncating.
- All user-visible strings go through a String Catalog from the first commit.

## 11. Open decisions

None outstanding for this phase. The split classification table is the item most likely
to need adjustment after real-bowler testing, and the design isolates it for that reason.
