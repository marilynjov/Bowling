# Phase 1b done check (#49)

First written 2026-10-22, re-checked 2026-10-27 against `origin/main` at `b1f89f7` (merge
of #108). Since the first check, #99, #101, #104, #105, #106, #107, #108, #109 and #111
have merged. Criteria from section 11 of
`docs/superpowers/specs/2026-10-07-phase-1-core-scoring-design.md`. This PR changes no
code.

## Test runs on main

| Run | Result |
|---|---|
| `swift test --package-path Packages/BowlingCore` | 269 tests in 28 suites, all passed |
| `swift test --package-path Packages/BowlingData` | 325 tests in 28 suites, all passed |
| `xcodebuild -scheme Bowling -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build test` | BUILD SUCCEEDED, TEST FAILED: 331 test cases passed, 1 failed |

The app failure is `SessionScoringModelTests.nextGameOnAnUnevenNightOpensTheReturnedGames`
(from PR #108). It expects the next games on an uneven night to be numbered `[3, 2]`.
PR #111, which merged just before #108, makes `startNextGame` give every bowler the
session's highest game number plus one, so Alex now gets 3. The two PRs were tested
apart and conflict only on main. See gap 11.

## Phase 1b criteria

| Criterion | Status | Evidence | Owner |
|---|---|---|---|
| Every stat in section 6 renders from fixture data under any combination of filters | missing | Engine and filters are done: #39 (PR #82) `StatsEngine1bTests` (`openAndCleanGames`, `firstBalls`, `byFrame`, `whatIfSinglePins`, `perGame`), `DemoFixture1bTotalsTests`, `StatsEngineWhatIfRescoreTests`; #41 (PR #83) `StatsFilter1bTests.everyBallCenterPatternLeagueCombination`, `filtersCombine`, `StatsRepository1bTests.predicateAgreesWithInMemoryFilter`; #40 (PR #80) `LeaveOccurrenceTests`, `LeaveOccurrenceQueryTests`. Every card is available (PR #105, `StatsCardID.isAvailable` is `true`, `StatsCardTests.everyPhase1CardIsAvailable`). Nothing renders yet: `Bowling/Features/Stats/StatsScreen.swift` is a placeholder (#10 open, PR #112 open), and #33, #34, #35 are open. | marilynjov |
| Ball detail shows correct strike-ball and spare-ball attribution for the mixed-ball fixture | missing | Data side done: #38 and #42 (PR #84), `MixedBallFixture`, `BallReportTests` (`asAStrikeBallCountsOnlyFirstBallsThrownWithIt`, `asASpareBallCountsOnlySpareAttemptsThrownWithIt`, `usage`, `groupsUnderTenFirstBallsFoldIntoOther`, `overTimeIsStrikeRatePerSession`, `compareBallsReturnsOneRowPerBallInOrder`), `BallReportStoreTests.ballReportFromTheStore`. `ArsenalScreen.swift` shows the 1a list and add form (#12, PR #109); rows are display only. Ball detail (#30) and Compare (#31) are open. | marilynjov |
| A resurface reminder fires when a game crosses a ball's interval | missing | Data side done: #42 (PR #84) `BallMaintenance.isResurfaceDue`, `BallMaintenanceTests.resurfaceIsDueAtOrPastTheInterval`; PR #106 `BallRepository.updateBall(_:with:)` with `BallFields.resurfaceIntervalGames` (`BallEditTests`, `BallRepositoryTests.resurfaceDueFollowsTheIntervalAndTheLatestResurface`); PR #107 `BallSummary.isResurfaceDue` (`BallMaintenanceRepositoryTests.summaryResurfaceDueAgreesWithMaintenance`). No notification code in the app (#32 open). Firing on a device is a manual check. | marilynjov (#32), human (device check) |
| An exported CSV opens correctly in Numbers and Excel and contains every entity's UUID | pending | Export done: #43 (PR #81) `CSVExportTests` (`fixtureEntitiesKeepTheirUUIDs`, `everyUUIDIsUniqueAcrossFiles`, `framesAndRollsPointAtExportedParents`, `zipHoldsEveryFileByteForByte`), `CSVTableTests.dataIsUTF8WithAByteOrderMarkSoExcelReadsAccents`, `fieldsWithCommasQuotesOrNewlinesAreQuoted`. No Settings export button (#37 open, `SettingsScreen.swift` is a placeholder). Opening the files in Numbers and Excel has not been done. #110 (open) will make the games table's `bowlerID` column read `Game.bowlerID`. | marilynjov (#37), human (open in Numbers and Excel), Santiago (#110) |
| The owner merge rule and the duplicate frame repair pass their tests | met | #44 (PR #79) `OwnerMergeTests` (including `twoOwnersKeepTheOldestAndMoveTheNewerOnesGames`, `runningTheMergeAgainChangesNothing`, and from PR #99 `gamesOfAnotherBowlerWaitingForTheirBowlerStayUnassigned`, `movedGamesTakeTheKeptOwnersBowlerID`); #45 (PR #85) `DuplicateRepairTests` (including `keepsTheNewestFrameAndRollThenValidatesAndScores`, `secondRepairChangesNothing`, and from PR #99 the duplicate games tests `keepsTheGameWithMoreRolls`, `aCopyWithoutItsFramesStillWinsByItsRowCount`, `everyDeviceKeepsTheSameGame`). All pass in the BowlingData run above. | Santiago |
| A customized Stats and Home layout survives an app relaunch and a reset to preset | missing | Data side done: #46 (PR #78) `StatsLayoutTests`, `BowlerLayoutTests` (`savedLayoutsAreReadBackByAFreshContext`, `resetStatsLayoutReturnsToThePresetAndLeavesHomeAlone`, `resetHomeLayoutReturnsToThePresetAndLeavesStatsAlone`, `resetLayoutsClearsBothIncludingUnknownCardIDs`). No Customize screen (#36 open). The relaunch needs an app test or a manual check. | marilynjov (#36), human (relaunch check) |
| The schema has been reviewed against every rule in section 3.1 | met | PR #99 merged (closes #48) after two review rounds: `docs/superpowers/reviews/2026-10-21-schema-review.md` and `SchemaTests` (`everyRelationshipIsOptionalWithAnInverse`, `deleteRulesMatchTheSpecTable`, `everyAttributeHasADefaultOrIsOptional`, `everyEntityHasTheCommonFields`, `attributeTypesAreCloudKitScalars`, `noAttributeIsUnique`, `schemaIsAdditiveOnly`, `onlyPersonalFieldsAreEncrypted`). Follow-ups #110 (open) and #89 (open, Phase 2) do not change the schema. | Santiago |

## Phase 1a criteria (still met?)

| Criterion | Status | Evidence | Owner |
|---|---|---|---|
| Perfect game, all-spares game, fouls, and every tenth-frame variant score correctly in tests | met | #18 (PR #56) `ScorerScoreTests.fullGame` ("perfect game", "all spares with 5 count", ...), `ScorerScoreTests.tenthFrame` (every tenth-frame variant), `ScorerFoulTests` (`foulInTenthFrame`, `firstBallFoulThenFullRackIsASpare`, `foulCountsZeroAsAStrikeBonus`, ...), `ScorerValidationTests`. Passing in the BowlingCore run above. | Santiago |
| Every 1a stat renders from fixture data, with the competition default applied, and each bowling style shows its preset | missing | Data side done: #23 (PR #59) `StatsEngineTests`, #24 (PR #58) `StatsFilterTests`, #25 (PR #54) `StatsPresetTests`, `StatsDefaultScopeTests`, #22 (PR #57) demo fixtures. Home tiles render (#11, PR #94, `HomeTilesTests`). The Stats screen is a placeholder (#10 open, PR #112 open). | marilynjov |
| A full three-game league night for two bowlers can be entered offline, pin by pin | pending | One game scores (#8, PR #96); rotation, frame edits, next game and the game summary are in (#95, PR #101); every bowler's next game gets the same number (PR #111, `GameRepositoryTests`); History lists and edits the night (#9, PR #108). Data side done (#26, PR #61, `RollEntryTests`, `GameRepositoryTests`). The UI test for the full night is #15 (open). `SessionScoringModelTests.nextGameOnAnUnevenNightOpensTheReturnedGames` fails on main (gap 11). | marilynjov |
| Real bowlers on TestFlight have used the pin deck for a league night and feedback is addressed | missing | #2 and #3 open. The app icon is in (#75, PR #104). #27 (Sentry and privacy manifest) still blocks a TestFlight build. | human, marilynjov |

## Other open Phase 1b issues

Not done criteria, but open in the milestone: #47 licensing for ball specs and oil
patterns (human), #93 balls belong to a bowler (Santiago), #28 and #29 full Arsenal list
and ball form (marilynjov).

## Gaps and suggested issues

None of these issues has been created.

1. **1b stat cards were switched off.** Resolved by PR #105: every card is available.
2. **No ball edit API.** Resolved by PR #106 (`updateBall`, photo, retire, delete, contract
   3.6 pinned) and PR #107 (follow-ups from its review).
3. **Stats screen and 1b stats UI.** #10 (PR #112), #33, #34, #35 cover it; no new issue.
   (marilynjov)
4. **Arsenal screens.** The 1a list and add form are in (PR #109). #28, #29, #30, #31
   cover the rest; no new issue. (marilynjov)
5. **Resurface notification.** #32 covers it. Suggested addition: a test that saving a
   game which reaches the interval schedules one notification for 9:00 the next morning,
   using an injectable scheduler. (marilynjov)
6. **CSV export in Settings.** #37 covers the button. Suggested issue (owner:frontend,
   test, Phase 1b): "Manual check: CSV export in Numbers and Excel", opening each file
   from the zip and recording that UUIDs and accents survive. (human) #110 covers the
   `bowlerID` column. (Santiago)
7. **Layout survives relaunch.** #36 covers the screen. Suggested addition to #36: a UI
   test that customizes Stats and Home, relaunches, checks the order, resets, and checks
   the preset. (marilynjov)
8. **Schema review.** Resolved by PR #99. #89 stays open for Phase 2. (Santiago)
9. **1a carry-over.** #10, #13, #14, #15, #2, #3 and #27 are still open in Phase 1a, so
   1a is not done either. #9 (History) closed with PR #108. No new issue. (marilynjov,
   human)
10. **Licensing.** #47 is open. (human)
11. **App test broken on main.** `SessionScoringModelTests.nextGameOnAnUnevenNightOpensTheReturnedGames`
    still expects `[3, 2]`; after PR #111 the numbers are `[3, 3]`. Suggested issue
    (owner:frontend, test, Phase 1a): "Update the uneven-night next-game test for #111".
    `main` should build and pass, so this one is urgent. (marilynjov)
