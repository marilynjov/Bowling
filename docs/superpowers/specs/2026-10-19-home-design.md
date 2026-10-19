# Home (#11)

Replaces the placeholder Home with the Phase 1 spec's Home (§7, Home): Resume, Start
session, Quick score, the stat tiles from the Home preset, and the three most recent
sessions.

Uses only the existing contract (`SessionRepository`, `BowlerRepository`,
`StatsRepository`, `StatsEngine`, `StatsPreset`). No package changes. Builds on #7 (the
new-session sheet) and #5 (`StatTile`, `StatFormat`), so the branch starts from
`feat/7-new-session` with `feat/5-shared-components` merged in.

## Layout

A scrolling stack under the large title **Home**, with Settings in the toolbar as today.
Top to bottom:

1. **Resume card**, only when `resumableSession()` returns a session.
2. **Start session** and **Quick score**.
3. **Tiles**.
4. **Recent sessions**.

### 1. Resume card

- Shows the event type, the center (if any), and the progress of the game it opens,
  as "Game 2 · frame 6". A final-only game, or one with no frames yet, shows
  "Game 2" alone.
- Tapping it opens Scoring on the **resume target**: the first incomplete game in the
  session, taking bowlers in lineup order and each bowler's games by `gameIndex`
  (the order `SessionSummary.games` is already in).
- Frame shown is the number of frames with at least one roll, plus one, capped at 10.

### 2. Start session and Quick score

- **Start session**: full-width prominent button in accent. Sets
  `app.isStartingSession = true`, which opens the #7 sheet.
- **Quick score**: full-width secondary (bordered) button below it. Opens the Quick
  score sheet.

### 3. Tiles

- **Which:** `StatsPreset.displayedHomeTiles(layout: owner.homeLayout, profile:
  owner.statsProfile)`, in that order. Casual: Average, High game, Strike %. League and
  competitive: Average, High game, High series, Strike %, Spare %.
- **Grid:** two columns, one column at accessibility text sizes.
- **Only tile-shaped cards:** `average`, `highGame`, `highSeries`, `strikePct`,
  `sparePct`, `fouls`. Any other card ID in a custom layout (trend chart, leaves table,
  and so on) is skipped on Home. How they look on Home is Customize's call (1b).
- **Scope:** the tiles use the same default scope as Stats:
  - `preferCompetition` is the owner's saved `statsScope` (`.competition` → true,
    `.all` → false). When it is nil or `.unknown`, `StatsPreset.prefersCompetition(profile)`.
  - The event types are `StatsRepository.defaultEventTypes(for: owner.id,
    preferCompetition:)`, which already falls back to every type when there are no
    competition games.
  - The report is `StatsEngine.report` over `games(matching: StatsFilter(datePreset:
    .allTime, eventTypes:, bowlerID: owner.id))`.
- **Average:** when the scope's event types are exactly `EventType.competition`, the
  tile shows the competition average, and beneath it "All games 168" from a second
  report over every event type. Otherwise it shows that report's average alone.
- **High game:** the score, sample line "<n> games". **High series:** the 3-game series
  (`highSeries.first { $0.gameCount == 3 }`). **Strike %, Spare %:** the rate init, with
  its bar. **Fouls:** per game, from the `fouls` mean.
- **No games:** each tile shows "–" and "0 games" (what `StatFormat` already does).

### 4. Recent sessions

- Up to 3 rows from `sessions()` (newest first): the date, event type, center (if any),
  and the owner's game scores joined with " · ", for example "187 · 201 · 176". A
  game that isn't complete shows its current score followed by "…".
- Tapping a row switches to the **History** tab. Opening that session's detail waits
  for History (#12).
- With no sessions: the text "Your sessions show up here." in InkMuted.

## Quick score sheet

- A sheet at medium height, titled **Quick score**, with Cancel and Save.
- One large number-pad field, focused when the sheet opens. Hint beneath it: "Saved as
  a casual game today. You can change it in History."
- **Save** is enabled only when the text is a whole number 0–300 (digits only, no
  spaces or signs). It calls `quickScore(finalScore:now:)` through `app.write`,
  dismisses the sheet, and shows the undo banner.
- If the save throws, the sheet stays open with the shared error alert.

### Undo banner

- An overlay at the bottom of Home: "Saved 187" with an **Undo** button.
- It goes away after 5 seconds, or when another quick score replaces it.
- **Undo** calls `deleteSession` on the saved session and hides the banner.

## Code (`Bowling/Features/Home/`)

| Unit | Does |
|---|---|
| `HomeTiles` | Pure. From the owner record, the scope report and the all-games report, builds the tile list: `[HomeTile]`, each a card ID with its title, value, sample line, optional progress, and the optional "All games" line. |
| `HomeData` | `static func load(from store: BowlingStore) -> HomeData`: the tiles, the resume card (summary plus `ScoringTarget` and its progress text), and up to 3 `RecentRow`s. One pass, called from `.task(id: app.revision)`. |
| `QuickScoreEntry` | `static func score(_ text: String) -> Int?`: digits only, 0–300, otherwise nil. |
| `HomeScreen` | The layout above. |
| `QuickScoreSheet` | The sheet. |
| `UndoBanner` | The banner view. |

`AppModel` gains:

- `selectedTab: AppTab` (`home`, `history`, `stats`, `arsenal`), bound to the root
  `TabView`.
- `resume(_ target: ScoringTarget)`: sets `scoring`.
- `quickScore(_ score: Int) throws -> SessionID`: writes through `write {}`.
- `undoQuickScore(_ id: SessionID) throws`: `deleteSession` through `write {}`.
- `isQuickScoring: Bool` for the sheet, and a new `ErrorPresenter`
  case `quickScore` (like `newSession`), so a failed save shows its alert over the sheet.

## Testing

On the iPhone 18 Pro Max test simulator, against an in-memory store.

- **HomeTilesTests:**
  - Casual and league presets give their tiles in order.
  - With competition games and no saved scope, a league bowler's Average shows the
    competition average with the all-games line.
  - With no competition games, the Average shows the all-games average without the line.
  - A saved scope of "All games" never shows the line.
  - A casual bowler with no saved scope uses all games.
  - Unknown and non-tile card IDs in a custom layout are skipped.
  - With no games, every tile is "–" with "0 games".
  - High series uses the 3-game series.
- **HomeDataTests:**
  - At most 3 recent rows, newest first.
  - A row lists only the owner's scores, and marks an incomplete game with "…".
  - The resume target is the first incomplete game in lineup order.
  - No resume card when every game is complete.
  - Progress text: "Game 2 · frame 6", and "Game 1" for a game with no rolls.
- **QuickScoreEntryTests:** accepts "0" and "300"; rejects "301", "-1", "", "18a", " 7".
- **AppModel:**
  - `quickScore` saves one complete casual final-only game dated today.
  - `undoQuickScore` removes the session.
  - `resume` opens Scoring on the target.
  - The quick-score alert shows while the sheet is up.
- **Previews:** light, dark and AX5 for Home (empty and with games) and the Quick
  score sheet.
- **Manual (the user):** Quick score then Undo; Resume opens the right game; a recent
  row opens History.

## Not done here

- Opening a session's detail from a recent row (#12 History).
- Customizing Home's tiles (1b).
- Non-tile cards on Home.
