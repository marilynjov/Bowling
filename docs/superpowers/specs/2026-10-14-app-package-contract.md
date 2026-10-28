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
   returned to the app (§2). `BowlingStore.schema` and
   `BowlingStore.makeContainer(inMemory:)` are public on main and return SwiftData types;
   OQ-20 decided to make them internal (#76).
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
   A failed write rolls the context back, so nothing is saved when one throws. Passing
   `.unknown` for an enum in a repository write keeps the stored value.
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

    /// Pin numbers 1...10, in any order; numbers outside that range are ignored.
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

**1b (#28, #29):** `.unknown` is also a value the user can pick for these two; a
value from a newer version reads as `.unknown` too.

```swift
/// §3.2 Ball.coverstock. Stored default: unknown.
public enum Coverstock: String, Sendable, Hashable, Codable, CaseIterable {
    case plastic, urethane, reactiveSolid, reactivePearl, reactiveHybrid, other
    case unknown
}

/// §3.2 Ball.coreType. Stored default: unknown. pancake is the plastic spare-ball core.
public enum CoreType: String, Sendable, Hashable, Codable, CaseIterable {
    case symmetric, asymmetric, pancake
    case unknown
}
```

Each enum also has `public init(storedValue: String)` that never fails, and its
`init(from: Decoder)` uses the same fallback. Maintenance kind is in section 2.9;
enums only in later phases (invitation status) are not in the contract yet.

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
    public var bowlerID: BowlerID?                 // §3.2 Game.bowlerID: kept when the Bowler row is missing (§3.4)
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

    // 1b (#41, #38): the session's center, league, and pattern, for the filters and
    // the ball report's "By condition" (§6).
    public var centerID: CenterID?
    public var leagueID: LeagueID?
    public var oilPatternID: OilPatternID?

    /// Public because Swift's memberwise init is internal and other packages
    /// (BowlingData, fixtures, tests) must build games (#17, PR #52).
    public init(
        id: GameID = GameID(), bowlerID: BowlerID? = nil, gameIndex: Int,
        entryMode: EntryMode, defaultBallID: BallID? = nil, finalScore: Int,
        isComplete: Bool, frames: [FrameRecord] = [],
        sessionID: SessionID? = nil, sessionDate: Date, eventType: EventType,
        centerID: CenterID? = nil, leagueID: LeagueID? = nil, oilPatternID: OilPatternID? = nil
    )
}
```

Rules:

- The repository fills session context on every conversion; the app treats it as
  read-only on a `GameRecord` (OQ-8). A game with no session gets `sessionID == nil`,
  `sessionDate` = the game's `createdAt`, and `eventType == .unknown`.
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
    public var finalScore: Int?        // tenth frame's running total, or the typed score
                                       // of a finalOnly game; nil until known
}

/// Where the next roll goes and what the bowler faces.
public struct RollPosition: Sendable, Hashable {
    public var frameIndex: Int
    public var rollIndex: Int
    public var standingPins: PinSet    // pins the deck enables (§7 Scoring 3); all ten when
                                       // earlier rolls on this rack were countOnly
    public var standingCount: Int      // the most this roll can knock down; bounds countOnly (#56)
    public var isFreshRack: Bool       // counts as a first ball (§6 "First balls")
    public init(frameIndex: Int, rollIndex: Int, standingPins: PinSet,
                standingCount: Int, isFreshRack: Bool)
}
```

A finalOnly game's scorecard has ten frames with no marks and no running totals.

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
    /// OQ-3. Best effort on an invalid game: duplicates and out-of-range indices are
    /// dropped.
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
    /// §6 "Default scope" over games already in memory: EventType.competition when
    /// `preferCompetition` and `bowler` has a complete league or tournament game in
    /// `games`; otherwise every event type, `.unknown` included. StatsRepository has the
    /// store-backed version (section 3.7).
    public static func defaultEventTypes(games: [GameRecord], bowler: BowlerID,
                                         preferCompetition: Bool) -> Set<EventType>
    // 1b: ballReport(for:games:maintenance:), compareBalls(_:games:), section 2.9
}
```

`ScoringError` case names are proposed; the set of cases traces to §4. A
`finalScoreOutOfRange` case is included because §4 bounds `finalScore` to 0...300 and
repositories refuse invalid games. `outOfOrder` also covers an index out of range or
skipped, rolls after an unfinished frame, and a roll after a spare or open in frames 1
to 9.

### 2.9 Maintenance and ball report (1b, §3.2 MaintenanceEvent, §6 "Ball report", #38, #42)

**Contract change, both developers review.** The spec's `ballReport(for:games:)` and
`compareBalls(games:)` gain one parameter each, because `[GameRecord]` cannot tell the
engine a ball's maintenance log or which balls are retired.

```swift
public typealias MaintenanceEventID = UUID

public enum MaintenanceKind: String, Sendable, Hashable, Codable, CaseIterable {
    case resurface, polish, oilExtraction, plugAndRedrill, other, unknown
}

public struct MaintenanceRecord: Sendable, Hashable, Codable, Identifiable {
    public var id: MaintenanceEventID
    public var date: Date                          // full timestamp, not a day
    public var kind: MaintenanceKind
    public var surfaceGritAfter: String
    public var gamesOnBallAtTime: Int              // games with session date <= date (§3.2)
    public var notes: String
}

