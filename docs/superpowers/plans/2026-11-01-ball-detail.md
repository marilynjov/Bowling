# Ball Detail Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a ball in Arsenal opens its page. The page has the header, specs, read-only maintenance, performance by role under the Stats filter, results by condition, a strike % chart with maintenance markers, and recent games.

**Architecture:**
- `BallDetailData` is a value type of display text. A pure builder makes it from `BallFields`, a `BallReport` and `[GameRecord]`, and a thin `load` reads those from the store.
- `BallDetailScreen` renders the data, and Arsenal pushes it through an `ArsenalRoute`.
- Shared Stats helpers are made reusable rather than copied: `StatTileContent.rate/mean` and the leave row mapping.

**Tech Stack:** SwiftUI iOS 18, Swift 6, Swift Charts, Swift Testing, BowlingFixtures (`MixedBallFixture`).

**Spec:** `docs/superpowers/specs/2026-11-01-ball-detail-design.md`

## Global Constraints

- **Packages:** never edit `Packages/`. Use contract §2.9 as is:
  - `StatsEngine.ballReport(for:games:maintenance:)`
  - `BallRepository.maintenance(for:)`
  - `StatsRepository.games(matching:now:calendar:)`
  - `GameRecord.uses(_:)`
- **Copy, exactly:**
  - "As a strike ball", "As a spare ball"
  - "No games with this ball in this filter."
  - "N of M games since resurface", "N games since resurface", "Never resurfaced · N games"
  - "No maintenance logged."
  - "Not enough sessions yet."
  - "Other"
  - "Strike ball", "Spare ball", "Strike and spare"
  - "Surface: …", "Serial …"
  - "Retired"
  - "By pattern", "By center", "Over time", "Recent games"
  - "Strike rate over N sessions, latest X%."
