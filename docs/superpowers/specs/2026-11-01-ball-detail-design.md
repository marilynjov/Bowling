# Ball detail screen — design

Issue #30 · Phase 1b · owner:frontend · branch `feat/30-ball-detail` (from `feat/29-ball-form`)

Authorities:
- Phase 1 spec §7 "Ball detail", and §6 "Ball report".
- Contract §2.9: `BallReport`, `BallMaintenance`, `StatsEngine.ballReport`, and the recent games rule.

## Goal

A ball's page shows the following, sections 1 to 7:
1. Header
2. Specs
3. Maintenance
4. Performance as a strike ball and as a spare ball
5. Results by condition
6. Strike % over time with maintenance markers
7. Recent games

Done when the mixed-ball fixture shows correct strike-ball and spare-ball blocks.

## Scope split with #32 and #33

- **Maintenance is read-only here.** #32 adds the "Log maintenance" button and sheet, and
  the resurface notification.
- **Performance follows the Stats tab's current filter**
  (`StatsFilterDraft.current(app.statsFilter, in:)`). The filter's chips show read-only above
  the blocks. #33 makes them editable.

## 1. Navigation

- `ArsenalScreen` rows become `NavigationLink(value: ArsenalRoute.ball(id))`.
  `enum ArsenalRoute: Hashable { case ball(BallID) }`, with
  `.navigationDestination(for: ArsenalRoute.self)` on the Arsenal list. Pushing replaces
  #29's temporary row tap to Edit.
- `BallDetailScreen(id:)` has an **Edit** toolbar button that sets
  `app.ballForm = .edit(id)`. The sheet stays on `ArsenalScreen`, which presents it over
  the pushed screen.
- The detail reloads on `app.revision`. When `detail(for:)` throws `.notFound` (the ball
  was deleted from Edit), it calls `dismiss()` to pop back to the list.
- A recent game row sets `app.historyPath = [.game(id)]` and `app.selectedTab = .history`.

## 2. Data: `BallDetailData`

A value type of display text. It is unit tested without views.

- **Builder.** `BallDetailData(fields:isRetired:report:recentGames:filterChips:centerNames:patternNames:calendar:)`
  is pure:
  - `fields: BallFields`
  - `isRetired: Bool`
  - `report: BallReport`
  - `recentGames: [GameRecord]`
  - `filterChips: [String]`
  - `centerNames: [CenterID: String]` and `patternNames: [OilPatternID: String]`

  Tests feed it `BowlingFixtures.MixedBallFixture` games through `StatsEngine.ballReport`.
- **Loader.** `static func load(id: BallID, store: BowlingStore, filter: StatsFilterDraft,
  now: Date, calendar: Calendar) throws -> BallDetailData`:
  1. `games = store.stats.games(matching: filter.filter, now:, calendar:)`
  2. `report = StatsEngine.ballReport(for: id, games: games, maintenance: store.balls.maintenance(for: id))`
  3. `recentGames` = the games that are complete and `uses(id)`, `suffix(10)`, reversed so
     the newest is first
  4. names from `store.sessions.centers()` and `oilPatterns()`

  It throws `.notFound` for an unknown ball.
- **Photo.** The header photo reuses `BallThumbnail` (#28) at a size of 96.

## 3. Sections

1. **Header:**
   - photo or placeholder
   - name
   - "Storm · 15 lb"
   - "Reactive solid · Asymmetric" (each part left out when not set)
   - role ("Strike ball", "Spare ball", "Strike and spare")
   - "Surface: 2000 Abralon" when set
   - "Serial SN123" when set
   - a "Retired" tag when retired
2. **Specs.** Label and value rows, in this order:
   - Coverstock name
   - Core name
   - RG
   - Differential
   - Intermediate differential
   - Factory finish
   - Release date (month and year)
   - Purchase date
   - Color
   - Notes

   Empty values are hidden, and the section is hidden when every row is.
3. **Maintenance:**
   - **With an interval:** "18 of 60 games since resurface" plus a `ProgressView` clamped
     to 1. When `isResurfaceDue`, the "Resurface due" badge from #28 sits beside it.
   - **Without an interval:** "18 games since resurface" when a resurface is logged, else
     "Never resurfaced · 18 games".
   - **Log:** `events` newest first. Each row shows the kind title (Resurface, Polish, Oil
     extraction, Plug and redrill, Other), the date, and the grit and notes when set. When
     there are no events: "No maintenance logged."
4. **Performance:**
   - **Filter chips:** read-only, as a `Text` row in the `StatsFilterBar` chip style, with
     no tap.
   - **"As a strike ball":**
     - Strikes (rate)
     - First ball average
     - Head pin (rate)
     - Average as main ball

     Sample line: "N first balls".
   - **"As a spare ball":**
     - Spares
     - Single pins
     - Splits

     Sample line: "N spare attempts".
   - **Order.** Both blocks always show. The spare block comes first when
     `intendedRole == .spare`.
   - **Tiles.** Values use `StatFormat`, and tiles use the existing `StatTile`.
   - **Leaves:** `report.leaves` through the Stats leave row mapping, shown in
     `LeavesCard`. The mapping is made shared, not copied.
   - **No games:** when `report.gamesBowled == 0`, the blocks are replaced by "No games
     with this ball in this filter." The chips still show.
5. **By condition.** Two tables, "By pattern" and "By center". Each row shows the name,
   the strike rate, and the first ball average.
   - A nil id reads "Other".
   - The order is the report's order.
   - An unknown id (not in names) reads "Other".
   - Each table is hidden when it has no rows.
6. **Over time:**
   - A Swift Charts line and points of `overTime` strike %.
   - A `RuleMark` at each event date in the chart's range: solid for `.resurface`, dashed
     for the other kinds.
   - With fewer than 2 points: "Not enough sessions yet."
   - The chart's accessibility label summarizes it: "Strike rate over N sessions, latest
     X%."
7. **Recent games.** Each row shows the date, the score, and the event type title. Each
   row is a button (see §1). The section is hidden when empty.

## 4. Testing

`BowlingTests/Arsenal/BallDetailDataTests.swift`. It imports `BowlingFixtures`. If the test
target can't see that module, the executor rules on linking it.

- **Mixed-ball fixture (done when):**
  - The strike ball's strike block counts the fixture's first balls with it, and its spare
    block counts only its own spare attempts.
  - The spare ball's spare block counts the league night spare attempts.

  The values are read from the report the fixture produces and compared with the tiles'
  text, so the test checks the screen's mapping, not the engine's arithmetic.
- **Block order:** `.spare` puts the spare block first; `.strike` and `.both` put the
  strike block first.
- **Specs:** empty values are hidden, and an all-empty ball has no specs section.
- **Header:** the parts are left out when not set, and the retired tag shows.
- **Maintenance text:**
  - with an interval, including a due ball
  - without one, with and without a resurface
  - the log newest first, with kind titles
- **Conditions:** names are resolved, and nil or unknown ids read "Other".
- **Recent games** through `load` with a store:
  - at most 10, newest first
  - only games using the ball
  - incomplete games left out
  - following the filter's event types
- **`load`** throws `.notFound` for an unknown id.
- **No games:** a ball with no games has the empty performance text.
- **Previews:**
  - the demo strike ball
  - a new ball with no games
  - a retired ball

  Each in light, dark and AX5.

## Not in scope

- Log maintenance and the notification (#32).
- Editable filter chips (#33).
- Compare (#31).
- Tapping a chart point.
