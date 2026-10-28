# Arsenal 1a: ball list and add form (#12)

The Arsenal tab from the Phase 1 spec (§7, Arsenal, 1a): active balls with name, weight,
intended role, and games bowled, and an add form with name, weight, intended role, and
brand only. It replaces the "N balls" placeholder.

Uses the existing contract: `BallRepository.activeBalls()` (`BallSummary`, including
`gamesBowled`) and `BallRepository.addBall(name:weightPounds:intendedRole:brand:)`, which
refuses an empty name or a weight outside 6 through 16 with `.invalidBall`. BowlingCore
`BallRole`. No package changes. The branch `feat/12-arsenal` starts from `main`.

**Done when:** a ball added in Arsenal appears in the Scoring ball chip and the New
session ball picker.

## Structure

| Unit | Does |
|---|---|
| `ArsenalList` | Pure. The rows built from `activeBalls()`, with each row's text. |
| `BallDraft` | Pure. The add form's values, whether Save is allowed, and the save call. |
| `AccessibilityText` | Gains `ballRow`, the row's VoiceOver label. |
| `AppModel` | Gains `isAddingBall` and the `.addBall` error presenter. |
| `ArsenalScreen`, `AddBallSheet` | The views. |

## 1. Ball list

- Active balls in `activeBalls()` order (by name). Retired balls are not shown; the
  Retired group is 1b (#28).
- Each row: the name; "15 lb · Strike"; and the games bowled, "12 games", "1 game", or
  "No games yet" for zero. Roles read Strike, Spare, Both. A ball whose stored role is
  `.unknown` (written by a newer version) shows no role: "15 lb".
- VoiceOver reads the row as one element: "Phaze, 15 pounds, strike, 12 games"
  (`AccessibilityText.ballRow`; "no games yet" for zero, the role left out when unknown).
- Rows are display only. Ball detail (#30) and editing (#29) come in 1b.
- Toolbar **+** (VoiceOver "Add ball") opens the add form.
- Empty: "No balls yet." and an **Add ball** button that opens the same form. New
  session already tells the user "No balls yet. Add them in Arsenal."
- The list reloads in `.task(id: app.revision)`.

## 2. Add form

A sheet titled "Add ball" with Cancel and Save.

- **Name**: text field, required. Trimmed on save.
- **Brand**: text field, optional ("Brand" placeholder).
- **Weight**: a picker of 6 through 16, shown as "15 lb". No default: it reads "Choose"
  until one is picked.
- **Role**: segmented Strike / Spare / Both, default Strike.
- **Save** is disabled until the trimmed name is not empty and a weight is picked
  (`BallDraft.canSave`). It writes through `app.write` and closes the sheet. If the
  write throws, `app.error` is set and the sheet stays open with its values; the alert
  shows from the sheet (`.sharedErrorAlert(in: .addBall)`).
- **Cancel** closes the sheet without saving. Swiping the sheet down is the same as
  Cancel.

`BallDraft`:

```swift
struct BallDraft: Hashable {
    var name = ""
    var brand = ""
    var weightPounds: Int?
    var role: BallRole = .strike
    var canSave: Bool
    /// - Throws: what `addBall` throws, or `.invalidBall(.weightOutOfRange)` with no weight.
    func save(to store: BowlingStore) throws -> BallSummary
}
```

## 3. Presenting and errors

- `AppModel.isAddingBall` drives the sheet, like `isStartingSession` drives New session.
- `ErrorPresenter` gains `.addBall`; `showsError(in:)` makes it topmost while
  `isAddingBall` is true and no Scoring cover is up. The Arsenal tab's own errors show
  from `.root`.
- `ErrorText` already has strings for `.invalidBall(.emptyName)` and
  `.invalidBall(.weightOutOfRange)` (#106); the form prevents both, so they only show if
  the repository refuses anyway.

## 4. Where the new ball shows up

`app.write` bumps `app.revision`. New session's `BallPicker` reads `activeBalls()` when it
opens, and `ScoringModel` reads it when Scoring opens, so a ball added in Arsenal is in
both the next time they open. No code changes there. A test checks the saved ball is in
`activeBalls()` and in New session's `Available.current(in:).balls`.

Scoring is a full-screen cover, so a ball can't be added while Scoring is open; there is
no live refresh to build.

## Testing

- `ArsenalListTests`: rows in name order, the "15 lb · Strike" line, game-count wording
  (0, 1, many), unknown role, retired balls left out.
- `BallDraftTests`: `canSave` for an empty or blank name and a missing weight; the name
  is trimmed; save adds the ball with all four fields; a refused save throws and adds
  nothing; the saved ball is in New session's `Available.current(in:).balls`.
- `AccessibilityTextTests`: `ballRow` for many games, zero games, and unknown role.
- `AppModelTests`: `.addBall` is the topmost presenter while adding.
- Light, Dark, and AX5 previews: the list with balls, the empty list, and the sheet.

## Merge note

#108 (History) also adds an `ErrorPresenter` case (`.sessionDetails`) and new `AccessibilityText` functions. Whichever merges
second resolves the small conflicts in `AppModel` and `AccessibilityText`.

## Not done here

Ball detail (#30), edit and the full form with photo (#29), retire and the Retired group
(#28), compare (#31), maintenance (#32), adding a ball from the New session picker
(waits for #29), and balls per bowler (#93).
