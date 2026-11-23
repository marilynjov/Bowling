# Accessibility and String Catalog Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every user-visible string sits in a String Catalog. An automated accessibility audit of the game flow runs on CI at default and AX5 text sizes. A VoiceOver-only checklist proves a full game can be scored by ear.

**Architecture:**
- **Catalog:** `Bowling/Localizable.xcstrings` is filled from the build's extracted strings and guarded by a unit test that parses the source file.
- **Fixed titles:** literals passed into `String` title parameters become `String(localized:)` at the call site, the style `StatTile` callers already use.
- **Audit:** `AccessibilityAuditUITests` reuses the #15 `-uiTesting` launch and a shared tap helper.

**Tech Stack:** SwiftUI iOS 18, Swift 6, String Catalogs (`.xcstrings`), Swift Testing, XCTest/XCUITest `performAccessibilityAudit`.

**Spec:** `docs/superpowers/specs/2026-11-01-accessibility-design.md`

**Precondition:** #118 (Settings) and #120 (BowlingUITests target, `-uiTesting`, identifiers) are merged. Merge `origin/main` into `feat/14-accessibility` before Task 1.

## Global Constraints

- Never edit `Packages/`.
- Do not reword strings `AccessibilityText` already tests. Their unit tests must stay green unchanged.
- User data (bowler, ball, center, league, oil pattern names) stays `String`. Only fixed copy is localized.
- English is the only language. The catalog's `sourceLanguage` is `"en"`.
- Shortcut identifiers are fixed: `scoring.strike`, `scoring.spare`, `scoring.miss`, `scoring.foul`, `scoring.undo`.
- AX5 launch arguments: `["-uiTesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]`.
- Audit findings are fixed in the app. An exclusion matches one element and one issue type, with a comment giving the reason. Never skip a whole audit type.
- Commits have no Co-Authored-By trailer.
- Unit tests: `xcodebuild test -scheme Bowling -destination 'id=2C568C51-3721-4FB2-90EE-D54EB3308C03' -parallel-testing-enabled NO -only-testing:BowlingTests/<Suite>`. UI tests: same with `-only-testing:BowlingUITests/<Class>`.
  - Run UI and full-suite runs in the background.
  - If xcodebuild hangs after printing a result, kill it by PID.
  - On "Failed to create a bundle instance", rerun.

## Review Focus

1. **A literal in a `String` parameter never reaches the catalog.** Task 1 Step 1's grep must come back empty. Test `catalogHasTheShortcutTitles` pins the ScoringScreen ones.
2. **A string added after this PR without a build in Xcode** leaves the catalog stale or incomplete. `StringCatalogTests.noKeyIsStale` catches stale keys. Missing keys are a known gap, written into the checklist ("build in Xcode before committing new copy").
3. **AX5 clips the pin deck or scorecard.** The AX5 audit's `.textClipped` must pass without an exclusion on those two.
4. **Foul and Undo lose their ids** when the shortcut ids stop deriving from the title. Test: the audit walk taps `scoring.undo` once.
5. **The VoiceOver checklist drifts from the app's real wording.** The checklist quotes `AccessibilityText` output. Task 4 copies it from the unit-tested strings, not from memory.

---

### Task 1: String Catalog and fixed titles

**Files:**
- Create: `Bowling/Localizable.xcstrings`, `BowlingTests/StringCatalogTests.swift`
- Modify:
  - `Bowling/Features/Scoring/ShortcutBar.swift`
  - every call site Step 1's grep lists, including `ChoiceCard`/`ScoringModesStep`/`ProfileStep`, `BallChip`, `NamedRefPicker` callers, `ClearedFramesNotice` callers and `StatsCards`

**Interfaces:**
- Produces: `ShortcutBar.shortcut(_ title: String, id: String, action:)`, with ids from Global Constraints. `PinByPinGameUITests` keeps working unchanged.
- Produces: `enum StringCatalog { static func load() throws -> [String: Entry] }`, test-only, inside `StringCatalogTests.swift`. It reads `Bowling/Localizable.xcstrings` located from `#filePath`: the file is the source, and the bundle carries only compiled `.strings`. `Entry` holds `extractionState: String?` and `hasPluralVariants: Bool`.

