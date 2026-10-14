# App and Package Contract

Date: 2026-10-14
Status: draft, needs approval from both marilynjov (frontend) and SantiagoM99 (data)
Issue: #1
Spec: `2026-10-07-phase-1-core-scoring-design.md` (cited below as §n)
Team plan: `2026-10-12-team-plan.md`
Aligned with: `Packages/` on main at 784d95b (issues #16 to #26). Where an earlier draft
and the code differed, this document now states what the code does.

This document pins down what the app target (`Bowling/`) may use from the packages
(`Packages/BowlingCore`, `Packages/BowlingData`), so screens can be built against demo
fixtures while the engines are written. The packages expose exactly these names. Any change to this document after it merges needs a PR that both
developers review.

## 0. How to read this

- Every item is tagged **1a** (needed now) or **1b** (deferred; shape listed but not
  pinned until the 1b contract PR).
- Every field cites its source in the spec. Items the spec needs but does not name are
  tagged **Proposed (OQ-n)** and are not final until the matching open question in
  section 9 is answered. Section 9 also records what the merged code does for each
  question; that is evidence for the answer, not the decision.
- Signatures show the public surface only. Bodies, private helpers, and the SwiftData
  `@Model` classes are not part of the contract: the app never sees `Session`, `Game`,
  `Frame`, `Roll`, or `Ball` models (§2), except as allowed by OQ-1.

## 1. Rules for the whole contract

1. **Value types only cross the boundary.** Everything the app receives is a `struct`
   or `enum` that is `Sendable` and `Hashable`. Types that are stored or exported are
   also `Codable`. No SwiftData model, `ModelContext`, or `PersistentIdentifier` is
   returned to the app (§2). The `@Model` classes are internal to BowlingData. The one
   exception on main is `BowlingStore.schema` and `BowlingStore.makeContainer(inMemory:)`,
   which are public (section 3.1, OQ-20).
2. **Identity is a UUID** generated on device (§3.1). Typed aliases keep call sites
   readable; `BallID` is the name the spec already uses (§6, ball report).

   ```swift
   public typealias BowlerID = UUID
   public typealias SessionID = UUID
   public typealias GameID = UUID
   public typealias BallID = UUID
   public typealias CenterID = UUID
   public typealias LeagueID = UUID
   public typealias OilPatternID = UUID
   ```

3. **Order is explicit.** Every array in a returned value is already sorted by
   `gameIndex`, `frameIndex`, or `rollIndex` (§3.1). The app never sorts games, frames,
   or rolls itself and never relies on insertion order.
4. **Enums have an unknown fallback.** Every contract enum is `String`-backed, its raw
   values are the stored strings (§3.1), and decoding an unrecognized raw value yields
   `.unknown` instead of failing. The UI shows `.unknown` as "Other" (§8). Repositories
   never overwrite a stored raw value the app did not explicitly change, so a value
   from a newer app version is preserved on save (§8). Passing `.unknown` to a
   repository write keeps the stored value. Whether every enum gets `.unknown` or only
   those the spec lists is OQ-4.
5. **Engines are pure.** `Scorer`, `LeaveClassifier`, and `StatsEngine` are
   deterministic, `nonisolated`, and synchronous (§2). They can be called from any
   isolation. Anything that depends on "now" or the calendar takes them as parameters.
6. **Repositories are `@MainActor` and synchronous.** They wrap the SwiftData main
   context, `throw` a `RepositoryError` on refusal, and save before returning. A failed
   write rolls the context back, so nothing is saved when one throws. **Proposed (OQ-2).**
7. **Stable string raw values never change.** Enum raw values and stats card IDs are
   persisted (§3.2 Bowler.statsLayout) and synced in phase 2. They may be added, never
   renamed or removed (§3.1, additive only).

## 2. BowlingCore value types

### 2.1 PinSet (1a, §4 "Pins and masks", §3.2 Roll.pinsDownMask)

```swift
public struct PinSet: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: UInt16
    public init(rawValue: UInt16)

    public static let pin1  = PinSet(rawValue: 1 << 0)
    public static let pin2  = PinSet(rawValue: 1 << 1)
    // ... pin3 through pin9
    public static let pin10 = PinSet(rawValue: 1 << 9)
    public static let all: PinSet          // pin1 through pin10

    /// Pin numbers 1...10; numbers outside that range are ignored.
    public init(pins: some Sequence<Int>)
    public var pins: [Int] { get }         // ascending
    public var count: Int { get }
    public func contains(pin: Int) -> Bool
}
```

Rules:

- Bit `n-1` is pin `n`, the same layout as `Roll.pinsDownMask` (§3.2), so the stored
  `Int` and `rawValue` convert without remapping.
- Bits 10 to 15 are always zero. Initializing from a value with those bits set clears
  them.
- `Codable` encodes the bare `rawValue` number.

### 2.2 Enums (1a)

```swift
/// §3.2 Game.entryMode, §4 "Entry modes".
public enum EntryMode: String, Sendable, Hashable, Codable, CaseIterable {
    case pinByPin, countOnly, finalOnly
    case unknown                                   // OQ-4
}

/// §3.2 Session.eventType. Stored default: casual.
public enum EventType: String, Sendable, Hashable, Codable, CaseIterable {
    case practice, league, tournament, casual
    case unknown                                   // OQ-4
    /// league and tournament (§6 "Default scope").
    public static let competition: Set<EventType>
}

/// §3.2 Bowler.statsProfile. Stored default: unknown, treated as casual.
public enum StatsProfile: String, Sendable, Hashable, Codable, CaseIterable {
    case casual, league, competitive, unknown
    /// `.unknown` returns `.casual` (§3.2, §9 "Stats presets").
    public var effective: StatsProfile { get }
}

/// §3.2 Bowler.handedness. Stored default: unknown.
public enum Handedness: String, Sendable, Hashable, Codable, CaseIterable {
    case right, left, unknown
}

/// §3.2 Ball.intendedRole. Stored default: strike.
public enum BallRole: String, Sendable, Hashable, Codable, CaseIterable {
    case strike, spare, both
    case unknown                                   // OQ-4
}
```

Each enum also has `public init(storedValue: String)` that never fails, and its
`init(from: Decoder)` uses the same fallback. Enums used only in 1b (coverstock, core
type, maintenance kind) and only in later phases (invitation status) are not in the 1a
contract.

### 2.3 RollRecord (1a, §3.2 Roll, §4)

```swift
public struct RollRecord: Sendable, Hashable, Codable {
    public var rollIndex: Int          // 1...3 (§3.2)
    public var pinsDown: PinSet        // empty for countOnly rolls and fouls (§3.2)
    public var pinCount: Int           // always set; 0 on a foul (§3.2, §4 "Fouls")
    public var pinsKnown: Bool         // true in pinByPin (§3.2)
    public var isFoul: Bool            // default false (§3.2)
    public var ballID: BallID?         // per-roll override; nil = game's default ball (§3.2)

    public init(rollIndex: Int, pinsDown: PinSet = [], pinCount: Int,
                pinsKnown: Bool, isFoul: Bool = false, ballID: BallID? = nil)
}
```

Rules:

- When `pinsKnown` is true, `pinCount == pinsDown.count`. Whether `Scorer.validate`
  reports a mismatch is OQ-6.
- A foul has `pinCount == 0` and `pinsDown == []` regardless of entry mode (§4).
- No `id`: a roll is identified by its game, `frameIndex`, and `rollIndex` (§3.1
  ordering). See OQ-7.

### 2.4 FrameRecord (1a, §3.2 Frame)

```swift
public struct FrameRecord: Sendable, Hashable, Codable {
    public var frameIndex: Int         // 1...10
    public var rolls: [RollRecord]     // sorted by rollIndex, 0...3 elements
    public init(frameIndex: Int, rolls: [RollRecord])
}
```

`rotationSlot` (Baker, phase 5) is not in the value type until phase 5 needs it.

### 2.5 GameRecord (1a, §3.2 Game, Session; §6 stats inputs)

```swift
public struct GameRecord: Sendable, Hashable, Codable, Identifiable {
    public var id: GameID
    public var bowlerID: BowlerID?                 // §3.2 Game.bowler (optional relationship)
    public var gameIndex: Int                      // 1-based within session for this bowler
    public var entryMode: EntryMode
    public var defaultBallID: BallID?              // §3.2 Game.defaultBall
    public var finalScore: Int                     // cached; typed by the user for finalOnly
    public var isComplete: Bool                    // all ten frames, or finalOnly
    public var frames: [FrameRecord]               // sorted by frameIndex; [] for finalOnly

    // Session context copied in by the repository, because StatsEngine takes only
    // [GameRecord] (§6) yet needs dates, event types, and series grouping.
    public var sessionID: SessionID?               // high game "with date and session", high series
    public var sessionDate: Date                   // trend, date filters
    public var eventType: EventType                // competition default scope

    // 1b, added when the 1b filters and ball report land (§6 Filters, By condition):
    // public var centerID: CenterID?
    // public var leagueID: LeagueID?
    // public var oilPatternID: OilPatternID?

    /// Public because Swift's memberwise init is internal and other packages
    /// (BowlingData, fixtures, tests) must build games (#17, PR #52).
    public init(
        id: GameID = GameID(), bowlerID: BowlerID? = nil, gameIndex: Int,
        entryMode: EntryMode, defaultBallID: BallID? = nil, finalScore: Int,
        isComplete: Bool, frames: [FrameRecord] = [],
        sessionID: SessionID? = nil, sessionDate: Date, eventType: EventType
    )
}
```

Rules:

- The repository fills session context on every conversion; the app treats it as
  read-only on a `GameRecord`. Session context on the record is **Proposed (OQ-8)**.
  A game with no session gets `sessionID == nil`, `sessionDate` = the game's
  `createdAt`, and `eventType == .unknown`.
- Only `isComplete == true` games count toward any stat (§6). `StatsEngine` enforces
  this itself, so callers may pass incomplete games.
- What `finalScore` holds while a game is incomplete is OQ-9.

### 2.6 Mark, scorecard, and roll positions (1a, §4)

`Mark` is named and specified by the spec:

```swift
/// §4 "Marks for display".
public enum Mark: Sendable, Hashable, Codable {
    case strike
    case spare
    case count(Int)      // 1...9
    case gutter          // zero on a roll where pins were available
    case foul            // shown as F
}
```

The scorecard strip, pending running totals, and the pin deck's disabled pins also need
Scorer output that the spec describes but does not name. **Proposed (OQ-3):**

```swift
public struct FrameScore: Sendable, Hashable {
    public var frameIndex: Int
    public var marks: [Mark]           // one per roll, in rollIndex order
    public var runningTotal: Int?      // nil until bonus rolls exist (§4 "Score computation")
    public init(frameIndex: Int, marks: [Mark], runningTotal: Int?)
}

public struct Scorecard: Sendable, Hashable {
    public var frames: [FrameScore]    // always 10 entries, frameIndex 1...10
    public var finalScore: Int?        // tenth frame's running total, or the typed score
                                       // of a finalOnly game; nil until known
    public init(frames: [FrameScore], finalScore: Int?)
}

/// Where the next roll goes and what the bowler faces.
public struct RollPosition: Sendable, Hashable {
    public var frameIndex: Int
    public var rollIndex: Int
    public var standingPins: PinSet    // pins the deck enables (§7 Scoring 3); all ten when
                                       // earlier rolls on this rack were countOnly
    public var standingCount: Int      // most the roll can knock down; the countOnly pad's bound
    public var isFreshRack: Bool       // counts as a first ball (§6 "First balls")
    public init(frameIndex: Int, rollIndex: Int, standingPins: PinSet,
                standingCount: Int, isFreshRack: Bool)
}
```

Rules:

- `FrameScore` carries no leave. The scorecard's split indicator (§4) is not delivered by
  `Scorer`; the app would have to call `LeaveClassifier` itself, which section 7 forbids.
  See OQ-3.
- A finalOnly game's scorecard has ten frames with no marks and no running totals.
- `standingCount` exists because `standingPins` cannot bound count entry: after a
  countOnly roll the pin identities are unknown (§7 "Count mode ... limited to pins
  available").

### 2.7 Leave (1a, §5)

```swift
/// Not stored (recomputed from the roll's PinSet), so it has no `.unknown` case.
public enum LeaveKind: String, Sendable, Hashable, Codable, CaseIterable {
    case strike, singlePin, makeable, split
}

public struct Leave: Sendable, Hashable, Codable {
    public var pins: PinSet            // standing after the first ball
    public var kind: LeaveKind
    public var isWashout: Bool
    public init(pins: PinSet, kind: LeaveKind, isWashout: Bool)
    public var name: String { get }    // ascending pin numbers joined by "-", e.g. "3-6-10";
                                       // empty for a strike
}
```

`LeaveDiagramView` (app, §7) draws a `Leave`: standing pins from `pins`, the split
marker from `kind == .split`, and the caption from `name`. `name` is not localized; the
accessibility label ("Leave 3, 6, 10, makeable", §10) is built by the app.

### 2.8 Engines (1a)

```swift
public enum Scorer {
    /// §4 "Validation". Empty means valid.
    public static func validate(_ game: GameRecord) -> [ScoringError]
    /// Proposed (OQ-3). Best effort on an invalid game: duplicates and out-of-range
    /// indices are dropped.
    public static func scorecard(for game: GameRecord) -> Scorecard
    /// Proposed (OQ-3). nil when the game is complete or finalOnly.
    public static func nextRoll(in game: GameRecord) -> RollPosition?
}

/// §4 "Validation": every violation the spec lists.
public enum ScoringError: Sendable, Hashable, Error {
    case pinsExceedAvailable(frameIndex: Int, rollIndex: Int)
    case notSubsetOfStanding(frameIndex: Int, rollIndex: Int)    // pinByPin roll 2 (and frame 10)
    case outOfOrder(frameIndex: Int)                             // frames or rolls out of order
    case duplicateIndex(frameIndex: Int, rollIndex: Int?)        // rollIndex nil = duplicate frame
    case unearnedThirdRoll                                       // frame 10
    case rollAfterStrike(frameIndex: Int)                        // frames 1...9
    case foulWithPins(frameIndex: Int, rollIndex: Int)
    case finalScoreOutOfRange                                    // finalOnly, 0...300 (§4)
}

public enum LeaveClassifier {
    /// §5. Input is the set left standing after a first ball.
    public static func classify(_ standing: PinSet) -> Leave
}

public enum StatsEngine {
    /// §6. `games` is already filtered; `filter` is for labeling.
    public static func report(games: [GameRecord], filter: StatsFilter) -> StatsReport
    /// §6 "Default scope" over games already in memory: EventType.competition when
    /// `preferCompetition` and `bowler` has a complete league or tournament game in
    /// `games`; otherwise every event type, `.unknown` included. StatsRepository has the
    /// store-backed version (section 3.7).
    public static func defaultEventTypes(games: [GameRecord], bowler: BowlerID,
                                         preferCompetition: Bool) -> Set<EventType>
    // 1b: ballReport(for:games:) -> BallReport, compareBalls(games:) -> [BallComparisonRow]
}
```

`ScoringError` case names are proposed; the set of cases traces to §4. A
`finalScoreOutOfRange` case is included because §4 bounds `finalScore` to 0...300 and
repositories refuse invalid games. `outOfOrder` also covers an index out of range or
skipped, rolls after an unfinished frame, and a roll after a spare or open in frames 1
to 9. `validate` does not compare `pinCount` with `pinsDown.count` (OQ-6).

## 3. Repositories (BowlingData)

### 3.1 Shape (Proposed, OQ-2)

```swift
@MainActor
public final class BowlingStore {
    /// inMemory: an empty store never written to disk, for tests and previews.
    public init(inMemory: Bool = false) throws
    public let sessions: SessionRepository
    public let games: GameRepository
    public let bowlers: BowlerRepository
    public let balls: BallRepository
    public let stats: StatsRepository

    // Public on main but outside the value-type boundary (OQ-20):
    public nonisolated static var schema: Schema { get }
    /// CloudKit off until phase 2.
    public nonisolated static func makeContainer(inMemory: Bool = false) throws -> ModelContainer
}

public enum RepositoryError: Error, Sendable, Hashable {
    case notFound
    case invalidGame([ScoringError])          // §4: repositories refuse invalid games
    case entryModeLocked                      // §8: mode fixed once the first roll exists
    case bowlerHasGames(count: Int)           // §3.3
    case cannotDeleteOwner                    // §3.3
    case ownerAlreadyExists                   // §3.2 Bowler.isOwner: one owner per user
    case invalidBall(BallFieldError)          // §3.2 Ball: name required, weight 6...16
}

public enum BallFieldError: Sendable, Hashable { case emptyName, weightOutOfRange }
```

All repository methods are `@MainActor`, synchronous, and save before returning. None
are `async` in 1a. Nothing is saved when one throws. `.invalidGame([])` (no scoring
errors) is the refusal for a write that does not apply to the game at all: roll input of
the other entry mode, a roll on a finalOnly or complete game, or a typed score on a game
scored from rolls.

### 3.2 Read models returned to screens (Proposed, OQ-1)

```swift
public struct BowlerRecord: Sendable, Hashable, Identifiable {
    public var id: BowlerID
    public var name: String
    public var isOwner: Bool
    public var handedness: Handedness
    public var statsProfile: StatsProfile          // meaningful on the owner only
    public var statsLayout: [String]               // raw card IDs; [] = preset (§3.2, §7)
    public var homeLayout: [String]                // raw card IDs; [] = preset
}

public struct SessionSummary: Sendable, Hashable, Identifiable {   // History row (§7)
    public var id: SessionID
    public var date: Date
    public var eventType: EventType
    public var centerName: String?
    public var leagueName: String?
    public var bowlerCount: Int
    public var games: [GameRecord]                 // grouped by bowler (owner first, then
                                                   // by name), each by gameIndex; games with
                                                   // no bowler last
    public var isComplete: Bool                    // every game complete (OQ-10)
}

public struct SessionDetail: Sendable, Hashable, Identifiable {
    public var id: SessionID
    public var metadata: SessionMetadata
    public var bowlers: [SessionBowler]            // owner first, then by name (OQ-11)
}

public struct SessionBowler: Sendable, Hashable {
    public var bowler: BowlerRecord
    public var games: [GameRecord]                 // sorted by gameIndex
    public var seriesTotal: Int                    // sum of cached final scores, incomplete
                                                   // games included (§3.2 Session, OQ-9)
}

public struct SessionMetadata: Sendable, Hashable {
    public var date: Date
    public var eventType: EventType                // writing .unknown keeps the stored value
    public var centerID: CenterID?
    public var leagueID: LeagueID?                 // only meaningful for league (§3.2)
    public var oilPatternID: OilPatternID?
    public var lanes: String
    public var notes: String
    public init(date: Date, eventType: EventType, centerID: CenterID? = nil,
                leagueID: LeagueID? = nil, oilPatternID: OilPatternID? = nil,
                lanes: String = "", notes: String = "")
}

public struct NamedRef: Sendable, Hashable, Identifiable {         // center, league, pattern pickers
    public var id: UUID
    public var name: String
}

public struct BallSummary: Sendable, Hashable, Identifiable {      // Arsenal list, ball picker (§7)
    public var id: BallID
    public var name: String
    public var brand: String
    public var weightPounds: Int
    public var intendedRole: BallRole
    public var gamesBowled: Int                    // §3.2 derived value: default ball or any
                                                   // roll override, each game once
}
```

Only `SessionMetadata` (and `RollEditOutcome`, section 3.4) has a public init; the other
read models are built by the repositories only.

### 3.3 SessionRepository (1a)

```swift
@MainActor public final class SessionRepository {
    /// History and Home's recent list. Date descending, then createdAt descending (OQ-11).
    public func sessions() -> [SessionSummary]
    public func session(_ id: SessionID) throws -> SessionDetail
    /// Home "Resume session" (§7). Newest session in `sessions()` order with an
    /// incomplete game (OQ-10).
    public func resumableSession() -> SessionSummary?

    /// New session "Start" (§7): creates the session and game 1 for each bowler.
    /// Returns the session; games are read back with `session(_:)`. Throws .notFound
    /// for a missing bowler, ball, center, league, or pattern. `.unknown` entry mode
    /// keeps the stored default (pinByPin).
    public func startSession(_ metadata: SessionMetadata,
                             bowlers: [(bowlerID: BowlerID, defaultBallID: BallID?)],
                             entryMode: EntryMode) throws -> SessionID
    /// Home "Quick score" (§7): casual session dated `now`, one complete finalOnly game
    /// for the owner. Throws .notFound before first launch, .invalidGame outside 0...300.
    public func quickScore(finalScore: Int, now: Date) throws -> SessionID
    /// History edit (§7), including changing a Quick score's event type.
    public func updateMetadata(_ id: SessionID, _ metadata: SessionMetadata) throws
    /// Cascades to games, frames, rolls (§3.3).
    public func deleteSession(_ id: SessionID) throws
    /// §8: backing out before anything was entered deletes the session. No-op when any
    /// game has a roll or is complete (a typed finalOnly score). Throws .notFound.
    public func discardIfUnstarted(_ id: SessionID) throws

    // Pickers with inline create (§7 New session). Sorted by name (localized standard
    // compare). createLeague throws .notFound for a missing center.
    public func centers() -> [NamedRef]
    public func leagues() -> [NamedRef]
    public func oilPatterns() -> [NamedRef]
    public func createCenter(name: String) throws -> CenterID
    public func createLeague(name: String, centerID: CenterID?) throws -> LeagueID
    public func createOilPattern(name: String) throws -> OilPatternID
}
```

Remembering the last-used center, league, pattern, and ball per event type is app-side
`UserDefaults` (§7) and not part of this contract.

### 3.4 GameRepository (1a, rolls included)

```swift
/// What the Scoring screen sends for one delivery (§7 Scoring 4 and 5).
public enum RollInput: Sendable, Hashable {
    case pins(PinSet)          // pinByPin: the pins that fell on this roll
    case count(Int)            // countOnly
    case foul                  // either mode
}

public struct RollEditOutcome: Sendable, Hashable {
    public var game: GameRecord
    public var clearedFrames: [Int]     // §8: frames that lost rolls, ascending
    public init(game: GameRecord, clearedFrames: [Int])
}

@MainActor public final class GameRepository {
    public func game(_ id: GameID) throws -> GameRecord

    /// Appends at Scorer.nextRoll(in:). Validates, saves after every roll (§8).
    /// Throws .invalidGame with the violations if the roll does not fit; .invalidGame([])
    /// for other-mode input, a finalOnly game, or a complete game; .notFound for a missing
    /// game or ball.
    public func recordRoll(_ input: RollInput, ballID: BallID?, in game: GameID) throws -> GameRecord
    /// §7 Undo. Removes the last roll, and its frame once empty. Returns the game
    /// unchanged when it has no rolls.
    public func undoLastRoll(in game: GameID) throws -> GameRecord
    /// §8: editing an earlier roll re-validates later rolls and clears every roll from
    /// the first invalid one onward. Throws .notFound for a missing game, roll, or ball;
    /// .invalidGame when the new roll itself does not fit.
    public func replaceRoll(frameIndex: Int, rollIndex: Int, with input: RollInput,
                            ballID: BallID?, in game: GameID) throws -> RollEditOutcome

    /// §8: allowed only before the first roll, else throws .entryModeLocked.
    /// `.unknown` never locks and keeps the stored mode.
    public func setEntryMode(_ mode: EntryMode, for game: GameID) throws
    /// §8: the offer made after .entryModeLocked.
    public func clearRolls(in game: GameID) throws -> GameRecord
    /// Throws .notFound for a missing ball.
    public func setDefaultBall(_ ballID: BallID?, for game: GameID) throws
    /// finalOnly only, 0...300 (§4). Marks the game complete. Throws
    /// .invalidGame([.finalScoreOutOfRange]), or .invalidGame([]) on a game scored from rolls.
    public func setFinalScore(_ score: Int, for game: GameID) throws
    /// §7 "Next game": game gameIndex + 1 for every bowler, with the entry mode and
    /// default ball of that bowler's latest game. Returned in the session's bowler order.
    public func startNextGame(in session: SessionID) throws -> [GameID]
    public func deleteGame(_ id: GameID) throws
}
```

Rules:

- The repository, not the app, sets `rollIndex`, `pinCount`, `pinsKnown`, and
  `isComplete`, and recomputes the cached `finalScore` with `Scorer` on every write.
  Before frame 10 is finished, the cached `finalScore` is the last known running total
  (OQ-9). `isComplete` is true when `Scorer.nextRoll(in:)` is nil.
- A foul in a pinByPin game is stored with `pinsKnown == true`.
- The single write path, `save(_:)`, is internal; the app writes only through the
  methods above.
- `.pins` on a countOnly game, or `.count` on a pinByPin game, is refused with
  `.invalidGame`. Any roll on a finalOnly game is refused.
- Whether "tap what is left standing" (§7) is converted by the app before calling
  `recordRoll(.pins(_:))` is up to the app: the repository always receives fallen pins.

### 3.5 BowlerRepository (1a)

```swift
@MainActor public final class BowlerRepository {
    /// nil before first launch completes.
    public func owner() -> BowlerRecord?
    /// Owner first, then others by name (OQ-11).
    public func bowlers() -> [BowlerRecord]

    /// First launch (§7). Throws .ownerAlreadyExists.
    public func createOwner(name: String, handedness: Handedness,
                            statsProfile: StatsProfile) throws -> BowlerRecord
    /// New session "add others by name" (§7).
    public func createBowler(name: String) throws -> BowlerRecord
    /// Throws .notFound before first launch. `.unknown` handedness keeps the stored value.
    public func updateOwner(name: String, handedness: Handedness) throws
    /// Settings bowling style (§7). Leaves a customized layout alone. Throws .notFound
    /// before first launch. `.unknown` keeps the stored value.
    public func setStatsProfile(_ profile: StatsProfile) throws
    /// §3.3: .cannotDeleteOwner, .bowlerHasGames(count:).
    public func deleteBowler(_ id: BowlerID) throws

    // 1b: setStatsLayout(_:), setHomeLayout(_:), resetLayouts() (§7 Customize).
}
```

`statsLayout` and `homeLayout` are the stored comma-separated strings split on ",",
unknown IDs kept. Settings "delete all data with double confirmation" (§7) needs a
repository method; none exists on main. Which repository owns it is OQ-12.

### 3.6 BallRepository (1a basic, §7 Arsenal 1a)

```swift
@MainActor public final class BallRepository {
    /// Non-retired balls, by name (OQ-13; no role-based picker order on main).
    public func activeBalls() -> [BallSummary]
    /// Name, weight, intended role, brand only (§7 Arsenal 1a). The name is trimmed;
    /// `.unknown` role keeps the stored default (strike).
    /// Throws .invalidBall(.emptyName) or .invalidBall(.weightOutOfRange).
    public func addBall(name: String, weightPounds: Int,
                        intendedRole: BallRole, brand: String) throws -> BallSummary

    // 1b: full add/edit form, photo, retire, delete with affected-game count (§3.3),
    // maintenance log, resurface due, ballReport, compare.
}
```

### 3.7 StatsRepository (1a)

```swift
@MainActor public final class StatsRepository {
    /// Applies the filter as a SwiftData predicate (1a needs no in-memory pass, §6) and
    /// returns games of every completion state for StatsEngine, sorted by sessionDate,
    /// then gameIndex. thisSeason is the last nine months. Games with no session or no
    /// bowler never match.
    public func games(matching filter: StatsFilter, now: Date, calendar: Calendar) -> [GameRecord]
    /// seasonLeague: the league whose seasonStart and seasonEnd thisSeason uses when both
    /// are set and in order. It does not restrict games to that league; in 1b it becomes
    /// the filter's league.
    public func games(matching filter: StatsFilter, seasonLeague: LeagueID?,
                      now: Date, calendar: Calendar) -> [GameRecord]
    /// §6 "Default scope": EventType.competition when the bowler has at least one
    /// complete league or tournament game and `preferCompetition` is true; otherwise
    /// every event type, `.unknown` included.
    public func defaultEventTypes(for bowler: BowlerID, preferCompetition: Bool) -> Set<EventType>
}
```

The app calls `stats.games(matching:now:calendar:)` and then `StatsEngine.report(games:filter:)`
(§2: feature models "call repositories, and run engines"). Where the "default stats
scope" setting is stored is OQ-14.

## 4. Stats (1a)

### 4.1 StatsFilter (§6 "Filters")

```swift
public enum DatePreset: String, Sendable, Hashable, Codable, CaseIterable {
    case thisWeek, thisMonth, last30Days, thisSeason, allTime
}

public struct StatsFilter: Sendable, Hashable, Codable {
    public var datePreset: DatePreset
    /// "All games" is every case, `.unknown` included; "Competition" is EventType.competition.
    public var eventTypes: Set<EventType>
    public var bowlerID: BowlerID                  // OQ-15
    // 1b: customRange: ClosedRange<Date>?, ballID, oilPatternID, centerID, leagueID

    public init(datePreset: DatePreset = .allTime,
                eventTypes: Set<EventType> = Set(EventType.allCases),
                bowlerID: BowlerID)

    /// Resolves the preset by calendar day in `calendar`'s time zone (§8). Half-open:
    /// start <= date < end; nil = all time. In 1a there is no league filter, so
    /// thisSeason is always the last 9 months (§6).
    public func dateInterval(now: Date, calendar: Calendar) -> DateInterval?
    /// leagueSeason: the league's seasonStart and seasonEnd, when both exist. thisSeason
    /// then covers those calendar days, the end day included. Other presets ignore it.
    public func dateInterval(now: Date, calendar: Calendar,
                             leagueSeason: DateInterval?) -> DateInterval?
    /// The in-memory form of the filter: bowler, event type, and date. Incomplete games
    /// match too; StatsEngine excludes them.
    public func matches(_ game: GameRecord, now: Date, calendar: Calendar,
                        leagueSeason: DateInterval? = nil) -> Bool
}
```

`DatePreset` raw values are persisted with a saved filter, so the stable raw value rule
(section 1, rule 7) applies to them. A stored event type this version does not know
matches only when `.unknown` is selected, which "All games" always does.

### 4.2 StatsReport (§6 "Definitions (1a)")

Every number carries the sample it was computed from (§6), so the UI can show "63% of
41 attempts" and never divides by zero (§8).

```swift
public struct Rate: Sendable, Hashable, Codable {
    public var hits: Int
    public var attempts: Int
    public init(hits: Int, attempts: Int)
    public var value: Double? { get }              // nil when attempts == 0
}

public struct Mean: Sendable, Hashable, Codable {
    public var total: Int
    public var count: Int
    public init(total: Int, count: Int)
    public var value: Double? { get }              // nil when count == 0
}

public struct GameRef: Sendable, Hashable, Codable {
    public var gameID: GameID
    public var sessionID: SessionID?
    public var date: Date
}

public struct HighGame: Sendable, Hashable, Codable {
    public var score: Int
    public var game: GameRef                       // "with date and session"
}

public struct HighSeries: Sendable, Hashable, Codable {
    public var gameCount: Int                      // 3 = three-game series
    public var total: Int
    public var sessionID: SessionID?
    public var date: Date
}

public struct TrendPoint: Sendable, Hashable, Codable {
    public var sessionID: SessionID?
    public var date: Date
    public var sessionAverage: Mean
    public var rollingAverage: Mean                // last nine complete games up to the end
                                                   // of this session, or all when fewer (OQ-16)
}

public struct LeaveRow: Sendable, Hashable, Codable {
    public var leave: Leave
    public var conversion: Rate                    // hits = converted, attempts = count
}

public struct StatsReport: Sendable, Hashable, Codable {
    public var filter: StatsFilter

    // Sample size per applicability group (§6 "Which games count for what").
    public var scoreGames: Int                     // complete games, all modes
    public var rollGames: Int                      // complete countOnly + pinByPin
    public var pinGames: Int                       // complete pinByPin

    // Overview (scoreGames)
    public var average: Mean
    public var averageLast10: Mean                 // last by session date, session, gameIndex (OQ-19)
    public var averageLast30: Mean
    public var highGame: HighGame?
    public var highSeries: [HighSeries]            // best per gameCount, ascending gameCount
    public var trend: [TrendPoint]                 // one point per session, ascending date

    // Strikes and spares (rollGames)
    public var firstBalls: Int
    public var strikes: Rate                       // strikes / first balls
    public var spares: Rate                        // spares / spare attempts (the only spare %)
    public var fouls: Mean                         // fouls per game

    // Leaves (pinGames)
    public var splitRate: Rate                     // split leaves / spare attempts
    public var splitConversion: Rate
    public var makeableConversion: Rate            // makeable + single-pin
    public var singlePinConversion: Rate
    public var leaves: [LeaveRow]                  // count descending; ties by pin numbers
                                                   // ascending (OQ-17)
    public var leftMostMadeLeast: LeaveRow?        // most misses (count x miss rate); ties go
                                                   // to the row higher in `leaves`; nil when
                                                   // nothing was missed; no minimum count (OQ-17)

    // 1b: openFrames, cleanGames, headPin, firstBallAverage, byFrame, whatIfSinglePins
}
```

`GameRef`, `HighGame`, `HighSeries`, `TrendPoint`, `LeaveRow`, and `StatsReport` also
have public memberwise-style inits on main (for tests and fixtures); the app reads
reports and does not build them.

Rules:

- `StatsEngine` ignores incomplete games and applies the applicability table itself:
  a finalOnly game never contributes to `firstBalls`, a countOnly game never to
  `leaves` (§6).
- Spare attempts after a first-ball foul count against a full rack and produce no leave
  (§5, §6).
- A complete game with an `.unknown` entry mode counts toward the overview (scoreGames)
  only, never toward roll or pin stats.
- The default high series shown in 1a is the three-game series (§6; the league-based
  default needs the 1b league filter).
- Home's "competition average with the all-games average beneath" (§6, §7) is two
  reports: the app requests one with `EventType.competition` and one with every event
  type.

### 4.3 Stats card IDs (§7 "Card catalog")

The raw values below are persisted in `Bowler.statsLayout` and `homeLayout` and synced
from phase 2. **They never change.** New cards add new cases.

```swift
public enum StatsCardID: String, Sendable, Hashable, Codable, CaseIterable {
    // Overview (1a)
    case average, highGame, highSeries
    // Trend (1a)
    case trendChart
    // Strikes and spares (1a)
    case strikePct, sparePct, fouls
    // Strikes and spares (1b)
    case openPct, cleanGamePct, firstBallAverage, headPinRate
    // Leaves (1a)
    case leavesTable, leftMostMadeLeast, splitConversion, makeableConversion, singlePinConversion
    // By frame (1b)
    case byFrameStrike, byFrameAverage
    // What if (1b)
    case whatIfSinglePins

    public var group: StatsCardGroup { get }
    /// False for 1b cards until 1b ships (§7 "Presets").
    public var isAvailable: Bool { get }
}

public enum StatsCardGroup: String, Sendable, Hashable, Codable, CaseIterable {
    case overview, trend, strikesAndSpares, leaves, byFrame, whatIf
}

public enum StatsPreset {
    /// §7 preset table, in display order, available cards only.
    public static func statsCards(for profile: StatsProfile) -> [StatsCardID]
    public static func homeTiles(for profile: StatsProfile) -> [StatsCardID]
    /// casual -> false ("All games"); league, competitive -> true ("Competition") (§6).
    public static func prefersCompetition(_ profile: StatsProfile) -> Bool
    // Not on main: displayedCards(layout:profile:). See below and OQ-21.
}
```

`StatsPreset.displayedCards(layout:profile:)` from the earlier draft is **not
implemented** in any form. PR #54 (#25) left it out because one function cannot tell
whether an empty layout falls back to the Stats or the Home preset, and suggested
splitting it into a Stats and a Home function or adding a surface parameter. Until OQ-21
is answered, the app has no package function that applies the §7 layout rules; since 1a
layouts are always empty, `statsCards(for:)` and `homeTiles(for:)` are what 1a screens
use.

Rules:

- `.unknown` profile uses the casual preset (§3.2, §9).
- `competitive` is every available card in `CaseIterable` order (§7 "every card"), which
  is the catalog order (OQ-18).
- `StatsCardID` has no `.unknown` case: layouts are stored as raw strings and unknown
  IDs are skipped on display, so no fallback case is needed.
- In 1a the league preset omits `openPct` until 1b ships (§7).
- A card whose group has zero games (for example `leavesTable` when `pinGames == 0`)
  stays in place and shows an explanation (§7 "Layout rules"); the copy is the app's.
- Saving a layout (1b) keeps unknown IDs (§7).

## 5. Demo fixture data (1a, §2, §9, issue #22)

Previews and StatsEngine tests read the same games. They live in the `BowlingFixtures`
library product of the BowlingCore package, which depends only on BowlingCore
(**Proposed, OQ-5**). The app imports `BowlingFixtures` for previews; BowlingData uses
it only in its test target.

Bowlers, balls, sessions, and games are plain enums with fixed IDs, not
`BowlerRecord`/`BallSummary` values (those are BowlingData types, which BowlingFixtures
cannot depend on). Every ID is a fixed, readable UUID, so tests and previews can name a
game or session directly.

```swift
import BowlingCore

public enum DemoFixture {
    /// 2026-10-14 12:00 UTC. Tests pass this; previews pass Date.now.
    public static let referenceDate: Date
    /// Every DemoGame (22), in DemoGame.allCases order. Session dates are whole days
    /// before `now` in the Gregorian calendar, so a date preset always selects the
    /// same games.
    public static func games(relativeTo now: Date) -> [GameRecord]
}

public enum DemoBowler: Int, CaseIterable, Sendable {
    case owner = 1      // games in every event type and entry mode
    case partner        // bowls the league night with the owner
    case friend         // only casual and practice games: the "All games" fallback (§6)
    public var id: BowlerID { get }
    public var name: String { get }
}

public enum DemoBall: Int, CaseIterable, Sendable {
    case ownerStrike = 1, ownerSpare, partnerStrike
    public var id: BallID { get }
    public var owner: DemoBowler { get }
    public var name: String { get }
    public var role: BallRole { get }
}

public enum DemoSession: Int, CaseIterable, Sendable {
    case leagueNight = 1     // three games, owner and partner
    case tournament          // four games: a three- and a four-game series
    case earlyLeague, practice, casualOuting
    case practiceInProgress  // holds the one incomplete game, for Resume
    case friendCasual, friendPractice
    public var id: SessionID { get }
    public var eventType: EventType { get }
    public var daysAgo: Int { get }   // spread across this week, last 30 days, and older
}

public enum DemoGame: Int, CaseIterable, Sendable {
    // 22 cases, ordered by session, then bowler, then gameIndex. tournament1 is a
    // perfect game; earlyLeague1 is all spares (150).
    public var id: GameID { get }
    public var session: DemoSession { get }
    public var bowler: DemoBowler { get }
}
```

Rules:

- `DemoBall` has no weight or brand and `DemoBowler` no handedness or stats profile, so a
  preview that needs a `BallSummary` or `BowlerRecord` fills those itself.
- There is **no seeded demo store** on main: the earlier draft's
  `BowlingStore.demo(now:)` does not exist. BowlingData seeds fixture games into its own
  test stores with test-only helpers. Whether previews get a seeded store is OQ-22.

Coverage the games must include, each traced to §9 or a 1a screen:

| Case | Source |
|---|---|
| All three entry modes | §9 StatsEngine |
| All four event types, at least one league and one tournament game | §9 |
| Fouls: first-ball foul then full-rack spare, second-ball foul, a tenth-frame foul | §9 Scorer, §6 |
| At least one incomplete game (excluded from stats, shown in History and Resume) | §9, §7 Home |
| A bowler with only casual and practice games (fallback to "All games") | §9 |
| A three-game league session for two bowlers (series, bowler strip) | §7, §11 |
| Splits, a washout, a sleeper (2-8 or 3-9), single-pin leaves made and missed | §5, §7 Leaves |
| A roll with a ball override differing from the game's default ball | §3.2, §7 Scoring |
| A perfect game and an all-spares game | §11 |

All rows are covered on main (`DemoGames.swift`): for example leagueNight1 has a
first-ball foul then a spare, a 2-8 sleeper, a 1-2-10 washout, and a roll with the spare
ball as override; leagueNight2 a second-ball foul; tournament4 a tenth-frame foul.

Expected values for every 1a stat are hand-computed and live in the BowlingCore test
target (`Tests/BowlingCoreTests/Fixtures/`), not in the shipped fixture (OQ-5).

## 6. Deferred to 1b (not pinned here)

Listed so nobody builds against a guess. Each gets its own contract PR before 1b work
starts.

- `StatsFilter` custom range, ball, oil pattern, center, league (§6); `GameRecord`
  center, league, pattern IDs.
- `StatsReport` 1b fields: open frame %, clean game %, head pin rate, first-ball average,
  by-frame, what-if (§6).
- Leave occurrences: date, session, frame number, ball on the spare attempt (§6).
- `BallReport`, `BallComparisonRow`, `StatsEngine.ballReport(for:games:)`,
  `compareBalls(games:)` (§6 "Ball report").
- Full `BallRecord`, coverstock and core enums, maintenance events, retire, delete with
  affected-game count, resurface due (§3.2, §7 Arsenal 1b).
- Layout writes from Customize and "Reset to preset" (§7).
- Ball, center, league, pattern delete warnings (§3.3).
- CSV export (§7 Settings 1b).
- Owner merge and duplicate frame repair are BowlingData-internal and never reach the
  app (§3.4).

## 7. What the app may not do

- Import SwiftData or touch `ModelContext`, except as decided in OQ-1 and OQ-20.
- Compute scores, leaves, marks, or stats itself. It renders `Scorecard`, `Leave`, and
  `StatsReport`.
- Sort games, frames, or rolls, or compare raw enum strings.
- Persist card IDs in any form other than the `StatsCardID` raw values.

## 8. Approval

- [ ] marilynjov (frontend)
- [ ] SantiagoM99 (data)

## 9. Open questions for both developers

1. **OQ-1, `@Query` versus value types.** §2 lets views use `@Query` "for simple lists",
   which hands SwiftData models to the app. AGENTS.md says the app talks to packages
   only through the contract. Proposal: no `@Query` in 1a; lists come from repository
   read models (section 3.2). Are the read models (`BowlerRecord`, `SessionSummary`,
   `SessionDetail`, `BallSummary`, `NamedRef`) acceptable?
   *On main:* the `@Model` classes are internal and these read models are what the
   repositories return, so no `@Query` is possible from the app. Still a proposal.
2. **OQ-2, isolation and async.** The spec is silent. Proposal: repositories are
   `@MainActor`, synchronous, and throwing, on the main context; engines are
   `nonisolated` and synchronous; nothing is `async` in 1a. Also: concrete classes or
   protocols? Concrete classes plus the seeded in-memory `BowlingStore.demo()` are
   proposed as the fake for previews. And: Swift 6 language mode with strict concurrency
   for both packages?
   *On main:* implemented as proposed: `@MainActor` final classes, synchronous and
   throwing, no protocols, no `async`; engines are pure static functions. Both packages
   use `swift-tools-version: 6.0`, so Swift 6 language mode with strict concurrency. The
   seeded demo store does not exist (OQ-22). Still a proposal.
3. **OQ-3, Scorer output for the UI.** §4 names `Mark` and nil running totals but no
   type that carries them, and no API for the pins the deck should enable. Proposal:
   `Scorecard`, `FrameScore`, `RollPosition`, `Scorer.scorecard(for:)`,
   `Scorer.nextRoll(in:)`. How does a split indicator reach the scorecard: from
   `FrameScore.leave` (proposed), or a flag on the mark?
   *On main:* the types and functions exist as proposed, plus
   `RollPosition.standingCount` (#18, ac3511a). `FrameScore` has no `leave`, so the split
   indicator question is still open. Still a proposal.
4. **OQ-4, which enums get `.unknown`.** §3.1 says unknown raw values decode to "an
   `unknown` or default case"; §8 says they display as "Other" and are preserved. The
   spec lists `unknown` only for handedness, statsProfile, coverstock, and core type;
   eventType ("default casual"), entryMode, and intendedRole ("default strike") have
   none. Proposal: add `.unknown` to the Swift enums for all of them, so a newer value
   is shown as "Other" instead of being treated as casual or strike. How does Stats
   treat a game with an unknown entry mode or event type (proposal: excluded unless
   "All games")?
   *On main:* all five stored enums have `.unknown`. An unknown event type matches only
   when `.unknown` is selected ("All games" includes it, "Competition" does not). An
   unknown entry mode counts toward the overview only. Still a proposal.
5. **OQ-5, where the fixture lives.** §2 says BowlingData owns the demo fixture, but
   StatsEngine tests (§9) run in BowlingCore, which cannot depend on BowlingData.
   Proposal: fixture `GameRecord`s in a small `BowlingFixtures` library in the
   BowlingCore package (depends only on BowlingCore); BowlingData seeds the demo store
   from it; expected values live in test targets. This affects #16's package layout.
   *On main:* `BowlingFixtures` ships in the BowlingCore package as proposed (#22,
   306d9f5), expected values are in the BowlingCore test target, and BowlingData seeds
   test stores from it in its tests only. Still a proposal.
6. **OQ-6, `pinCount` versus mask.** Does `Scorer.validate` report a pinByPin roll whose
   `pinCount` differs from `pinsDown.count`? §4's list does not include it.
   *On main:* no. The repository always derives `pinCount` from the pins, so the
   mismatch cannot come from the app. Still a proposal.
7. **OQ-7, roll and frame identity.** `RollRecord` and `FrameRecord` carry no `id`
   (proposed: addressed by index). Does the app ever need the SwiftData UUID of a frame
   or roll (for example for 1b leave occurrences)?
   *On main:* no `id` on either; `replaceRoll` addresses rolls by frame and roll
   index. Still a proposal.
8. **OQ-8, session context on `GameRecord`.** `StatsEngine` takes only `[GameRecord]`
   but needs the date, event type, and session of each game. Proposal: copy
   `sessionID`, `sessionDate`, `eventType` onto `GameRecord`. Alternative: a separate
   session lookup passed to the engine.
   *On main:* implemented as proposed. Still a proposal.
9. **OQ-9, scores of incomplete games.** What does `finalScore` hold before frame 10
   finishes (last known running total, or 0)? Does a session's series total (§3.2) and
   History's score column include incomplete games?
   *On main:* the last known running total (0 before any frame is scored), and
   `seriesTotal` includes incomplete games. Still a proposal.
10. **OQ-10, "incomplete session".** §7 shows "Resume session when an incomplete
    session exists" but does not define it. Proposal: a session with at least one
    incomplete game; if several exist, the most recent by date.
    *On main:* implemented as proposed; ties follow `sessions()` order. Still a
    proposal.
11. **OQ-11, tie-break orders.** Sessions with the same date (proposal: `createdAt`
    descending); bowlers within a session (proposal: order added, which needs a stored
    order the schema does not have, or else owner first then name); `bowlers()` order.
    *On main:* sessions by `createdAt` descending; bowlers in a session and
    `bowlers()` owner first, then by name (no stored lineup order). Still a proposal.
12. **OQ-12, delete all data.** Settings has it (§7). Which repository owns it, and does
    it also delete the owner (sending the user back to first launch)?
    *On main:* not implemented. Open.
13. **OQ-13, ball order.** §3.2 says `intendedRole` "drives ... picker order". Proposal:
    in the roll picker, spare and both first on a spare attempt, strike and both first on
    a first ball; ties by name. Arsenal list: by name?
    *On main:* `activeBalls()` is by name; no role-based picker order exists. Picker
    order is open.
14. **OQ-14, default stats scope storage.** §6 says the choice "is stored in Settings".
    UserDefaults (per device, not synced) or a field on Bowler (synced, but not in the
    §3.2 table)? Changing the bowling style sets its starting value; does it overwrite a
    choice the user already made?
    *On main:* no storage exists. `StatsPreset.prefersCompetition` gives the starting
    value and `defaultEventTypes(for:preferCompetition:)` takes it as a parameter. Open.
15. **OQ-15, bowler filter.** Is the bowler filter required (one bowler at a time,
    defaulting to the owner), or can Stats combine several bowlers?
    *On main:* `StatsFilter.bowlerID` is required, one bowler at a time. Still a
    proposal.
16. **OQ-16, trend rolling average.** §6: "average per session over time, with a
    rolling average of the last nine games overlaid." Is the rolling series one point
    per session (average of the nine games up to the end of that session, proposed) or
    one point per game? What does it show with fewer than nine games?
    *On main:* one point per session, the last nine complete games up to the end of
    that session, or all of them when fewer exist. Still a proposal.
17. **OQ-17, leave ordering and the callout.** Tie-break for leaves with equal counts
    (proposal: name ascending), and for "left most, made least" ties. Is there a minimum
    count before a leave can be the callout?
    *On main:* equal counts by pin numbers ascending (numeric, so "2-8" before
    "10"); callout ties go to the leave higher in the table; no minimum count. Still a
    proposal.
18. **OQ-18, competitive preset order.** "Every card" in which order: the catalog order
    in §7 (proposed)?
    *On main:* catalog order, which is `StatsCardID.allCases` order. Still a
    proposal.
19. **OQ-19, StatsReport last-N averages.** §6: "also shown for the last 10, 30, and all
    games in the filter". Last by date across sessions, ordered by session date then
    `gameIndex` (proposed)?
    *On main:* by session date, then session ID, then `gameIndex`. Still a
    proposal.
20. **OQ-20, public container factory.** `BowlingStore.schema` and
    `BowlingStore.makeContainer(inMemory:)` are public on main (44f7523) and hand out a
    SwiftData `ModelContainer`, against rule 1. Keep them public for app wiring (for
    example `.modelContainer` in a future phase), or make them internal?
21. **OQ-21, applying a saved layout.** The draft's
    `StatsPreset.displayedCards(layout:profile:)` was not built (#25, PR #54). Split it
    into a Stats and a Home function, or add a surface parameter? Needed by 1b
    Customize; 1a layouts are always empty.
22. **OQ-22, demo store for previews.** §9 says every 1a screen has a preview backed by
    the demo fixture data. Main has the fixture games but no seeded store. Add a public
    `BowlingStore.demo(now:)` in BowlingData (which would then depend on
    BowlingFixtures), or have previews build view state from `DemoFixture` directly?
