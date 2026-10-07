# Bowling App Program Roadmap

Date: 2026-10-07
Status: approved in conversation, pending written review
Owner: Marilyn Joven (solo developer)

## Purpose

A bowling tracker for any bowler, from casual to competitive, that covers as much of
the 50-feature market matrix (`Bowling App Feature Matrix.xlsx`) as is feasible for one
developer, in priority order of the matrix's tiers. The matrix also identifies three
gaps no competitor fills, which this app should own:

1. Spare percentage measured over spare attempts only (row 12).
2. Each missed spare linked to its date and the ball used (row 18).
3. Photo scan that lets the bowler correct misreads and keeps the original photo (Photo Scan tab).

## Decisions

| Decision | Choice | Reason |
|---|---|---|
| Platform | iOS only, SwiftUI only | Solo developer, Apple frameworks cover every phase through 6 |
| Minimum iOS | 18 | Supports iPhone XS and newer. Liquid Glass appears automatically on iOS 26+, custom glass behind availability checks |
| Persistence | SwiftData, local store | Native, offline by default, syncs through iCloud in phase 2 with no server |
| Personal sync | iCloud via SwiftData CloudKit integration | Free, no accounts, restores history on a new device |
| Shared and social backend | Supabase, introduced in phase 5 (multi-device team scoring) or phase 7 (social), whichever comes first | Open source and self-hostable on the developer's PC for development; hosted tier for production. Postgres makes leaderboards plain SQL. Firebase cannot be self-hosted |
| Source of truth | Always the device and iCloud. The server only holds copies of what must be shared | A server outage never blocks scoring |
| Other bowlers on one phone | Local names, no account required, ever | Matches how lane consoles work. Optional account linking arrives with phase 7 |
| State and testing | Observation, Swift Testing, Swift Charts | Current Apple stack, no third-party dependencies until a phase truly needs one |
| Monetization | Undecided, everything free through phase 3 | Decide at phase 4. Competitors charge for photo scan and league tools |

## Code organization

```
Bowling/
  Bowling.xcodeproj
  Bowling/                       app target
    App/                         entry point, root tab view, dependency wiring
    Features/
      Scoring/                   live scoring screen, pin deck, scorecard
      Sessions/                  history list, session detail, new session flow
      Stats/                     dashboards, filters, charts
      Arsenal/                   balls and maintenance
      Settings/
    Components/                  shared views: PinDeckView, ScorecardStrip, StatTile
    Resources/                   assets, string catalog
  Packages/
    BowlingCore/                 scoring rules, leave classification, stats engine (pure Swift)
    BowlingData/                 SwiftData models, repositories, import and export codecs
  BowlingTests/
  BowlingUITests/
docs/superpowers/specs/          one design doc per phase
docs/superpowers/plans/          one implementation plan per phase
```

Later phases add packages instead of growing the app target: `ScanKit` (phase 4),
`LeagueKit` (phase 5), `PracticeKit` (phase 6), `SocialKit` (phase 7).

Pure logic lives in packages so it runs in unit tests without a simulator and can be
reused by widgets, a watch app, or server functions.

## Domain model rules that every phase depends on

The phase 1 schema carries every later phase. Rules, fixed from day one so iCloud sync
is a configuration change and not a migration:

- All relationships optional.
- Every attribute has a default value.
- No unique constraints.
- Identities are UUIDs generated on device.
- The schema is only ever added to. Attributes and entities are never renamed or removed
  once phase 2 promotes the CloudKit schema to production.
- Fields reserved for later phases exist from phase 1 where cheap: `remoteID` on every
  entity for publishing to the server, `sourceImageData` and `scanConfidence` on Game for
  photo scan, `rotationSlot` on Frame for Baker.

## Working rhythm for every phase

1. Design spec written to `docs/superpowers/specs/`, reviewed and approved.
2. Implementation plan written to `docs/superpowers/plans/`, reviewed and approved.
3. Build on a feature branch, tests first.
4. TestFlight to a handful of real bowlers.
5. Merge to `main`, tag the phase, move on. `main` always builds.

