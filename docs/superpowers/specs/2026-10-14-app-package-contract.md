# App and Package Contract

Date: 2026-10-14 (open questions decided 2026-10-14, issue #1)
Status: decided, approved when both boxes in section 8 are checked
Issue: #1
Spec: `2026-10-07-phase-1-core-scoring-design.md` (cited below as §n)
Team plan: `2026-10-12-team-plan.md`

This document pins down what the app target (`Bowling/`) may use from the packages
(`Packages/BowlingCore`, `Packages/BowlingData`), so screens can be built against demo
fixtures while the engines are written. The packages created by #16 must expose exactly
these names. Any change to this document after it merges needs a PR that both
developers review.

## 0. How to read this

- Every item is tagged **1a** (needed now) or **1b** (deferred; shape listed but not
  pinned until the 1b contract PR).
- Every field cites its source in the spec. Items the spec needs but does not name are
  tagged **OQ-n**, pointing to the decision recorded in section 9.
- Signatures show the public surface only. Bodies, private helpers, and the SwiftData
  `@Model` classes are not part of the contract: the app never sees `Session`, `Game`,
  `Frame`, `Roll`, or `Ball` models (§2), except as allowed by OQ-1.

## 1. Rules for the whole contract

1. **Value types only cross the boundary.** Everything the app receives is a `struct`
   or `enum` that is `Sendable` and `Hashable`. Types that are stored or exported are
   also `Codable`. No SwiftData model, `ModelContext`, or `PersistentIdentifier` is
   returned to the app (§2).
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
   from a newer app version is preserved on save (§8). Every contract enum gets
   `.unknown` (OQ-4).
5. **Engines are pure.** `Scorer`, `LeaveClassifier`, and `StatsEngine` are
   deterministic, `nonisolated`, and synchronous (§2). They can be called from any
   isolation. Anything that depends on "now" or the calendar takes them as parameters.
6. **Repositories are `@MainActor` and synchronous.** They wrap the SwiftData main
   context, `throw` a `RepositoryError` on refusal, and save before returning (OQ-2).
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

    /// Pin numbers 1...10, ascending.
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

/// §3.2 Bowler.statsScope: the user's explicit default stats scope (OQ-14). The
/// stored empty string means "follow the bowling style" and reads as nil on
/// BowlerRecord; `.unknown` (a value from a newer version) is also treated as nil.
public enum StatsScope: String, Sendable, Hashable, Codable, CaseIterable {
    case competition, all, unknown
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

- When `pinsKnown` is true, `pinCount == pinsDown.count`. `Scorer.validate` does not
  report a mismatch, because the repository always derives `pinCount` from the pins
  (OQ-6).
- A foul has `pinCount == 0` and `pinsDown == []` regardless of entry mode (§4).
- No `id`: a roll is identified by its game, `frameIndex`, and `rollIndex` (§3.1
  ordering, OQ-7).

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
  read-only on a `GameRecord` (OQ-8).
- Only `isComplete == true` games count toward any stat (§6). `StatsEngine` enforces
  this itself, so callers may pass incomplete games.
- While a game is incomplete, `finalScore` holds the last known running total (OQ-9).
  History and session detail label such a game "in progress".

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
Scorer output that the spec describes but does not name (OQ-3):

```swift
public struct FrameScore: Sendable, Hashable {
    public var frameIndex: Int
    public var marks: [Mark]           // one per roll, in rollIndex order
    /// The leave of the frame's spare attempt rack, which drives the split indicator
    /// and the frame's leave diagram (§4, §7). At most one per frame, because fill-ball
    /// leaves are not listed (#57). nil for strikes, countOnly and finalOnly games, and
    /// first-ball fouls.
    public var leave: Leave?
    public var runningTotal: Int?      // nil until bonus rolls exist (§4 "Score computation")
}

public struct Scorecard: Sendable, Hashable {
    public var frames: [FrameScore]    // always 10 entries, frameIndex 1...10
    public var finalScore: Int?        // tenth frame's running total; nil until known
}

/// Where the next roll goes and what the bowler faces.
public struct RollPosition: Sendable, Hashable {
    public var frameIndex: Int
    public var rollIndex: Int
    public var standingPins: PinSet    // pins the deck enables (§7 Scoring 3)
    public var standingCount: Int      // the most this roll can knock down; bounds countOnly (#56)
    public var isFreshRack: Bool       // counts as a first ball (§6 "First balls")
}
```

### 2.7 Leave (1a, §5)

```swift
public enum LeaveKind: String, Sendable, Hashable, Codable {
    case strike, singlePin, makeable, split
}

public struct Leave: Sendable, Hashable, Codable {
    public var pins: PinSet            // standing after the first ball
    public var kind: LeaveKind
    public var isWashout: Bool
    public var name: String { get }    // ascending pin numbers joined by "-", e.g. "3-6-10"
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
    /// OQ-3.
    public static func scorecard(for game: GameRecord) -> Scorecard
    /// OQ-3. nil when the game is complete or finalOnly.
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
    // 1b: ballReport(for:games:) -> BallReport, compareBalls(games:) -> [BallComparisonRow]
}
```

`ScoringError` case names are proposed; the set of cases traces to §4. A
`finalScoreOutOfRange` case is included because §4 bounds `finalScore` to 0...300 and
repositories refuse invalid games.

## 3. Repositories (BowlingData)

### 3.1 Shape (OQ-2)

```swift
@MainActor
public final class BowlingStore {
    public init(inMemory: Bool = false) throws       // the app's store, or an empty test store
    public let sessions: SessionRepository
    public let games: GameRepository
    public let bowlers: BowlerRepository
    public let balls: BallRepository
    public let stats: StatsRepository

    /// Settings "Delete all data" (§7, OQ-12): deletes every record, the owner
    /// included, so the app returns to first launch. From phase 2 the deletion syncs to
    /// every device on the iCloud account, and the confirmation must say so.
    public func deleteAllData() throws
}

public enum RepositoryError: Error, Sendable, Hashable {
    case notFound
    case invalidGame([ScoringError])          // §4: repositories refuse invalid games
    case entryModeLocked                      // §8: mode fixed once the first roll exists
    case bowlerHasGames(count: Int)           // §3.3
    case cannotDeleteOwner                    // §3.3
    case ownerAlreadyExists                   // §3.2 Bowler.isOwner: one owner per user
    case invalidBall(BallFieldError)          // §3.2 Ball: name required, weight 6...16
    case invalidBowler(BowlerFieldError)      // a bowler's name is required
    case notFinalOnly                         // setFinalScore on a game scored from rolls
}

public enum BallFieldError: Sendable, Hashable { case emptyName, weightOutOfRange }
public enum BowlerFieldError: Sendable, Hashable { case emptyName }
```

All repository methods are `@MainActor`, synchronous, and save before returning. None
are `async` in 1a.

### 3.2 Read models returned to screens (OQ-1)

No `@Query` in 1a: screens read these value types. Screens re-fetch after their own
writes. Phase 2 adds a change signal on `BowlingStore` for changes that arrive through
sync.


```swift
public struct BowlerRecord: Sendable, Hashable, Identifiable {
    public var id: BowlerID
    public var name: String
    public var isOwner: Bool
    public var handedness: Handedness
    public var statsProfile: StatsProfile          // meaningful on the owner only
    public var statsLayout: [String]               // raw card IDs; [] = preset (§3.2, §7)
    public var homeLayout: [String]                // raw card IDs; [] = preset
    public var statsScope: StatsScope?             // nil = follow the bowling style (OQ-14)
}

public struct SessionSummary: Sendable, Hashable, Identifiable {   // History row (§7)
    public var id: SessionID
    public var date: Date
    public var eventType: EventType
    public var centerName: String?
    public var leagueName: String?
    public var bowlerCount: Int
    public var games: [GameRecord]                 // sorted by bowler, then gameIndex
    public var isComplete: Bool                    // OQ-10
}

public struct SessionDetail: Sendable, Hashable, Identifiable {
    public var id: SessionID
    public var metadata: SessionMetadata
    public var bowlers: [SessionBowler]            // lineup order, from Game.lineupIndex (OQ-11)
}

public struct SessionBowler: Sendable, Hashable {
    public var bowler: BowlerRecord
    public var games: [GameRecord]                 // sorted by gameIndex
    public var seriesTotal: Int                    // sum of final scores, incomplete games included;
                                                   // the app labels it "so far" when one is (OQ-9)
}

public struct SessionMetadata: Sendable, Hashable {
    public var date: Date
    public var eventType: EventType
    public var centerID: CenterID?
    public var leagueID: LeagueID?                 // only meaningful for league (§3.2)
    public var oilPatternID: OilPatternID?
    public var lanes: String
    public var notes: String
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
    public var gamesBowled: Int                    // §3.2 derived value
}
```

### 3.3 SessionRepository (1a)

```swift
@MainActor public final class SessionRepository {
    /// History and Home's recent list. Sorted by date descending (OQ-11 for ties).
    public func sessions() -> [SessionSummary]
    public func session(_ id: SessionID) throws -> SessionDetail
    /// Home "Resume session" (§7). Most recent session with an incomplete game (OQ-10).
    public func resumableSession() -> SessionSummary?

    /// New session "Start" (§7): creates the session and game 1 for each bowler.
    /// `bowlers` is in lineup order; each position is stored as Game.lineupIndex
    /// (OQ-11). Returns the session; games are read back with `session(_:)`.
    public func startSession(_ metadata: SessionMetadata,
                             bowlers: [(bowlerID: BowlerID, defaultBallID: BallID?)],
                             entryMode: EntryMode) throws -> SessionID
    /// Home "Quick score" (§7): casual session dated now, one finalOnly game, owner.
    public func quickScore(finalScore: Int, now: Date) throws -> SessionID
    /// History edit (§7), including changing a Quick score's event type.
    public func updateMetadata(_ id: SessionID, _ metadata: SessionMetadata) throws
    /// Cascades to games, frames, rolls (§3.3).
    public func deleteSession(_ id: SessionID) throws
    /// §8: backing out before any roll deletes the session. No-op if any roll exists.
    public func discardIfUnstarted(_ id: SessionID) throws

    // Pickers with inline create (§7 New session). Sorted by name.
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
    case pinsLeft(PinSet)      // pinByPin: the pins still standing after this roll
    case count(Int)            // countOnly
    case foul                  // either mode
}

public struct RollEditOutcome: Sendable, Hashable {
    public var game: GameRecord
    public var clearedFrames: [Int]     // §8: frames whose later rolls were cleared
}

@MainActor public final class GameRepository {
    public func game(_ id: GameID) throws -> GameRecord

    /// Appends at Scorer.nextRoll(in:). Validates, saves after every roll (§8).
    /// Throws .invalidGame and saves nothing if the result would be invalid.
    public func recordRoll(_ input: RollInput, ballID: BallID?, in game: GameID) throws -> GameRecord
    /// §7 Undo. Removes the last roll. No-op on a game with no rolls.
    public func undoLastRoll(in game: GameID) throws -> GameRecord
    /// §8: editing an earlier roll re-validates later rolls and clears every roll from
    /// the first invalid one onward.
    public func replaceRoll(frameIndex: Int, rollIndex: Int, with input: RollInput,
                            ballID: BallID?, in game: GameID) throws -> RollEditOutcome

    /// §8: allowed only before the first roll, else throws .entryModeLocked.
    public func setEntryMode(_ mode: EntryMode, for game: GameID) throws
    /// §8: the offer made after .entryModeLocked.
    public func clearRolls(in game: GameID) throws -> GameRecord
    public func setDefaultBall(_ ballID: BallID?, for game: GameID) throws
    /// finalOnly only, 0...300 (§4). Marks the game complete. Throws .notFinalOnly on
    /// a game scored from rolls.
    public func setFinalScore(_ score: Int, for game: GameID) throws
    /// §7 "Next game": game gameIndex + 1 for every bowler, same default balls and
    /// lineup order.
    public func startNextGame(in session: SessionID) throws -> [GameID]
    public func deleteGame(_ id: GameID) throws
}
```

Rules:

- The repository, not the app, sets `rollIndex`, `pinCount`, `pinsKnown`, and
  `isComplete`, and recomputes the cached `finalScore` with `Scorer` on every write.
- `.pins` or `.pinsLeft` on a countOnly game, or `.count` on a pinByPin game, is refused
  with `.invalidGame`. Any roll on a finalOnly game is refused.
- `.pinsLeft` is what the pin deck sends by default, since it defaults to tapping the
  pins left standing (§7). The repository converts it to fallen pins (the rack's
  standing pins minus `pinsLeft`) and refuses, with `.invalidGame`, a selection that
  includes a pin that was not standing. The app never does this subtraction.
- Switching a finalOnly game with a typed score to another mode discards the score.
  The app asks the user to confirm before calling `setEntryMode`.

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
    /// New session "add others by name" (§7). Throws .invalidBowler(.emptyName) for a
    /// name that is blank after trimming, as do createOwner and updateOwner.
    public func createBowler(name: String) throws -> BowlerRecord
    public func updateOwner(name: String, handedness: Handedness) throws
    /// Settings bowling style (§7). Does not touch a customized layout in 1a. A nil
    /// statsScope follows the new style; an explicit one is kept (OQ-14).
    public func setStatsProfile(_ profile: StatsProfile) throws
    /// Settings default stats scope (§6, §7). nil = follow the bowling style.
    public func setStatsScope(_ scope: StatsScope?) throws
    /// §3.3: .cannotDeleteOwner, .bowlerHasGames(count:).
    public func deleteBowler(_ id: BowlerID) throws

    // 1b: setStatsLayout(_:), setHomeLayout(_:), resetLayouts() (§7 Customize).
}
```

Settings "delete all data with double confirmation" (§7) is `BowlingStore.deleteAllData()`
(section 3.1, OQ-12).

### 3.6 BallRepository (1a basic, §7 Arsenal 1a)

```swift
@MainActor public final class BallRepository {
    /// Non-retired balls, sorted by name. The roll picker reorders them by
    /// `intendedRole` in the app (OQ-13).
    public func activeBalls() -> [BallSummary]
    /// Name, weight, intended role, brand only (§7 Arsenal 1a).
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
    /// Applies the filter (predicates where possible, rest in memory, §6) and returns
    /// games for StatsEngine. Sorted by sessionDate, then gameIndex.
    public func games(matching filter: StatsFilter, now: Date, calendar: Calendar) -> [GameRecord]
    /// §6 "Default scope": EventType.competition when the bowler has at least one
    /// complete league or tournament game and `preferCompetition` is true; otherwise
    /// every event type. The app passes the owner's explicit `statsScope` as
    /// `preferCompetition` when set, and the bowling style's preference otherwise (OQ-14).
    public func defaultEventTypes(for bowler: BowlerID, preferCompetition: Bool) -> Set<EventType>
}
```

The app calls `stats.games(matching:)` and then `StatsEngine.report(games:filter:)`
(§2: feature models "call repositories, and run engines"). The default stats scope is
stored as `Bowler.statsScope` (OQ-14).

## 4. Stats (1a)

### 4.1 StatsFilter (§6 "Filters")

```swift
public enum DatePreset: String, Sendable, Hashable, Codable, CaseIterable {
    case thisWeek, thisMonth, last30Days, thisSeason, allTime
}

public struct StatsFilter: Sendable, Hashable, Codable {
    public var datePreset: DatePreset
    public var eventTypes: Set<EventType>
    public var bowlerID: BowlerID                  // OQ-15
    // 1b: customRange: ClosedRange<Date>?, ballID, oilPatternID, centerID, leagueID

    /// Resolves the preset by calendar day in the device calendar and time zone (§8).
    /// In 1a there is no league filter, so thisSeason is always the last 9 months (§6).
    public func dateInterval(now: Date, calendar: Calendar) -> DateInterval?   // nil = all time
}
```

### 4.2 StatsReport (§6 "Definitions (1a)")

Every number carries the sample it was computed from (§6), so the UI can show "63% of
41 attempts" and never divides by zero (§8).

```swift
public struct Rate: Sendable, Hashable, Codable {
    public var hits: Int
    public var attempts: Int
    public var value: Double? { get }              // nil when attempts == 0
}

public struct Mean: Sendable, Hashable, Codable {
    public var total: Int
    public var count: Int
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
    public var rollingAverage: Mean                // last nine games up to this session's end, or
                                                   // all of them when fewer than nine (OQ-16)
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
    public var averageLast10: Mean                 // OQ-19
    public var averageLast30: Mean
    public var highGame: HighGame?
    public var highSeries: [HighSeries]            // best per gameCount, ascending gameCount
    public var trend: [TrendPoint]                 // ascending date

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
    public var leaves: [LeaveRow]                  // count descending, then pin numbers ascending (OQ-17)
    public var leftMostMadeLeast: LeaveRow?        // most misses among leaves seen at least 3 times;
                                                   // ties go to the higher row; nil if none (OQ-17)

    // 1b: openFrames, cleanGames, headPin, firstBallAverage, byFrame, whatIfSinglePins
}
```

Rules:

- `StatsEngine` ignores incomplete games and applies the applicability table itself:
  a finalOnly game never contributes to `firstBalls`, a countOnly game never to
  `leaves` (§6).
- Spare attempts after a first-ball foul count against a full rack and produce no leave
  (§5, §6). They count in the split % denominator.
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
    /// 1b, §7 "Layout rules": [] -> that surface's preset; unknown IDs skipped for
    /// display. Separate functions for Stats and Home, so an empty layout falls back to
    /// the right preset (#54).
    public static func displayedStatsCards(layout: [String], profile: StatsProfile) -> [StatsCardID]
    public static func displayedHomeTiles(layout: [String], profile: StatsProfile) -> [StatsCardID]
}
```

Rules:

- `.unknown` profile uses the casual preset (§3.2, §9).
- `competitive` is every available card in `CaseIterable` order, which is the catalog
  order (§7 "every card", OQ-18).
- In 1a the league preset omits `openPct` until 1b ships (§7).
- A card whose group has zero games (for example `leavesTable` when `pinGames == 0`)
  stays in place and shows an explanation (§7 "Layout rules"); the copy is the app's.
- Saving a layout (1b) keeps unknown IDs (§7).

## 5. Demo fixture data (1a, §2, §9, issue #22)

Previews and StatsEngine tests read the same games. They live in the `BowlingFixtures`
library in the BowlingCore package, which depends only on BowlingCore (OQ-5). Because
BowlingCore cannot depend on BowlingData, bowlers and balls are fixture enums, not
BowlingData read models (#57):

```swift
// BowlingFixtures
public enum DemoFixture {
    /// A fixed reference date for tests. Previews pass Date.now.
    public static let referenceDate: Date

    /// About twenty games. Session dates are offsets from `now`, so date presets
    /// ("this week", "last 30 days") always select the same games.
    public static func games(relativeTo now: Date) -> [GameRecord]
}

/// Fixed-UUID fixture entities, each with `id` and `name`; DemoBall adds `owner` and
/// `role`, DemoSession `eventType` and `daysAgo`, DemoGame `session` and `bowler`.
public enum DemoBowler: Int, CaseIterable, Sendable { ... }
public enum DemoBall: Int, CaseIterable, Sendable { ... }
public enum DemoSession: Int, CaseIterable, Sendable { ... }
public enum DemoGame: Int, CaseIterable, Sendable { ... }

// BowlingData: seeds an in-memory store from BowlingFixtures (#62).

extension BowlingStore {
    /// In-memory store seeded with every DemoFixture value. Used by every preview.
    @MainActor public static func demo(now: Date = .now) throws -> BowlingStore
}
```

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

Expected values for every 1a stat are hand-computed and live in the test targets, not
in the shipped fixture (OQ-5).

The app links `BowlingFixtures` for previews only (#65).

## 6. Deferred to 1b (not pinned here)

Listed so nobody builds against a guess. Each gets its own contract PR before 1b work
starts.

- `StatsFilter` custom range, ball, oil pattern, center, league (§6); `GameRecord`
  center, league, pattern IDs.
- ~~`StatsReport` 1b fields: open frame %, clean game %, head pin rate, first-ball average,
  by-frame, what-if (§6).~~ Pinned in "StatsReport 1b fields" below (#39).
- Leave occurrences: date, session, frame number, ball on the spare attempt (§6).
- `BallReport`, `BallComparisonRow`, `StatsEngine.ballReport(for:games:)`,
  `compareBalls(games:)` (§6 "Ball report").
- Full `BallRecord`, coverstock and core enums, maintenance events, retire, delete with
  affected-game count, resurface due (§3.2, §7 Arsenal 1b).
- Layout writes from Customize and "Reset to preset" (§7), and `StatsPreset`'s
  `displayedStatsCards` and `displayedHomeTiles` (section 4.3).
- Ball, center, league, pattern delete warnings (§3.3).
- CSV export (§7 Settings 1b).
- Owner merge and duplicate frame repair are BowlingData-internal and never reach the
  app (§3.4).

### StatsReport 1b fields (§6 "Definitions (1b)", #39)

Added to `StatsReport` with default values, so its 1a initializer is unchanged;
`StatsEngine.report(games:filter:)` always fills them.

```swift
extension StatsReport {   // stored properties on the struct
    public var openFrames: Rate                    // frames with no strike or spare / frames (rollGames)
    public var cleanGames: Rate                    // games with no open frame / rollGames
    public var firstBallAverage: Mean              // pins / firstBalls; a foul counts 0 (rollGames)
    public var headPin: Rate                       // pin 1 down / first balls that were not fouls (pinGames)
    public var byFrame: [FrameStats]               // always 10 rows, frames 1...10 (rollGames)
    public var whatIfSinglePins: WhatIfSinglePins  // pinGames
}

public struct FrameStats: Sendable, Hashable, Codable {
    public var frameIndex: Int                     // 1...10
    public var strikes: Rate                       // strikes on roll 1 / games
    public var pins: Mean                          // first-rack pins per game: ball 1, plus ball 2
                                                   // unless ball 1 was a strike; frame 10's fill
                                                   // balls are left out, like a bonus
}

public struct WhatIfSinglePins: Sendable, Hashable, Codable {
    public var actual: Mean                        // real average of the pinByPin games
    public var allMade: Mean                       // same games, missed single pins made, rescored
    public var rewritten: Int                      // missed single-pin leaves rewritten
    public var difference: Double? { get }         // allMade - actual per game; nil with no games
}
```

Rules:

- A frame is open when none of its marks is a strike or a spare. Frame 10 gets a fill
  ball only after one of them, so "X 10 -" is not open and "4 -" is.
- The what-if rewrites the second ball of every missed single-pin spare attempt to knock
  the pin down and rescores with `Scorer`. A frame 10 spare made this way gets a fill ball
  of 0, so the gain is the spares' own. Fill-ball leaves are not spare attempts (1a) and
  are not rewritten.
- `StatsCardID.isAvailable` stays false for the 1b cards until their screens ship.

## 7. What the app may not do

- Import SwiftData or touch `ModelContext` (OQ-1).
- Compute scores, leaves, marks, or stats itself, or convert pins left to pins that fell.
  It renders `Scorecard`, `Leave`, and `StatsReport` and sends `RollInput`.
- Sort games, frames, or rolls, or compare raw enum strings.
- Persist card IDs in any form other than the `StatsCardID` raw values.

## 8. Approval

- [x] marilynjov (frontend)
- [x] SantiagoM99 (data)

## 9. Open questions, decided 2026-10-14 (issue #1)

1. **OQ-1, `@Query` versus value types.** §2 lets views use `@Query` "for simple lists",
   which hands SwiftData models to the app. AGENTS.md says the app talks to packages
   only through the contract. Proposal: no `@Query` in 1a; lists come from repository
   read models (section 3.2). Are the read models (`BowlerRecord`, `SessionSummary`,
   `SessionDetail`, `BallSummary`, `NamedRef`) acceptable?
   **Decision:** Accepted. No `@Query` in 1a; screens read the section 3.2 read models. Phase 2 adds a change signal for sync.
2. **OQ-2, isolation and async.** The spec is silent. Proposal: repositories are
   `@MainActor`, synchronous, and throwing, on the main context; engines are
   `nonisolated` and synchronous; nothing is `async` in 1a. Also: concrete classes or
   protocols? Concrete classes plus the seeded in-memory `BowlingStore.demo()` are
   proposed as the fake for previews. And: Swift 6 language mode with strict concurrency
   for both packages?
   **Decision:** Accepted. `@MainActor`, synchronous, throwing repositories; `nonisolated` engines; concrete classes; `BowlingStore.demo()` as the preview fake; Swift 6 strict concurrency.
3. **OQ-3, Scorer output for the UI.** §4 names `Mark` and nil running totals but no
   type that carries them, and no API for the pins the deck should enable. Proposal:
   `Scorecard`, `FrameScore`, `RollPosition`, `Scorer.scorecard(for:)`,
   `Scorer.nextRoll(in:)`. How does a split indicator reach the scorecard: from
   `FrameScore.leave` (proposed), or a flag on the mark?
   **Decision:** Accepted, including `RollPosition.standingCount` (#56). The split indicator comes from `FrameScore.leave`: the leave of the frame's spare attempt rack (#63).
4. **OQ-4, which enums get `.unknown`.** §3.1 says unknown raw values decode to "an
   `unknown` or default case"; §8 says they display as "Other" and are preserved. The
   spec lists `unknown` only for handedness, statsProfile, coverstock, and core type;
   eventType ("default casual"), entryMode, and intendedRole ("default strike") have
   none. Proposal: add `.unknown` to the Swift enums for all of them, so a newer value
   is shown as "Other" instead of being treated as casual or strike. How does Stats
   treat a game with an unknown entry mode or event type (proposal: excluded unless
   "All games")?
   **Decision:** Accepted. Every contract enum gets `.unknown`, shown as "Other". An unknown entry mode counts for score stats only; an unknown event type appears only under "All games".
5. **OQ-5, where the fixture lives.** §2 says BowlingData owns the demo fixture, but
   StatsEngine tests (§9) run in BowlingCore, which cannot depend on BowlingData.
   Proposal: fixture `GameRecord`s in a small `BowlingFixtures` library in the
   BowlingCore package (depends only on BowlingCore); BowlingData seeds the demo store
   from it; expected values live in test targets. This affects #16's package layout.
   **Decision:** Accepted. `BowlingFixtures` in the BowlingCore package (#57); spec §2 updated.
6. **OQ-6, `pinCount` versus mask.** Does `Scorer.validate` report a pinByPin roll whose
   `pinCount` differs from `pinsDown.count`? §4's list does not include it.
   **Decision:** No. The repository always derives `pinCount` from the pins, so a mismatch cannot be written.
7. **OQ-7, roll and frame identity.** `RollRecord` and `FrameRecord` carry no `id`
   (proposed: addressed by index). Does the app ever need the SwiftData UUID of a frame
   or roll (for example for 1b leave occurrences)?
   **Decision:** Index addressing. 1b leave occurrences use game ID plus frame index.
8. **OQ-8, session context on `GameRecord`.** `StatsEngine` takes only `[GameRecord]`
   but needs the date, event type, and session of each game. Proposal: copy
   `sessionID`, `sessionDate`, `eventType` onto `GameRecord`. Alternative: a separate
   session lookup passed to the engine.
   **Decision:** Accepted: `sessionID`, `sessionDate`, `eventType` on `GameRecord`.
9. **OQ-9, scores of incomplete games.** What does `finalScore` hold before frame 10
   finishes (last known running total, or 0)? Does a session's series total (§3.2) and
   History's score column include incomplete games?
   **Decision:** Last known running total. Series totals include incomplete games and the app labels them "so far"; History shows the game as "in progress". Stats exclude incomplete games.
10. **OQ-10, "incomplete session".** §7 shows "Resume session when an incomplete
    session exists" but does not define it. Proposal: a session with at least one
    incomplete game; if several exist, the most recent by date.
    **Decision:** Accepted.
11. **OQ-11, tie-break orders.** Sessions with the same date (proposal: `createdAt`
    descending); bowlers within a session (proposal: order added, which needs a stored
    order the schema does not have, or else owner first then name); `bowlers()` order.
    **Decision:** Sessions: date descending, then `createdAt` descending. Bowlers in a session: lineup order, stored as `Game.lineupIndex` (new), because Scoring rotates bowlers like a lane console. `bowlers()`: owner first, then name.
12. **OQ-12, delete all data.** Settings has it (§7). Which repository owns it, and does
    it also delete the owner (sending the user back to first launch)?
    **Decision:** `BowlingStore.deleteAllData()`, deleting everything including the owner and returning to first launch. From phase 2 the confirmation says it also deletes the data on the user's other devices.
13. **OQ-13, ball order.** §3.2 says `intendedRole` "drives ... picker order". Proposal:
    in the roll picker, spare and both first on a spare attempt, strike and both first on
    a first ball; ties by name. Arsenal list: by name?
    **Decision:** Accepted. Arsenal by name; the roll picker orders by role in the app.
14. **OQ-14, default stats scope storage.** §6 says the choice "is stored in Settings".
    UserDefaults (per device, not synced) or a field on Bowler (synced, but not in the
    §3.2 table)? Changing the bowling style sets its starting value; does it overwrite a
    choice the user already made?
    **Decision:** On the owner Bowler as `statsScope` (new), synced like `statsLayout`. Empty follows the bowling style; a style change never overwrites an explicit choice.
15. **OQ-15, bowler filter.** Is the bowler filter required (one bowler at a time,
    defaulting to the owner), or can Stats combine several bowlers?
    **Decision:** Required for 1a: one bowler, default the owner.
16. **OQ-16, trend rolling average.** §6: "average per session over time, with a
    rolling average of the last nine games overlaid." Is the rolling series one point
    per session (average of the nine games up to the end of that session, proposed) or
    one point per game? What does it show with fewer than nine games?
    **Decision:** One point per session; with fewer than nine games, the average of all games so far.
17. **OQ-17, leave ordering and the callout.** Tie-break for leaves with equal counts
    (proposal: name ascending), and for "left most, made least" ties. Is there a minimum
    count before a leave can be the callout?
    **Decision:** Count descending, then pin numbers ascending. The callout is the leave with the most misses among leaves seen at least 3 times (new minimum); ties go to the higher row; nil when none qualifies.
18. **OQ-18, competitive preset order.** "Every card" in which order: the catalog order
    in §7 (proposed)?
    **Decision:** Catalog order.
19. **OQ-19, StatsReport last-N averages.** §6: "also shown for the last 10, 30, and all
    games in the filter". Last by date across sessions, ordered by session date then
    `gameIndex` (proposed)?
    **Decision:** Accepted: session date, then session, then `gameIndex`.
