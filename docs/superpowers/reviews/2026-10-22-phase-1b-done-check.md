# Phase 1b done check (#49)

Date: 2026-10-22. Checked against `origin/main` at `00ac432` (merge of #98). Criteria
from section 11 of `docs/superpowers/specs/2026-10-07-phase-1-core-scoring-design.md`.
PR #99 (schema review, #48) is open and awaiting marilynjov, so its criterion is pending
on #99. This PR changes no code.

## Test runs on main

| Run | Result |
|---|---|
| `swift test --package-path Packages/BowlingCore` | 265 tests in 28 suites, all passed |
| `swift test --package-path Packages/BowlingData` | 244 tests in 21 suites, all passed |
| `xcodebuild -scheme Bowling -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build test` | BUILD SUCCEEDED, TEST SUCCEEDED: 219 test cases passed, 0 failed |

## Phase 1b criteria

| Criterion | Status | Evidence | Owner |
|---|---|---|---|
| Every stat in section 6 renders from fixture data under any combination of filters | missing | Engine and filters are done: #39 (PR #82) `StatsEngine1bTests` (`openAndCleanGames`, `firstBalls`, `byFrame`, `whatIfSinglePins`, `perGame`), `DemoFixture1bTotalsTests`, `StatsEngineWhatIfRescoreTests`; #41 (PR #83) `StatsFilter1bTests.everyBallCenterPatternLeagueCombination`, `filtersCombine`, `StatsRepository1bTests.predicateAgreesWithInMemoryFilter`; #40 (PR #80) `LeaveOccurrenceTests`, `LeaveOccurrenceQueryTests`. Nothing renders yet: `Bowling/Features/Stats/StatsScreen.swift` is a placeholder (#10 open), and #33, #34, #35 are open. `StatsCardID.isAvailable` is still false for the seven 1b cards (`StatsCards.swift`, pinned by `StatsCardTests.onlyPhase1aCardsAreAvailable`), so presets and layouts drop them. | marilynjov (screens), Santiago (flip `isAvailable`) |
| Ball detail shows correct strike-ball and spare-ball attribution for the mixed-ball fixture | missing | Data side done: #38 and #42 (PR #84), `MixedBallFixture`, `BallReportTests` (`asAStrikeBallCountsOnlyFirstBallsThrownWithIt`, `asASpareBallCountsOnlySpareAttemptsThrownWithIt`, `usage`, `groupsUnderTenFirstBallsFoldIntoOther`, `overTimeIsStrikeRatePerSession`, `compareBallsReturnsOneRowPerBallInOrder`), `BallReportStoreTests.ballReportFromTheStore`. No ball detail screen: `ArsenalScreen.swift` is a placeholder; #28, #30, #31 open. | marilynjov |
| A resurface reminder fires when a game crosses a ball's interval | missing | Calculation done: #42 (PR #84) `BallMaintenance.isResurfaceDue`, `BallMaintenanceTests.resurfaceIsDueAtOrPastTheInterval`, `BallMaintenanceRepositoryTests`. No notification code in the app (#32 open). BowlingData has no public way to set `Ball.resurfaceIntervalGames`: `BallRepository` only has `activeBalls()` and `addBall(name:weightPounds:intendedRole:brand:)`, and contract 3.6 lists the full add/edit form, photo, retire and delete as "not yet pinned". Firing on a device is a manual check. | Santiago (ball edit API), marilynjov (#32), human (device check) |
| An exported CSV opens correctly in Numbers and Excel and contains every entity's UUID | pending | Export done: #43 (PR #81) `CSVExportTests` (`fixtureEntitiesKeepTheirUUIDs`, `everyUUIDIsUniqueAcrossFiles`, `framesAndRollsPointAtExportedParents`, `zipHoldsEveryFileByteForByte`), `CSVTableTests.dataIsUTF8WithAByteOrderMarkSoExcelReadsAccents`, `fieldsWithCommasQuotesOrNewlinesAreQuoted`. No Settings export button (#37 open, `SettingsScreen.swift` is a placeholder). Opening the files in Numbers and Excel has not been done. | marilynjov (#37), human (open in Numbers and Excel) |
| The owner merge rule and the duplicate frame repair pass their tests | met | #44 (PR #79) `OwnerMergeTests` (including `twoOwnersKeepTheOldestAndMoveTheNewerOnesGames`, `runningTheMergeAgainChangesNothing`); #45 (PR #85) `DuplicateRepairTests` (including `keepsTheNewestFrameAndRollThenValidatesAndScores`, `secondRepairChangesNothing`). Both pass in the BowlingData run above. #99 extends both (duplicate games, orphan guard); recheck after it merges. | Santiago |
| A customized Stats and Home layout survives an app relaunch and a reset to preset | missing | Data side done: #46 (PR #78) `StatsLayoutTests`, `BowlerLayoutTests` (`savedLayoutsAreReadBackByAFreshContext`, `resetStatsLayoutReturnsToThePresetAndLeavesHomeAlone`, `resetHomeLayoutReturnsToThePresetAndLeavesStatsAlone`, `resetLayoutsClearsBothIncludingUnknownCardIDs`). No Customize screen (#36 open). The relaunch needs an app test or a manual check. | marilynjov (#36), human (relaunch check) |
| The schema has been reviewed against every rule in section 3.1 | pending | PR #99 (closes #48): `docs/superpowers/reviews/2026-10-21-schema-review.md` and extended `SchemaTests`. Open, review state "changes requested", awaiting marilynjov. On main today `SchemaTests` covers optional relationships with inverses, no unique attributes, and external storage for photos. | Santiago (#99), marilynjov (review) |

## Phase 1a criteria (still met?)

| Criterion | Status | Evidence | Owner |
|---|---|---|---|
| Perfect game, all-spares game, fouls, and every tenth-frame variant score correctly in tests | met | #18 (PR #56) `ScorerScoreTests.fullGame` ("perfect game", "all spares with 5 count", ...), `ScorerScoreTests.tenthFrame` (every tenth-frame variant), `ScorerFoulTests` (`foulInTenthFrame`, `firstBallFoulThenFullRackIsASpare`, `foulCountsZeroAsAStrikeBonus`, ...), `ScorerValidationTests`. Passing in the BowlingCore run above. | Santiago |
| Every 1a stat renders from fixture data, with the competition default applied, and each bowling style shows its preset | missing | Data side done: #23 (PR #59) `StatsEngineTests`, #24 (PR #58) `StatsFilterTests`, #25 (PR #54) `StatsPresetTests`, `StatsDefaultScopeTests`, #22 (PR #57) demo fixtures. Home tiles render (#11, PR #94, `HomeTilesTests`). The Stats screen is a placeholder (#10 open). | marilynjov |
| A full three-game league night for two bowlers can be entered offline, pin by pin | missing | One game scores (#8, PR #96, `ScoringModelTests`, `ScoringModelEntryTests`, `ScoringFlowTests`); data side done (#26, PR #61, `RollEntryTests`, `GameRepositoryTests`). Bowler rotation, next game and summary are in #95 (open); the UI test is #15 (open). | marilynjov |
| Real bowlers on TestFlight have used the pin deck for a league night and feedback is addressed | missing | #2 and #3 open. Needs #75 (app icon) and #27 (Sentry and privacy manifest) before a TestFlight build. | human, marilynjov |

## Other open Phase 1b issues

Not done criteria, but open in the milestone: #47 licensing for ball specs and oil
patterns (human), #93 balls belong to a bowler (Santiago), #28 and #29 Arsenal list and
ball form (marilynjov).

## Gaps and suggested issues

None of these issues has been created.

1. **1b stat cards are switched off.** `StatsCardID.isAvailable` returns false for
   `openPct`, `cleanGamePct`, `firstBallAverage`, `headPinRate`, `byFrameStrike`,
   `byFrameAverage`, `whatIfSinglePins`. Suggested issue (owner:data, Phase 1b): "Make
   the 1b stats cards available", flipping `isAvailable` and updating
   `StatsCardTests.onlyPhase1aCardsAreAvailable` and the preset tests, timed with #35.
2. **No ball edit API.** Contract 3.6 leaves the full add/edit form, photo, retire, and
   delete with affected-game count unpinned, and nothing can set
   `resurfaceIntervalGames`, which the reminder needs. Suggested issue (owner:data,
   contract, Phase 1b): "BallRepository 1b: edit every field, interval, photo, retire,
   delete", blocking #29, #28 and #32. Coordinate with #93.
3. **Stats screen and 1b stats UI.** #10, #33, #34, #35 cover it; no new issue.
   (marilynjov)
4. **Arsenal screens.** #28, #29, #30, #31 cover it; no new issue. (marilynjov)
5. **Resurface notification.** #32 covers it. Suggested addition: a test that saving a
   game which reaches the interval schedules one notification for 9:00 the next morning,
   using an injectable scheduler. (marilynjov)
6. **CSV export in Settings.** #37 covers the button. Suggested issue (owner:frontend,
   test, Phase 1b): "Manual check: CSV export in Numbers and Excel", opening each file
   from the zip and recording that UUIDs and accents survive. (human)
7. **Layout survives relaunch.** #36 covers the screen. Suggested addition to #36: a UI
   test that customizes Stats and Home, relaunches, checks the order, resets, and checks
   the preset. (marilynjov)
8. **Schema review.** Pending on #99. After it merges, recheck the owner merge and
   duplicate repair criterion against the extended tests. (Santiago, marilynjov review)
9. **1a carry-over.** #10, #95, #15, #2, #3, #75, #27 are still open, so 1a is not done
   either. No new issue. (marilynjov, human)
10. **Licensing.** #47 is open. (human)
