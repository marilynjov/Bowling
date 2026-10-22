# Schema review before phase 2 (#48)

Date: 2026-10-21. Reviewer: SantiagoM99.

Scope: every `@Model` in `Packages/BowlingData/Sources/BowlingData/Models`, checked against
section 3.1 of the phase 1 design spec, the CloudKit rules in `AGENTS.md` and the roadmap,
and what phases 2 to 8 will need. Phase 2 promotes the CloudKit schema, after which
attributes and entities can only be added.

Rules checked for every entity:

- **Defaults**: every attribute has a default or is optional.
- **Unique**: no `@Attribute(.unique)`.
- **Relationships**: optional, explicit inverse, delete rule Nullify or Cascade only.
- **Ordering**: no to-many relationship read in array order; a sort key exists.
- **Enums**: stored as a raw `String` with a `StoredEnum` fallback for unknown values.
- **Types**: only scalar types CloudKit supports (String, Int, Double, Bool, Date, UUID,
  Data). No Codable structs, arrays, or transformables.
- **Common**: `id`, `createdAt`, `updatedAt`, `remoteID` present.
- **Names**: names we will not want to rename later.

Result for the whole schema: it already follows every rule. The review added tests that
lock the rules in and fixed the spec wording. After Santiago decided the open questions,
it also added `Game.bowlerID`, CloudKit encryption on three personal fields, and repair of
duplicate games (see "Decisions").

## Bowler

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | All attributes defaulted; `email` optional |
| Unique | Pass | None |
| Relationships | Pass | `games` optional, inverse `Game.bowler`, Nullify |
| Ordering | Pass | `games` only counted or grouped; sessions sort by `lineupIndex`, `gameIndex` |
| Enums | Pass | `handedness`, `statsProfile` use `StoredEnum`; `statsScope` decodes through BowlingCore `StatsScope(storedValue:)`, empty means follow style |
| Types | Pass | String, Bool |
| Common | Pass | |
| Names | Pass | `statsLayout`/`homeLayout` as comma-separated card IDs are a stable format; new card IDs only add |
| Encryption | Fix | `email` is a third party's address; now `.allowsCloudEncryption` (decision 3) |

## Session

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | |
| Unique | Pass | |
| Relationships | Pass | `games` Cascade; `center`, `league`, `oilPattern` to-one, implicit Nullify, inverses declared on the other side |
| Ordering | Pass | `gamesByBowler()` sorts by `lineupIndex`, then `gameIndex` |
| Enums | Pass | `eventType` with fallback `casual` |
| Types | Pass | |
| Common | Pass | |
| Names | Pass | |

## Game

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | `gameIndex`/`lineupIndex` default 1; reserved fields optional or defaulted |
| Unique | Pass | |
| Relationships | Pass | `frames` and `photo` Cascade; `session`, `bowler`, `defaultBall` implicit Nullify |
| Ordering | Pass | `record()` sorts frames by `frameIndex`; never uses array order |
| Enums | Pass | `entryMode`, `invitationStatus` with fallbacks; conversions keep BowlingCore `.unknown` |
| Types | Pass | |
| Common | Pass | |
| Names | Pass | Phase 4 (`scanConfidence`, `photo`) and phase 7 (`invitationStatus`, `scoredByName`) fields reserved |
| Sync | Fix | Added `bowlerID: UUID?` so a game keeps its bowler's identity when the bowler is deleted or not imported yet (decision 2) |

## Frame

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | |
| Unique | Pass | |
| Relationships | Pass | `rolls` Cascade, `game` implicit Nullify |
| Ordering | Pass | Rolls sorted by `rollIndex` in `record()`; duplicate repair keys on `frameIndex`/`rollIndex` |
| Enums | Pass | None |
| Types | Pass | |
| Common | Pass | |
| Names | Pass | `rotationSlot` reserved for Baker |

## Roll

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | |
| Unique | Pass | |
| Relationships | Pass | `frame`, `ball` implicit Nullify, inverses on `Frame.rolls`, `Ball.rollsAsOverride` |
| Ordering | Pass | `rollIndex` |
| Enums | Pass | None |
| Types | Pass | `pinsDownMask` as Int is a stable ten-bit format |
| Common | Pass | |
| Names | Pass | `pinCount`/`pinsKnown` already cover phase 4 scanned games |

## Ball

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | `weightPounds` default 0 exists only for CloudKit; `init` requires a weight |
| Unique | Pass | |
| Relationships | Pass | `photo`, `maintenance` Cascade; `gamesAsDefault`, `rollsAsOverride` Nullify |
| Ordering | Pass | Maintenance read by `date` |
| Enums | Pass | `coverstock`, `coreType`, `intendedRole` with fallbacks |
| Types | Pass | |
| Common | Pass | |
| Names | Pass | Phase 8 drilling fields will be additions |

## GamePhoto and BallPhoto

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | `imageData` defaults to empty Data |
| Unique | Pass | |
| Relationships | Pass | To-one back to owner, implicit Nullify; owner cascades |
| Ordering | Pass | One-to-one |
| Enums | Pass | None |
| Types | Pass | Data with `.externalStorage`, synced as a CKAsset |
| Common | Pass | |
| Names | Pass | Binary data kept off `Game` and `Ball`, as the roadmap requires |

## MaintenanceEvent

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | |
| Unique | Pass | |
| Relationships | Pass | `ball` implicit Nullify; `Ball.maintenance` cascades |
| Ordering | Pass | `date` |
| Enums | Pass | `kind` with fallback `other` |
| Types | Pass | |
| Common | Pass | |
| Names | Pass | |

## BowlingCenter, League, OilPattern