/// §3.2 derived values, over every game the ball was used in (not the stats filter).
public struct BallMaintenance: Sendable, Hashable {
    public var gamesBowled: Int                    // default or any roll override, once per game
    public var gamesSinceResurface: Int            // games after the latest resurface; with
                                                   // none, since purchase (#107 review)
    public var lastResurface: Date?                // nil: never resurfaced
    public var resurfaceIntervalGames: Int?
    public var events: [MaintenanceRecord]         // newest first; the over-time chart markers
    public var isResurfaceDue: Bool { get }        // interval set and gamesSinceResurface >= it
    /// The latest resurface wins: a game counts when its session date is > it. Only with
    /// no resurface logged, a game counts when its session date is >= purchaseDate, so
    /// games logged before the purchase date do not count (1b, #32). Without either,
    /// every game. BallRepository passes the start of the purchase day in its calendar.
    public init(ball: BallID, games: [GameRecord], events: [MaintenanceRecord],
                resurfaceIntervalGames: Int?, purchaseDate: Date? = nil)
    /// The same rule over session dates only; BallSummary.isResurfaceDue uses it.
    public static func gamesSinceResurface(sessionDates: [Date], lastResurface: Date?,
                                           purchaseDate: Date?) -> Int
}

extension GameRecord {
    public func uses(_ ball: BallID) -> Bool       // default ball or any roll override
}

public struct BallReport: Sendable, Hashable {
    public var ballID: BallID
    // Usage, over complete games in the filter that use the ball
    public var gamesBowled: Int
    public var firstBalls: Int
    public var spareAttempts: Int                  // second roll thrown with the ball
    public var firstUsed: Date?
    public var lastUsed: Date?
    public var maintenance: BallMaintenance
    // As a strike ball, over first balls thrown with it
    public var strikes: Rate
    public var firstBallAverage: Mean              // a foul counts as 0
    public var headPin: Rate                       // pinByPin, fouls excluded
    public var averageAsMainBall: Mean             // games with it as the default ball
    // As a spare ball, over spare attempts thrown with it
    public var spares: Rate
    public var singlePinConversion: Rate
    public var splitConversion: Rate
    public var leaves: [LeaveRow]                  // same order as StatsReport.leaves
    // By condition
    public var byOilPattern: [ConditionRow]
    public var byCenter: [ConditionRow]
    // Over time
    public var overTime: [BallTrendPoint]          // one per session with a first ball, oldest first
}

public struct ConditionRow: Sendable, Hashable, Codable {
    public var id: UUID?                           // pattern or center; nil = "Other"
    public var strikes: Rate
    public var firstBallAverage: Mean
}

public struct BallTrendPoint: Sendable, Hashable, Codable {
    public var sessionID: SessionID?
    public var date: Date
    public var strikes: Rate
}

public struct BallComparisonRow: Sendable, Hashable, Codable, Identifiable {
    public var ballID: BallID
    public var id: BallID { get }                  // ballID, for Compare's Table
    public var gamesBowled: Int
    public var averageAsMainBall: Mean
    public var strikes: Rate
    public var firstBallAverage: Mean
    public var spares: Rate
}

extension StatsEngine {
    /// `games` already filtered; `maintenance` from `BallRepository.maintenance(for:)`.
    public static func ballReport(for ball: BallID, games: [GameRecord],
                                  maintenance: BallMaintenance) -> BallReport
    /// One row per ball, in the order given; the app passes `activeBalls()` IDs.
    public static func compareBalls(_ balls: [BallID], games: [GameRecord]) -> [BallComparisonRow]
}

extension BallRepository {
    /// Throws .notFound.
    public func maintenance(for ball: BallID) throws -> BallMaintenance
    /// Snapshots the games with session date <= `date`, so a back-dated event matches
    /// when it happened; a non-empty grit becomes the ball's current surface (§3.2)
    /// unless another event with a grit is dated later.
    /// Throws .invalidMaintenance(.dateInFuture) for a date after now,
    /// .invalidMaintenance(.unknownKind) for .unknown, or .notFound.
    public func logMaintenance(_ kind: MaintenanceKind, date: Date = .now, surfaceGritAfter: String,
                               notes: String, for ball: BallID) throws -> MaintenanceRecord
}
```

Rules:

- Every roll counts for its override ball, else the game's default ball (§6). A spare
  attempt belongs to the ball that threw the second roll, at the leave.
- A pattern or center with fewer than 10 first balls with the ball, and games with no
  pattern or center recorded, are summed into the "Other" row (`id == nil`), listed last
  and only when it has first balls. Shown rows: most first balls first, ties by UUID.
- The app reads names for `ConditionRow.id` from `SessionRepository.centers()` and
  `oilPatterns()`.
- The ball detail calls `stats.games(matching:)`, `balls.maintenance(for:)`, then
  `StatsEngine.ballReport`. Compare calls `StatsEngine.compareBalls` with
  `balls.activeBalls()` IDs.
- The ball detail's recent games are the last ten of the same `stats.games(matching:)`
  result filtered with `uses(_:)` (`suffix(10)`, since it is sorted oldest first), so
  the list follows the filter. `BallReport` does not carry them.
- `GameRecord.centerID`, `leagueID`, and `oilPatternID` (section 2.5) are filled by the
  repository from the game's session.
- A maintenance date is a full timestamp; `logMaintenance` defaults it to now. On the
  day of a session, a resurface before the session's start time counts that session's
  games as since the resurface; one after it does not.
- `logMaintenance` refuses a date after now with `.invalidMaintenance(.dateInFuture)`:
  a future resurface would be the latest and hold games since resurface at 0. The app's
  `ErrorText` needs a message for it.
- `logMaintenance(.unknown, ...)` throws `.invalidMaintenance(.unknownKind)`: `.unknown`
  only reads a kind from a newer app version, so the picker leaves it out.

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

    // Becoming internal (OQ-20, #76); not for the app:
    public nonisolated static var schema: Schema { get }
    /// CloudKit off until phase 2.
    public nonisolated static func makeContainer(inMemory: Bool = false) throws -> ModelContainer
}

public enum RepositoryError: Error, Sendable, Hashable {
    case notFound
    case invalidGame([ScoringError])          // §4: repositories refuse invalid games
    case entryModeLocked                      // §8: mode fixed once the first roll exists
    case bowlerHasGames(count: Int)           // §3.3
    case ballHasGames(count: Int)             // §3.3, 1b: retire instead (section 3.6)
    case cannotDeleteOwner                    // §3.3
    case ownerAlreadyExists                   // §3.2 Bowler.isOwner: one owner per user
    case invalidBall(BallFieldError)          // §3.2 Ball: name required, weight 6...16,
                                              // 1b: specs >= 0, interval >= 1
    case invalidBowler(BowlerFieldError)      // a bowler's name is required
    case invalidMaintenance(MaintenanceFieldError) // section 2.9: no future date, no .unknown kind
    case invalidPlace(PlaceFieldError)        // a center, league, or oil pattern name is required
    case notFinalOnly                         // setFinalScore on a game scored from rolls
}

public enum BallFieldError: Sendable, Hashable {
    case emptyName, weightOutOfRange
    case negativeSpec                         // 1b: RG or a differential < 0 or not finite
    case resurfaceIntervalBelowOne            // 1b: set but < 1; nil turns the reminder off
    case purchaseDateInFuture                 // 1b: purchase day after today
    case photoTooLarge                        // 1b: over BallRepository.maxPhotoBytes
}
public enum BowlerFieldError: Sendable, Hashable { case emptyName }
public enum MaintenanceFieldError: Sendable, Hashable { case dateInFuture, unknownKind }
public enum PlaceFieldError: Sendable, Hashable { case emptyName }
```

