# Customize screen for Stats and Home (#36)

Short design. Parent spec: `2026-10-07-phase-1-core-scoring-design.md`, section 7 (Stats:
card catalog, presets, Customize, layout rules) and section 7 Home.

## Intent

Stakeholders find the stats in competing apps confusing. Phase 1a shows a preset picked
by the bowling style; 1b lets the bowler choose exactly which stats they see, and in what
order, on Stats and on Home. Done when a customized layout survives a relaunch and a
reset to preset.

## Goals

- One Customize screen, used for both Stats cards and Home tiles.
- Reorder and remove the cards in the layout; add any other card from the catalog,
  grouped, each with a one-line description.
- "Reset to preset" returns to the bowling style's preset.
- Changing the bowling style in Settings asks whether to replace a customized layout with
  the new preset (spec section 7).
- Onboarding's bowling style question adds "or pick exactly the stats you want" (spec,
  Home 1a/1b).

## Non-goals

- No contract or package changes. BowlingData already has `setStatsLayout`,
  `setHomeLayout`, `resetStatsLayout`, `resetHomeLayout`, `resetLayouts`, and Stats and
  Home already display the saved layouts.
- No per-friend layouts: layouts are the owner's only.

## Anti-goals

- A layout that jumps around or silently loses cards: unknown card IDs from a newer app
  version stay saved (the repository already keeps them).
- Saving the unedited preset freezing it: the repository stores `""` for that, so the
  bowler keeps following the preset as it grows.

## Approaches

1. **Sheet with Cancel and Save (picked).** A draft list; nothing is written until Save,
   Cancel throws it away. Matches the spec's "Saving writes `statsLayout`" and the app's
   other editing sheets (ball form, maintenance, filter).
2. Pushed screen that writes every change at once. No Cancel, every drag is a store
   write and a revision bump that reloads Stats behind it.
3. Edit mode in place on Stats and Home. Two implementations instead of one, and no room
   for the catalog with descriptions.

## Design

- **Entry points:** a Customize toolbar button on Stats; an Edit button beside Home's
  tiles. Both present `CustomizeSheet` for `.stats` or `.home`.
- **Sheet content** (a `List` in edit mode):
  - "In your layout": the current cards in order, drag to reorder, delete to remove.
  - One section per `StatsCardGroup` with the cards not in the layout, each with its title,
    one-line description, and an add button that appends it to the layout.
  - "Reset to preset" at the bottom, with a confirmation; it writes the reset and closes.
- **Catalog:** Stats offers every available `StatsCardID`. Home offers only cards with a
  tile form (`StatTileContent.make` non-nil): not `trendChart`, `leavesTable`,
  `leftMostMadeLeast`, `byFrameStrike`, `byFrameAverage`, `whatIfSinglePins`.
- **Save** calls `setStatsLayout` / `setHomeLayout` through `app.write`. A layout can't be
  saved empty (Save disabled with a hint).
- **Descriptions:** a new app-side `title` and `description` per card ID, in the String
  Catalog.
- **Style change:** when Settings changes the bowling style and either layout is
  customized (non-empty), a confirmation offers "Use the new preset" (`resetLayouts`) or
  "Keep my layout".
- **Accessibility:** reorder has VoiceOver actions (move up / down); the sheet works at AX5.

## Left to the builder

- Exact copy of the 19 descriptions.
- Pure logic (draft editing, catalog per destination, "is customized") lives in a testable
  value type in the app target, tested with Swift Testing; a UI test checks the done
  criterion (customize, relaunch on the same store, reset).