| Check | Result | Reason |
|---|---|---|
| Defaults | Pass | Optional location, season, and pattern figures; `gamesPerSession` default 3 |
| Unique | Pass | Same-name records on two devices are merged by hand in phase 2 (spec 3.4) |
| Relationships | Pass | Every to-many Nullify; `League.center` implicit Nullify |
| Ordering | Pass | Not ordered |
| Enums | Pass | None |
| Types | Pass | |
| Common | Pass | |
| Names | Pass | `patternKey` links to the phase 8 bundled library by string key, never by relationship |
| Encryption | Fix | `BowlingCenter.latitude`/`longitude` now `.allowsCloudEncryption` (decision 3) |

## Issue #89 (orphan games)

`Game.bowlerID` now records which bowler an orphan game belonged to (decision 2). The
rule in `mergeOwners()` is unchanged: it still claims every game with no bowler. Choosing
the new rule is still open in #89 (see "Still open").

## Later phases

Fields phases 3 to 8 need that are not reserved yet. All are pure additions, which stay
allowed after promotion, so none has to land before phase 2:

- Phase 3: a source-app tag on `Game` for imported games (deferred, decision 4).
- Phase 5: Baker frames owned by different bowlers, likely `Frame.bowler` with an inverse
  on `Bowler`; league handicap, roster, and schedule as new entities.
- Phase 6: per-frame practice questions as new entities.
- Phase 8: drilling layout and hand measurements on `Ball`; a MapKit place identifier on
  `BowlingCenter`.

## Fixes made

1. `SchemaTests` now locks in the rules: delete rules match the spec 3.3 table (every
   relationship not listed there nullifies), no minimum or maximum relationship counts,
   every attribute has a default or is optional, `id`/`createdAt`/`updatedAt`/`remoteID`
   on every entity with the right types, CloudKit scalar types only, binary data only on
   the photo entities, and an additive-only snapshot of every attribute and relationship
   name. Checked by mutation: a removed default, a Cascade on `Bowler.games`, and a
   renamed attribute each fail.
2. Spec 3.1 lists `Game.lineupIndex` as a sort key and states that the side without the
   inverse keeps SwiftData's default Nullify; spec 3.2 says `Session.games` sorts by
   `lineupIndex`, then `gameIndex`. The code already did both.
3. `Game.bowlerID: UUID?`, written only through `Game.assign(_:)` (`Game.bowler` is
   `private(set)`). Set by `startSession`, `quickScore`, next game, owner merge, and the
   demo fixtures. It survives the bowler's Nullify delete. Tests in `GameBowlerIDTests`,
   `OwnerMergeTests`, and `DeleteRuleTests`.
4. `@Attribute(.allowsCloudEncryption)` on `Bowler.email`, `BowlingCenter.latitude`, and
   `BowlingCenter.longitude`. `SchemaTests.onlyPersonalFieldsAreEncrypted` locks the exact
   set. Spec 3.1 and 3.2 record it.
5. `repairDuplicates()` removes duplicate games before the frame and roll repair (spec
   3.4 "Duplicate games"). Tests in `DuplicateGameRepairTests` cover each tiebreak,
   matching by `bowlerID`, idempotence, and two devices reaching the same game.

### After marilynjov's review of PR #99

6. Duplicate games rank by `Game.recordedRollCount` (new attribute, written by
   `Game.apply(_:in:)` on every roll write), then `updatedAt`, then UUID: Game-row fields
   only, since CloudKit can deliver a Game row before its frames. A game holding fewer
   rolls than its count is not rescored while it imports. A frame that arrives after its
   game was deleted stays unlinked; no repair deletes it (spec 3.4).
7. `mergeOwners()` skips orphan games whose `bowlerID` is set and is not an owner's.
8. Spec 3.4 states the repair order (`repairDuplicates` before `mergeOwners`) and that
   survivors are chosen per bowler.
9. `Game.bowlerID` is `private(set)`; only `assign(_:)` writes it.
10. `repairDuplicates()` returns `DuplicateRepairResult` with the deleted game IDs; the
    contract notes that phase 2's change signal must carry them.

## Decisions (Santiago, 2026-10-21)

1. **Versioned schema after promotion.** Keep `BowlingSchemaV1` as is until phase 2.
   `lineupIndex`, `bowlerID`, and the encryption options were changed in V1 in place,
   which is fine before release. Phase 2 decides the pattern for later versions and
   tests opening an old store. No code change.
2. **`Game.bowlerID` for #89.** Added now (fix 3).
3. **CloudKit encryption.** `Bowler.email` and the center coordinates are encrypted
   (fix 4). `notes` stays unencrypted.
4. **Import source tag.** Deferred to phase 3, where it is a pure addition.
5. **Duplicate games after offline sync.** Decided: same session, same bowler
   (`bowlerID` where set), same `gameIndex` means duplicates. Keep the one with the higher
   `recordedRollCount`, then the newer `updatedAt`, then the smaller UUID string; delete
   the others with their frames; never merge rolls across games (fixes 5 and 6).

## Still open

- **#89 orphan rule.** `mergeOwners()` now leaves alone orphans whose `bowlerID` names
  another bowler (fix 7), but still claims orphans with no `bowlerID`. #89 still needs
  the check of how NSPersistentCloudKitContainer batches related records on import
  before the rest of the rule is chosen.
- **Unlinked frames.** Frames that arrive for a deleted game stay with `game == nil`.
  Phase 2 can clean them up once persistent history shows an import has finished.
- **Single repair entry point.** Neither repair has a caller yet. Phase 2 adds the one
  entry point that runs them in the spec 3.4 order.
- Games created before `bowlerID` existed have it nil. Phase 1 has not shipped, so only
  development stores have such games.
