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

Result for the whole schema: it already follows every rule. No model changes are needed.
The fixes below are tests that lock the rules in and a spec wording fix.

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

## Issue #89 (orphan games)

No schema change is required for the fixes #89 proposes: "only claim orphans that stay
orphaned after the import" and "leave them unassigned" both work on the current fields.
One option does touch the schema, so it is listed as question 2 below.

## Later phases

Fields phases 3 to 8 need that are not reserved yet. All are pure additions, which stay
allowed after promotion, so none has to land before phase 2:

- Phase 3: a source-app tag on `Game` for imported games (question 4).
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

## Questions for Santiago

1. **Versioned schema after promotion.** `BowlingSchemaV1` lists the top-level model
   classes, and `lineupIndex` was added to V1 in place (the code still handles "games
   stored before `lineupIndex` existed"). Once a migration plan is in use, changing V1's
   models in place can leave existing stores at a version hash the plan does not know.
   Before release, decide the pattern for V2: nested model copies per version with a
   lightweight stage, or no migration plan until a custom stage is needed. Worth testing
   on a device that still has an old store.
2. **Denormalized bowler ID on Game (#89).** A `Game.bowlerID: UUID?` copy of
   `bowler.id` would let `mergeOwners()` tell "bowler not imported yet" or "bowler deleted
   on another device" from a true orphan, without timing heuristics. Cheap now; added
   after release, games synced before it would lack the value. Add it, or solve #89
   without schema changes?
3. **CloudKit encryption for personal fields.** `@Attribute(.allowsCloudEncryption)` can
   only be set when a field is first created in CloudKit, not added later. Candidates:
   `Bowler.email` (a third party's address, phase 7), `BowlingCenter.latitude`/
   `longitude`, and free-text `notes`. Encrypted fields cannot be queried server side,
   which this app never does. Encrypt any of these before promotion?
4. **Import source tag.** Phase 3 tags each imported game with its source app. Add a
   `Game.importSource: String?` now, or wait for phase 3 (it is a pure addition either
   way)?
5. **Duplicate games after offline sync.** Spec 3.4 repairs duplicate frames and rolls,
   but "Next game" on two offline devices can create two games with the same bowler and
   `gameIndex` in one session. Both may hold real rolls, so they cannot simply be merged.
   Not a schema change, but should spec 3.4 cover it (for example, renumber by
   `createdAt`) before phase 2?