- **The ball's games are the owner's.** `load` uses the Stats filter's dates and event types with `bowlerID` set to the owner, and the chips show the owner's name. A friend in the Stats filter would otherwise empty every ball's page. This is a ruling against the spec's "follows the Stats filter"; ledger it.
- **Fixed copy goes through `String(localized:)`.** Counted strings get plural handling only through the catalog later (#14), so the code uses the plain `"\(n) …"` forms.
- **No Co-Authored-By trailer** in commits.
- **Unit tests:** `xcodebuild test -scheme Bowling -destination 'id=2C568C51-3721-4FB2-90EE-D54EB3308C03' -parallel-testing-enabled NO -only-testing:BowlingTests/<Suite>`.
  - A single Swift Testing test needs its trailing `()`.
  - Run full-suite runs in the background.
  - Kill a hung xcodebuild by PID.
  - On "Failed to create a bundle instance", rerun.

## Review Focus

1. **A ball with games, but none in the current filter**, for example a practice-only ball under "Competition". Performance reads "No games with this ball in this filter.", while Maintenance still counts every game. Test: `noGamesInFilterKeepsMaintenance` (Task 3).
2. **A ball past its interval.** It reads "70 of 60 games since resurface", with the progress clamped to 1 and the badge shown. Test: `pastIntervalClampsProgress` (Task 1).
3. **A maintenance event dated before the first charted session** gets no marker outside the chart's range. Test: `markersStayInsideTheChart` (Task 2).
4. **One session only** shows "Not enough sessions yet." and no chart. Test: `oneSessionIsNotEnough` (Task 2).
5. **The Stats filter set to a friend** still shows the owner's games for the ball. Test: `friendFilterStillShowsOwnersGames` (Task 3).

---

### Task 1: BallDetailData — header, specs, maintenance

**Files:**
- Create: `Bowling/Features/Arsenal/BallDetailData.swift`
- Test: `BowlingTests/Arsenal/BallDetailDataTests.swift`. The test imports `BowlingFixtures`. If the test target can't import it, add the package product to the BowlingTests target's Frameworks phase in `project.pbxproj` and ledger the ruling.

**Interfaces:**
- Produces:

```swift
struct BallDetailData: Hashable {
    struct Header: Hashable { var name, subtitle: String; var construction, role, surface, serial: String?; var isRetired: Bool }
    struct SpecRow: Hashable { var label, value: String }
    struct LogRow: Hashable { var title, date: String; var detail: String? }   // detail: "grit · notes", either part optional
    struct Maintenance: Hashable { var summary: String; var progress: Double?; var isDue: Bool; var log: [LogRow] }
    var header: Header
    var specs: [SpecRow]                 // empty → section hidden
    var maintenance: Maintenance
    // Task 2 adds: performance, leaves, byPattern, byCenter, trend, recent, chips
    init(fields: BallFields, isRetired: Bool, report: BallReport, recentGames: [GameRecord],
         filterChips: [String], centerNames: [CenterID: String], patternNames: [OilPatternID: String],
         calendar: Calendar = .current)
}
```

`Header.subtitle` is "Storm · 15 lb", with the brand left out when blank. `construction` is the coverstock and core titles from `BallForm.title(for:)`, joined with " · ", leaving out unset parts, and nil when both are unset. `role` is nil for `.unknown`.

- [ ] **Step 1: Write the failing tests.** A helper `report(maintenance:)` builds a `BallReport` with `StatsEngine.ballReport(for:games: [], maintenance:)`.

```swift
@Test func headerLeavesOutUnsetParts()  // BallFields(name:"Phaze", weightPounds:15) → subtitle "15 lb", construction/surface/serial nil, role "Strike ball"
@Test func headerShowsEveryPart()       // brand Storm, .reactiveSolid/.asymmetric, surface "2000 Abralon", serial "SN123", retired →
                                        // "Storm · 15 lb", "Reactive solid · Asymmetric", "Surface: 2000 Abralon", "Serial SN123", isRetired
@Test func roleTitles()                 // .spare "Spare ball", .both "Strike and spare", .unknown nil
@Test func specsHideEmptyValues()       // only coreName "Velocity" and rg 2.48 → [("Core name","Velocity"), ("RG","2.48")]
@Test func specsOrder()                 // fully filled ball → labels in spec §3.2 order; release date shows month and year only
@Test func maintenanceWithInterval()    // interval 60, 18 since → "18 of 60 games since resurface", progress 0.3, !isDue
@Test func pastIntervalClampsProgress() // interval 60, 70 since → "70 of 60 games since resurface", progress 1, isDue
@Test func maintenanceWithoutInterval() // resurface logged → "18 games since resurface", progress nil; none logged → "Never resurfaced · 18 games"
@Test func logNewestFirstWithTitles()   // events resurface (grit "2000 Abralon") then polish (notes "Shine") → titles ["Polish","Resurface"]; details ["Shine","2000 Abralon"]; empty log → []
```

Build `BallMaintenance` with its public init over `GameRecord`s from a small local helper (`n` complete games dated after the resurface).

- [ ] **Step 2: Run.** Expected: FAIL, because `BallDetailData` doesn't exist yet.
- [ ] **Step 3: Implement** the header, specs and maintenance.
  - Kind titles: Resurface, Polish, Oil extraction, Plug and redrill, Other. `.unknown` reads "Other".
  - Dates use `.dateTime.month(.abbreviated).day().year()` in `calendar`. The release date uses `.month(.wide).year()`.
  - Numbers use `.number.precision(.fractionLength(0...3))`.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: BallDetailData header, specs and maintenance (#30)`.

### Task 2: BallDetailData — performance, conditions, trend, recent rows

**Files:**
- Modify:
  - `Bowling/Features/Arsenal/BallDetailData.swift`
  - `Bowling/Components/StatTileContent.swift`: `rate` and `mean` become internal.
  - `Bowling/Features/Stats/StatsCards.swift`: `row(_:)` moves to `extension LeaveRowContent { init(_ row: LeaveRow) }`.
  - `Bowling/Components/StatFormat.swift`: `Unit.spareAttempts` reads "No spare attempts yet", "1 spare attempt" or "N spare attempts".
- Test: `BowlingTests/Arsenal/BallDetailDataTests.swift`, plus `StatFormatTests` for the new unit.

**Interfaces:**
- Consumes: Task 1's init.
- Produces, on `BallDetailData`:

```swift
struct PerformanceBlock: Hashable { var title: String; var tiles: [StatTileContent]; var sample: String }
struct ConditionRowText: Hashable { var name, strikes, firstBallAverage: String }
struct TrendPoint: Hashable { var date: Date; var percent: Double }
struct Marker: Hashable { var date: Date; var isResurface: Bool }
struct Trend: Hashable { var points: [TrendPoint]; var markers: [Marker]; var accessibilityLabel: String }
struct RecentGame: Hashable, Identifiable { var id: GameID; var date, score, eventType: String }
var chips: [String]
var performance: [PerformanceBlock]      // [] when report.gamesBowled == 0
var leaves: [LeaveRowContent]
var byPattern: [ConditionRowText]; var byCenter: [ConditionRowText]
var trend: Trend?                        // nil when fewer than 2 points
var recent: [RecentGame]                 // recentGames mapped in the order given
```

**Tiles:**
- Strike block:
  - `rate("Strikes", strikes, .firstBalls)`
  - `mean("First ball average", firstBallAverage, .firstBalls)`
  - `rate("Head pin", headPin, .firstBalls)`
  - `mean("Average as main ball", averageAsMainBall, .games)`
  - sample: `StatFormat.sample(firstBalls, .firstBalls)`
- Spare block:
  - `rate("Spares", spares, .spareAttempts)`
  - `rate("Single pins", singlePinConversion, .spareAttempts)`
  - `rate("Splits", splitConversion, .spareAttempts)`
  - sample: `StatFormat.sample(spareAttempts, .spareAttempts)`

**Markers:** only events with `points.first!.date <= date <= points.last!.date`.

- [ ] **Step 1: Write the failing tests.** `now` is fixed, and the strike and spare balls are `DemoBall.ownerStrike.id` / `.ownerSpare.id`.

```swift
@Test func mixedBallStrikeBlock()   // MixedBallFixture games + strikeBallMaintenance, interval 4 → strike ball report;
                                    // performance[0].title "As a strike ball"; tiles[0].value == StatFormat.percent(report.strikes);
                                    // sample == "\(report.firstBalls) first balls"; report.firstBalls > 0
@Test func mixedBallSpareBlock()    // spare ball report, role .spare → performance[0].title "As a spare ball";
                                    // sample == "\(report.spareAttempts) spare attempts"; report.spareAttempts > 0;
                                    // tiles[0].value == StatFormat.percent(report.spares)
@Test func blockOrderFollowsRole()  // .strike and .both → strike first; .spare → spare first; always 2 blocks with games
@Test func noGamesHasNoBlocks()     // games [] → performance == [], chips still set
@Test func conditionNames()         // names resolved; nil id and an id missing from names → "Other"; report order kept
@Test func markersStayInsideTheChart() // event before the first point → not in markers; resurface inside → isResurface true; polish → false
@Test func oneSessionIsNotEnough()  // one trend point → trend nil
@Test func trendAccessibility()     // "Strike rate over N sessions, latest X%." with X from StatFormat.percent of the last point
@Test func recentRowsText()         // a 213 league game → score "213", eventType EventType.league.title, date formatted
```

Also add `StatFormatTests.spareAttemptsSample`: 0 gives "No spare attempts yet", 1 gives "1 spare attempt", 3 gives "3 spare attempts".

- [ ] **Step 2: Run** BallDetailDataTests and StatFormatTests. Expected: FAIL.
- [ ] **Step 3: Implement.** Move the shared helpers first, so StatsCards behaves the same.
- [ ] **Step 4: Run** BallDetailDataTests, StatFormatTests and StatsCardsTests (or whichever suites cover `StatsCards`). Expected: PASS, with the existing Stats tests unchanged.
- [ ] **Step 5: Commit** `feat: BallDetailData performance, conditions, trend and recent games (#30)`.

### Task 3: BallDetailData.load

**Files:**
- Modify: `Bowling/Features/Arsenal/BallDetailData.swift`
- Test: `BowlingTests/Arsenal/BallDetailDataTests.swift`, with a store-backed `@Suite struct BallDetailLoadTests`.

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `static func load(id: BallID, store: BowlingStore, filter: StatsFilterDraft, now: Date = .now, calendar: Calendar = .current) throws -> BallDetailData`.

`load` works in this order:
1. Set the filter's bowler to the owner (Global Constraints).
2. `games(matching:)`.
3. `maintenance(for:)`, then `ballReport`.
4. `recentGames` = complete games that `uses(id)`, `suffix(10)`, reversed so the newest is first.
5. Names from `centers()` and `oilPatterns()`.
6. Chips from the adjusted draft's `chips`.

- [ ] **Step 1: Write the failing tests.** Sessions are started through `store.sessions.startSession` with games completed by `QuickScore` or `finalOnly` entries, following the existing test helpers.

```swift
@Test func unknownBallThrows()                   // throws RepositoryError.notFound
@Test func recentGamesNewestFirstAtMostTen()     // 12 games with the ball on 12 days → 10 rows, first is newest
@Test func recentGamesOnlyUseTheBall()           // another ball's game is left out
@Test func incompleteGamesAreLeftOut()
@Test func recentGamesFollowTheFilter()          // filter competition only; a practice game is left out
@Test func noGamesInFilterKeepsMaintenance()     // ball only in practice, filter competition → performance []; maintenance.summary counts the practice games
@Test func friendFilterStillShowsOwnersGames()   // filter.bowlerID = friend → recent has the owner's game; chips contain the owner's name
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement `load`.**
- [ ] **Step 4: Run** BallDetailDataTests and BallDetailLoadTests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: BallDetailData loads from the store under the Stats filter (#30)`.

### Task 4: BallDetailScreen and navigation

**Files:**
- Create: `Bowling/Features/Arsenal/BallDetailScreen.swift`, `Bowling/Features/Arsenal/ArsenalRoute.swift`
- Modify: `Bowling/Features/Arsenal/ArsenalScreen.swift`. Rows become `NavigationLink(value: ArsenalRoute.ball(row.id))`, and the #29 row tap to Edit goes. Add `.navigationDestination(for: ArsenalRoute.self)`.

**Interfaces:**
- Consumes:
  - Task 3 `load`
  - `StatsFilterDraft.current(app.statsFilter, in:)`
  - `BallThumbnail` (#28, size 96)
  - `ResurfaceDueBadge`, which moves out of `ArsenalScreen` to its own file `Bowling/Features/Arsenal/ResurfaceDueBadge.swift` so both screens use it
  - `StatTile(_ content:)`, `LeavesCard`
  - the `StatsFilterBar` chip look, as a read-only `HStack` of capsules
- Produces: `enum ArsenalRoute: Hashable { case ball(BallID) }`, `struct BallDetailScreen: View { init(id: BallID) }`.

- [ ] **Step 1: Build the screen** per spec §3.
  - Use a `ScrollView` of cards on `Color.canvas`, matching the Stats cards' look.
  - Add the Edit toolbar button: `app.ballForm = .edit(id)`.
  - Load in `.task(id: app.revision)`. On `.notFound`, call `dismiss()`.
  - A recent game row sets `app.historyPath = [.game(id)]` and `app.selectedTab = .history`.
  - Chart: `LineMark` and `PointMark` with y in 0...100. `RuleMark(x:)` per marker, dashed with `StrokeStyle(dash: [4, 3])` unless `isResurface`, in `.inkMuted`. Apply `.accessibilityElement(children: .ignore)` and `.accessibilityLabel(trend.accessibilityLabel)`.
  - Header and rows: each condition row and log row is one accessibility element.
- [ ] **Step 2: Add previews:**
  - the demo store's `DemoBall.ownerStrike` id from `BowlingFixtures`
  - a new ball with no games
  - a retired ball

  Each in light, dark and AX5.
- [ ] **Step 3: Build, then run the full unit suite** in the background. Expected: BUILD and TEST SUCCEEDED, with no new warnings in the files this branch touches.
- [ ] **Step 4: Hand check.** If the session can't drive the simulator, hand it to Marilyn and record that in the ledger. The checks:
  - Arsenal row → detail.
  - Edit, then save → the detail updates.
  - Delete an unused ball from Edit → back to the list.
  - A recent game → History opens on that game.
  - AX5 is readable.
- [ ] **Step 5: Commit** `feat: ball detail screen (#30)`.

Done when, after the PR:
- CI is green.
- Santiago approves.
- The mixed-ball fixture's strike and spare blocks are correct (Task 2 tests).
