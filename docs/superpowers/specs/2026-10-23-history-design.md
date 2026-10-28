# History: sessions, games, edit and delete (#9)

The History tab, from the Phase 1 spec (§7, History): sessions by month, session detail
with series totals, game detail with the full scorecard, leaves and balls used, Edit into
Scoring, and swipe to delete with confirmation. It also closes three gaps #95 (PR #101)
left for History, and takes Santiago's two #101 review notes.

Uses the existing contract: `SessionRepository.sessions`, `session`, `updateMetadata`,
`deleteSession`; `GameRepository.game`, `deleteGame`, `startNextGame`; BowlingCore
`Scorer`, `FrameScore.leave`. Ball names come from `BallRepository.detail(for:)` once
#106 merges. One small data-side request is listed at the end. The branch
`feat/9-history` starts from `main`.

**Done when:** editing an earlier frame from History shows which later frames need
re-entry (the #95 cleared-frames notice), and a night closed while its summary was up
can be continued with Next game.

## Structure

| Unit | Does |
|---|---|
| `HistoryRoute` | `enum { case session(SessionID), game(GameID) }`, the History stack's routes. |
| `AppModel` | Gains `historyPath: [HistoryRoute]` and `openSession(_:)`. |
| `HistoryList` | Pure. `sessions()` grouped by month, with each row's text. |
| `SessionDetailData` | Pure. One session: metadata line, a section per bowler, latest game number, resumable. |
| `GameDetailData` | Pure. One game: title, scorecard, leaves, balls used, whether it's the latest. |
| `SessionDetailsDraft` | The details half of `NewSessionDraft`, shared by New session and the details form. |
| `HistoryScreen`, `SessionDetailScreen`, `GameDetailScreen`, `SessionDetailsForm` | The views. |
| `SessionScoringModel` (#95) | Gains a start-on-target option and two Next game fixes. |

## 1. History list

- Sessions grouped by calendar month of their date, newest month first and newest
  session first inside a month. Month headers read "October 2026".
- Each row: the date; "event · center · league" (league only for league nights, missing
  parts left out); "3 bowlers" when there is more than one; and the owner's scores, as
  on Home's recent rows. An unfinished session adds "In progress". The row view is
  Home's `RecentSessionRow`, extended for the league and bowler count, so both match.
- Tapping a row pushes session detail.
- Swipe to delete asks "Delete this session? Its N games will be deleted." (with "1
  game" for one), then calls `deleteSession`.
- Empty: "Your sessions show up here." and a Start session button that opens New
  session, as on Home.

## 2. Session detail

- Header: date, event, center, league, oil pattern and lanes, each left out when not
  set, then notes when there are any.
- Toolbar **Edit** opens the details form (section 5).
- Then one section per bowler in lineup order: the header is the bowler's name and
  "Series 590"; each game is a row with "Game 2" and a compact `ScorecardStrip`. Tapping
  a game pushes game detail.
- Swipe to delete a game asks "Delete Alex's game 2?". When it is the session's only
  game, it asks "Delete this session? It has no other games." and deletes the session
  instead, so no empty session is left.
- An in-progress session (the one `resumableSession()` returns) shows **Resume**, which
  opens Scoring exactly as Home's Resume does.

## 3. Game detail

- Title "Game 2 · Alex".
- The full scorecard (`ScorecardStrip`), then a grid of the ten frames, each with its
  leave as a `LeaveDiagramView` (split marker included). Leave rules match the game
  summary: a final-score game has no leaves section; a count-only game shows "Enter pins
  to see leaves."; a strike frame shows the strike diagram.
- **Balls used**: the game's default ball first ("Default · Phaze"), then each override
  ball once, with the frames it was used in ("Hammer · frames 3 and 7"). Nothing when no
  ball was set. A ball that can't be found reads "Deleted ball".
- **Edit** opens Scoring on this game (section 4).
- **Delete game** at the bottom, with the same confirmation as the swipe in section 2.
  After it, the screen pops back to session detail (or to the list when the session was
  deleted).

## 4. Edit into Scoring

- Edit opens Scoring on the whole night at this game number: every bowler who has a game
  with this number, with the bowler strip, as #95 does.
- `ScoringTarget` gains `startsOnTarget: Bool` (default `false`). History passes `true`:
  the turn starts on this game's bowler even when the rotation rule would pick someone
  else. Home's Resume keeps `false`.
- The game summary offers **Next game** only when this game number is the session's
  latest (the highest `gameIndex` among all bowlers). On an older game number it shows
  only **Done**, which closes Scoring.
- A finished night closed while its summary was up (#101 gap): Edit on its latest game
  opens Scoring with every game finished, so the complete panel shows **Summary**, and
  the summary offers Next game.

### Next game fixes (Santiago's #101 note)

1. Next game builds the night from the IDs `startNextGame` returns, not from
   `gameIndex + 1`, so an uneven night shows the right games and leaves no one out.
2. If building the models fails after the write worked, the summary closes and the
   error shows, so a second tap can't create another game.

Also from the #101 review: `ScoringModelEditTests` gets a test that replaces a roll after
picking an override ball and checks `rolls[0].ballID` is that ball.

## 5. Session details form

- A sheet from session detail's Edit: date, event, center, league (filtered by the
  picked center, cleared when the center changes, as in #102), oil pattern, lanes,
  notes. No lineup and no scoring mode.
- Starts from the saved metadata. **Save** calls `updateMetadata`; **Cancel** discards.
- `SessionDetailsDraft` holds these fields and rules. `NewSessionDraft` keeps the lineup
  and scoring mode and uses a `SessionDetailsDraft` for the rest, so New session and this
  form can't drift apart.

## 6. Navigation

- History's `NavigationStack(path: $app.historyPath)` maps each `HistoryRoute` to its
  screen with `navigationDestination(for:)`.
- `AppModel.openSession(_ id:)` selects the History tab and sets the path to
  `[.session(id)]`. Home's recent rows call it instead of only switching tabs.
- After a delete, the screen removes its route and any above it from the path.
- A pushed screen whose session or game no longer exists (deleted elsewhere, or by sync
  later) shows "This session was deleted." / "This game was deleted." with a button back
  to the list, instead of failing.

## Saving and errors

Every write goes through `app.write`, so every screen reloads on `revision`. A failed
write goes to `app.error` and the shared alert on the topmost screen; the screen keeps
its data. Edit on a game deleted a moment ago gets Scoring's existing `.notFound` alert.

## Accessibility

- A list row reads as one element: "October 21, League, AMF Bowl, Tuesday Mixed,
  3 bowlers, 201, 189, 224, in progress".
- A bowler header reads "Alex, series 590"; a game row reads "Game 2, 189".
- Frames and leaves reuse `AccessibilityText.frame` and `.leave`. A balls-used row reads
  "Hammer, frames 3 and 7".
- Swipe actions are also VoiceOver actions, so delete never needs a swipe.
- Previews in light, dark and AX5 for each screen.

## Testing

Unit tests, written first, on the pure types and the models. No UI test here; #15 covers
the end-to-end flow.

- `HistoryList`: months newest first, sessions newest first inside a month, empty list;
  row text for a league night, a one-bowler session, a session without a center, and an
  in-progress session; scores follow lineup order.
- `SessionDetailData`: sections in lineup order with series totals; latest game number on
  an uneven night (one bowler's latest game deleted); resumable only for the session
  `resumableSession()` returns; a session's only game is flagged for the delete prompt.
- `GameDetailData`: leaves for pin-by-pin, count-only and final-score games; balls used
  lists the default, then each override once with its frames (one ball in two frames
  listed once); a missing ball reads "Deleted ball"; latest flag.
- `AppModel`: `openSession` sets the tab and the path; deleting pops the right routes.
- `SessionScoringModel`: `startsOnTarget` starts on the tapped bowler when rotation would
  pick another; Next game on an uneven night opens the returned games; no Next game on
  an older game number; a failed rebuild closes the summary.
- `SessionDetailsDraft`: starts from saved metadata; the league follows the center;
  saving keeps untouched fields; New session still passes its existing tests.

## Data-side request (Santiago)

`startNextGame` numbers each bowler's next game from that bowler's latest. After a
bowler's latest game is deleted, the night splits (Alex gets a second Game 2 while Sam
gets Game 3). Request: number the next game from the session's highest `gameIndex` for
everyone. Not blocking: Next game fix 1 makes the app open whatever the call returns.

## Not done here

Game photos (1b), search and filters in History, CSV export (#37), changing who bowled a
game, a calendar view.
