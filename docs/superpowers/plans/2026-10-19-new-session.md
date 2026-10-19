# New Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Home's temporary practice Start with the new-session form: when, where, lineup with the owner's ball, entry mode, notes, and per-event-type remembered values.

**Architecture:** Plain structs carry the logic and are unit tested: `NameSearch` (picker filtering and the Add row), `SessionDefaultsStore` (remembered values in an injected `UserDefaults`), and `NewSessionDraft` (form state, lineup rules, metadata, start). `AppModel.startSession(_:)` writes through `write {}`, saves the defaults, and opens Scoring. SwiftUI views bind to the draft; the root presents the sheet from `AppModel.isStartingSession`, like the Scoring cover.

**Tech Stack:** SwiftUI, Swift Testing, BowlingData (`SessionRepository`, `BowlerRepository`, `BallRepository`), BowlingCore (`EventType`, `EntryMode`, IDs).

**Spec:** `docs/superpowers/specs/2026-10-18-new-session-design.md`

## Global Constraints

- iOS 18 minimum; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and member import visibility: import every module whose types a file uses.
- Contract only: `startSession(_:bowlers:entryMode:)`, `session(_:)`, `centers()`, `leagues()`, `oilPatterns()`, `createCenter(name:)`, `createLeague(name:centerID:)`, `createOilPattern(name:)`, `bowlers()`, `owner()`, `createBowler(name:)`, `activeBalls()`. No package changes.
- `createCenter`, `createLeague`, `createOilPattern` do not trim: the app passes trimmed names.
- D1 colors only through asset symbols (`.canvas`, `.surface`, `.hairline`, `.ink`, `.inkMuted`, `.accent`, `.accentText`).
- Copy exactly as the spec: "New session", "Cancel", "Start", "Practice", "League", "Tournament", "Casual", "Center", "League", "Oil pattern", "Lanes" (placeholder "13–14"), "None", `Add "<text>"`, "Add bowler", "Ball", "No ball", "No balls yet. Add them in Arsenal.", "Pin by pin", "Count", "Final score", "You can switch before the first roll.", "Notes".
- UserDefaults keys: `newSession.defaults.<EventType rawValue>`, `newSession.lastEventType`. Never the synced store.
- Previews are `#if DEBUG`: light, dark, AX5.
- Tests run on iPhone 18 Pro Max (`id=2C568C51-3721-4FB2-90EE-D54EB3308C03`) with `-parallel-testing-enabled NO`, never the iPhone 18 Pro. Tests never touch `UserDefaults.standard`: use `UserDefaults(suiteName: "test.\(UUID())")!`.

Test command (whole suite): `xcodebuild test -scheme Bowling -destination 'id=2C568C51-3721-4FB2-90EE-D54EB3308C03' -parallel-testing-enabled NO`. One suite: add `-only-testing:BowlingTests/<Suite>`.

## Review Focus

1. A name typed with spaces around it ("  Sunset Lanes ") is created trimmed, and an existing name typed in another case ("sunset lanes") offers no Add row — Task 1 tests `addNameIsTrimmed`, `noAddRowForAnExistingNameInAnyCase`.
2. League → Practice → League in one form: Practice's session saves no league, and going back to League restores League's remembered league — Task 3 test `switchingEventsRestoresEachTypesValues`.
3. A double tap on Start creates one session — Task 4 test `secondStartAfterSuccessDoesNothing`.
4. A friend dragged above the owner: Scoring opens on the friend's game and the lineup order is kept — Task 4 test `scoringOpensOnTheFirstLineupBowler`.
5. A remembered ball retired or center deleted since last time: the row starts empty and Start works — Task 3 test `applyingDropsMissingIDs`.

Ruling against the spec's Units ("Home: Start presents the sheet"): the root presents the sheet from `AppModel.isStartingSession`, because the shared alert must be presented by the topmost view (as with Scoring), and `showsError(in:)` needs to know the sheet is up. Home's Start sets the flag.

