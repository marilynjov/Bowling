# App Shell Design (#4)

**Status:** draft, for review by marilynjov.
**Issue:** #4, Phase 1a, `owner:frontend`.
**Builds on:** [Phase 1 spec](2026-10-07-phase-1-core-scoring-design.md) section 7, and
[app and package contract](2026-10-14-app-package-contract.md) rule 1 and OQ-1.

## 1. Purpose

The shell is the first app code. It sets how every later screen (#6 to #13) gets data,
refreshes, navigates, and shows errors, so those issues only fill in screens. It ships
with placeholder screens.

**Done when:** all four tabs, Settings, and the Scoring cover navigate on iOS 18 and
iOS 26, and every placeholder reads real data from the store.

**Not in scope:** the real screens (#6 to #13), shared components (#5), accessibility
labels (#14), the UI test (#15).

## 2. Decisions

| Question | Decision | Why |
|---|---|---|
| How other tabs learn data changed | An app-side `revision` counter on `AppModel`, bumped by every write; screens reload in `.task(id: app.revision)` | The contract gives the app value types with no change signal in 1a (OQ-1). This needs no contract change, and phase 2's sync signal can bump the same counter. |
| How Scoring is presented | One full-screen cover owned by the root | Scoring needs the whole screen for one-handed entry (spec §7), and Home, New session, and History all open it. |
| Store fails to open | An error screen with Retry, never an empty store | An empty store looks like a first launch; setting up again on top of unreadable data risks losing it. |

## 3. Files

```
Bowling/
  App/
    BowlingApp.swift    @main; opens BowlingStore, shows the error screen if it throws
    AppModel.swift      @Observable wrapper: store, revision, scoring target, error
    RootView.swift      first launch or tabs; the Scoring cover; the shared alert
    Glass.swift         .glassBackground(in:) modifier
  Features/
    Onboarding/         placeholder until #6
    Home/               placeholder until #11; gear to Settings; temporary Start
    History/            placeholder until #9
    Stats/              placeholder until #10
    Arsenal/            placeholder until #12
    Settings/           placeholder until #13
    Scoring/            placeholder cover until #8
  Components/           shared views from #5
BowlingTests/           Swift Testing target for AppModel
```

`MyApp.swift` and `ContentView.swift` are removed. The "Fixtures" preview from #65 is
replaced by the placeholder previews, which read the demo store.

## 4. AppModel

`@MainActor @Observable final class AppModel`, injected with `.environment(app)`.

```swift
let store: BowlingStore
private(set) var revision = 0
var scoring: ScoringTarget?      // the open Scoring session, or nil
var error: (any Error)?          // shown by the shared alert

/// Every write goes through here so the other tabs refresh.
func write<T>(_ body: (BowlingStore) throws -> T) rethrows -> T

/// No owner yet: show first launch.
var needsOnboarding: Bool        // store.bowlers.owner() == nil, read per revision

static func preview() -> AppModel   // wraps BowlingStore.demo()
```

- `write` bumps `revision` whether the body returns or throws. A failed write rolls back
  in the repository, so reloading after one is harmless, and it keeps `write` simple.
- `write` rethrows. The caller decides whether to handle the error itself or hand it to
  the shared alert by setting `app.error`.
- Reads call the repositories directly (`app.store.sessions.sessions()`), in a screen's
  `.task(id: app.revision)`.
- `ScoringTarget` is `Identifiable` and holds the `SessionID` and the `GameID` to open,
  so History's Edit can open a specific game later. The placeholder ignores it.
- `needsOnboarding` reads `revision` before asking the store, so the root switches to the
  tabs as soon as `createOwner` goes through `write`.

## 5. Navigation

- **RootView:** `needsOnboarding` shows the onboarding placeholder; otherwise a
  `TabView` with Home, History, Stats, Arsenal, each in its own `NavigationStack`.
- **Settings:** pushed from a gear button in Home's toolbar (spec §7).
- **Scoring:** `.fullScreenCover(item: $app.scoring)` on the root, above the tabs, so
  any screen opens it by setting `app.scoring`. The placeholder has a close button.
- **Onboarding placeholder:** a "Continue" button that creates an owner named "Bowler"
  with the league profile through `app.write`, enough to reach the tabs until #6.
- **Home placeholder:** the owner's name, the gear, and a temporary "Start" button that
  starts a practice session for the owner and opens the Scoring cover.
- **History, Stats, Arsenal placeholders:** one real value each (session count, the
  owner's game count, active ball count), so the read path works from day one.

## 6. Liquid Glass

`Glass.swift` has one modifier, `.glassBackground(in shape: some Shape)`: `glassEffect`
in that shape on iOS 26 and later, `.thinMaterial` clipped to it on iOS 18. Components
use the modifier and never repeat the availability check. The tab bar gets Liquid Glass
from the system on iOS 26.

## 7. Errors

- **Store fails to open:** `BowlingApp` catches the error from `BowlingStore()` and shows
  "Your bowling data couldn't be opened", the error description, and Retry, which tries
  again. There is no reset here; "Delete all data" needs a working store and stays in
  Settings.
- **Write errors:** the root shows one alert for `app.error`, with plain text for each
  `RepositoryError` case and the error description for anything else. Errors with their own handling (Scoring's "clear rolls
  first", for example) are handled on that screen, from #8 on.

## 8. Testing

- **`BowlingTests` (Swift Testing),** on an in-memory store:
  - a successful write bumps `revision`;
  - a throwing write bumps `revision` and rethrows;
  - `needsOnboarding` is true with no owner and false after `createOwner` via `write`;
  - setting and clearing `scoring`.
- **Previews:** every placeholder and the error screen, using `AppModel.preview()`.
- **Builds:** Debug on iOS 18 and iOS 26 simulators; Release, so `#if DEBUG` preview
  code stays out of it.
- **By hand:** the four tabs, Settings, the Scoring cover, and onboarding to tabs.