All repository methods are `@MainActor`, synchronous, and save before returning. None
are `async` in 1a. `.invalidGame([])` (no scoring errors) is the refusal for a write that
does not apply to the game at all: roll input of the other entry mode, or a roll on a
finalOnly or complete game.

### 3.2 Read models returned to screens (OQ-1)

No `@Query` in 1a: screens read these value types. Screens re-fetch after their own
writes. Phase 2 adds a change signal on `BowlingStore` for changes that arrive through
sync. That signal must carry the game IDs the post-import repair deleted (internal
`repairDuplicates()` already returns them in `DuplicateRepairResult.deleted`): a screen
holding one of those IDs, such as Scoring, gets `.notFound` on its next read and has to
leave it.

Phase 2 must also settle, before sync turns on:

- **Never delete a game in use.** Duplicate ranking reads `recordedRollCount` and
  `updatedAt`, which change while a game is bowled, so two devices with different
  snapshots can each delete the other's copy. The repair must skip a game open in
  Scoring on this device or written recently (for example, `updatedAt` within the last
  few minutes) and retry on a later import.
- **Leave Scoring cleanly.** If a game Scoring holds is deleted anyway, Scoring closes it
  with a short message and returns to the session or Home. It never shows the
  `.notFound` error from the next `recordRoll`.
- **A stuck roll count.** A game whose `recordedRollCount` stays above the rows that will
  ever exist (an older app that undid rolls without updating the count, or Roll
  deletions that sync before the Game row) is treated as importing forever: never
  rescored and never fully repaired. Phase 2 needs an exit, such as recounting once
  persistent history shows the import finished, or after a time limit.


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
    public var isComplete: Bool                    // every game complete (OQ-10)
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
    public init(date: Date, eventType: EventType, centerID: CenterID? = nil,
                leagueID: LeagueID? = nil, oilPatternID: OilPatternID? = nil,
                lanes: String = "", notes: String = "")
}

public struct NamedRef: Sendable, Hashable, Identifiable {         // center, league, pattern pickers
    public var id: UUID
    public var name: String
}

// 1b (#91): league details for the Stats season chip ("This season (15 Aug - 11 Feb)"),
// the high series default (§6, length = gamesPerSession when a league filter is set),
// and filtering the New session league picker by center.
public struct LeagueRecord: Sendable, Hashable, Identifiable {
    public var id: LeagueID
    public var name: String
    public var centerID: CenterID?                 // League.center
    public var seasonLabel: String                 // free text, "" when not set
    public var seasonStart: Date?                  // either date may be nil; the season is
    public var seasonEnd: Date?                    // usable only when both are set
    public var gamesPerSession: Int                // default 3
}

public struct BallSummary: Sendable, Hashable, Identifiable {      // Arsenal list, ball picker (§7)
    public var id: BallID
    public var name: String
    public var brand: String
    public var weightPounds: Int
    public var intendedRole: BallRole
    public var gamesBowled: Int                    // §3.2 derived value: default ball or any
                                                   // roll override, each game once
    public var isRetired: Bool                     // 1b
    public var hasPhoto: Bool                      // 1b: photo(for:) or a placeholder
    public var isResurfaceDue: Bool                // 1b: BallMaintenance.isResurfaceDue
}
```

Of these, only `SessionMetadata` has a public init (and `RollEditOutcome`, section 3.4);
the others are built by the repositories only.

### 3.3 SessionRepository (1a)

```swift
@MainActor public final class SessionRepository {
    /// History and Home's recent list. Date descending, then createdAt descending (OQ-11).
    public func sessions() -> [SessionSummary]
    public func session(_ id: SessionID) throws -> SessionDetail
    /// Home "Resume session" (§7). First session in `sessions()` order with an
    /// incomplete game (OQ-10).
    public func resumableSession() -> SessionSummary?