Cross-cutting from phase 1: Dynamic Type and VoiceOver on the pin deck and scorecard, a
String Catalog, a privacy manifest, crash reporting (Sentry is configured in the
developer's environment).

## Phases

### Phase 1: Core scoring and stats, on device

Matrix rows 1, 2, 3, 5, 8, 9, 10, 11, 12, 13, 15, 18, 19, 28, 29, 30.

- Frontend: four tabs. Home with current averages and a start button. History with
  sessions and game scorecards. Stats with a filter bar and sections. Arsenal. Scoring
  screen with scorecard strip, tappable pin deck, strike, spare and miss shortcuts, undo,
  per-roll ball picker, and a switch to count-only or final-score entry.
- Backend: none. SwiftData local store.
- Packages created: BowlingCore and BowlingData, both tested.
- Done when a perfect game, an all-spares game, and every tenth-frame variant score
  correctly in tests, every stat above renders from fixture data, and a full league
  night can be entered offline.
- Risk: the pin deck interaction is the make-or-break UX. Iterate on it with real bowlers.

Detailed design: `2026-10-07-phase-1-core-scoring-design.md`.

### Phase 2: iCloud backup and sync

Matrix row 4.

- Frontend: sync status in Settings, clear message when no iCloud account is signed in.
- Backend: iCloud and background modes capabilities, CloudKit enabled on the SwiftData
  configuration, CloudKit schema initialized in development then promoted to production.
  Last writer wins is the built-in conflict rule and is acceptable for personal data.
- Done when a game entered on one device appears on another, and a fresh install
  restores full history.
- Risk: the CloudKit schema is additive only once promoted. Phase 1's model must be right.

### Phase 3: Share and move data

Matrix rows 20, 38, 39.

- Frontend: scorecard image renderer with pins-left marks, shared through the system
  share sheet. CSV export of games, frames, and tags through the file exporter. CSV
  import that previews rows and asks for confirmation.
- Backend: none. Import parsers for SnapStrike and BowlSheet CSV live in BowlingData
  with sample files as test fixtures.
- Done when exporting then re-importing a history produces identical stats.

### Phase 4: Photo scan of the lane monitor

Matrix row 6 and the Photo Scan tab. The feature most likely to make a bowler switch apps.

- Frontend: camera or photo picker, a review screen showing the photo beside the
  reconstructed scorecard, tap any frame to correct, save. Original photo stays attached
  to the game.
- On-device pipeline in a new ScanKit package: Vision document and table recognition to
  find the score grid, text recognition for names and marks, a parser that turns X, /,
  and digits into rolls, and the phase 1 scoring engine to verify that the reconstructed
  frames reproduce the printed totals. A mismatch flags the frame instead of saving silently.
- Optional cloud mode: opt-in call to a vision model for dark or animated displays. Needs
  one serverless function to hold the API key. This is the first place a hosted component
  appears; decide then whether it is Supabase or a single cloud function.
- Scanned games are per-ball count mode because pin identity cannot be read from a
  monitor. The stats engine already handles that mode.
- Done when a test set of at least thirty monitor photos from different scoring systems
  reconstructs with every mismatch flagged and none silently wrong.

### Phase 5: League and team

Matrix rows 14, 22, 33, 21.

- Frontend: league setup with handicap rule, roster, and schedule. Standings computed
  from entered scores. Baker mode with configurable roster size and rotation,
  substitutions, and per-bowler stats drawn from their own frames.
- Logic: LeagueKit package with USBC-style handicap math, standings, and Baker rotation.
  Baker reuses the phase 1 engine with frames owned by different bowlers.
- Multi-device team scoring is the last item and the first that needs people-to-people
  data. SwiftData cannot share records between iCloud accounts, so this item introduces
  the Supabase backend with Sign in with Apple, a shared game table, and realtime updates.
  It can be deferred to phase 7 to ship the rest of phase 5 without a server.
- Done when a league secretary can run a season's standings from the app, and a
  five-bowler Baker game scores correctly in tests.

### Phase 6: Practice tools

Matrix rows 25, 24, 26, 31.

- Frontend: stopwatch ball speed with a distance setting, video speed and rev tool where
  the bowler marks release and arrival frames, delayed instant replay with a 5 to 30
  second delay, custom per-frame yes/no questions shown during scoring and summarized
  in Stats.
- Logic: PracticeKit package on AVFoundation. Replay records continuously and plays back
  from a moving offset.
- Backend: none. Videos stay on device and are not synced, with a note to the user.
- Done when replay runs with the configured delay for a full practice session without
  memory growth.

### Phase 7: Social and competition

Matrix rows 17, 34, 35.

- Frontend: profile, friend search and follow, feed of friends' recent games, challenge
  creation with format and dates, leaderboards by center and overall.
- Backend: Supabase. Tables for profiles, follows, published games, challenges, entries,
  leaderboard snapshots. Row-level security so a user reads only what they follow or
  what is public. A scheduled function recomputes leaderboards. Published games are
  summaries copied from the device, never the source of truth.
- Also required: account deletion, privacy policy, content reporting, age gating. This is
  the first phase where user content is visible to others.
- Done when two accounts can follow each other, see each other's games, and complete a
  challenge.

### Phase 8: Reference and coaching

Matrix rows 40, 41, 42, 43, 37, 32. A grab bag; reorder freely.

- Oil pattern library seeded from published PBA and Kegel pattern sheets as bundled JSON,
  linked to the OilPattern entity from phase 1.
- Alley finder using MapKit's bowling point-of-interest category. Also lets the user pick
  a center from the map in the new-session flow.
- Drilling layouts and hand measurements as fields on Ball.
- Ball catalog only if a licensable data source is found.
- Ball path simulator as a simple two-dimensional model. The matrix notes a competitor's
  developer considers accurate prediction unreliable; present it as illustrative.
- AI coach as a serverless function that receives a stats summary and returns a practice
  plan, with the model key held server-side.

## Deferred, with reasons

| Row | Feature | Reason |
|---|---|---|
| 7 | Automatic import from center scoring systems | Needs a data partnership with each scoring vendor |
| 16 | Live scoring from other lanes and centers | Same vendor dependency |
| 23 | Phone camera ball tracking on a tripod | Research-grade computer vision project |
| 27 | Ball data and pinfall in one shot record | Depends on 23 or 48 |
| 36 | Compare with pros | Needs licensed PBA and PWBA data |
| 44 | Paying league dues | Payments product for treasurers, not a bowler feature |
| 45 | League admin platform | Web product for secretaries |
| 46 | USBC digital card | USBC's own app |
| 47 | Coach dashboard | Revisit after phase 7 when accounts exist |
| 48, 49 | Specto sensor data and gamified drills | Needs Kegel hardware and API access |
| 50 | Predicting ball reaction | Unsolved problem per the matrix |

Revisit each after phases 1 through 4 ship.
