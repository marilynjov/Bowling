# First Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `OnboardingPlaceholder` with the three-step first launch: name and hand, bowling style, ways to score.

**Architecture:** A plain `OnboardingDraft` struct holds the answers and the Continue rules and creates the owner in one repository call; it is unit tested against an in-memory store. Three SwiftUI step screens in one `NavigationStack` (`OnboardingFlow`) bind to the draft; Start writes through `app.write`, which flips `needsOnboarding` so `RootView` shows the tabs.

**Tech Stack:** SwiftUI, Swift Testing, BowlingData (`BowlerRepository`), BowlingCore (`Handedness`, `StatsProfile`).

**Spec:** `docs/superpowers/specs/2026-10-18-first-launch-design.md`

## Global Constraints

- iOS 18 minimum; app target has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and member import visibility: import every module whose types a file uses (`BowlingCore` for `Handedness`/`StatsProfile`, `BowlingData` for `BowlerRepository`/`BowlerRecord`).
- The app talks to packages only through the contract: `BowlerRepository.createOwner(name:handedness:statsProfile:)`. No package changes.
- D1 colors only through asset symbols (`.canvas`, `.surface`, `.hairline`, `.ink`, `.inkMuted`, `.accent`, `.accentText`); no hard-coded colors.
- Copy is exactly the spec's wording (Welcome, "Your name", "You bowl", the three style lines, the three scoring rows, "You pick one for each session.").
- Nothing preselected; nothing saved before Start.
- Previews are `#if DEBUG` and show light, dark, and AX3.
- Tests run on the iPhone 18 Pro Max simulator (`id=2C568C51-3721-4FB2-90EE-D54EB3308C03`) with `-parallel-testing-enabled NO`, never on the iPhone 18 Pro.

## Review Focus

1. Going Back from step 2 or 3 and forward again keeps every answer (draft lives in the flow, steps take bindings).
2. The keyboard is up on step 1: Continue stays visible above it (`safeAreaInset(edge: .bottom)`).
3. A double tap on Start creates one owner (Start disabled while `isSaving`) — Task 1 test `secondCreateAfterSuccessThrowsOwnerExists`.
4. An owner appears from elsewhere before Start (sync, phase 2): the shared alert shows "Your profile already exists." and Start re-enables — covered by the same Task 1 test plus Task 3's error path.
5. A name with inner spaces or non-Latin letters ("Ana María", "李") is kept as typed, only trimmed at the ends — Task 1 test `keepsInnerSpacesAndAnyScript`.

---

### Task 1: OnboardingDraft

**Files:**
- Create: `Bowling/Features/Onboarding/OnboardingDraft.swift`
- Test: `BowlingTests/Onboarding/OnboardingDraftTests.swift`

**Interfaces:**
- Produces:
  - `struct OnboardingDraft { var name: String = ""; var handedness: Handedness?; var style: StatsProfile? }`
  - `var canLeaveProfile: Bool` — trimmed name non-empty and `handedness != nil`
  - `var canFinish: Bool` — `canLeaveProfile && style != nil`
  - `func createOwner(in bowlers: BowlerRepository) throws -> BowlerRecord?` — nil without saving unless `canFinish`; otherwise passes the name as typed (the repository trims).

- [ ] **Step 1: Write the failing tests** (suite `OnboardingDraftTests`, `init() throws { store = try BowlingStore(inMemory: true) }`)

