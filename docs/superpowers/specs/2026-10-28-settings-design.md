# Settings 1a (#13)

The Settings screen from the Phase 1 spec (§7, Settings): owner profile, bowling style,
pin entry default, auto-advance, rotation default, default stats scope, delete all data
with double confirmation, about, and an iCloud placeholder. It replaces the "Coming in #13"
placeholder pushed from Home's toolbar.

Uses the existing contract: `BowlerRepository.owner()`, `updateOwner(name:handedness:)`,
`setStatsProfile(_:)`, `setStatsScope(_:)`, `StatsPreset.prefersCompetition(_:)`, and
`BowlingStore.deleteAllData()`. No package changes. The branch `feat/13-settings` starts
from `main`.

**Done when:** every setting changes the behavior it names.

## Decisions

| Question | Decision |
|---|---|
| Profile editing | A pushed Profile screen with Name, Hand and Save. Settings shows "Sam · Right-handed". |
| Delete all data and on-device settings | Clears them too: the New session form's remembered values and the three scoring toggles. A true fresh start. |
| Bowling style and default games | Saved as soon as they are picked, like iOS Settings. |
| Scoring toggles | Stay on the device (`ScoringSettings`), never synced. |

## Structure

| Unit | Does |
|---|---|
| `SettingsRows` | Pure. The owner plus `ScoringSettings` → each row's text and current choice. |
| `ProfileDraft` | Pure. Name, hand, `canSave`, `save(to:)`. |
| `ScoringSettings.reset()`, `SessionDefaultsStore.reset()` | Remove their keys, so reads return the defaults. |
| `AppModel.deleteAllData()` | Deletes every record, clears both stores, resets in-memory state. |
| `SettingsScreen`, `ProfileScreen` | The views. |

## 1. Settings screen

A grouped `Form` titled "Settings".

**Profile**
- "Sam · Right-handed" (or "Sam · Left-handed"; just "Sam" for an unknown hand), a
  navigation row to Profile.
- **Bowling style**: a picker of Casual, League, Competitive. Picking saves through
  `setStatsProfile`. A style from a newer version (`.unknown`) shows no selection.
  Footer: "Decides which stats you see first."

**Stats**
- **Default games**: a picker of "Follow bowling style (Competition)" or "Follow bowling
  style (All games)" (the word in brackets is what the current style picks, from
  `StatsPreset.prefersCompetition(_:)`), "Competition", and "All games". It saves
  `setStatsScope(nil)`, `(.competition)`, `(.all)`. A stored `.unknown` reads as Follow.
  Footer: "Where Stats and Home start. You can still change it on Stats."

**Scoring**
- **Pin entry**: "Tap standing" (default) or "Tap what fell" → `tapWhatFell`.
- **Auto-advance on spares**: a toggle, shown only with Tap what fell → `autoAdvanceOnSpare`.
  Footer: "Records the second ball once it makes a spare."
- **Rotate bowlers**: a toggle → `rotateBowlers`. Footer: "Each night starts with this.
  You can still switch it in Scoring."

**iCloud sync**: one row, "iCloud sync" with "Coming soon" trailing, not tappable.

**About**: "Version" with "1.0 (12)" from `CFBundleShortVersionString` and `CFBundleVersion`.

**Data**: "Delete all data" as a destructive button.

The screen reloads the owner in `.task(id: app.revision)`.

## 2. Profile

Pushed from the profile row. Title "Profile", a Save button.

- **Name**: a text field, starting with the owner's name.
- **Hand**: a segmented picker of Left and Right; an unknown hand starts with none picked
  and saves as `.unknown`, which keeps the stored value.
- Save is disabled while the name is blank (whitespace only). The repository trims it.
- Save writes `updateOwner` through `app.write` and pops back. An error shows the shared
  alert and keeps the screen and its values.

## 3. Delete all data

1. A confirmation dialog: title "Delete all data?", message "This deletes every session,
   game, ball and your profile from this iPhone.", a destructive "Delete all data" and
   Cancel.
2. Then an alert: title "This can't be undone.", a destructive "Delete everything" and
   Cancel.
3. `AppModel.deleteAllData()`: `write { try $0.deleteAllData() }`, then
   `sessionDefaults.reset()`, `scoringSettings.reset()`, `statsFilter = nil`,
   `savedQuickScore = nil`, `selectedTab = .home`. The root sees no owner and shows first
   launch. If the delete throws, nothing else is reset and the error shows the shared alert.

## Testing

- `SettingsRowsTests`: the profile summary for right, left and unknown; the Follow label for
  league ("Competition") and casual ("All games"); the selected scope for nil, competition,
  all and unknown; the selected style for each case including unknown (none).
- `ProfileDraftTests`: blank and whitespace names can't save; save updates the owner's name
  (trimmed) and hand; an unknown hand keeps the stored one.
- `ScoringSettingsTests` / `SessionDefaultsStoreTests`: `reset()` returns every value to its
  default.
- Done when, in `SettingsBehaviorTests`:
  - Bowling style: changing league → casual changes `HomeData`'s tiles and
    `StatsPreset.displayedStatsCards` for the owner.
  - Default games: setting `.all` for a league owner with league games makes
    `StatsFilterDraft.current(nil, in:)` "All games" and drops Home's all-games line.
  - Scoring: each toggle set through the Settings rows reads back from a new
    `ScoringSettings` on the same defaults, which is what Scoring opens with.
  - Delete all data: `needsOnboarding` is true, `sessionDefaults` and `scoringSettings` are
    back to defaults, `statsFilter` and `savedQuickScore` are nil.
- Light, Dark and AX5 previews for Settings (league owner, and Tap what fell on), Profile, and
  the delete prompts.

## Not done here

CSV export (#37), merge places (§4), the phase 2 wording that the delete reaches other
devices, and a real iCloud setting.