---

### Task 1: NameSearch

**Files:**
- Create: `Bowling/Features/NewSession/NameSearch.swift`
- Test: `BowlingTests/NewSession/NameSearchTests.swift`

**Interfaces:**
- Produces: `enum NameSearch`
  - `static func filter<T>(_ items: [T], by text: String, name: (T) -> String) -> [T]` — all items when trimmed text is empty; otherwise items whose name contains the trimmed text, case- and diacritic-insensitive (`localizedStandardContains` or `range(of:options: [.caseInsensitive, .diacriticInsensitive])`). Order kept.
  - `static func addName(for text: String, existing: [String]) -> String?` — the trimmed text, or nil when it is empty or equals an existing name case-insensitively.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func emptySearchShowsEverything() {
    #expect(NameSearch.filter(["B", "A"], by: "  ", name: { $0 }) == ["B", "A"])
}
@Test func searchIgnoresCaseAndAccents() {
    let names = ["Café Lanes", "Sunset Lanes", "AMF"]
    #expect(NameSearch.filter(names, by: "cafe", name: { $0 }) == ["Café Lanes"])
    #expect(NameSearch.filter(names, by: " lanes", name: { $0 }) == ["Café Lanes", "Sunset Lanes"])
}
@Test func addNameIsTrimmed() {
    #expect(NameSearch.addName(for: "  Sunset Lanes \n", existing: []) == "Sunset Lanes")
}
@Test func noAddRowForBlankText() {
    #expect(NameSearch.addName(for: " \t", existing: []) == nil)
}
@Test func noAddRowForAnExistingNameInAnyCase() {
    #expect(NameSearch.addName(for: "sunset lanes", existing: ["Sunset Lanes"]) == nil)
    #expect(NameSearch.addName(for: "Sunset", existing: ["Sunset Lanes"]) == "Sunset")
}
```

- [ ] **Step 2: Run** `-only-testing:BowlingTests/NameSearchTests`. Expected: build FAIL, "cannot find 'NameSearch'".
- [ ] **Step 3: Implement `NameSearch`.**
- [ ] **Step 4: Run.** Expected: 5/5 pass.
- [ ] **Step 5: Commit** `git add Bowling/Features/NewSession/NameSearch.swift BowlingTests/NewSession/NameSearchTests.swift` / `git commit -m "feat: picker search and add row (#7)"`

### Task 2: SessionDefaults and SessionDefaultsStore

**Files:**
- Create: `Bowling/Features/NewSession/SessionDefaults.swift`
- Test: `BowlingTests/NewSession/SessionDefaultsStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct SessionDefaults: Codable, Hashable { var centerID: CenterID?; var leagueID: LeagueID?; var oilPatternID: OilPatternID?; var ballID: BallID?; var entryMode: EntryMode? }` (memberwise init with all defaults nil).
  - `struct SessionDefaultsStore { init(_ defaults: UserDefaults = .standard); func defaults(for: EventType) -> SessionDefaults; func save(_: SessionDefaults, for: EventType); var lastEventType: EventType }` — stored as JSON `Data` under `newSession.defaults.<rawValue>`; `save` also writes `lastEventType`. Missing or undecodable data reads as `SessionDefaults()`; a missing or unknown last event type reads as `.practice`.

- [ ] **Step 1: Write the failing tests** (suite holds `let suite = UserDefaults(suiteName: "test.\(UUID())")!`, `store = SessionDefaultsStore(suite)`)

```swift
@Test func valuesRoundTripPerEventType() {
    let d = SessionDefaults(centerID: UUID(), leagueID: UUID(), oilPatternID: UUID(), ballID: UUID(), entryMode: .countOnly)
    store.save(d, for: .league)
    #expect(store.defaults(for: .league) == d)
}
@Test func savingLeagueLeavesPracticeAlone() {
    let practice = SessionDefaults(centerID: UUID(), entryMode: .finalOnly)
    store.save(practice, for: .practice)
    store.save(SessionDefaults(centerID: UUID()), for: .league)
    #expect(store.defaults(for: .practice) == practice)
    #expect(store.defaults(for: .tournament) == SessionDefaults())
}
@Test func unreadableDataReadsAsEmpty() {
    suite.set(Data("nope".utf8), forKey: "newSession.defaults.league")
    #expect(store.defaults(for: .league) == SessionDefaults())
}
@Test func lastEventTypeRoundTrips() {
    #expect(store.lastEventType == .practice)
    store.save(SessionDefaults(), for: .tournament)
    #expect(store.lastEventType == .tournament)
    suite.set("bogus", forKey: "newSession.lastEventType")
    #expect(store.lastEventType == .practice)
}
```

- [ ] **Step 2: Run** `-only-testing:BowlingTests/SessionDefaultsStoreTests`. Expected: build FAIL, "cannot find 'SessionDefaults'".
- [ ] **Step 3: Implement.** `EventType(storedValue:)` maps unknown raw values to `.unknown`; treat `.unknown` as `.practice`.
- [ ] **Step 4: Run.** Expected: 4/4 pass.
- [ ] **Step 5: Commit** `git commit -m "feat: remembered session values per event type (#7)"`

### Task 3: NewSessionDraft

**Files:**
- Create: `Bowling/Features/NewSession/NewSessionDraft.swift`
- Test: `BowlingTests/NewSession/NewSessionDraftTests.swift`

**Interfaces:**
- Consumes: `SessionDefaults` (Task 2).
- Produces:
  - `struct LineupEntry: Hashable, Identifiable { var bowlerID: BowlerID; var name: String; var isOwner: Bool; var ballID: BallID?; var id: BowlerID { bowlerID } }`
  - `struct Available: Hashable { var centers: Set<CenterID>; var leagues: Set<LeagueID>; var oilPatterns: Set<OilPatternID>; var balls: Set<BallID>; static func current(in store: BowlingStore) -> Available }`
  - `struct NewSessionDraft` with `var date: Date`, `var eventType: EventType`, `var centerID: CenterID?`, `var leagueID: LeagueID?`, `var oilPatternID: OilPatternID?`, `var lanes = ""`, `var notes = ""`, `var entryMode: EntryMode = .pinByPin`, `var lineup: [LineupEntry]`
  - `init(owner: BowlerRecord, date: Date, eventType: EventType = .practice)` — lineup is the owner alone, no ball.
  - `mutating func add(_ bowler: BowlerRecord)` — appends unless `bowler.id` is in the lineup.
  - `mutating func remove(atOffsets: IndexSet)` — skips the owner.
  - `mutating func move(fromOffsets: IndexSet, toOffset: Int)`
  - `var ownerBallID: BallID? { get set }` — the owner entry's ball.
  - `var metadata: SessionMetadata` — `leagueID` nil unless `eventType == .league`.
  - `func applying(_ d: SessionDefaults, available: Available) -> NewSessionDraft` — sets center, league, pattern, owner's ball to `d`'s values only when in `available` (else nil), `entryMode` to `d.entryMode ?? .pinByPin`; leaves date, event type, lanes, notes, lineup membership.
  - `var defaults: SessionDefaults` — center, league (nil unless League), pattern, owner's ball, entry mode.
  - `func start(in sessions: SessionRepository) throws -> SessionID` — lineup in order; owner gets `ownerBallID`, friends nil.

- [ ] **Step 1: Write the failing tests** (suite `init` makes `store = try BowlingStore(inMemory: true)`, `owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)`, `friend = try store.bowlers.createBowler(name: "Ana")`)

```swift
@Test func startsWithTheOwnerAlone() {
    let d = NewSessionDraft(owner: owner, date: .now)
    #expect(d.lineup.map(\.bowlerID) == [owner.id])
    #expect(d.lineup.first?.isOwner == true)
    #expect(d.entryMode == .pinByPin)
}
@Test func onlyLeagueSessionsKeepTheLeague() {
    var d = NewSessionDraft(owner: owner, date: .now, eventType: .league)
    d.leagueID = UUID()
    #expect(d.metadata.leagueID == d.leagueID)
    d.eventType = .practice
    #expect(d.metadata.leagueID == nil)
    #expect(d.defaults.leagueID == nil)
}
@Test func ownerCantBeRemoved() {
    var d = NewSessionDraft(owner: owner, date: .now)
    d.add(friend)
    d.remove(atOffsets: [0, 1])
    #expect(d.lineup.map(\.bowlerID) == [owner.id])
}
@Test func addingABowlerTwiceAddsOne() {
    var d = NewSessionDraft(owner: owner, date: .now)
    d.add(friend); d.add(friend); d.add(owner)
    #expect(d.lineup.map(\.bowlerID) == [owner.id, friend.id])
}
@Test func applyingDropsMissingIDs() {
    let kept = UUID()
    let d = NewSessionDraft(owner: owner, date: .now).applying(
        SessionDefaults(centerID: kept, leagueID: UUID(), oilPatternID: UUID(), ballID: UUID(), entryMode: .countOnly),
        available: Available(centers: [kept], leagues: [], oilPatterns: [], balls: []))
    #expect(d.centerID == kept)
    #expect(d.leagueID == nil && d.oilPatternID == nil && d.ownerBallID == nil)
    #expect(d.entryMode == .countOnly)
}
@Test func applyingNothingGivesPinByPinAndNoPicks() {
    var d = NewSessionDraft(owner: owner, date: .now)
    d.centerID = UUID(); d.entryMode = .finalOnly
    d = d.applying(SessionDefaults(), available: Available(centers: [], leagues: [], oilPatterns: [], balls: []))
    #expect(d.centerID == nil && d.entryMode == .pinByPin)
}
@Test func switchingEventsRestoresEachTypesValues() {
    let league = UUID(), center = UUID()
    let all = Available(centers: [center], leagues: [league], oilPatterns: [], balls: [])
    var d = NewSessionDraft(owner: owner, date: .now, eventType: .league)
    d.add(friend); d.lanes = "13–14"
    d = d.applying(SessionDefaults(centerID: center, leagueID: league), available: all)
    d.eventType = .practice
    d = d.applying(SessionDefaults(), available: all)
    #expect(d.metadata.leagueID == nil && d.centerID == nil)
    d.eventType = .league
    d = d.applying(SessionDefaults(centerID: center, leagueID: league), available: all)
    #expect(d.metadata.leagueID == league && d.centerID == center)
    #expect(d.lanes == "13–14" && d.lineup.count == 2)
}
@Test func startCreatesOneGamePerBowlerInLineupOrder() throws {
    let ball = try store.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "Storm")
    var d = NewSessionDraft(owner: owner, date: .now)
    d.add(friend); d.move(fromOffsets: [1], toOffset: 0)
    d.ownerBallID = ball.id; d.entryMode = .countOnly
    let detail = try store.sessions.session(try d.start(in: store.sessions))
    #expect(detail.bowlers.map(\.bowler.id) == [friend.id, owner.id])
    #expect(detail.bowlers.map { $0.games.count } == [1, 1])
    #expect(detail.bowlers[1].games[0].defaultBallID == ball.id)
    #expect(detail.bowlers[0].games[0].defaultBallID == nil)
    #expect(detail.bowlers[0].games[0].entryMode == .countOnly)
}
```


- [ ] **Step 2: Run** `-only-testing:BowlingTests/NewSessionDraftTests`. Expected: build FAIL, "cannot find 'NewSessionDraft'".
- [ ] **Step 3: Implement.** `Available.current(in:)` reads `centers()`, `leagues()`, `oilPatterns()`, `activeBalls()` ids.
- [ ] **Step 4: Run.** Expected: 8/8 pass.
- [ ] **Step 5: Commit** `git commit -m "feat: new session draft (#7)"`

### Task 4: AppModel starts a session from a draft

**Files:**
- Modify: `Bowling/App/AppModel.swift`
- Modify: `BowlingTests/ScoringFlowTests.swift`, `BowlingTests/AppModelTests.swift`
- Test: `BowlingTests/NewSession/StartSessionTests.swift`

**Interfaces:**
- Consumes: `NewSessionDraft.start(in:)`, `.defaults`, `.eventType` (Task 3); `SessionDefaultsStore` (Task 2).
- Produces:
  - `init(store: BowlingStore, sessionDefaults: SessionDefaultsStore = SessionDefaultsStore())`; `let sessionDefaults: SessionDefaultsStore`
  - `var isStartingSession = false` — the sheet is up.
  - `func startSession(_ draft: NewSessionDraft) throws` — does nothing unless `isStartingSession`; writes through `write {}`; after success saves `draft.defaults` for `draft.eventType`, sets `isStartingSession = false`, and sets `scoring` to the first lineup bowler's first game. On throw: nothing saved, `scoring` stays nil, flag stays true.
  - `ErrorPresenter.newSession`; `showsError(in:)`: `.scoring` when `scoring != nil`, else `.newSession` when `isStartingSession`, else `.root`.
  - `startPracticeSession()` stays until Task 6.

- [ ] **Step 1: Write the failing tests** (`StartSessionTests`: app with in-memory store and a fresh suite, owner and friend created through `app.write`, `app.isStartingSession = true`)

```swift
@Test func startOpensScoringAndRemembersValues() throws {
    let center = try app.write { try $0.sessions.createCenter(name: "Sunset") }
    var d = NewSessionDraft(owner: owner, date: .now, eventType: .league)
    d.centerID = center; d.entryMode = .countOnly
    try app.startSession(d)
    let target = try #require(app.scoring)
    #expect(!app.isStartingSession)
    #expect(try app.store.sessions.session(target.sessionID).bowlers.first?.games.first?.id == target.gameID)
    #expect(app.sessionDefaults.defaults(for: .league) == SessionDefaults(centerID: center, entryMode: .countOnly))
    #expect(app.sessionDefaults.lastEventType == .league)
}
@Test func scoringOpensOnTheFirstLineupBowler() throws {
    var d = NewSessionDraft(owner: owner, date: .now)
    d.add(friend); d.move(fromOffsets: [1], toOffset: 0)
    try app.startSession(d)
    let target = try #require(app.scoring)
    let detail = try app.store.sessions.session(target.sessionID)
    #expect(detail.bowlers.map(\.bowler.id) == [friend.id, owner.id])
    #expect(detail.bowlers[0].games[0].id == target.gameID)
}
@Test func failedStartSavesNothing() {
    var d = NewSessionDraft(owner: owner, date: .now, eventType: .tournament)
    d.centerID = UUID()   // not in the store: startSession throws .notFound
    #expect(throws: RepositoryError.notFound) { try app.startSession(d) }
    #expect(app.scoring == nil && app.isStartingSession)
    #expect(app.sessionDefaults.defaults(for: .tournament) == SessionDefaults())
    #expect(app.store.sessions.sessions().isEmpty)
}
@Test func secondStartAfterSuccessDoesNothing() throws {
    let d = NewSessionDraft(owner: owner, date: .now)
    try app.startSession(d)
    try app.startSession(d)
    #expect(app.store.sessions.sessions().count == 1)
}
```

In `AppModelTests`, add `newSessionSheetShowsTheAlertWhileUp`: with `error` set and `isStartingSession = true`, only `.newSession` shows it; with `scoring` also set, only `.scoring`. In `ScoringFlowTests`, replace `startPracticeSession()` with `app.isStartingSession = true; try app.startSession(NewSessionDraft(owner: owner, date: .now))` and inject a fresh suite.

- [ ] **Step 2: Run** `-only-testing:BowlingTests/StartSessionTests`. Expected: build FAIL, "has no member 'startSession'".
- [ ] **Step 3: Implement** in `AppModel.swift`.
- [ ] **Step 4: Run the whole suite.** Expected: all pass.
- [ ] **Step 5: Commit** `git commit -m "feat: start a session from the draft (#7)"`

### Task 5: Pickers

**Files:**
- Create: `Bowling/Features/NewSession/NamedRefPicker.swift`, `AddBowlerPicker.swift`, `BallPicker.swift`

**Interfaces:**
- Consumes: `NameSearch` (Task 1).
- Produces:
  - `NamedRefPicker(title: String, items: [NamedRef], selection: Binding<UUID?>, create: (String) throws -> UUID)` — `.searchable`; None row, filtered items with accent checkmark, `Add "<name>"` from `NameSearch.addName`; picking or adding pops (`@Environment(\.dismiss)`); a throwing `create` sets `app.error` and stays.
  - `AddBowlerPicker(candidates: [BowlerRecord], onPick: (BowlerRecord) -> Void, create: (String) throws -> BowlerRecord)` — same pattern, no None row.
  - `BallPicker(balls: [BallSummary], selection: Binding<BallID?>)` — "No ball" row, then "name · weight lb"; empty `balls` shows "No balls yet. Add them in Arsenal." as the No ball row's footer.

No unit tests: the logic is `NameSearch`. Each view gets light, dark, and AX5 previews with sample data.

- [ ] **Step 1: Implement the three views.**
- [ ] **Step 2: Build** `xcodebuild build -scheme Bowling -destination 'id=2C568C51-3721-4FB2-90EE-D54EB3308C03'`. Expected: BUILD SUCCEEDED, no new warnings.
- [ ] **Step 3: Commit** `git commit -m "feat: center, bowler and ball pickers (#7)"`

### Task 6: NewSessionSheet and wiring

**Files:**
- Create: `Bowling/Features/NewSession/NewSessionSheet.swift`
- Modify: `Bowling/App/RootView.swift`, `Bowling/Features/Home/HomeScreen.swift`, `Bowling/App/AppModel.swift` (delete `startPracticeSession()`)

**Interfaces:**
- Consumes: everything above.
- Produces: `NewSessionSheet()` reading `AppModel` from the environment.

- [ ] **Step 1: Implement `NewSessionSheet`** as the spec's Form sections 1–5. On appear: owner from `app.store.bowlers.owner()`, `eventType = app.sessionDefaults.lastEventType`, then `applying(app.sessionDefaults.defaults(for:), available: .current(in: app.store))`. `.onChange(of: draft.eventType)` re-applies that type's defaults. Lists reload in `.task(id: app.revision)`. Inline creates go through `app.write` with the name from `NameSearch.addName`; a league is created with `draft.centerID`. Owner row `.deleteDisabled(true)`; `.onMove` on the lineup. Start: `do { try app.startSession(draft) } catch { app.error = error }`; Cancel sets `app.isStartingSession = false`. Previews light, dark, AX5 with `AppModel.preview()`.
- [ ] **Step 2: Wire.** RootView: `.sheet(isPresented: $app.isStartingSession) { NewSessionSheet().sharedErrorAlert(in: .newSession) }`. Home's Start sets `app.isStartingSession = true`. Delete `startPracticeSession()`.
- [ ] **Step 3: Run the whole suite.** Expected: all pass, build has no new warnings.
- [ ] **Step 4: Check in the simulator** (iPhone 18 Pro Max): Start opens the sheet; add a center by typing; League shows the League row; add a friend; Start opens Scoring; Start again shows the remembered center. Screenshot at AX5.
- [ ] **Step 5: Commit** `git commit -m "feat: new session sheet (#7)"`
