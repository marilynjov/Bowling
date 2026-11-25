# Customize Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One Customize sheet that edits the owner's Stats cards and Home tiles (reorder, remove, add from the grouped catalog with descriptions, reset to preset), plus the bowling-style prompt and onboarding line that go with it (#36).

**Architecture:** App target only. A pure `LayoutDraft` value type holds the edit and is unit-tested; `CustomizeSheet` is a thin SwiftUI `List` over it, presented from `AppModel.customizing`. Saving and resetting go through the existing BowlingData layout methods via `app.write`.

**Tech Stack:** SwiftUI, Swift Testing, XCTest UI tests. No package or contract changes.

**Spec:** `docs/superpowers/specs/2026-11-25-customize-design.md` (parent: `2026-10-07-phase-1-core-scoring-design.md` section 7).

## Global Constraints

- No changes under `Packages/`; use `BowlerRepository.setStatsLayout(_:)`, `setHomeLayout(_:)`, `resetStatsLayout()`, `resetHomeLayout()`, `resetLayouts()` and `StatsPreset.displayedStatsCards/displayedHomeTiles/statsCards(for:)/homeTiles(for:)` as they are.
- Every store write goes through `app.write { ... }`; a thrown error sets `app.error`.
- User-facing text uses `String(localized:)` / `Text("...")`. `Localizable.xcstrings` is not on `main` yet (#125 adds it); whichever PR lands second syncs it.
- Match surrounding style: `Color.canvas` / `.surface` / `.ink` / `.inkMuted` / `.hairline`, doc comment on each type, Debug `#Preview`s in Light, Dark and AX5.
- CI is locked by billing: verify locally (`BowlingTests`, the new UI test, both `swift test` runs) and say so in the PR.

## Review Focus

1. **Saving an empty layout:** Save is disabled with "Add at least one card." under the layout section; the repository never receives `[]` (an empty layout would read as "use the preset" and surprise the bowler). Test in Task 2.
2. **Home layout holding a non-tile card** (synced from Stats-style edits or a newer version): the Home draft drops it from the editable list but `layoutToSave` keeps unknown raw IDs, so nothing is lost. Test in Task 2.
3. **Cancel after edits:** nothing is written; Home and Stats look as before. Test in Task 5 (step 1b).
4. **Changing the bowling style with preset layouts:** no prompt appears; only a non-empty `statsLayout` or `homeLayout` triggers it. Test in Task 4.
5. **Adding a card already in the layout** (double tap on add): appears once. Test in Task 2.

---

### Task 1: Card titles and descriptions

**Files:**
- Create: `Bowling/Features/Customize/StatsCardText.swift`
- Modify: `Bowling/Features/Stats/StatsCards.swift:137-150` (call `StatsCardText.title` instead of the private `title(_:)`)
- Test: `BowlingTests/Customize/StatsCardTextTests.swift`

**Interfaces:**
- Produces: `enum StatsCardText { static func title(_ card: StatsCardID) -> String; static func description(_ card: StatsCardID) -> String; static func title(_ group: StatsCardGroup) -> String }`

- [ ] **Step 1: Write the failing tests**

```swift
@Test func everyCardHasADistinctTitleAndADescription() {
    let titles = StatsCardID.allCases.map(StatsCardText.title)
    #expect(Set(titles).count == titles.count)
    for card in StatsCardID.allCases {
        #expect(!StatsCardText.description(card).isEmpty, "\(card)")
        #expect(StatsCardText.title(card) != card.rawValue, "\(card)")
    }
}
@Test func titlesMatchTheCardsOnStats() {
    #expect(StatsCardText.title(.trendChart) == "Trend")
    #expect(StatsCardText.title(.average) == "Average")
    #expect(StatsCardText.title(.leftMostMadeLeast) == "Left most, made least")
}
@Test func everyGroupHasATitle() {
    #expect(StatsCardGroup.allCases.map(StatsCardText.title)
        == ["Overview", "Trend", "Strikes and spares", "Leaves", "By frame", "What if"])
}
```

- [ ] **Step 2: Run, expect a build failure** (`StatsCardText` undefined)

Run: `xcodebuild test -scheme Bowling -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:BowlingTests/StatsCardTextTests`

- [ ] **Step 3: Implement `StatsCardText`**

Move `StatsCards.title(_:)` and its `emptyReport` here unchanged; `StatsCards` calls `StatsCardText.title`. Descriptions are one plain sentence each, under ~60 characters, saying what the number is (e.g. `average`: "Your average score per game.", `headPinRate`: "How often your first ball hits the head pin.", `whatIfSinglePins`: "Your average if you made every single-pin spare.").

- [ ] **Step 4: Run Task 1 tests and `StatsCardsTests`; expect PASS**

- [ ] **Step 5: Commit** `feat: Stats card titles and descriptions for Customize (#36)`

---

### Task 2: LayoutDraft

**Files:**
- Create: `Bowling/Features/Customize/LayoutDraft.swift`
- Test: `BowlingTests/Customize/LayoutDraftTests.swift`

**Interfaces:**
- Consumes: `StatsCardText` (Task 1), `StatTileContent.make(_:_:)`, `StatsPreset`, `BowlerRecord`.
- Produces:
```swift
enum LayoutDestination: Hashable { case stats, home }
struct LayoutDraft: Hashable {
    var destination: LayoutDestination
    private(set) var cards: [StatsCardID]
    init(destination: LayoutDestination, owner: BowlerRecord)
    /// Cards the destination can show (Home: those with a tile form), not in `cards`, by group in catalog order; empty groups left out.
    var catalog: [(group: StatsCardGroup, cards: [StatsCardID])]
    var canSave: Bool                    // !cards.isEmpty
    var isCustomized: Bool               // the owner's stored layout for this destination is non-empty
    mutating func add(_ card: StatsCardID)        // appends; no-op if present or not offered
    mutating func remove(atOffsets: IndexSet)
    mutating func move(fromOffsets: IndexSet, toOffset: Int)
    static func offers(_ card: StatsCardID, for: LayoutDestination) -> Bool
}
```
(`catalog` can be an array of a small `CatalogGroup: Identifiable` struct if tuples get in SwiftUI's way.)

- [ ] **Step 1: Write the failing tests** (owner records built in-memory via `BowlingStore(inMemory: true)` and `createOwner(..., statsProfile: .league)`):

```swift
@Test func startsFromTheDisplayedLayout()  // league Stats draft == StatsPreset.statsCards(for: .league); isCustomized == false
@Test func startsFromASavedLayout()        // after setStatsLayout([.fouls, .average]) → cards == [.fouls, .average], isCustomized
@Test func homeOffersOnlyTileCards() {
    for card in [StatsCardID.trendChart, .leavesTable, .leftMostMadeLeast, .byFrameStrike, .byFrameAverage, .whatIfSinglePins] {
        #expect(!LayoutDraft.offers(card, for: .home)); #expect(LayoutDraft.offers(card, for: .stats))
    }
}
@Test func catalogIsEverythingElseByGroup() // league Home: catalog flattens to the 13 tile cards minus the 5 in the preset, in StatsCardID.allCases order; no group with no cards
@Test func addAppendsOnce()                 // add(.fouls) twice → .fouls appears once, at the end, and leaves the catalog
@Test func addIgnoresANonTileCardOnHome()   // home draft add(.trendChart) → cards unchanged
@Test func removeAndMove()                  // remove(atOffsets: [0]); move([0], toOffset: 2) give the expected orders
@Test func anEmptyLayoutCannotBeSaved()     // remove all → canSave == false
@Test func homeDraftDropsANonTileCard()
    // owner record copied with homeLayout = ["average", "trendChart", "fromTheFuture"] (BowlerRecord is a plain struct)
    // → LayoutDraft(destination: .home, owner:).cards == [.average]
    // Saving keeps the unknown ID: StatsPreset.layoutToSave([.average], replacing: that layout) contains "fromTheFuture"
```

- [ ] **Step 2: Run, expect build failure**

- [ ] **Step 3: Implement `LayoutDraft`**

`init` reads `StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: owner.statsProfile)` (or `displayedHomeTiles`), filtering Home through `offers`. `offers(.home)` is `StatTileContent.make(card, <empty report>) != nil`; reuse `StatsCardText`'s empty report (make it internal there).

- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat: LayoutDraft for Customize (#36)`

---

### Task 3: Customize sheet and its entry points

**Files:**
- Create: `Bowling/Features/Customize/CustomizeSheet.swift`
- Modify: `Bowling/App/AppModel.swift` (add `var customizing: LayoutDestination?`; `ErrorPresenter.customize`, topmost when `customizing != nil`, checked after `ballForm`)
- Modify: the root view that presents `ballForm` (find with `git grep -n "ballForm" Bowling/App`) to present `.sheet(item:)` for `customizing` the same way
- Modify: `Bowling/Features/Stats/StatsScreen.swift` (toolbar `Button("Customize", systemImage: "slider.horizontal.3") { app.customizing = .stats }`)
- Modify: `Bowling/Features/Home/HomeScreen.swift:60-70` (a header row above the tiles: `Text("Your stats").monoLabel()` and a trailing `Button("Edit") { app.customizing = .home }`)
- Test: `BowlingTests/AppModelTests.swift` (presenter)

**Interfaces:**
- Consumes: `LayoutDraft`, `LayoutDestination`, `StatsCardText`.
- Produces: `struct CustomizeSheet: View { init(destination: LayoutDestination) }`; `LayoutDestination: Identifiable` (`id: Self`).

- [ ] **Step 1: Write the failing test**

```swift
@Test func customizeSheetShowsErrors() {
    let app = AppModel.preview()
    app.customizing = .stats
    app.error = RepositoryError.notFound
    #expect(app.showsError(in: .customize))
    #expect(!app.showsError(in: .root))
}
```

- [ ] **Step 2: Run, expect build failure**

- [ ] **Step 3: Implement**

- `CustomizeSheet` loads the owner on appear into `@State var draft: LayoutDraft`. `NavigationStack` titled "Customize Stats" / "Customize Home", toolbar Cancel (dismiss, `app.customizing = nil`) and Save (`.disabled(!draft.canSave)`).
- `List`, `.environment(\.editMode, .constant(.active))`:
  - Section "In your layout": `ForEach(draft.cards)` with title + description, `.onMove`, `.onDelete`; footer "Add at least one card." when `!draft.canSave`.
  - One Section per `draft.catalog` group, header `StatsCardText.title(group)`; each row a `Button` with `Label` "plus.circle.fill" (accent), title and description, `.accessibilityLabel("Add \(title)")`.
  - Section with a destructive "Reset to preset" button, `.disabled(!draft.isCustomized)`, confirmation dialog "Go back to the cards for your bowling style?" → `resetStatsLayout()`/`resetHomeLayout()` and close.
- Save: `app.write { try $0.bowlers.setStatsLayout(draft.cards) }` (or `setHomeLayout`), close on success, `app.error = error` on failure and keep the sheet.
- Reorder at AX sizes and with VoiceOver works through List's built-in edit mode; also add `.accessibilityActions` "Move up" / "Move down" on layout rows.
- Previews: Stats light, Home dark, Stats AX5.

- [ ] **Step 4: Run `BowlingTests`; expect PASS. Build and look at the previews.**
- [ ] **Step 5: Commit** `feat: Customize sheet on Stats and Home (#36)`

---

### Task 4: Bowling style prompt and onboarding line

**Files:**
- Modify: `Bowling/Features/Settings/SettingsScreen.swift:161-164`
- Modify: `Bowling/Features/Settings/SettingsRows.swift` (add `var hasCustomLayout: Bool`, true when the owner's `statsLayout` or `homeLayout` is non-empty)
- Modify: `Bowling/Features/Onboarding/BowlingStyleStep.swift:19`
- Test: `BowlingTests/Settings/SettingsRowsTests.swift`

**Interfaces:**
- Consumes: `BowlerRepository.resetLayouts()`, `setStatsProfile(_:)`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func presetLayoutsAreNotCustom()   // fresh league owner → SettingsRows(owner:).hasCustomLayout == false
@Test func aSavedLayoutIsCustom()        // after setHomeLayout([.average]) → true; after resetLayouts() → false
```

- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement**

`setStyle` writes the profile as today; if `rows.hasCustomLayout` was true before the write, set `@State var pendingLayoutChoice = true` and show a `confirmationDialog("Use the stats for your new bowling style?")` with "Use the new preset" (`app.write { try $0.bowlers.resetLayouts() }`) and "Keep my layout" (cancel role). Onboarding text becomes "This decides which stats you see. You can change it anytime in Settings, or pick exactly the stats you want."

- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat: offer the new preset after a bowling style change (#36)`

---

### Task 5: Done criterion UI test

**Files:**
- Modify: `Bowling/App/UITestLaunch.swift` (add `static let persistentArgument = "-persistentStore"`: with it, `openStore()` uses `BowlingStore()` (on-disk, in the simulator app's container) and creates the owner only if `store.bowlers.owner() == nil`)
- Test: `BowlingTests/UITestLaunchTests.swift`, `BowlingUITests/CustomizeUITests.swift`

- [ ] **Step 1: Write the UI test**

`testLayoutSurvivesRelaunchAndReset`, launch args `["-uiTesting", "-persistentStore"]`:
1. Home → Edit. If "Reset to preset" is enabled, tap it and confirm (clears a previous run), then Edit again.
   1b. Add "Fouls", tap Cancel; assert Home has no "Fouls" tile. Edit again.
2. Add "Fouls", remove "Average" (swipe or delete control on its row), Save.
3. Assert Home's tiles include "Fouls" and not "Average".
4. `app.terminate()`, `app.launch()`; assert the same.
5. Edit → Reset to preset → confirm; assert "Average" is back and "Fouls" is gone.
6. Repeat 2–5 for Stats via the Customize toolbar button, checking card titles.

- [ ] **Step 2: Run on the iPhone 18 Pro, expect failure** (no `-persistentStore`)
- [ ] **Step 3: Implement the launch flag**; add a unit test that `UITestLaunch` recognises it.
- [ ] **Step 4: Run the UI test, `BowlingTests`, and `swift test` for both packages; expect PASS**
- [ ] **Step 5: Commit** `test: Customize survives relaunch and reset (#36)`