    /// New session "Start" (§7): creates the session and game 1 for each bowler.
    /// `bowlers` is in lineup order; each position is stored as Game.lineupIndex
    /// (OQ-11). Returns the session; games are read back with `session(_:)`. Throws
    /// .notFound for a missing bowler, ball, center, league, or pattern.
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
    // compare). Names are trimmed of surrounding whitespace and newlines, like bowler
    // names; a blank name throws .invalidPlace(.emptyName). createLeague throws .notFound
    // for a missing center.
    public func centers() -> [NamedRef]
    public func leagues() -> [NamedRef]
    public func oilPatterns() -> [NamedRef]
    public func createCenter(name: String) throws -> CenterID
    public func createLeague(name: String, centerID: CenterID?) throws -> LeagueID
    public func createOilPattern(name: String) throws -> OilPatternID

    // 1b (#91). Same order as leagues(). leagueRecords(centerID:) returns only that
    // center's leagues, never those with no center; an unknown center gives [].
    // league(_:) throws .notFound.
    public func leagueRecords() -> [LeagueRecord]
    public func leagueRecords(centerID: CenterID) -> [LeagueRecord]
    public func league(_ id: LeagueID) throws -> LeagueRecord
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
    public var clearedFrames: [Int]     // §8: frames that lost rolls, ascending
    public init(game: GameRecord, clearedFrames: [Int])
}

@MainActor public final class GameRepository {
    public func game(_ id: GameID) throws -> GameRecord

    /// Appends at Scorer.nextRoll(in:). Validates, saves after every roll (§8).
    /// Throws .invalidGame with the violations if the roll does not fit, .invalidGame([])
    /// for other-mode input or a finalOnly or complete game, and .notFound for a missing
    /// game or ball. Saves nothing when it throws.
    public func recordRoll(_ input: RollInput, ballID: BallID?, in game: GameID) throws -> GameRecord
    /// §7 Undo. Removes the last roll, and its frame once empty. Returns the game
    /// unchanged when it has no rolls.
    public func undoLastRoll(in game: GameID) throws -> GameRecord
    /// §8: editing an earlier roll re-validates later rolls and clears every roll from
    /// the first invalid one onward. Throws .notFound for a missing game, roll, or ball,
    /// and .invalidGame when the new roll itself does not fit.
    public func replaceRoll(frameIndex: Int, rollIndex: Int, with input: RollInput,
                            ballID: BallID?, in game: GameID) throws -> RollEditOutcome

    /// §8: allowed only before the first roll, else throws .entryModeLocked.
    /// `.unknown` never locks and keeps the stored mode.
    public func setEntryMode(_ mode: EntryMode, for game: GameID) throws
    /// §8: the offer made after .entryModeLocked.
    public func clearRolls(in game: GameID) throws -> GameRecord
    /// Throws .notFound for a missing ball.
    public func setDefaultBall(_ ballID: BallID?, for game: GameID) throws
    /// finalOnly only, 0...300 (§4). Marks the game complete. Throws .notFinalOnly on
    /// a game scored from rolls, .invalidGame([.finalScoreOutOfRange]) outside 0...300.
    public func setFinalScore(_ score: Int, for game: GameID) throws
    /// §7 "Next game": one new game for every bowler who still has a game in the
    /// session, all numbered the session's highest gameIndex + 1, with the entry mode
    /// and default ball of that bowler's latest game, in lineup order.
    public func startNextGame(in session: SessionID) throws -> [GameID]
    public func deleteGame(_ id: GameID) throws
}
```

Rules:

- The repository, not the app, sets `rollIndex`, `pinCount`, `pinsKnown`, and
  `isComplete`, and recomputes the cached `finalScore` with `Scorer` on every write.
  `isComplete` is true when `Scorer.nextRoll(in:)` is nil.
- A foul in a pinByPin game is stored with `pinsKnown == true`.
- The single write path, `save(_:)`, is internal; the app writes only through the
  methods above.
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
    /// Throws .notFound before first launch.
    public func updateOwner(name: String, handedness: Handedness) throws
    /// Settings bowling style (§7). Does not touch a customized layout in 1a. A nil
    /// statsScope follows the new style; an explicit one is kept (OQ-14). Throws
    /// .notFound before first launch.
    public func setStatsProfile(_ profile: StatsProfile) throws
    /// Settings default stats scope (§6, §7). nil = follow the bowling style.
    public func setStatsScope(_ scope: StatsScope?) throws
    /// §3.3: .cannotDeleteOwner, .bowlerHasGames(count:).
    public func deleteBowler(_ id: BowlerID) throws

    // 1b, §7 Customize (#46). Each throws .notFound without an owner and touches
    // updatedAt. Saving keeps stored IDs this build cannot show (StatsPreset.layoutToSave)
    // and stores "" when the result equals the profile's preset (§4.3);
    // a reset clears the stored layout, unknown IDs included.
    public func setStatsLayout(_ cards: [StatsCardID]) throws
    public func setHomeLayout(_ cards: [StatsCardID]) throws
    /// "Reset to preset" on Stats or Home: clears that surface only.
    public func resetStatsLayout() throws
    public func resetHomeLayout() throws
    /// Clears both, when the user accepts the new preset after a bowling style change.
    public func resetLayouts() throws
}
```

`statsLayout` and `homeLayout` are the stored comma-separated strings split on ",",
unknown IDs kept. Settings "delete all data with double confirmation" (§7) is `BowlingStore.deleteAllData()`
(section 3.1, OQ-12).

