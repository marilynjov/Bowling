# Stats screen (#10)

The Stats tab from the Phase 1 spec (§6 and §7, Stats): a filter bar with date presets,
event types and bowler, then the bowling style's cards, each with its sample size, and an
explanation on a card whose games don't apply. It replaces the "N games" placeholder.

Uses the existing contract: `StatsRepository.games(matching:now:calendar:)` and
`defaultEventTypes(for:preferCompetition:)`, `StatsEngine.report(games:filter:)`,
`StatsFilter`, `DatePreset`, `StatsReport` (1a and 1b fields), `StatsCardID`,
`StatsPreset.displayedStatsCards(layout:profile:)` and
`prefersCompetition(scope:profile:)`, `BowlerRepository.owner()` and `bowlers()`. No package
changes. The branch `feat/10-stats` starts from `main`.

**Done when:** every 1a card renders from the demo data for each bowling style (casual,
league, competitive).

## Decisions

| Question | Decision |
|---|---|
| 1b cards in the presets (#105 made them available) | `openPct`, `cleanGamePct`, `firstBallAverage`, `headPinRate` render as plain tiles now; `byFrameStrike`, `byFrameAverage`, `whatIfSinglePins` show "Coming soon" until #35. No card disappears. |
| Card wording on Home and Stats | One shared tile mapping; Home's `HomeTiles` uses it, so the same number reads the same on both. |
| Filter lifetime | Kept on `AppModel` while the app runs; not saved. |
| Customize | #36 (1b). |

## Structure

| Unit | Does |
|---|---|
| `StatsFilterDraft` | Pure. The current `StatsFilter`, its default for a bowler, and the chip text. |
| `StatsCards` | Pure. Card IDs plus a `StatsReport` → each card's content. |
| `StatTileContent` | Pure. The shared single-number tile mapping, used by `StatsCards` and `HomeTiles`. |
| `AccessibilityText` | Gains the trend, leave-row and not-applicable labels. |
| `AppModel` | Gains `statsFilter: StatsFilterDraft?` (nil until Stats first loads). |
| `StatsScreen`, `StatsFilterBar`, `StatsFilterSheet`, `TrendCard`, `LeavesCard` | The views. |

## 1. Filter

- **Default** for a bowler (the owner when Stats first opens): date "All time"; event types
  from `defaultEventTypes(for: bowler, preferCompetition: StatsPreset.prefersCompetition(scope: owner.statsScope, profile: owner.statsProfile))`.
  The owner's scope and style decide for every bowler, since they are the owner's settings.
- **Chips**, in order:
  - Date: "This week", "This month", "Last 30 days", "This season", "All time".
  - Scope: "Competition" when the event types are exactly `EventType.competition`; "All
    games" when they are every case; otherwise the picked types in the order Practice,
    League, Tournament, Casual, joined with ", " (league and practice picked reads
    "Practice, League").
  - Bowler: the bowler's name.
- Tapping the bar opens the filter sheet. The bar is always visible above the cards.
- Changing the bowler resets the scope to that bowler's default. An explicit scope pick
  after that stays.
- The filter lives on `AppModel.statsFilter` while the app runs. If its bowler is deleted,
  Stats falls back to the owner's default.

## 2. Filter sheet

A sheet titled "Filters" with Cancel and Done. Cancel drops the edits; Done applies them.

- **Date**: a picker of the five presets.
- **Games**: segmented Competition / All games / Custom. Custom shows a toggle for each of
  Practice, League, Tournament, Casual. Done stays disabled while Custom has none on.
- **Bowler**: a picker of `bowlers()`, the owner first.

## 3. Cards

Cards come from `StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: owner.statsProfile)`
in that order, each in a Surface card (14 pt corners, per the visual style).

Each card's sample group and content:

| Card | Group (games) | Content |
|---|---|---|
| `average` | score | Tile "Average", value, "41 games"; below it "Last 10 201 · Last 30 195" when there are more than 10 / 30 games |
| `highGame` | score | Tile "High game", score, its date ("Oct 21") |
| `highSeries` | score | Tile "High series", the 3-game total, its date; "–" with no 3-game session |
| `trendChart` | score | Chart (§5) |
| `strikePct` | roll | Tile "Strike %", "63%", "of 210 frames", bar |
| `sparePct` | roll | Tile "Spare %", "of 77 chances", bar |
| `fouls` | roll | Tile "Fouls", per game, "41 games" |
| `openPct`, `cleanGamePct` | roll | Tiles "Open %" (of frames), "Clean games %" (of games) |
| `firstBallAverage` | roll | Tile "First-ball average", value, "of 210 first balls" |
| `headPinRate` | pin | Tile "Head pin %", "of 198 first balls" |
| `leavesTable` | pin | Leaves list (§4) |
| `leftMostMadeLeast` | pin | "Left most, made least": that leave's diagram, "Made 2 of 9"; "No leave seen 3 times yet." when nil |
| `splitConversion`, `makeableConversion`, `singlePinConversion` | pin | Tiles "Split conversion %", "Makeable conversion %", "Single-pin conversion %", "of N leaves" |
| `byFrameStrike`, `byFrameAverage`, `whatIfSinglePins` | — | Title and "Coming soon." |

Titles for the three 1b-later cards: "Strikes by frame", "Average by frame", "What if".

**Not applicable.** When a card's group has zero games, the card keeps its title and
shows instead:

- score games 0: "No complete games yet."
- roll games 0: "Enter frames to see strikes and spares."
- pin games 0: "Enter pins to see leaves."

The single-number tiles are `StatTileContent` (title, value, sample, progress), built by
one function shared with Home; Home's tiles keep their current text.

## 4. Leaves card

The `leaves` rows, at most 10, each: `LeaveDiagramView(size: .small)`, the pins caption it
draws, "Made 7 of 9", and the rate. A "Show all N leaves" row expands the rest in place
when there are more than 10. Rows are not tappable (the occurrence list is 1b, #34).
VoiceOver per row: "Leave 3, 6, 10, split, made 2 of 9".

## 5. Trend card

Swift Charts: one point per `TrendPoint` with a session average, a line through them
(Accent), and the rolling average as a second, dashed line (InkMuted). The x axis is dates,
the y axis scores. Sample: "12 sessions". With one session it shows the point alone.
VoiceOver reads the card as one element: "Trend, 12 sessions, latest session 201, rolling
average 195".

## 6. Screen states

- No owner: not reachable (first launch runs before the tabs).
- No complete games for the filter at all: the cards still show, each with its
  not-applicable text, so the layout doesn't change shape.
- The screen reloads in `.task(id:)` keyed on `app.revision` and the filter.

## Testing

- `StatsFilterDraftTests`: the default for a league owner with competition games
  ("Competition"), a casual owner ("All games"), an explicit `statsScope`; chip text for
  each preset, "Competition", "All games", and a custom set in fixed order; changing the
  bowler resets the scope; a deleted bowler falls back to the owner.
- `StatsCardsTests`:
  - For each of casual, league and competitive, the demo report gives a non-empty,
    applicable content for every 1a card in that preset (the Done-when).
  - Each tile's title, value and sample from a known report.
  - Not-applicable text for each group at zero games.
  - "Coming soon" for the three later cards; the four 1b tiles render.
  - `leftMostMadeLeast` nil → its "No leave seen 3 times yet." text.
- `HomeTilesTests` still pass with the shared mapping.
- `AccessibilityTextTests` for the trend and leave-row labels.
- Light, Dark and AX5 previews: Stats for the demo owner, the empty store, and the filter
  sheet.

## Merge note

#108 and #109 also add `AccessibilityText` functions and `AppModel` members; whichever
merges later resolves small conflicts.

## Not done here

Customize (#36), the full 1b filter bar (#33), by-frame and what-if cards (#35), the leave
occurrence list (#34), custom date ranges, and the league-length high series (#91).
