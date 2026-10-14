# Working on Bowling

iOS bowling tracker (SwiftUI, SwiftData, Swift Testing, Swift Charts). Two-person team:
marilynjov is the frontend developer (`Bowling/` app target), SantiagoM99 is the data and
AI developer (`Packages/`: BowlingCore, BowlingData, later ScanKit, LeagueKit, ...).

Read before working:

- `docs/superpowers/specs/2026-10-07-program-roadmap.md`: decisions, code layout, domain
  model rules (CloudKit compatibility), phases.
- `docs/superpowers/specs/2026-10-07-phase-1-core-scoring-design.md`: current phase spec.
- `docs/superpowers/specs/2026-10-12-team-plan.md`: ownership, contract, workflow.

## Rules

- The app target talks to packages only through the contract: BowlingCore value types
  (`PinSet`, `RollRecord`, `FrameRecord`, `GameRecord`), repository methods, `StatsReport`,
  `BallReport`, stats card IDs. Contract changes need a PR reviewed by both developers.
- SwiftData schema must follow the CloudKit rules in the roadmap from the first build:
  optional relationships with explicit inverses, no Deny delete rules, defaults on every
  attribute, no unique constraints, explicit `gameIndex`/`frameIndex`/`rollIndex` ordering.
- Pure logic lives in packages and is tested with Swift Testing, no simulator needed.
- No third-party dependencies unless a phase truly needs one.
- One branch per GitHub issue (labels `owner:frontend` / `owner:data`, milestone per
  phase). The other developer reviews every PR. `main` always builds.

## Commands

```sh
# Build the app
xcodebuild -scheme Bowling -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
# Package tests (once Packages/ exists)
swift test --package-path Packages/BowlingCore
# Issues for the data role
gh issue list --label owner:data --milestone "Phase 1a"
```