```swift
@Test func profileNeedsANameAndAHand() {
    var d = OnboardingDraft()
    #expect(!d.canLeaveProfile)
    d.handedness = .left
    for blank in ["", "   ", "\n\t"] { d.name = blank; #expect(!d.canLeaveProfile) }
    d.name = " Ana "
    #expect(d.canLeaveProfile)
    d.handedness = nil
    #expect(!d.canLeaveProfile)
}
@Test func finishNeedsAStyle() {
    var d = OnboardingDraft(name: "Ana", handedness: .right)
    #expect(!d.canFinish)
    d.style = .league
    #expect(d.canFinish)
}
@Test func createsTheOwnerWithTheAnswers() throws {
    let d = OnboardingDraft(name: " Ana ", handedness: .left, style: .competitive)
    let owner = try #require(try d.createOwner(in: store.bowlers))
    #expect(owner.name == "Ana")
    #expect(owner.isOwner)
    #expect(owner.handedness == .left)
    #expect(owner.statsProfile == .competitive)
    #expect(owner.statsScope == nil)   // follows the bowling style
    #expect(store.bowlers.owner()?.id == owner.id)
}
@Test func incompleteDraftSavesNothing() throws {
    #expect(try OnboardingDraft(name: "Ana", handedness: .right).createOwner(in: store.bowlers) == nil)
    #expect(try OnboardingDraft(name: "Ana", style: .casual).createOwner(in: store.bowlers) == nil)
    #expect(store.bowlers.owner() == nil)
}
@Test func secondCreateAfterSuccessThrowsOwnerExists() throws {
    let d = OnboardingDraft(name: "Ana", handedness: .right, style: .casual)
    _ = try d.createOwner(in: store.bowlers)
    #expect(throws: RepositoryError.ownerAlreadyExists) { try d.createOwner(in: store.bowlers) }
    #expect(store.bowlers.bowlers().count == 1)
}
@Test func keepsInnerSpacesAndAnyScript() throws {
    let owner = try OnboardingDraft(name: "  Ana María ", handedness: .right, style: .casual)
        .createOwner(in: store.bowlers)
    #expect(owner?.name == "Ana María")
    #expect(OnboardingDraft(name: "李", handedness: .left).canLeaveProfile)
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme Bowling -destination 'platform=iOS Simulator,id=2C568C51-3721-4FB2-90EE-D54EB3308C03' -parallel-testing-enabled NO -only-testing:BowlingTests/OnboardingDraftTests`
Expected: build error "cannot find 'OnboardingDraft' in scope".

- [ ] **Step 3: Implement `OnboardingDraft`** per the Interfaces block. Trim with `.whitespacesAndNewlines` for `canLeaveProfile`.