### 3.6 BallRepository (1a basic, §7 Arsenal 1a; 1b full, §7 Arsenal 1b)

```swift
@MainActor public final class BallRepository {
    /// Non-retired balls, sorted by name. The roll picker reorders them by
    /// `intendedRole` in the app (OQ-13).
    public func activeBalls() -> [BallSummary]
    /// Name, weight, intended role, brand only (§7 Arsenal 1a). The name is trimmed.
    /// Throws .invalidBall(.emptyName) or .invalidBall(.weightOutOfRange).
    public func addBall(name: String, weightPounds: Int,
                        intendedRole: BallRole, brand: String) throws -> BallSummary

    // 1b: maintenance(for:), logMaintenance(_:date:surfaceGritAfter:notes:for:),
    // section 2.9. maintenance(for:) is also the resurface reminder's input (#32):
    // gamesSinceResurface counts from the latest resurface, else from the start of the
    // purchase day, else every game; compare isResurfaceDue before and after a save.

    // 1b (#28, #29, #30, #32). Every method throws .notFound for an unknown ball.
    /// Retired balls, sorted by name: the Arsenal list's Retired group (#28).
    public func retiredBalls() -> [BallSummary]
    /// Header and specs of the ball detail screen, and the edit form's values (#30).
    public func detail(for ballID: BallID) throws -> BallDetail
    /// The 1b form. Name trimmed; an empty surfaceGrit starts from factoryFinish (§7).
    /// Throws .invalidBall(...) as updateBall.
    public func addBall(_ fields: BallFields) throws -> BallDetail
    /// Replaces every editable field, so a field left at its BallFields default is
    /// cleared: the edit form starts from detail(for:).fields and changes only what the
    /// user edits. Throws .invalidBall(.emptyName), .invalidBall(.weightOutOfRange),
    /// .invalidBall(.negativeSpec), .invalidBall(.resurfaceIntervalBelowOne),
    /// .invalidBall(.purchaseDateInFuture) for a changed purchase date on a day after
    /// today; an unchanged one is not checked, since a date saved "later today" further
    /// east reads as tomorrow here after sync.
    public func updateBall(_ ballID: BallID, with fields: BallFields) throws -> BallDetail
    /// Nil when the ball has no photo.
    public func photo(for ballID: BallID) throws -> Data?
    /// At most 5 MB (5_000_000 bytes).
    public nonisolated static let maxPhotoBytes: Int
    /// The app downscales first (a JPEG for the list and detail header, well under the
    /// limit). Replaces an existing photo; empty data removes it. Throws
    /// .invalidBall(.photoTooLarge) over maxPhotoBytes, keeping the old photo.
    public func setPhoto(_ imageData: Data, for ballID: BallID) throws
    public func removePhoto(for ballID: BallID) throws
    /// Retired balls keep their games, stats, and log; they leave activeBalls().
    public func setRetired(_ isRetired: Bool, for ballID: BallID) throws
    /// Deletes the ball, its photo, and its log. Throws .ballHasGames(count:) when any
    /// game uses it as the default or on a roll override: a roll's nil ball means the
    /// game's default, so nullifying an override would credit those rolls to another
    /// ball. The app offers "Retire instead" (§3.3).
    public func deleteBall(_ ballID: BallID) throws
}

/// Every editable Ball field (§3.2 Ball). Public init; only name and weightPounds have
/// no default.
public struct BallFields: Sendable, Hashable {
    public var name: String
    public var brand: String                       // default ""
    public var weightPounds: Int                   // 6...16
    public var coverstock: Coverstock              // default .unknown
    public var coverstockName: String
    public var coreType: CoreType                  // default .unknown
    public var coreName: String
    public var rg: Double?                         // >= 0
    public var differential: Double?               // >= 0
    public var intermediateDifferential: Double?   // >= 0, asymmetric cores only
    public var intendedRole: BallRole              // default .strike; .unknown keeps stored
    public var serialNumber: String
    public var colorDescription: String
    public var releaseDate: Date?                  // month precision
    public var purchaseDate: Date?                 // not after today, checked on add
                                                   // and only when updateBall changes it
    public var factoryFinish: String
    public var surfaceGrit: String                 // current surface
    public var resurfaceIntervalGames: Int?        // nil: no reminder; else >= 1
    public var notes: String
}

public struct BallDetail: Sendable, Hashable, Identifiable {
    public var id: BallID
    public var fields: BallFields
    public var isRetired: Bool
    public var hasPhoto: Bool
    public var gamesBowled: Int                    // default or any roll override, once per game
}
```