- [ ] **Step 1: List the leaks**

Run: `grep -rnE '(shortcut|pick|ChoiceCard|ChoiceButton|ClearedFramesNotice|NamedRefPicker|StatTile|StatsCard)\([^)]*"[A-Z]' Bowling --include='*.swift' | grep -v 'String(localized'`

These are literals passed to `String` parameters. Record the list in the ledger.

- [ ] **Step 2: Write the failing tests** in `BowlingTests/StringCatalogTests.swift`

```swift
@Test func catalogExistsAndIsEnglish() throws   // file parses, sourceLanguage == "en", strings.count > 100
@Test func noKeyIsStale() throws                 // no entry has extractionState == "stale"
@Test func catalogHasTheShortcutTitles() throws  // keys "Strike", "Spare", "Miss", "Foul", "Undo", "Next" present
@Test func appCopyIsInTheCatalog() throws        // "Start session", "New session", "Game complete", "Pin %lld, standing" present
```

- [ ] **Step 3: Run them to verify they fail**

Run: unit command with `-only-testing:BowlingTests/StringCatalogTests`
Expected: FAIL. The catalog file is missing.

- [ ] **Step 4: Make the leaks extractable**

- Wrap each literal from Step 1 in `String(localized:)` at its call site.
- Give `ShortcutBar.shortcut` an `id:` parameter and pass the fixed ids.

- [ ] **Step 5: Create and fill the catalog**

1. Write `{"sourceLanguage":"en","strings":{},"version":"1.0"}` to `Bowling/Localizable.xcstrings`. The synchronized group adds it to the target.
2. Build the scheme once.
3. If the build left the file empty, fill it with `xcrun xcstringstool sync Bowling/Localizable.xcstrings --stringsdata <every .stringsdata under DerivedData/.../Bowling.build>`, and ledger the ruling.
4. Delete any keys left `stale`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: the Step 3 command, then `-only-testing:BowlingUITests/PinByPinGameUITests` in the background.
Expected: both TEST SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add Bowling BowlingTests/StringCatalogTests.swift
git commit -m "feat: String Catalog with every app string; fixed shortcut ids (#14)"
```

### Task 2: Plural variants

**Files:**
- Modify: `Bowling/Localizable.xcstrings`
- Test: `BowlingTests/StringCatalogTests.swift`

**Interfaces:**
- Consumes: Task 1's `StringCatalog.load()`.

- [ ] **Step 1: Write the failing test**

```swift
@Test(arguments: ["%lld bowlers", "%lld games", "%lld pins standing: %@",
                  "This bowler has %lld games. Delete them first.",
                  "This ball was used in %lld games. Retire it instead.",
                  "Delete this session? Its %lld games will be deleted."])
