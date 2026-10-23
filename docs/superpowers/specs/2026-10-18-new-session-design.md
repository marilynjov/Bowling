# New session (#7)

Replaces Home's temporary practice Start with the new-session form from the Phase 1 spec
(§7, New session): date, event type, center, league, oil pattern, lanes, the bowler
lineup with a ball per bowler, entry mode, and notes. **Start** creates the session and
the first game for each bowler and opens Scoring.

Uses only the existing contract (`SessionRepository`, `BowlerRepository`,
`BallRepository`). No package changes.

## Balls and friends

Balls stay the owner's: the owner's row picks from `BallRepository.activeBalls()`. A
friend's balls need balls to belong to a bowler, which is a data change for SantiagoM99
(agreed with marilynjov, 2026-10-18). Until it merges, friends' rows have no ball picker
and start with `defaultBallID: nil`. The friend ball picker is a follow-up issue once the
contract has per-bowler balls.

## Flow

Home's **Start** opens a **New session** sheet in a `NavigationStack`, toolbar
**Cancel** (leading) and **Start** (trailing, confirmation placement).

- **Cancel** dismisses and saves nothing about the session. Centers, leagues, patterns,
  and bowlers created from the pickers stay; they are list entries, not the session.
- **Start** is always enabled: the owner is always in the lineup and every other field
  is optional. It calls `startSession`, saves the remembered values for the event type,
  dismisses the sheet, and opens Scoring on the first lineup bowler's first game.
- If Start throws, the sheet stays open with the shared error alert, the form keeps
  its values, and the remembered values are not saved.

## Form

A `Form`, top to bottom.

### 1. When

- **Date**: date and time, default now.
- **Event**: segmented control, Practice · League · Tournament · Casual
  (`EventType.practice`, `.league`, `.tournament`, `.casual`). First default: Practice.

### 2. Where

- **Center**, **League** (shown only when the event is League), **Oil pattern**: each
  row shows the picked name or "None" and pushes a `NamedRefPicker`.
- **Lanes**: text field, placeholder "13–14".

`NamedRefPicker` is a searchable list:

- A **None** row first, then the items from `centers()` / `leagueRecords()` / `oilPatterns()`
  filtered by the search text (case- and diacritic-insensitive contains), checkmark on
  the current pick.
- A last row **Add "<text>"** when the trimmed search text is non-empty and matches no
  listed name exactly, ignoring case and accents ("cafe lanes" matches "Café Lanes").
  The League picker lists only the picked center's leagues (or those with no center when
  none is picked), so a league name can repeat at another center. Changing the center
  clears the league. Add creates the item (`createCenter`, `createLeague(name:centerID:)`
  with the form's current center, `createOilPattern`), picks it, and pops back.
- Picking a row pops back.

### 3. Bowlers

- The lineup in order. The owner is preselected first and cannot be removed.
- Long-press drag reorders any row, the owner included (`onMove`).
- Swipe to remove a friend.
- Each row: the name, and on the owner's row a **Ball** value ("No ball" when none)
  that pushes `BallPicker`: a **No ball** row, then `activeBalls()` as
  "name · weight lb". An empty arsenal shows "No balls yet. Add them in Arsenal."
  under No ball. Adding a ball here waits for the full ball form (#29).
- An **Add bowler** row pushes `AddBowlerPicker`: a searchable list of `bowlers()` that
  are not the owner and not already in the lineup, and a last row **Add "<name>"** under
  the same rule as `NamedRefPicker`, which calls `createBowler(name:)`. Picking or adding
  appends the bowler to the lineup and pops back.

### 4. Scoring

- Segmented control: Pin by pin · Count · Final score (`.pinByPin`, `.countOnly`,
  `.finalOnly`). First default: Pin by pin.
- Footer: "You can switch before the first roll."

### 5. Notes

- Multi-line text field, placeholder "Notes".

## Remembered values

Per Phase 1 §7, the last-used center, league, oil pattern, owner's ball, and entry mode
are remembered **per event type** in UserDefaults, not in the synced store.

- Saved only after a successful Start, under the session's event type.
- Opening the form: date is now, event type is the last started session's event type
  (Practice the first time), and that type's remembered values fill the form. Lanes,
  notes, and friends start empty.
- Switching event type in the form replaces center, league, pattern, owner's ball, and
  entry mode with the new type's remembered values (empty / Pin by pin when none). Date,
  lanes, notes, and the lineup are kept.
- A remembered ID no longer in the current lists (deleted center, retired ball) is
  dropped and the row starts empty. `startSession` throws `.notFound` on a missing
  reference, so a stale ID must never reach it.
- Unreadable stored data is treated as nothing remembered.

## Units

All in `Bowling/Features/NewSession/`.

- **`NewSessionDraft`** (struct, no UI): `date`, `eventType`, `centerID`, `leagueID`,
  `oilPatternID`, `lanes`, `notes`, `entryMode`, `lineup: [LineupEntry]`
  (`bowlerID`, `name`, `isOwner`, `ballID`).
  - `add(_ bowler: BowlerRecord)` appends unless already in the lineup.
  - `remove(at:)` ignores the owner. `move(fromOffsets:toOffset:)`.
  - `metadata: SessionMetadata`: `leagueID` is nil unless the event is League.
  - `applying(_ defaults: SessionDefaults, available: Available) -> Self`, where
    `Available` holds the current center, league, pattern, and active ball IDs.
  - `defaults: SessionDefaults` (what to remember after Start).
  - `start(in sessions: SessionRepository) throws -> SessionID`.
- **`SessionDefaults`** (Codable struct): `centerID`, `leagueID`, `oilPatternID`,
  `ballID`, `entryMode`, all optional.
- **`SessionDefaultsStore`**: wraps an injected `UserDefaults`. Keys
  `newSession.defaults.<eventType rawValue>` and `newSession.lastEventType`.
- **Views**: `NewSessionSheet`, `NamedRefPicker`, `AddBowlerPicker`, `BallPicker`.
- **`AppModel`**: `startPracticeSession()` becomes `startSession(_ draft:)`, which
  writes through `write {}`, saves the defaults after the write succeeds, and sets
  `scoring` to the first lineup bowler's first game. `ScoringFlowTests` start from a
  default draft.
- **Home**: Start presents the sheet.

## Look

D1 style (`2026-10-14-visual-style-design.md`): canvas background, Surface rows,
accent for the checkmark and the Add rows. Light, dark, and AX5 previews for each view.
Labels use system text styles so they scale with Dynamic Type.

## Testing

Swift Testing in `BowlingTests/NewSession/`, on the test simulator.

- Draft: a non-league session's metadata has no league; the owner can't be removed;
  adding the same bowler twice adds one; `applying` drops IDs not in `available`;
  `applying` with empty defaults gives Pin by pin and no picks; `start` creates one game
  per lineup bowler in lineup order with the owner's ball.
- Store: values round-trip per event type; saving League doesn't change Practice;
  unreadable data reads as empty; the last event type round-trips.
- AppModel: `startSession` opens Scoring on the first lineup bowler's game and saves
  the defaults; a start that throws (a deleted center) saves no defaults and leaves
  `scoring` nil.

## Not in #7

- Friends' ball picker (waits on per-bowler balls).
- Adding a ball from the form (#29).
- Resume of an unfinished session from Home (#11).