A coverstock or core type in `BallFields` that reads the same as the stored string keeps
that string, so editing another field never overwrites a newer version's value with
`"unknown"`. The schema is unchanged; `Ball.bowler` (#93) comes later.

**Resolving a ball name by ID.** Old games and rolls keep pointing at a ball after it is
retired, so the app resolves a `ballID` (a game's `defaultBallID`, a roll's `ballID`, a
`LeaveOccurrence.ballID`) over retired balls too: `detail(for:)` for one ball, or
`activeBalls() + retiredBalls()` for a lookup table. `activeBalls()` alone is only for
pickers. `deleteBall` refuses a ball any game uses, so a `ballID` that resolves to
nothing (`.notFound`) should only come from sync; show it as an unknown ball.

### 3.7 StatsRepository (1a)

```swift
@MainActor public final class StatsRepository {
    /// Applies the filter as a SwiftData predicate (no in-memory pass, §6) and returns
    /// games of every completion state for StatsEngine, sorted by sessionDate, then
    /// gameIndex. 1b (#41): thisSeason uses `filter.leagueID`'s seasonStart and seasonEnd
    /// when both are set and in order, otherwise the last nine months. Games with no
    /// session or no bowler never match.
    public func games(matching filter: StatsFilter, now: Date, calendar: Calendar) -> [GameRecord]
    /// §6 "Default scope": EventType.competition when the bowler has at least one
    /// complete league or tournament game and `preferCompetition` is true; otherwise
    /// every event type, `.unknown` included. The app passes the owner's explicit `statsScope` as
    /// `preferCompetition` when set, and the bowling style's preference otherwise (OQ-14).
    public func defaultEventTypes(for bowler: BowlerID, preferCompetition: Bool) -> Set<EventType>
}
```

The app calls `stats.games(matching:now:calendar:)` and then `StatsEngine.report(games:filter:)`
(§2: feature models "call repositories, and run engines"). The default stats scope is
stored as `Bowler.statsScope` (OQ-14).

## 4. Stats (1a)

### 4.1 StatsFilter (§6 "Filters"; 1b fields #41)

```swift
public enum DatePreset: String, Sendable, Hashable, Codable, CaseIterable {
    case thisWeek, thisMonth, last30Days, thisSeason, allTime
}

public struct StatsFilter: Sendable, Hashable, Codable {
    public var datePreset: DatePreset
    /// "All games" is every case, `.unknown` included; "Competition" is EventType.competition.
    public var eventTypes: Set<EventType>
    public var bowlerID: BowlerID                  // OQ-15

    // 1b (#41). nil means any; all fields combine with AND.
    public var customRange: ClosedRange<Date>?     // calendar days, end day included; replaces datePreset
    public var ballID: BallID?                     // game's default ball OR any roll override (§6)
    public var oilPatternID: OilPatternID?         // the session's pattern
    public var centerID: CenterID?                 // the session's center
    public var leagueID: LeagueID?                 // the session's league; also thisSeason's dates

    public init(
        datePreset: DatePreset = .allTime, eventTypes: Set<EventType> = Set(EventType.allCases),
        customRange: ClosedRange<Date>? = nil, bowlerID: BowlerID, ballID: BallID? = nil,
        oilPatternID: OilPatternID? = nil, centerID: CenterID? = nil, leagueID: LeagueID? = nil
    )

    /// Resolves the dates by calendar day in `calendar`'s time zone (§8). Half-open:
    /// start <= date < end; nil = all time. thisSeason is the last 9 months (§6).
    public func dateInterval(now: Date, calendar: Calendar) -> DateInterval?
    /// leagueSeason: the seasonStart and seasonEnd of `leagueID`'s league, when both exist;
    /// StatsRepository looks it up. thisSeason then covers those calendar days, the end
    /// day included. Other presets and a custom range ignore it.
    public func dateInterval(now: Date, calendar: Calendar,
                             leagueSeason: DateInterval?) -> DateInterval?
    /// The in-memory form of the repository's predicate, for callers holding GameRecords.
    /// Incomplete games match too; StatsEngine excludes them.
    public func matches(_ game: GameRecord, now: Date, calendar: Calendar,
                        leagueSeason: DateInterval? = nil) -> Bool
}
```

`DatePreset` raw values are persisted with a saved filter, so the stable raw value rule
(section 1, rule 7) applies to them.

1b rules (#41):

- A filter saved by 1a decodes with every 1b field nil.
- `customRange` is stored as instants and resolved with the reader's calendar, so a saved
  filter opened in another time zone can shift by a day. Accepted for now.
- League filters match the session's league, whatever its event type; pair it with
  `eventTypes` to also require league sessions.
- The 1a-only `StatsRepository.games(matching:seasonLeague:now:calendar:)` overload is
  removed: the league that gives thisSeason its dates is now `filter.leagueID`.

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

`GameRef`, `HighGame`, `HighSeries`, `TrendPoint`, `LeaveRow`, and `StatsReport` also
have public memberwise-style inits (for tests and fixtures); the app reads reports and
does not build them.

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
    /// True for every Phase 1 card since 1b (the gap found in #100). A card added later
    /// starts false; presets and layouts leave it out until it is true.
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
    /// The saved scope (BowlerRecord.statsScope) wins: .competition -> true, .all ->
    /// false; nil or .unknown -> prefersCompetition(profile). For Home and Stats.
    public static func prefersCompetition(scope: StatsScope?, profile: StatsProfile) -> Bool
    /// 1b, §7 "Layout rules": [] -> that surface's preset; unknown IDs skipped for
    /// display. Separate functions for Stats and Home, so an empty layout falls back to
    /// the right preset (#54).
    public static func displayedStatsCards(layout: [String], profile: StatsProfile) -> [StatsCardID]
    public static func displayedHomeTiles(layout: [String], profile: StatsProfile) -> [StatsCardID]
    /// 1b (#46): the raw layout to store after Customize. BowlerRepository calls it; the
    /// app does not need to.
    public static func layoutToSave(_ cards: [StatsCardID], replacing previous: [String]) -> [String]
}
```

Rules:

- `.unknown` profile uses the casual preset (§3.2, §9).
- `competitive` is every available card in `CaseIterable` order, which is the catalog
  order (§7 "every card", OQ-18).
- The league preset ends with `openPct`, and `competitive` includes all seven 1b cards
  (§7). A bowler with an empty layout gets them with no migration. A layout saved before
  1b that holds 1b IDs (synced from a newer device) now shows them where they were saved.
- A card whose group has zero games (for example `leavesTable` when `pinGames == 0`)
  stays in place and shows an explanation (§7 "Layout rules"); the copy is the app's.
- Saving a layout (1b) keeps unknown IDs (§7). "Unknown" means any stored ID this build
  cannot show: not a `StatsCardID`, or a card whose `isAvailable` is false. Each one stays
  right after the shown card it followed, or after the nearest earlier card still in the
  layout, or first if none came before it (#46).
- Display (1b, #46) lists each card once, first occurrence wins. A layout with no card
  this build can show displays the preset, so Stats and Home are never blank. Saving an
  empty list with no unknown IDs stores "", which is the preset: an empty save means
  "use the preset", not "show nothing". The app disables Save while the list is empty,
  so a user who wants the preset uses "Reset to preset".
- Saving a layout identical to the owner's current preset for that surface (`statsCards`
  for Stats, `homeTiles` for Home) stores "", not an explicit list, so the owner keeps
  following the preset and gets cards added to it later. Any edit is stored as given.
  BowlerRepository applies this rule (#46).
- A surface is customized when its stored layout is not "". A layout holding only
  unknown IDs from a newer device counts as customized on purpose: it displays the
  preset here, but a save keeps those IDs, so the newer device's layout survives (#46).
- `StatsCardID` has no `.unknown` case: layouts are stored as raw strings and unknown
  IDs are skipped on display, so no fallback case is needed.

## 5. Demo fixture data (1a, §2, §9, issue #22)

Previews and StatsEngine tests read the same games. They live in the `BowlingFixtures`
library in the BowlingCore package, which depends only on BowlingCore (OQ-5). Because
BowlingCore cannot depend on BowlingData, bowlers and balls are fixture enums, not
BowlingData read models (#57):

```swift
// BowlingFixtures
public enum DemoFixture {
    /// 2026-10-14 12:00 UTC. Tests pass this; previews pass Date.now.
    public static let referenceDate: Date

    /// Every DemoGame (22), in DemoGame.allCases order. Session dates are whole days
    /// before `now` in the Gregorian calendar, so date presets ("this week", "last 30
    /// days") always select the same games.
    public static func games(relativeTo now: Date) -> [GameRecord]
}

/// Fixed-UUID fixture entities, each with `id` and `name`; DemoBall adds `owner` and
/// `role`, DemoSession `eventType` and `daysAgo`, DemoGame `session` and `bowler`.
public enum DemoBowler: Int, CaseIterable, Sendable {
    case owner = 1      // games in every event type and entry mode
    case partner        // bowls the league night with the owner
    case friend         // only casual and practice games: the "All games" fallback (§6)
}
public enum DemoBall: Int, CaseIterable, Sendable {
    case ownerStrike = 1, ownerSpare, partnerStrike
}
public enum DemoSession: Int, CaseIterable, Sendable {
    case leagueNight = 1     // three games, owner and partner
    case tournament          // four games: a three- and a four-game series
    case earlyLeague, practice, casualOuting
    case practiceInProgress  // holds the one incomplete game, for Resume
    case friendCasual, friendPractice
}
public enum DemoGame: Int, CaseIterable, Sendable {
    // 22 cases, ordered by session, then bowler, then gameIndex. tournament1 is a
    // perfect game; earlyLeague1 is all spares (150).
}

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

`DemoBall` has no weight or brand, and `DemoBowler` no handedness or stats profile.

Every row is covered by `DemoGames.swift`: for example leagueNight1 has a first-ball foul
then a spare, a 2-8 sleeper, a 1-2-10 washout, and a roll with the spare ball as
override; leagueNight2 a second-ball foul; tournament4 a tenth-frame foul.

Expected values for every 1a stat are hand-computed and live in the BowlingCore test
target (`Tests/BowlingCoreTests/Fixtures/`), not in the shipped fixture (OQ-5).

The app links `BowlingFixtures` for previews only (#65).

## 6. Deferred to 1b (not pinned here)

Listed so nobody builds against a guess. Each gets its own contract PR before 1b work
starts.

- ~~`StatsFilter` custom range, ball, oil pattern, center, league (§6); `GameRecord`
  center, league, pattern IDs.~~ Pinned in sections 4.1 and 2.5 (#41).
- ~~`StatsReport` 1b fields: open frame %, clean game %, head pin rate, first-ball average,
  by-frame, what-if (§6).~~ Pinned in section 6.2 (#39).
- ~~Leave occurrences: date, session, frame number, ball on the spare attempt (§6).~~
  Pinned in section 6.3 (#40).
- ~~`BallReport`, `BallComparisonRow`, `StatsEngine.ballReport(for:games:)`,
  `compareBalls(games:)` (§6 "Ball report").~~ Pinned in section 2.9 (#38).
- ~~Full `BallRecord`, coverstock and core enums, maintenance events, retire, delete with
  affected-game count, resurface due (§3.2, §7 Arsenal 1b).~~ Pinned in sections 2.2,
  2.9, 3.2 and 3.6 as `BallDetail` and `BallFields`; delete refuses a used ball with
  `.ballHasGames(count:)` instead of warning.
- ~~Layout writes from Customize and "Reset to preset" (§7), and `StatsPreset`'s
  `displayedStatsCards` and `displayedHomeTiles` (section 4.3).~~ Pinned in sections 3.5
  and 4.3 (#46).
- Center, league, pattern delete warnings (§3.3). Ball delete: section 3.6.
- CSV export (§7 Settings 1b): pinned in section 6.1.
- Owner merge and duplicate frame repair are BowlingData-internal and never reach the
  app (§3.4).

### 6.1 CSV export (1b, §7 Settings, §9 "CSV export", #43)

```swift
extension BowlingStore {
    /// Writes one CSV per entity into a fresh folder in the temporary directory, zips it
    /// with NSFileCoordinator `.forUploading`, and returns the zip's URL for the file
    /// exporter or share sheet. The zip is "Bowling Export yyyy-MM-dd.zip" (device time zone).
    @MainActor public func exportCSV(now: Date = .now) throws -> URL
}
```

The zip holds a folder of the same name with these files, in this order. Every file
starts with `id, createdAt, updatedAt, remoteID`; the remaining columns, in order:

| File | Columns after the common four |
|---|---|
| bowlers.csv | name, isOwner, handedness, email, statsProfile, statsLayout, homeLayout, statsScope |
| sessions.csv | date, eventType, centerID, leagueID, oilPatternID, lanes, notes |
| games.csv | sessionID, bowlerID, gameIndex, lineupIndex, entryMode, defaultBallID, finalScore, isComplete, scanConfidence, invitationStatus, scoredByName |
| frames.csv | gameID, frameIndex, rotationSlot |
| rolls.csv | frameID, rollIndex, pinsDownMask, pinCount, pinsKnown, isFoul, ballID |
| balls.csv | name, brand, weightPounds, coverstock, coverstockName, coreType, coreName, rg, differential, intermediateDifferential, intendedRole, serialNumber, colorDescription, releaseDate, purchaseDate, factoryFinish, surfaceGrit, resurfaceIntervalGames, isRetired, notes |
| maintenance.csv | ballID, date, kind, surfaceGritAfter, gamesOnBallAtTime, notes |
| centers.csv | name, notes, city, latitude, longitude |
| leagues.csv | name, notes, centerID, seasonLabel, seasonStart, seasonEnd, gamesPerSession |
| oilPatterns.csv | name, notes, lengthFeet, volumeMilliliters, patternKey |

Encoding: RFC 4180 (CRLF, fields with a comma, quote, CR, or LF quoted, quotes doubled),
UTF-8 with a byte order mark for Excel. UUIDs uppercase; dates ISO 8601 UTC with
milliseconds; booleans `true`/`false`; nil is an empty field; enums are the stored raw
string, unknown values included. Columns are only ever appended, never renamed or
reordered, so phase 3 can re-import by UUID. Photos are not exported.
Fields starting with `=`, `+`, `-`, or `@` are written as is, so a spreadsheet may read
them as formulas; this is accepted for now and tracked in
[#86](https://github.com/marilynjov/Bowling/issues/86).

### 6.2 StatsReport 1b fields (1b, §6 "Definitions (1b)", #39)

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
- `StatsCardID.isAvailable` is true for the seven 1b cards: `openPct` reads
  `openFrames`, `cleanGamePct` `cleanGames`, `firstBallAverage` `firstBallAverage`,
  `headPinRate` `headPin`, `byFrameStrike` `byFrame[].strikes`, `byFrameAverage`
  `byFrame[].pins`, `whatIfSinglePins` `whatIfSinglePins`. A card whose group has zero
  games (for example `headPinRate` with `pinGames == 0`) stays in place with an
  explanation, as in section 4.

### 6.3 Leave occurrences (1b, §6 "Definitions (1b)", #40)

Pinned by #40; needs review by both developers.

```swift
/// One spare attempt at a leave, addressed by game ID plus frame index (OQ-7).
public struct LeaveOccurrence: Sendable, Hashable, Codable, Identifiable {
    public struct ID: Sendable, Hashable, Codable { public var gameID: GameID; public var frameIndex: Int }
    public var id: ID { get }          // game ID plus frame index (OQ-7)
    public var game: GameRef           // game ID, session ID, session date
    public var gameIndex: Int
    public var frameIndex: Int         // 1...10; a frame holds at most one spare attempt
    public var ballID: BallID?         // spare roll's override, else the game's default ball
    public var isConverted: Bool
}

extension StatsEngine {
    /// Complete pinByPin games only, like the leaves table; matches on `leave.pins`.
    /// Newest first: session date, session, game index, frame, all descending. Sessions
    /// on the same date keep their order in `games`, a later one being newer.
    public static func leaveOccurrences(of leave: Leave, games: [GameRecord]) -> [LeaveOccurrence]
}

extension StatsRepository {
    /// Same games as games(matching:now:calendar:), then the engine, with
    /// same-date sessions in History's order (date, then createdAt, newest first).
    public func leaveOccurrences(of leave: Leave, matching filter: StatsFilter,
                                 now: Date, calendar: Calendar) -> [LeaveOccurrence]
}
```

Rules:

- The app passes the `LeaveRow.leave` it was tapped from and the same filter as the
  report, so the list's count equals the row's count.
- Occurrences after a first-ball foul do not exist (no leave, §5), and a frame 10 fill
  ball is not a spare attempt, so its leave is never listed.
- The app shows the session from `game.sessionID` and the ball name from `ballID`,
  resolved over active and retired balls as section 3.6 describes; it does not re-sort
  the list.

## 7. What the app may not do

- Import SwiftData or touch `ModelContext` (OQ-1, OQ-20).
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
20. **OQ-20, public container factory.** `BowlingStore.schema` and
    `BowlingStore.makeContainer(inMemory:)` are public in BowlingData (44f7523) and hand
    out a SwiftData `Schema` and `ModelContainer`, which rule 1 and OQ-1 keep away from
    the app. Make them internal, or keep them public for app wiring and say so in rule 1?
   **Decision:** Make both internal (#76). The app doesn't use them; with no `@Query` in 1a it
   never needs a `ModelContainer`, and `BowlingStore(inMemory:)` covers previews and tests.
   Phase 2's CloudKit setup stays inside BowlingData.
