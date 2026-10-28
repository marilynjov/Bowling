# Phase 1 Design: Core Scoring and Stats, On Device

Date: 2026-10-08 (revises 2026-10-07)
Status: revised after review, pending written approval
Roadmap: `2026-10-08-program-roadmap.md`
Sub-phases: 1a (scoring engine and core stats) and 1b (analysis, arsenal, ball detail)

## 0. Changes from the 2026-10-07 version

1. Split into phase 1a and phase 1b, each with its own scope and done criteria (section 1).
   CSV export moves into 1b.
2. Matrix features are cited by name. The roadmap's Appendix A maps names to ranks.
3. Model rules for CloudKit made explicit: every relationship has an inverse and a
   declared delete rule, no Deny rules, enums stored as raw strings with an unknown
   fallback (section 3.1).
4. Photos move off Game and Ball into `GamePhoto` and `BallPhoto` with external storage.
5. OilPattern links to the phase 8 bundled library through `patternKey` instead of being
   filled by it.
6. Duplicate handling after sync is designed now (owner merge, named-entity merge) so
   phase 2 only implements it (section 3.4).
7. BowlingCore value types renamed `RollRecord` and `FrameRecord` so they never collide
   with the SwiftData models `Roll` and `Frame`.
8. Fouls are modeled (`Roll.isFoul`) and scored per the USBC rule.
9. Stats default to competition games; practice and casual are excluded unless the
   filter includes them.
10. League gains optional season start and end dates, which define "this season".
11. Entry mode rule made consistent: switching modes is allowed only before the first roll.
12. Resurface reminders use a local notification as well as the badge.
13. Ordering fields renamed to match the roadmap: `gameIndex`, `frameIndex`, `rollIndex`.
14. Stats shown depend on the bowler: first launch asks how the user bowls and picks a
    stats preset (1a); 1b adds a Customize screen to choose and order every stat on Stats
    and Home (section 7). Comes from stakeholder feedback that stats in competing apps
    are confusing.
15. Leaves are drawn as small pin diagrams everywhere they appear, not only as pin
    numbers (section 7).
