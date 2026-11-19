# Accessibility and String Catalog pass — design

Issue #14 · Phase 1a · owner:frontend · branch `feat/14-accessibility`
Phase 1 spec §10 is the authority. This pass checks it and closes the gaps.

## Goal

A full game can be scored with VoiceOver only. Every user-visible string goes through a
String Catalog. Accessibility problems on the game flow fail CI.

## What already holds

`AccessibilityText` already produces the §10 wording: pins, deck summary, frames (a foul
reads "foul") and leaves as one element. Unit tests cover it. Every screen has an AX5
preview. This pass does not reword them. It confirms them and adds what is missing below.

## 1. String Catalog

- **Catalog file:** add `Bowling/Localizable.xcstrings`, English source, filled from the
  strings the build extracts (`SWIFT_EMIT_LOC_STRINGS` is already on). It is committed with
  every extracted key present and an English value for each.
- **Plurals:** countable strings use the catalog's plural variants instead of one fixed
  form. Examples: "\(n) bowlers", "\(n) pins standing", game counts.
- **Fixed titles reach the catalog.** Helpers that take a fixed title as `String`
  currently hide literals from extraction. They take `LocalizedStringResource` instead, or
  their callers pass `String(localized:)`. Whichever fits the helper, the literal must be
  extracted. Known sites:
  - `ShortcutBar.shortcut(_:action:)`
  - `ChoiceCard`, `ScoringModesStep`
  - `StatTile` / `StatTileContent`, `StatsCards`
  - `BallChip`, `NamedRefPicker`'s title
  - `ClearedFramesNotice`
  - `EventTypeTitle`

  The plan audits every `title: String` and `Text(<String>)` site. Values that are user
  data, such as bowler, ball, center and league names, stay `String`.
- **Identifiers:** `ShortcutBar`'s `scoring.<title>` identifiers stop depending on the
  display title. Each shortcut gets a fixed id: `scoring.strike`, `scoring.spare`,
  `scoring.miss`, `scoring.foul`, `scoring.undo`. This closes the #120 deferred minor.
- **Guard:** a unit test, `StringCatalogTests`, reads the bundled catalog. It fails when
  the catalog is missing, when a key has no English value, or when a key is marked stale.

## 2. Automated accessibility audit

- **Test file:** `BowlingUITests/AccessibilityAuditUITests.swift`. It launches with
  `-uiTesting` (the #15 launch mode).
- **Screens:** it runs `performAccessibilityAudit()` on each:
  1. Home
  2. New session sheet
  3. Scoring, mid-game: after a few balls, so the scorecard has marks, totals and a leave
  4. Game summary, after a finished game
- **Text sizes:** two test methods walk the same screens, one at the default size and one
  at AX5. AX5 is set with the launch arguments
  `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.
- **Findings:** each finding is fixed in the app. A finding judged a false positive is
  excluded in the audit's issue handler. The handler matches the element and the issue type,
  with a comment giving the reason. It never skips a whole audit type.
- **Shared steps:** the steps that enter balls are shared with `PinByPinGameUITests` through
  a small helper in `BowlingUITests`, so both tests tap the same way.

## 3. VoiceOver-only game

- **Checklist:** `docs/accessibility-checklist.md`, a one-page script to run on an iPhone:
  1. Turn VoiceOver on.
  2. Start a session.
  3. Enter the #15 game by ear: X, 7/, 9-, X, X, 8/ (7-10), 9/, X, 72, XXX.
  4. Confirm the scorecard reads each frame and the summary reads 193.

  It lists what each step should sound like.
- **Recording the run:** Marilyn runs it once before merge. The PR records the device, iOS
  version and result. Anything wrong is fixed in this branch and the checklist re-run.

## 4. Layout at accessibility sizes

§10 says the pin deck and scorecard adapt at accessibility sizes rather than truncating.
The AX5 audit's clipped-text check covers it on the game flow. A finding there is fixed in
the layout, not by lowering the size cap.

## Done when

- `StringCatalogTests` and both `AccessibilityAuditUITests` methods pass on CI.
- The VoiceOver checklist run is recorded in the PR as passed.

## Not in scope

- Translations: English is the only language.
- Screens added in Phase 1b, which get their own pass.
- Rewording strings `AccessibilityText` already tests.