func countedStringsHavePluralForms(key: String) throws  // entry exists and hasPluralVariants
```

Use the exact keys Task 1's catalog shows for these strings. If the catalog spells one differently, use the catalog's key and ledger it.

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL, `hasPluralVariants` false for each.

- [ ] **Step 3: Add `one` / `other` plural variations** in the catalog for each key. The English `one` form uses the singular, e.g. "1 game".

- [ ] **Step 4: Run StringCatalogTests and the AccessibilityText and StatFormat tests**

Run: unit command with `-only-testing:BowlingTests/StringCatalogTests -only-testing:BowlingTests/AccessibilityTextTests -only-testing:BowlingTests/StatFormatTests`
Expected: TEST SUCCEEDED, with the existing wording tests unchanged.

- [ ] **Step 5: Commit** `feat: plural forms for counted strings (#14)`

### Task 3: Accessibility audit of the game flow

**Files:**
- Create: `BowlingUITests/GameFlow.swift`, `BowlingUITests/AccessibilityAuditUITests.swift`
- Modify:
  - `BowlingUITests/PinByPinGameUITests.swift`: use `GameFlow`.
  - the app views the audit flags.

**Interfaces:**
- Produces: `@MainActor struct GameFlow`, with `init(app: XCUIApplication)` and these methods:
  - `tap(_ id: String, wait: Bool = false)`
  - `pins(_ standing: Int...)`: taps the pins, then Next.
  - `startSession()`: Home › Start session › Start, then waits for `scoring.next`.
- Consumes: Task 1's shortcut ids.

- [ ] **Step 1: Move the helpers into `GameFlow`.** `PinByPinGameUITests` calls them, with no behaviour change. Run it and expect TEST SUCCEEDED.

- [ ] **Step 2: Write the audit tests**

`final class AccessibilityAuditUITests: XCTestCase` with:
- `testGameFlowAtDefaultSize()`
- `testGameFlowAtAX5()`

Both call `walk(arguments:)`:
1. Launch.
2. Audit Home.
3. Tap `home.startSession` and audit the New session sheet.
4. Tap Start. Enter X, then 7 standing pins 4 7 10, Next, then Undo (`scoring.undo`), then pins 4 7 10, Next, then Spare. Audit Scoring.
5. Enter the rest of the #15 game and wait for `summary.score`. Audit the summary.

Each audit is `try app.performAccessibilityAudit { issue in exclusion(issue) }`, where `exclusion` returns false (fail on everything) to start.

- [ ] **Step 3: Run them**

Run: UI command with `-only-testing:BowlingUITests/AccessibilityAuditUITests`, in the background.
Expected: FAIL, listing the audit's issues. Ledger each one: screen, element, issue type.

- [ ] **Step 4: Fix each issue in the app**

- **Missing label:** add one through `AccessibilityText`, with a unit test for its wording.
- **Clipped text:** fix the layout so it wraps or stacks. Don't cap the Dynamic Type size.
- **Small hit target:** raise the frame to 44 pt.
- **Contrast:** use the theme token that passes.

An issue that is not real, such as a system control the app doesn't own, gets an exclusion as Global Constraints says, plus a `Ruling:` line.

- [ ] **Step 5: Run both audit tests and the full suite**

Expected: TEST SUCCEEDED, including both methods.

- [ ] **Step 6: Commit** `test: accessibility audit of the game flow at default and AX5 sizes (#14)`

### Task 4: VoiceOver-only checklist

**Files:**
- Create: `docs/accessibility-checklist.md`

**Interfaces:**
- Consumes: the wording in `AccessibilityText` (Task 3 may have added some) and the #15 game table.

- [ ] **Step 1: Write the checklist**

One page:
- **Setup:** turn VoiceOver on (Settings › Accessibility › VoiceOver, or triple-click) and sign in with a fresh profile, or use Delete all data.
- **The game, frame by frame:** for each frame, the gestures (swipe to the pin, double-tap; swipe to Next/Strike/Spare/Miss, double-tap) and the exact phrases to hear. Copy the phrases from `AccessibilityTextTests` expectations, e.g. "Pin 7, standing", "3 pins standing: 4, 7, 10", "Frame 2: 7, spare, total 39".
- **Finish:** the summary reads 193. End the session.
- **Result block:** device, iOS version, date, pass/fail, notes.
- **Rule for later:** build once in Xcode before committing new copy, so the catalog picks it up.

- [ ] **Step 2: Check every quoted phrase against the unit tests**

Run: `grep -n "<phrase>" BowlingTests/Components/AccessibilityTextTests.swift` for each phrase that isn't a button title.
Expected: each phrase matches a tested string or a `String(localized:)` literal.

- [ ] **Step 3: Commit** `docs: VoiceOver-only scoring checklist (#14)`

Done when, after the PR:
- CI passes `StringCatalogTests` and both audit methods.
- Marilyn's checklist run is recorded in the PR as passed. If the run finds a problem, it gets fixed on this branch and the run is repeated.