16. Decisions from the app and package contract (`2026-10-14-app-package-contract.md`,
    issue #1): the pin deck defaults to tapping the pins left standing; bowlers keep
    their lineup order (`Game.lineupIndex`); the default stats scope is stored as
    `Bowler.statsScope`; the "left most, made least" callout needs a leave seen at least
    3 times; fixtures live in a `BowlingFixtures` library; "Delete all data" also
    deletes the owner.

## 1. Purpose and scope

Let any bowler record games on an iPhone, offline, at the level of detail they have time
for, and see every statistic that can be computed from what they entered. Everything in
this phase runs on the device with no account and no network.

Success looks like: a league bowler enters a three-game night during league, including
which pins fell on every ball, in less time than it takes to walk back from the ball
return; a casual bowler types one final score in ten seconds; both open Stats the next
day and see numbers that are correct.

### Phase 1a: scoring engine and core stats

Matrix features: frame-by-frame and pin-by-pin entry; final-score-only entry; offline
scoring; average, high game and series, strike and spare percentages; pin leaves and
spare conversion by leave; spare percentage over spare attempts only; makeable spares
versus splits; practice versus competition separation; ball and pattern tagging per
game.

- The complete schema from section 3, including every 1b and reserved field. The schema
  is not promoted to CloudKit production until phase 2, but it is designed once, here.
- Frame-by-frame, pin-by-pin entry with automatic frame advance and tenth-frame handling.
- Per-ball count entry and final-score-only entry.
- Fouls.
- Sessions tagged practice, league, tournament, or casual, with center, league, oil
  pattern, lanes, and notes. The oil pattern is recorded per session, so every game in a
  session shares it; a bowler who changes patterns starts a new session.
- Multiple bowlers in one session on one phone, as local names.
- A basic arsenal: add a ball with name, weight, and intended role; pick a default ball
  per game and override per roll.
- Stats screen cards: overview, trend, strikes and spares, leaves table with split,
  makeable, and single-pin conversion, shown from the preset for the bowler's style.
  Filters: date presets, event type, bowler.
- Leave diagrams: every leave drawn as a small pin deck.
- History with editing and deleting of games and sessions.
- Home, Settings, first-launch flow, including the bowling style question.

### Phase 1b: analysis, arsenal, and ball detail

Matrix features: tag and filter by ball, pattern, center, or league; personal arsenal
with maintenance dates; ball detail page; each missed spare linked to its date and ball;
custom date ranges; strike rate by frame number and average per frame; head pin rate and
clean game rate; "what if I made every single-pin spare" average; CSV export.

- Full ball add and edit form, ball photo, maintenance log, resurface reminders, ball
  detail screen with the ball report, Compare table, retire.
- Full filter set on Stats and on the ball detail screen: custom date range, ball, oil
  pattern, center, league.
- Leave occurrence list (tap a leave to see every occurrence with date and ball).
- By-frame section, head pin rate, clean game rate, first-ball average, open frame rate,
  what-if section.
- CSV export of games, frames, rolls, and tags from Settings.
- Customize screen for the cards on Stats and the tiles on Home.

### Out of scope for phase 1

iCloud sync (phase 2), share images and CSV import (phase 3), photo scan (phase 4),
handicap, standings and Baker (phase 5), practice tools (phase 6), anything with accounts
including sending a game to another bowler (phase 7), pattern and ball libraries (phase
8), monetization.

## 2. Architecture

Three layers, dependencies pointing downward only.

```
SwiftUI views and @Observable feature models        (app target, Features/)
        |
BowlingData: SwiftData models, repositories          (Packages/BowlingData)
        |
BowlingCore: value types, scoring, leaves, stats     (Packages/BowlingCore, pure Swift)
```

- **BowlingCore** has no dependency on SwiftData or SwiftUI. It defines the value types
  (`PinSet`, `RollRecord`, `FrameRecord`, `GameRecord`) and the three engines: `Scorer`,
  `LeaveClassifier`, `StatsEngine`. Every function is deterministic and unit tested. The
  `Record` suffix keeps these names distinct from the SwiftData models in files that
  import both packages.
- **BowlingData** defines the SwiftData `@Model` classes, the `ModelContainer` setup, and
  repositories that fetch models and convert them to BowlingCore value types for the
  engines. It seeds the demo store used by previews from the `BowlingFixtures`
  library, and owns the CSV codec (1b). `BowlingFixtures` lives in the BowlingCore
  package so BowlingCore's tests can use it too, since BowlingCore cannot depend on
  BowlingData.
- **App target** contains only views, feature models, and navigation. Feature models are
  `@Observable` classes that hold screen state, call repositories, and run engines. Views
  never touch `ModelContext` directly except through `@Query` for simple lists.

Why a package for the engines: they must be tested exhaustively, they must not depend on
persistence, and phases 4 and 5 reuse them for scan verification and Baker scoring.

## 3. Domain model

### 3.1 Rules every model follows

These come from the roadmap and must hold before phase 2 promotes the CloudKit schema.

- **Identity**: `id: UUID` generated on device. No unique constraints.
- **Defaults**: every attribute has a default value or is optional.
- **Relationships**: all optional, every one with an explicit inverse declared on one
  side with `@Relationship(inverse:)`, every one with a delete rule of Nullify or
  Cascade. The side that declares the inverse states its rule; the other side keeps
  SwiftData's default, Nullify. Never Deny; refusals happen in repositories (section 3.3).
- **Ordering**: CloudKit does not preserve relationship order. Order lives in
  `Game.lineupIndex` (bowlers within a session), `Game.gameIndex`, `Frame.frameIndex`,
  and `Roll.rollIndex`. Every fetch and every conversion to BowlingCore sorts by these
  fields; nothing relies on array order.
- **Enums**: stored as a raw `String` attribute with a computed Swift enum property.
  Unknown raw values decode to an `unknown` or default case instead of failing, so an
  older app version that receives a case added later keeps working. Raw strings also
  make SwiftData predicates simple.
- **Encryption**: personal fields use `@Attribute(.allowsCloudEncryption)`:
  `Bowler.email` and `BowlingCenter.latitude`/`longitude`. CloudKit only accepts
  encryption when a field is first created, so a new personal field is marked before it
  ships. Notes stay unencrypted.
- **Binary data**: never on a frequently synced entity. Photos live in `GamePhoto` and
  `BallPhoto`, with `@Attribute(.externalStorage)`, downscaled on save.
- **Reference data**: bundled libraries (phase 8) live in a separate, non-synced
  ModelConfiguration. User data references them by stable string key, never by
  relationship.
- **Timestamps**: `createdAt` and `updatedAt` on every entity, for CSV export, duplicate
  merging, and debugging sync.
- **Publishing**: `remoteID: String?` on every entity, unused until phase 5 or 7.
- **Additive only**: once phase 2 promotes the schema, attributes and entities are never
  renamed or removed.

### 3.2 Entities

Common fields `id`, `createdAt`, `updatedAt`, and `remoteID` are omitted from the tables
below but exist on every entity.

#### Bowler

| Field | Type | Notes |
|---|---|---|
| name | String | |
| isOwner | Bool | One owner per user. Enforced in the repository, with a merge rule after sync (section 3.4) |
| handedness | String raw: right, left, unknown | Default unknown |
| email | String? | Reserved for phase 7 game invitations. Not shown in phase 1. `@Attribute(.allowsCloudEncryption)` |
| statsProfile | String raw: casual, league, competitive, unknown | Owner only. Set at first launch, changeable in Settings. Default unknown, treated as casual |
| statsLayout | String | Owner only. Ordered card IDs for Stats, comma-separated. Empty means use the profile's preset (section 7) |
| homeLayout | String | Owner only. Ordered card IDs for Home's tiles. Empty means use the profile's preset |
| statsScope | String raw: competition, all, unknown | Owner only. The default stats scope chosen in Settings. Empty means follow the bowling style; unknown is treated as empty |
| mergedOwnerIDs | String | Owner only. Comma-separated, sorted UUIDs of the owners merged into this one (section 3.4) |
| games | [Game]? | Inverse of Game.bowler |

#### Session

| Field | Type | Notes |
|---|---|---|
| date | Date | Start of the outing |
| eventType | String raw: practice, league, tournament, casual | Default casual |
| center | BowlingCenter? | Inverse of BowlingCenter.sessions |
| league | League? | Only meaningful when eventType is league. Inverse of League.sessions |
| oilPattern | OilPattern? | Inverse of OilPattern.sessions |
| lanes | String | Free text, for example "17-18" |
| notes | String | |
| games | [Game]? | Inverse of Game.session. Sorted by Game.lineupIndex, then Game.gameIndex |

A session's series total is the sum of its games' final scores for one bowler.

#### Game

| Field | Type | Notes |
|---|---|---|
| session | Session? | |
| bowler | Bowler? | Set only through `Game.assign(_:)`, which also sets bowlerID |
| bowlerID | UUID? | Copy of bowler.id. Kept when the bowler is deleted (Nullify) or not imported yet, so phase 2 sync can tell those games from ones that never had a bowler (#89) |
| gameIndex | Int | 1-based order within the session for this bowler |
| lineupIndex | Int | Default 1. The bowler's position in the session lineup, set at Start and copied by Next game. Scoring rotates bowlers in this order |
| entryMode | String raw: pinByPin, countOnly, finalOnly | Fixed once the first roll exists (section 8) |
| defaultBall | Ball? | Inverse of Ball.gamesAsDefault |
| finalScore | Int | Cached. Computed by the Scorer for pinByPin and countOnly; typed by the user for finalOnly |
| isComplete | Bool | True when all ten frames are finished or when finalOnly |
| recordedRollCount | Int | Default 0. Rolls the game holds, written with them. On the Game row so sync can rank a copy whose rolls have not arrived (section 3.4) |
| frames | [Frame]? | Inverse of Frame.game. Zero frames when finalOnly |
| photo | GamePhoto? | Inverse of GamePhoto.game. Reserved for phase 4 |
| scanConfidence | Double? | Reserved for phase 4 |
| invitationStatus | String raw: none, sent, accepted, declined, expired | Default none. Reserved for phase 7 |
| scoredByName | String? | Reserved for phase 7. Set on the recipient's copy of an accepted invitation |

#### Frame

| Field | Type | Notes |
|---|---|---|
| game | Game? | |
| frameIndex | Int | 1 through 10 |
| rolls | [Roll]? | Inverse of Roll.frame. Sorted by Roll.rollIndex |
| rotationSlot | Int? | Reserved for Baker in phase 5 |

#### Roll

| Field | Type | Notes |
|---|---|---|
| frame | Frame? | |
| rollIndex | Int | 1 through 3 |
| pinsDownMask | Int | Ten-bit mask, bit n-1 is pin n. 0 for countOnly rolls and fouls |
| pinCount | Int | Pins credited on this roll. Always set; derived from the mask when pins are known; 0 on a foul |
| pinsKnown | Bool | True in pinByPin mode. False for countOnly and for phase 4 scanned games |
| isFoul | Bool | Default false. See section 4 |
| ball | Ball? | Override for this roll; nil means the game's default ball. Inverse of Ball.rollsAsOverride |

#### Ball

| Field | Type | Notes |
|---|---|---|
| name | String | Required |
| brand | String | |
| weightPounds | Int | 6 through 16. Required |
| coverstock | String raw: plastic, urethane, reactiveSolid, reactivePearl, reactiveHybrid, other, unknown | Default unknown |
| coverstockName | String | Manufacturer's coverstock name, for example "SPEC Solid" |
| coreType | String raw: symmetric, asymmetric, pancake, unknown | Pancake is the plastic spare-ball core |
| coreName | String | Manufacturer's core name |
| rg | Double? | Radius of gyration, typically 2.4 to 2.6 |
| differential | Double? | Typically 0.00 to 0.06 |
| intermediateDifferential | Double? | Asymmetric cores only. Also called mass bias differential |
| intendedRole | String raw: strike, spare, both | Default strike. Drives which stats lead on the detail screen and picker order |
| serialNumber | String | |
| colorDescription | String | Free text |
| releaseDate | Date? | Month precision |
| purchaseDate | Date? | |
| factoryFinish | String | Out-of-box surface, for example "2000 Abralon". Current surface starts from this on add |
| surfaceGrit | String | Current surface, for example "2000 polished" |
| resurfaceIntervalGames | Int? | Reminder threshold. Nil means no reminder |
| isRetired | Bool | Retired balls stay for history but are hidden from pickers |
| notes | String | Drilling layout and hand measurements go here until phase 8 adds fields |
| photo | BallPhoto? | Inverse of BallPhoto.ball |
| maintenance | [MaintenanceEvent]? | Inverse of MaintenanceEvent.ball |
| gamesAsDefault | [Game]? | Inverse of Game.defaultBall |
| rollsAsOverride | [Roll]? | Inverse of Roll.ball |

#### GamePhoto and BallPhoto

| Field | Type | Notes |
|---|---|---|
| imageData | Data | `@Attribute(.externalStorage)`. Downscaled on save |
| game / ball | Game? / Ball? | One-to-one with its owner |

BallPhoto is used in 1b. GamePhoto is created in phase 1 only by the schema; phase 4
writes it.

#### MaintenanceEvent

| Field | Type | Notes |
|---|---|---|
| ball | Ball? | |
| date | Date | |
| kind | String raw: resurface, polish, oilExtraction, plugAndRedrill, other | |
| surfaceGritAfter | String | Copied to Ball.surfaceGrit on save when non-empty |
| gamesOnBallAtTime | Int | Snapshot of games bowled when the event was logged |
| notes | String | |

Derived values, computed by the repository:

- **Games bowled**: count of games where defaultBall is this ball, plus games where any
  roll overrides to it, counted once per game.
- **Games since last resurface**: games bowled since the most recent event of kind
  resurface, or since purchase if none. The latest resurface always wins over the
  purchase date.
- **Resurface due**: `resurfaceIntervalGames` is set and games since last resurface meets
  or exceeds it.

#### BowlingCenter, League, OilPattern

Each has `name` and `notes`, and an inverse `sessions: [Session]?`.

- **BowlingCenter** adds optional `city`, `latitude`, `longitude` (phase 8 map; the
  coordinates are encrypted in CloudKit), and
  `leagues: [League]?` as the inverse of League.center.
- **League** adds `center: BowlingCenter?`, `seasonLabel: String`, `seasonStart: Date?`,
  `seasonEnd: Date?`, and `gamesPerSession: Int` default 3.
- **OilPattern** adds `lengthFeet: Int?`, `volumeMilliliters: Double?`, and
  `patternKey: String?`. In phase 8 the user can link a pattern they created to the
  bundled library by setting `patternKey`; the library data itself never enters the
  synced store.

### 3.3 Relationships and delete rules

| From | To | Inverse | Delete rule on "From" |
|---|---|---|---|
| Session.games | Game | Game.session | Cascade |
| Game.frames | Frame | Frame.game | Cascade |
| Frame.rolls | Roll | Roll.frame | Cascade |
| Game.photo | GamePhoto | GamePhoto.game | Cascade |
| Ball.photo | BallPhoto | BallPhoto.ball | Cascade |
| Ball.maintenance | MaintenanceEvent | MaintenanceEvent.ball | Cascade |
| Ball.gamesAsDefault | Game | Game.defaultBall | Nullify |
| Ball.rollsAsOverride | Roll | Roll.ball | Nullify |
| Bowler.games | Game | Game.bowler | Nullify |
| BowlingCenter.sessions | Session | Session.center | Nullify |
| BowlingCenter.leagues | League | League.center | Nullify |
| League.sessions | Session | Session.league | Nullify |
| OilPattern.sessions | Session | Session.oilPattern | Nullify |

Repository rules on top of the schema:

- Deleting a Bowler who has games is refused with an explanation; the user can delete
  the games first. The owner can never be deleted.
- Deleting a Ball that any game uses, as its default or on a roll override, is refused
  with the count of affected games and the app offers "retire instead". Nullifying would
  be wrong: a roll with no ball means the game's default ball, so an override's rolls
  would move to another ball.
- Deleting a Center, League, or Pattern warns with the count of affected sessions.

### 3.4 Duplicates after sync (designed now, implemented in phase 2)

Without unique constraints, iCloud sync can produce duplicates. Two cases are certain,
so the design handles them now:

- **Two owners.** A second device creates its own owner at first launch, then receives
  the first device's owner through sync. Rules:
  - First launch checks the iCloud account status. If an account is signed in, the
    first-launch flow offers "Restore from iCloud" and waits for the initial import
    before creating an owner.
  - After every remote import, the repository looks for more than one owner. It keeps
    the oldest by `createdAt` (ties broken by smaller UUID string), moves every game of
    the others to it, copies over any non-empty fields the kept owner lacks, and deletes
    the others. The rule is deterministic, so every device reaches the same result.
  - The kept owner adds the deleted owners' IDs, and the IDs they had absorbed, to
    `mergedOwnerIDs`. A device offline during the merge can still log a game for a
    merged owner; it syncs in with no bowler and that owner's `bowlerID`, and the next
    merge gives it to the kept owner. A game with no bowler whose `bowlerID` names
    neither an owner nor a merged owner is never claimed (see "Games with no bowler").
- **Games with no bowler.** CloudKit does not import relationships atomically, so a Game
  can arrive before its Bowler, or after another device deleted that Bowler. After every
  remote import the repository links each game with no bowler to the Bowler whose id
  equals `Game.bowlerID`, without stamping `updatedAt` or changing `lineupIndex`. The
  owner merge then claims only games with no bowler whose `bowlerID` is empty or names an
  owner or a merged owner. A game whose `bowlerID` names a missing bowler stays
  unassigned: it keeps that `bowlerID` in its record, stats, and CSV export, so it counts
  only for that bowler, which means in no one's stats while the bowler is missing. Phase
  2 shows it as "Unknown bowler" and lets the user assign it by hand. Waiting until the
  bowler is "confirmed missing" is not possible, because sync never signals that every
  record has arrived.
- **Same-name centers, leagues, and patterns** created on two devices. These are not
  merged automatically, because two centers can share a name. Settings gains a "Merge"
  action in phase 2 that moves all sessions from one record to another and deletes the
  empty one.
- **Duplicate frames or rolls.** If an unfinished game is resumed on two devices while
  offline, sync can deliver two Frame rows with the same `frameIndex`, or two Roll rows
  with the same `rollIndex` in one frame. After every remote import the repository keeps
  the row with the newest `updatedAt` per index (ties broken by smaller UUID string),
  deletes the others, and rescores the game. Repair runs before validation, so a synced
  game is never left unsaveable. If the kept rows do not form a valid game, rolls are
  cleared from the first one that no longer fits, even when later frames were really
  rolled, so every device ends with the same valid game.
- **Duplicate games.** If "Next game" runs on two devices while offline, sync can deliver
  two games in one session for the same bowler with the same `gameIndex`. The bowler is
  `Game.bowlerID` where set, otherwise `bowler.id`; games with neither are never treated
  as duplicates. After every remote import, before the frame and roll repair, the
  repository keeps the game with the highest `recordedRollCount`, then the newest
  `updatedAt`, then the smaller UUID string, and deletes the others with their frames and
  rolls. Only fields on the Game row decide, because CloudKit can deliver a Game row
  before its Frame and Roll rows. Rolls are never merged across games. The survivor is
  chosen per bowler, so one session can end up with bowler 1's game 2 from one device
  and bowler 2's game 2 from the other. A second run
  changes nothing, and every device reaches the same result once it holds the same Game
  rows. A game holding fewer rolls than its `recordedRollCount` is still importing: only
  its duplicate frame and roll rows are removed, and it is not cleared, rescored, or
  stamped, since a gap from rows still on the way would read as invalid. A frame that arrives after its game was deleted stays unlinked
  (`game == nil`); no repair deletes it, because a frame waiting for its Game row looks
  the same.
- **Repair order.** `BowlingStore.repairSyncedData()` runs every repair in this order:
  `repairDuplicates` (duplicate games, then duplicate frames and rolls), then the relink
  of games to their bowlers, then `mergeOwners`. The merge renumbers clashing `gameIndex`
  values when it moves a second owner's games, so if it ran first, duplicate games would
  no longer share an index and would never be found. The relink must also come before
  the merge, so a game whose bowler has arrived is linked, not judged an orphan. Each
  step is idempotent. The app calls it at launch and after each finished, successful
  CloudKit import event.
- **Before sync turns on.** Phase 2 must keep the repair from deleting a game that is
  open or recently written, close Scoring cleanly when its game is deleted, and give a
  game stuck with `recordedRollCount` above its real rows a way out of "importing". The
  app-package contract, section 3.2, has the details.

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
- **finalOnly**: no frames; the user types `finalScore` in 0 through 300.

The Scorer operates on `pinCount`, so it works identically for the first two modes.
`LeaveClassifier` and pin-level stats require `pinsKnown`.

### Frame rules, frames 1 through 9

- Roll 1: 0 through 10 pins. 10 is a strike; the frame is finished.
- Roll 2: 0 through (10 minus roll 1). A total of 10 is a spare. In pinByPin mode roll 2's
  `PinSet` must be a subset of the pins left standing after roll 1.

### Frame 10

- Roll 1 strike: roll 2 is on a fresh rack. If roll 2 is also a strike, roll 3 is on a
  fresh rack; otherwise roll 3 is limited to the pins roll 2 left standing.
- Roll 1 not a strike: roll 2 is limited to the pins left. If rolls 1 and 2 make a spare,
  roll 3 is on a fresh rack. Otherwise the frame ends after roll 2.
- Frame 10 pins total at most 30.

### Fouls

A foul delivery counts as a roll with `pinCount` 0 and `isFoul` true. Following USBC
rules, pins knocked down by a foul are respotted, so the rack after a foul is the same as
before it: after a first-ball foul the second ball faces all ten pins, and knocking them
all down is scored as a spare. A foul on a second ball scores 0 for that ball and ends
the frame as normal. The UI records a foul with the Foul shortcut, which needs no pin
input.

### Score computation

Frame score is the frame's pin count plus bonuses: a strike adds the next two rolls, a
spare adds the next one roll, in roll order across frames. Frame 10 has no bonus beyond
its own rolls. A frame's running total is nil until its bonus rolls exist, and the UI
shows a blank for pending frames as a lane monitor does. Final score is the tenth frame's
running total; maximum 300.

### Validation

`Scorer.validate(_ game: GameRecord) -> [ScoringError]` returns every violation: a roll
over the pins available, a roll 2 subset violation in pinByPin mode, frames or rolls out
of order or with duplicate indices, a frame 10 third roll that is not earned, a roll
after a strike in frames 1 through 9, a foul with a non-zero pin count. Repositories
refuse to save invalid games. The scoring UI prevents invalid input in the first place
by disabling pins that are already down.

### Marks for display

Per roll, `Mark` is one of `strike`, `spare`, `count(Int)`, `gutter` (zero on a roll where
pins were available), or `foul` (shown as F). Split leaves show the count with a split
indicator when pins are known.

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
     8-9, 9-10, plus the sleeper pairs 2-8 and 3-9, where one pin stands directly behind
     the other with no pin between them; or
   - a down pin stands directly in front of two standing pins, using the pairs 1 in front
     of 2 and 3, 2 of 4 and 5, 3 of 5 and 6, 4 of 7 and 8, 5 of 8 and 9, 6 of 9 and 10.

   Otherwise `makeable`.

The sleeper pairs keep the 2-8 and 3-9 makeable: the pins do not touch, but no pin is
down between them, so they are not splits under USBC's definition. The second clause
follows USBC's split definition, for example the 4-5 is a split when the 2 pin is down.
It also classifies the 7-8, 8-9, 9-10, and 2-3 as splits when the pin in front is down.
If real bowlers disagree with any case, the adjacency and in-front tables are the only
thing to edit, and the test suite pins every two-pin and three-pin combination.

A foul first ball leaves no leave, because the rack is respotted; its spare attempt is
counted against a full rack (section 6).

Names use ascending pin numbers joined by hyphens: "7-10", "4-7-10", "3-6-10".

## 6. Statistics (BowlingCore `StatsEngine`)

Input: `[GameRecord]` already filtered, plus the filter description for labeling. Output:
`StatsReport`, a value type with every number below and the sample size each number was
computed from. Every figure shows its denominator in the UI, for example "63% of 41
attempts", because bowlers distrust percentages without counts.

### Default scope: competition games

Practice games distorting averages is a recurring complaint about competing apps. The
default `StatsFilter` therefore includes event types league and tournament only, shown as
a "Competition" chip in the filter bar, but only when the selected bowler has at least
one complete league or tournament game. Otherwise the default is "All games", so a
bowler who only enters casual or practice games, including Quick score games (which are
casual), still sees their stats. One tap switches to "All games" or any custom
combination of practice, league, tournament, and casual. Home's tiles show the
competition average with the all-games average beneath it, or only the all-games
average when there are no competition games. The choice of default is set in Settings
and stored as `Bowler.statsScope` on the owner, so it syncs. While it is empty, the
bowling style decides: casual starts on "All games", league and competitive start on
"Competition". An explicit choice is never overwritten by a later style change.

### Which games count for what

| Stat group | finalOnly | countOnly | pinByPin |
|---|---|---|---|
| Average, high game, high series, trend | yes | yes | yes |
| Strike %, spare %, open %, clean game, by-frame stats, first-ball average | no | yes | yes |
| Leaves, split and makeable rates, head pin rate, missed-spare list, what-if | no | no | yes |

Only games with `isComplete` true count toward any stat. An unfinished game appears in
History and in "Resume session" but enters Stats only when its tenth frame is finished,
so a game paused at frame 5 never pulls the average down.

Each section of the Stats screen states how many games it is based on.

### Definitions (1a)

- **Average**: sum of final scores divided by games. Also shown for the last 10, 30, and
  all games in the filter.
- **High game**: maximum final score, with date and session.
- **High series**: for each session and bowler, sum of final scores. Reported per game
  count (three-game series, four-game series); the default display is the count matching
  the league's `gamesPerSession` when a league filter is set, otherwise three.
- **Trend**: average per session over time, charted, with a rolling average of the last
  nine games overlaid.
- **First balls**: every roll 1 in frames 1 through 9, roll 1 in frame 10, and any frame 10
  roll on a fresh rack. A game has 10 to 12 first balls.
- **Strike %**: strikes divided by first balls.
- **Spare attempts**: first balls that left pins standing (including a foul, which leaves
  all ten) and were followed by a second roll on the same rack.
- **Spare %**: spares divided by spare attempts. This is the only spare percentage shown.
- **Split %**: spare attempts classified split divided by spare attempts, including
  attempts after a first-ball foul, which have no leave. **Split conversion %**: splits
  converted divided by splits.
- **Makeable conversion %**: makeable and single-pin leaves converted divided by their
  count. **Single-pin conversion %** reported separately.
- **Leaves table**: for each distinct `Leave`, count, conversions, conversion rate, sorted
  by count, then by pin numbers. A "left most, made least" callout highlights the leave
  with the most misses among leaves seen at least 3 times, so a one-off leave never
  headlines. With no such leave there is no callout.
- **Fouls**: count per game, shown in the strikes and spares section when non-zero.

### Definitions (1b)

- **Open frame %**: frames with neither strike nor spare divided by frames.
- **Clean game %**: games with zero open frames divided by games.
- **Head pin rate**: first balls where pin 1 fell divided by first balls, excluding fouls.
- **First-ball average**: mean pin count on first balls.
- **Leave occurrences**: tapping a leave lists every occurrence with date, session, frame
  number, and the ball used on the spare attempt.
- **By frame number**: for frames 1 through 10, strike rate on roll 1 and mean pins in the
  frame excluding bonuses.
- **What if I made every single-pin spare**: for each pinByPin game, rewrite every missed
  single-pin leave as a converted spare, rescore with `Scorer`, and report the resulting
  average next to the real one with the difference.
- **Ball stats**: when a ball filter is set, all of the above for games or rolls using
  that ball.

### Ball report (1b)

`StatsEngine.ballReport(for ball: BallID, games: [GameRecord]) -> BallReport` powers the
ball detail screen. Every roll resolves its ball as the roll override if present,
otherwise the game's default ball, so the report is exact even when a bowler switches
balls mid-game.

- **Usage**: games bowled, first balls thrown, spare attempts thrown, first and last date
  used, games since last resurface, resurface due flag.
- **As a strike ball**, over first balls thrown with it: strike %, first-ball average,
  head pin rate, and the average of games where it was the default ball, labeled "games
  with this ball as main ball".
- **As a spare ball**, over spare attempts thrown with it: spare conversion %,
  single-pin conversion %, split conversion %, and the leaves table restricted to those
  attempts, with the same tap-through to occurrences.
- **By condition**: strike % and first-ball average grouped by oil pattern, and
  separately by center. A group displays only when it has at least 10 first balls;
  smaller groups are summed into "Other".
- **Over time**: strike % per session since purchase, charted, with maintenance events
  drawn as markers on the date axis.
- **Comparison**: `StatsEngine.compareBalls(games:) -> [BallComparisonRow]` returns, for
  every non-retired ball, games bowled, average as main ball, strike %, first-ball
  average, and spare conversion %, each with its sample size.

The ball report honors the stats filter, so a bowler can ask "this ball, this league,
this season".

### Filters

`StatsFilter` has date range, event types, bowler, ball, oil pattern, center, league.

- 1a: date presets (this week, this month, last 30 days, this season, all time), event
  types, bowler.
- 1b: custom start and end dates, ball, oil pattern, center, league.

"This season" uses the selected league's `seasonStart` and `seasonEnd` when a league
filter is set and both dates exist; otherwise the last 9 months. The repository applies
filters as SwiftData predicates where possible and the rest in memory. The ball filter
matches a game if its default ball or any roll override is the ball.

## 7. Screens

Root is a `TabView` with Home, History, Stats, Arsenal. Settings is reachable from Home's
toolbar. On iOS 26 and later the tab bar is Liquid Glass automatically. Custom components
use `glassEffect` behind an availability check and a thin material otherwise.

### Home (1a)

- Headline tiles from the bowler's Home layout (section 7, Stats cards), each with sample
  size. The league and competitive presets show competition average with all-games
  average beneath, high game, high series, strike %, spare %. The casual preset shows
  average, high game, and strike %.
- Large "Start session" button, and "Quick score" for a final-score-only game, saved as a
  casual session dated now. The event type can be changed afterward in History.
- "Resume session" when an incomplete session exists.
- Recent sessions list, three rows, linking into History.
- First launch: if an iCloud account is signed in, offer "Restore from iCloud" (active
  from phase 2; in phase 1 it is hidden). Otherwise ask for the owner's name and
  handedness, then the bowling style question, then show a short explanation of the
  three entry modes.
- Bowling style question: "How do you bowl?" with Casually, In a league, and
  Competitively, each with one line describing it. Above the options: "This decides
  which stats you see. You can change it anytime in Settings." From 1b it adds: "or pick
  exactly the stats you want." The answer sets `statsProfile` and the default stats
  scope.

### New session (1a)

A form: date defaults to now, event type segmented control, center picker with inline
create, league picker shown only for league type, oil pattern picker with inline create,
lanes text field, bowlers in lineup order (owner preselected, add others by name, drag
to reorder), default ball per bowler, entry mode default pinByPin. "Start" creates the
session and the first game for each bowler and opens Scoring. The last-used center, league, pattern, and ball are
remembered per event type in UserDefaults, not in the synced store.

### Scoring (1a)

The core screen. Layout top to bottom:

1. **Bowler strip** when the session has more than one bowler, showing each name and
   current score. The app rotates to the next bowler after each frame like a lane
   console; a toolbar toggle turns rotation off so one bowler can finish alone.
2. **Scorecard strip**: ten frames in a horizontal row, each showing marks and running
   total, the current frame highlighted. Tapping a finished frame enters edit mode on it.
3. **Pin deck**: ten pins in the triangle. Pins already down on this rack are dimmed and
   disabled. Tapping toggles a pin between standing and fallen. By default the bowler
   taps the pins left standing after the roll, and untapped pins count as fallen;
   stakeholder feedback named marking the pins left as the most important part of
   entry. A setting flips this so the bowler taps what fell. Strike, Spare, Miss, and
   Foul work the same in both.
4. **Shortcuts**: Strike, Spare (fills all remaining), Miss (zero), Foul, Undo, and the
   ball chip showing the current ball with a tap to override for this roll.
5. **Next**: records the pins currently marked as fallen and advances. Strike, Spare,
   Miss, and Foul record and advance immediately. A setting makes the deck auto-advance
   when the marked count makes a spare.

Count mode replaces the pin deck with a 0 through 10 numeric pad limited to pins
available, plus the Foul shortcut.

Tenth frame shows a third roll box only when earned. Finishing frame 10 for the last
bowler shows a game summary sheet: score, strikes, spares, opens, leaves as pin diagrams,
with "Next game"
and "End session". "Next game" creates game `gameIndex + 1` for every bowler with the same
default balls.

Scoring must work with the phone in one hand. Pin targets are at least 48 points and the
deck fills the width of the screen.

### History (1a)

Sessions grouped by month, each row showing date, event type, center, bowler count, and
scores. Session detail shows its games as scorecards per bowler with the series total and
allows editing session metadata. Game detail shows the full scorecard, the leave in each
frame as a pin diagram with split indicator, the balls used, and an Edit button that
opens Scoring on that game. Swipe to delete with confirmation at both levels.

### Stats

Filter bar at the top, always visible, showing active filters as chips (default from the
bowling style) with a sheet to edit them. Below it, a vertical list of cards, each with
its sample size.

**Card catalog.** Every card has a stable string ID, grouped for the Customize screen:

| Group | Cards (ID) | Phase |
|---|---|---|
| Overview | `average`, `highGame`, `highSeries` | 1a |
| Trend | `trendChart` | 1a |
| Strikes and spares | `strikePct`, `sparePct`, `fouls` | 1a |
| Strikes and spares | `openPct`, `cleanGamePct`, `firstBallAverage`, `headPinRate` | 1b |
| Leaves | `leavesTable`, `leftMostMadeLeast`, `splitConversion`, `makeableConversion`, `singlePinConversion` | 1a |
| By frame | `byFrameStrike`, `byFrameAverage` | 1b |
| What if | `whatIfSinglePins` | 1b |

Tapping a leave in `leavesTable` opens the occurrence list (1b).

**Presets** by `statsProfile`, in display order. Cards from a later sub-phase appear in
the preset when that sub-phase ships.

| Profile | Stats cards | Home tiles |
|---|---|---|
| casual | `average`, `highGame`, `trendChart`, `strikePct`, `sparePct` | `average`, `highGame`, `strikePct` |
| league | casual's cards plus `highSeries`, `leavesTable`, `leftMostMadeLeast`, `singlePinConversion`, `openPct` | `average`, `highGame`, `highSeries`, `strikePct`, `sparePct` |
| competitive | every card | `average`, `highGame`, `highSeries`, `strikePct`, `sparePct` |

**Customize (1b).** A toolbar button on Stats and an edit button on Home open the same
screen: the cards in the current layout, reorderable and removable, and below them every
other card by group, each with a one-line description, to add. "Reset to preset" clears
the saved layout. Saving writes `statsLayout` or `homeLayout` on the owner. Changing the
bowling style later asks whether to replace a customized layout with the new preset.

**Layout rules.** Unknown card IDs in a saved layout (from a newer app version) are
skipped when displaying and kept when saving. A card that does not apply to the current
filter's games shows a short explanation, for example "Enter pins to see leaves",
instead of disappearing, so the layout never jumps around.

**Leave diagrams.** Every leave on Stats, in the occurrence list, in game detail, and on
the game summary sheet is drawn with `LeaveDiagramView`, a small pin deck with standing
pins filled and down pins outlined, a split marker when the leave is a split, and the
pin numbers as a caption, for example "3-6-10". Bowlers recognize a leave by its shape
faster than by its numbers.

### Arsenal

**1a: basic list and add.** Active balls with name, weight, intended role, and games
bowled. Add form with name, weight, intended role, and brand only. This is enough for the
per-roll ball picker and ball tagging.

**1b: full arsenal.**

- **List.** Active balls, then a collapsed "Retired" group. Each row shows the photo or a
  colored placeholder, name, brand, weight, intended role, games bowled, and a "Resurface
  due" badge. A toolbar button opens **Compare**, a sortable table built from the
  comparison rows, with a column picker for small screens.
- **Ball detail.** Sections top to bottom:
  1. Header: photo, name, brand, weight, coverstock and core type, intended role, current
     surface, serial number, Edit button.
  2. Specs: coverstock name, core name, RG, differential, intermediate differential,
     factory finish, release date, purchase date, color, notes. Empty optional values
     are hidden.
  3. Maintenance: games since last resurface against the interval with a progress bar,
     the maintenance log newest first, and a "Log maintenance" button. Logging a
     resurface or polish with a grit value updates the ball's current surface.
  4. Performance: the ball report. The strike-ball block leads when the intended role is
     strike, the spare-ball block leads when it is spare; both show regardless. A filter
     chip row mirrors the Stats filter.
  5. By condition: two small tables, by pattern and by center.
  6. Over time: the strike % chart with maintenance markers.
  7. Recent games: the last ten games using this ball, linking into History.
- **Add and edit form.** Identity (name, brand, weight, color, serial, photo),
  Construction (coverstock, coverstock name, core type, core name, RG, differential,
  intermediate differential, factory finish, release date), Use (intended role, purchase
  date, current surface, resurface interval), Notes. Only name and weight are required.
  Retire and delete live here, with the warnings from section 3.3.
- **Resurface reminder.** When a saved game pushes a ball to or past its interval, the
  badge appears and a local notification is scheduled for 9:00 the next morning, when
  the bowler is away from the lanes and can plan the resurface. The app asks for
  notification permission the first time the user sets a resurface interval, not at
  launch.

### Settings

- 1a: owner profile, bowling style, pin entry default (tap standing, the default, or tap
  fallen),
  auto-advance on marks, bowler rotation default, default stats scope (competition or all
  games), delete all data with double confirmation, about and version, and a placeholder
  row for iCloud sync that says "Coming soon". Delete all data removes everything,
  including the owner, and returns to first launch. From phase 2 the confirmation says
  it also deletes the data on the user's other devices.
- 1b: "Export CSV" under data management, writing one file per entity type (sessions,
  games, frames, rolls, balls, maintenance) zipped, through the system file exporter.
  Zipping uses `NSFileCoordinator` with the `.forUploading` reading option on the
  export folder, which produces a zip with no third-party dependency.
  Stable column names and the entity UUIDs are included so phase 3 can re-import the
  export without duplicates.

## 8. Error handling and edge cases

- Invalid roll input is impossible through the UI and rejected by the repository if it
  arrives any other way.
- An unfinished game is saved after every roll, so nothing is lost if the app is killed.
- Editing an earlier frame re-validates later rolls. Any later roll that becomes invalid
  is cleared from that roll onward, and the user is told which frames need re-entry.
- Entry mode can be changed only before the game's first roll. After that, changing mode
  is refused and the user is offered to clear the game's rolls first. There is no
  automatic upgrade from countOnly to pinByPin. A finalOnly game with a typed score can
  switch mode, but the app asks the user to confirm discarding the score first.
- A session with no games is deleted automatically if the user backs out before any roll.
- Stats on zero games show empty-state copy, never NaN or division by zero.
- Dates use the device calendar and time zone; stats filters compare by calendar day.
- Unknown raw enum values from a newer app version display as "Other" and are preserved
  unchanged on save.

## 9. Testing

### Phase 1a

- **Scorer**: Swift Testing with parameterized cases. Perfect game 300, all spares with
  5 count 150, all gutters 0, all nines 90, alternating strikes and spares, every
  tenth-frame branch, pending running totals, each validation error. Fouls: first-ball
  foul followed by a full-rack spare, second-ball foul, foul in each tenth-frame
  position.
- **LeaveClassifier**: every one-pin, two-pin, and three-pin combination with the head
  pin down (129 cases) asserted against a fixture table, plus the washouts and a sample
  of larger leaves.
- **Sleeper spares**: the 2-8 and 3-9 classify as makeable, and the 2-7 and 3-10 as
  splits, asserted explicitly in addition to the combination table.
- **StatsEngine (1a stats)**: a fixture set of about twenty games across the three entry
  modes, with fouls and all event types, with hand-computed expected values, including
  the competition default scope, the fallback to all games when there are no
  competition games, exclusion of incomplete games, and the applicability rules.
- **BowlingData**: in-memory `ModelContainer` tests for repositories, delete rules,
  repository refusals, conversion to and from BowlingCore value types, filter
  predicates, the owner invariant, and unknown enum values round-tripping.
- **Stats presets**: each `statsProfile`, including unknown, maps to its preset; casual
  starts on "All games" and league and competitive on "Competition".
- **Ordering**: a test that inserts frames and rolls in shuffled order and asserts that
  conversion to `GameRecord` and the computed score are unchanged.
- **App target**: a UI test that creates a session, enters a full pin-by-pin game, and
  checks the final score on the summary sheet. Assertions on accessibility identifiers.
- **Previews**: every 1a screen has a preview backed by the demo fixture data.

### Phase 1b

- **StatsEngine (1b stats)**: extend the fixture set with hand-computed values for
  every 1b definition, including the what-if recomputation.
- **Ball report**: a fixture where one ball is the default and another overrides on
  spare attempts, asserting correct attribution of first balls and spare attempts, that
  groups under 10 first balls fold into "Other", and that games since last resurface
  counts only games after the latest resurface event.
- **CSV export**: export the fixture set and assert stable columns, row counts, and
  UUIDs.
- **Owner merge rule**: a BowlingData test that creates two owners with games on each
  and asserts the deterministic merge result, so phase 2 only wires it to remote import.
- **Duplicate frame repair**: a BowlingData test that inserts two frames with the same
  `frameIndex` and two rolls with the same `rollIndex`, and asserts that repair keeps
  the newest of each and the game validates and scores.
- **Stats layout**: a saved layout round-trips; reset returns to the preset; unknown
  card IDs are skipped on display and preserved on save.
- **Previews**: every 1b screen.

## 10. Accessibility and localization

- Every pin is an accessibility element labeled "Pin 7, standing" or "Pin 7, down", and
  the deck exposes a summary like "6 pins standing: 4, 7, 8, 9, 10".
- Scorecard frames are labeled with frame number, marks, and running total; a foul reads
  as "foul".
- A leave diagram is one accessibility element reading its pins and kind, for example
  "Leave 3, 6, 10, makeable" or "Leave 7, 10, split".
- All text uses text styles so Dynamic Type works; the pin deck and scorecard adapt
  layout at accessibility sizes rather than truncating.
- All user-visible strings go through a String Catalog from the first commit.

## 11. Done criteria

### Phase 1a is done when

- A perfect game, an all-spares game, games with fouls, and every tenth-frame variant
  score correctly in tests.
- Every 1a stat renders from fixture data, with the competition default applied, and each
  bowling style shows its preset.
- A full three-game league night for two bowlers can be entered offline, pin by pin.
- Real bowlers on TestFlight have used the pin deck for at least one league night and
  their feedback has been addressed. The pin deck is the make-or-break interaction.

### Phase 1b is done when

- Every stat in section 6 renders from fixture data under any combination of filters.
- The ball detail screen shows correct strike-ball and spare-ball attribution for the
  mixed-ball fixture.
- A resurface reminder fires when a game crosses a ball's interval.
- An exported CSV opens correctly in Numbers and Excel and contains every entity's UUID.
- The owner merge rule and the duplicate frame repair pass their tests.
- A customized Stats and Home layout survives an app relaunch and a reset to preset.
- The schema has been reviewed against every rule in section 3.1, because phase 2 locks
  it.

## 12. Open decisions

- **Split table.** The classification tables are the item most likely to need adjustment
  after real-bowler testing; the design isolates them for that reason.
- **Casual games.** Casual is excluded from the competition default alongside practice.
  If testers treat casual as competition, change the default; nothing else depends on it.
- **Stat explanations.** An info button on every card explaining the stat in one plain
  sentence with the bowler's own numbers, for example "Spare %: of the 41 times you had
  pins left after your first ball, you knocked them all down 26 times." Candidate for
  1b; decide after TestFlight feedback on the presets.
- **Preset contents.** The card lists per bowling style are a first guess. Adjust them
  from TestFlight feedback; only the preset table changes.