- [ ] **Step 4: Run to verify it passes** — same command. Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Bowling/Features/Onboarding/OnboardingDraft.swift BowlingTests/Onboarding/OnboardingDraftTests.swift
git commit -m "Hold first-launch answers in a draft that creates the owner once (#6)"
```

### Task 2: ChoiceCard, Welcome step, bowling style step

**Files:**
- Create: `Bowling/Features/Onboarding/ChoiceCard.swift`, `ProfileStep.swift`, `BowlingStyleStep.swift`

**Interfaces:**
- Consumes: `OnboardingDraft` (Task 1).
- Produces:
  - `struct ChoiceCard: View { init(title: String, detail: String? = nil, isSelected: Bool, action: @escaping () -> Void) }` — Surface fill, 1 pt Hairline border, 2 pt `.accent` border plus `checkmark.circle.fill` in `.accentText` when selected, 12 pt continuous corners, full width, min height 48; `.accessibilityElement(children: .combine)`, `.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)`.
  - `struct ProfileStep: View { @Binding var draft: OnboardingDraft; var onContinue: () -> Void }` — title "Welcome" (`.navigationTitle`, large); "Your name" label + `TextField` (`.textContentType(.name)`, `.submitLabel(.done)`, `@FocusState` focused in `.onAppear`, submit clears focus); "You bowl" label + two `ChoiceCard`s in an HStack ("Right" → `.right`, "Left" → `.left`); Continue in `safeAreaInset(edge: .bottom)`, `.borderedProminent`, `.controlSize(.large)`, full width, `.disabled(!draft.canLeaveProfile)`.
  - `struct BowlingStyleStep: View { @Binding var draft: OnboardingDraft; var onContinue: () -> Void }` — title "How do you bowl?"; intro "This decides which stats you see. You can change it anytime in Settings." in `.inkMuted`; three `ChoiceCard`s with the spec's table (title, line, `StatsProfile`); Continue as in ProfileStep, `.disabled(draft.style == nil)`.
  - Both steps: `ScrollView` content, 16 pt gutters, `.background(.canvas)`.

- [ ] **Step 1: Write the three views and their previews** — each step previewed with a `@State` draft in a `NavigationStack`: light, dark, AX3; ProfileStep also with a filled draft ("Ana", `.left`) so the selected state shows.
- [ ] **Step 2: Build** — `xcodebuild -scheme Bowling -destination 'platform=iOS Simulator,id=2C568C51-3721-4FB2-90EE-D54EB3308C03' build`. Expected: `** BUILD SUCCEEDED **` with no new warnings.
- [ ] **Step 3: Check previews by hand** — light, dark, AX3: nothing clipped, selected card outlined, Continue dims when off.
- [ ] **Step 4: Commit**

```bash
git add Bowling/Features/Onboarding/ChoiceCard.swift Bowling/Features/Onboarding/ProfileStep.swift Bowling/Features/Onboarding/BowlingStyleStep.swift
git commit -m "Add the Welcome and How do you bowl steps (#6)"
```

### Task 3: Ways to score, the flow, and wiring it into the root

**Files:**
- Create: `Bowling/Features/Onboarding/ScoringModesStep.swift`, `OnboardingFlow.swift`
- Modify: `Bowling/App/RootView.swift` (`OnboardingPlaceholder()` → `OnboardingFlow()`)
- Delete: `Bowling/Features/Onboarding/OnboardingPlaceholder.swift`

**Interfaces:**
- Consumes: `OnboardingDraft.createOwner(in:)`, `ProfileStep`, `BowlingStyleStep` (Tasks 1–2); `AppModel.write`, `AppModel.error`.
- Produces:
  - `struct ScoringModesStep: View { var isSaving: Bool; var onStart: () -> Void }` — title "Ways to score"; three rows (title in `.headline` `.ink`, line in `.inkMuted`) with the spec's copy, "Pin by pin" tagged "Default" with `.monoLabel()` in `.accentText`; footer "You pick one for each session."; Start button styled as Continue, `.disabled(isSaving)`.
  - `struct OnboardingFlow: View` — `@Environment(AppModel.self)`, `@State draft = OnboardingDraft()`, `@State path: [Step]` with `enum Step: Hashable { case style, scoring }`, `@State isSaving = false`; root `ProfileStep` pushes `.style`, which pushes `.scoring`. `start()`: set `isSaving`; `try app.write { try draft.createOwner(in: $0.bowlers) }`; on throw set `app.error = error` and `isSaving = false`.

- [ ] **Step 1: Write `ScoringModesStep` and `OnboardingFlow`** with previews (ScoringModesStep light, dark, AX3; OnboardingFlow with `AppModel(store: try! BowlingStore(inMemory: true))`).
- [ ] **Step 2: Swap the root and delete the placeholder.** Update `RootView`'s comment if it names the placeholder.
- [ ] **Step 3: Run the whole suite** — `xcodebuild test -scheme Bowling -destination 'platform=iOS Simulator,id=2C568C51-3721-4FB2-90EE-D54EB3308C03' -parallel-testing-enabled NO`. Expected: `** TEST SUCCEEDED **`, every earlier test still passing.
- [ ] **Step 4: Walk the flow in the simulator** (fresh install): Continue off until name + hand; Back from step 2 keeps both; style required; Start lands on Home showing the typed name. AX3 with the keyboard up: Continue visible.
- [ ] **Step 5: Commit**

```bash
git add Bowling/Features/Onboarding Bowling/App/RootView.swift
git commit -m "Add Ways to score and run first launch from the root (#6)"
```
