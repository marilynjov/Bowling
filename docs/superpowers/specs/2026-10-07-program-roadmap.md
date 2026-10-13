# Bowling App Program Roadmap

Date: 2026-10-07
Status: approved in conversation, pending written review

## Purpose

A bowling tracker for any bowler, from casual to competitive, that covers as much of the
52-feature market matrix (`bowling_app_feature_matrix.xlsx`) as one developer can,
sequenced by dependencies and cost first and by the matrix's importance tiers second.
Cheap features that reuse the scoring engine ship early even when their tier is lower;
tier 1 features that need infrastructure (iCloud, photo scan) follow as soon as their
foundations exist.

### Gaps this app should own

The matrix marks these as not built by any competitor:

1. Spare percentage measured over spare attempts only (phase 1a).
2. Each missed spare linked to its date and the ball used (phase 1b).
3. Custom date ranges on every stat (phase 1b).
4. Custom per-frame yes/no questions (phase 6).
5. Baker for any roster size, with individual stats (phase 5).

And these as only partly built, scattered across separate apps:

6. Photo scan that lets the bowler correct misreads and keeps the original photo (phase 4).
7. Ball detail page combining specs, the bowler's own setup, and per-ball performance
   (phase 1b; until phase 8 adds drilling layout and hand measurement fields, the setup
   lives in the ball's notes).
8. Scoring a friend's game so it lands in the friend's own history (phase 7).

Recommended matrix change: add a fixed `ID` column (F01, F02, ...) that never changes, so
documents can cite features without depending on rank.

## Decisions

| Decision | Choice | Reason |
|---|---|---|
| Platform | iOS only, SwiftUI only | Solo developer; Apple frameworks cover every phase through 6. Android users are reached only through the invitation landing page (phase 7) |
| Minimum iOS | 18 | Supports iPhone XS and newer. Liquid Glass appears automatically on iOS 26+. iOS 26-only APIs (custom glass, Vision document recognition) sit behind availability checks with a fallback |
| Persistence | SwiftData, local store | Native, offline by default, syncs through iCloud in phase 2 with no server |
| Personal sync | iCloud via SwiftData CloudKit integration | Free, no accounts, restores history on a new device |
| Shared and social backend | Supabase, introduced with the first feature that needs people-to-people data: multi-device team scoring (phase 5) or social (phase 7) | Open source and self-hostable on the developer's PC for development; hosted tier for production. Postgres makes leaderboards plain SQL. Firebase cannot be self-hosted |
| Source of truth | The device and iCloud, except for a live shared team game, where the server copy is authoritative until the game is finished; each device then saves its own local copy | A server outage never blocks personal scoring, and two phones scoring one team game cannot overwrite each other |
| Accounts | Introduced with the backend (phase 5 or 7). Sign in with Apple or email | Everything in phases 1 to 4 and 6 works without an account |
| Other bowlers on one phone | Local names until accounts exist. After that, a game scored for someone else reaches their own history only through an invitation they accept in their own account | Anyone who wants their games in the app must have an account |
| Game invitations | The scorer enters the friend's email. The server emails a one-time claim link; whichever signed-in account opens it receives the game. The app always replies "invitation sent" and never reveals whether that email has an account. Unclaimed invitations and their email addresses are deleted after 30 days | Email matching fails for Hide My Email relay addresses. A claim link works with any account, does not leak who uses the app, and brings in new sign-ups |
| Invitation email delivery | Supabase Edge Function plus a transactional email provider with a custom domain | Supabase Auth's built-in sender allows about 2 emails per hour and is meant for auth flows, not game notifications |
| State and testing | Observation, Swift Testing, Swift Charts | Current Apple stack, no third-party dependencies until a phase truly needs one |
| Monetization | Undecided, everything free through phase 3 | Decide at phase 4, when the first paid infrastructure (cloud scan mode) appears. Competitors charge for photo scan and league tools |
| Reference data licensing | Start the licensing conversations for ball specs (BOWWWL) and oil pattern data (Kegel, PBA) during phase 1b, though the features stay in phase 8 | Stakeholder feedback names an integrated ball catalog and pattern database as valued features; licensing takes time and decides whether phase 8 can ship them |
| Release gate | TestFlight from phase 1a; public App Store release only after phase 2 | Data loss is the top complaint across competing apps; the app must not reach the public without backup |

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
      Arsenal/                   balls, ball detail, maintenance
      Settings/
    Components/                  shared views: PinDeckView, LeaveDiagramView, ScorecardStrip, StatTile
    Resources/                   assets, string catalog, bundled reference data
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

The phase 1a schema carries every later phase. Once phase 2 promotes the CloudKit schema
to production, attributes and entities can only be added, never renamed or removed. Every
rule below must therefore hold from the first build.

CloudKit compatibility:

- All relationships optional, and every relationship declares an explicit inverse.
- No Deny delete rules. Use Nullify or Cascade.
- Every attribute has a default value or is optional.
- No unique constraints. Identities are UUIDs generated on device.
- No reliance on relationship order. CloudKit does not preserve it, so order is stored
  explicitly: `gameIndex` on Game within its Session, `frameIndex` on Frame, `rollIndex`
  on Roll. Every query that displays a game sorts by these.

Storage:

- Binary data never lives on a frequently synced entity. Photos go in their own entities
  (`GamePhoto`, `BallPhoto`) with `@Attribute(.externalStorage)`, linked by relationship,
  so syncing a game does not move a photo and photos do not bloat the user's iCloud.
- Bundled reference data (oil patterns in phase 8, any future catalog) lives in a
  separate local ModelConfiguration that does not sync. User data references it by a
  stable string key such as `patternKey`, never by relationship. This prevents every
  device creating and syncing its own duplicate copy.

Reserved fields, added in phase 1a where cheap:

- `remoteID` on every user-data entity, for publishing to the server.
- On Game: `scanConfidence`, `entryMode` (`pinByPin`, `countOnly`, or `finalOnly`), and
  `invitationStatus`.
- On Roll: `pinCount`, `pinsDownMask`, and `pinsKnown`, so scanned games (count only)
  and pin-level games share one model.
- On Frame: `rotationSlot`, for Baker.
- On Bowler: `email`, for invitations; `statsProfile`, `statsLayout`, and `homeLayout`, so
  the stats a user chose follow them to a new device in phase 2.

## Working rhythm for every phase

1. Design spec written to `docs/superpowers/specs/`, reviewed and approved.
2. Implementation plan written to `docs/superpowers/plans/`, reviewed and approved.
3. Build on a feature branch, tests first.
4. TestFlight to a handful of real bowlers.
5. Merge to `main`, tag the phase, move on. `main` always builds.
6. Compare actual time against the phase's time box and recalibrate the remaining
   estimates.

Cross-cutting from phase 1a: Dynamic Type and VoiceOver on the pin deck and scorecard, a
String Catalog, a privacy manifest that declares the crash reporter's data (Sentry is
configured in the developer's environment), crash reporting.

## Phases

Time boxes are initial estimates for one developer working part time on the app and
should be recalibrated after phase 1a.

### Phase 1a: Scoring engine and core stats, on device (4 to 6 weeks)

Features: frame-by-frame and pin-by-pin entry; final-score-only entry; offline scoring;
average, high game and series, strike and spare percentages; pin leaves and spare
conversion by leave; spare percentage over spare attempts only; makeable spares versus
splits; practice versus competition separation; ball and pattern tagging per game.

- Frontend: four tabs. Home with current averages and a start button. History with
  sessions and game scorecards. Stats as cards chosen by a preset for the bowler's style,
  asked at first launch with an explanation that the answer changes which stats appear.
  Leaves drawn as small pin diagrams everywhere. Arsenal as a simple ball list (full
  arsenal in 1b). Scoring screen with scorecard strip, tappable pin deck, strike, spare,
  foul and miss shortcuts, undo, per-roll ball picker, and a switch to count-only or
  final-score entry.
- Backend: none. SwiftData local store built to every domain model rule above.
- Packages created: BowlingCore and BowlingData, both tested.
- Done when a perfect game, an all-spares game, a game with fouls, and every
  tenth-frame variant score correctly in tests; every stat above renders from fixture
  data; and a full league night can be entered offline.
- Risk: the pin deck interaction is the make-or-break UX. Iterate on it with real
  bowlers before starting 1b.

Detailed design: `2026-10-07-phase-1-core-scoring-design.md`.

### Phase 1b: Analysis, arsenal, and ball detail (3 to 5 weeks)

Features: tag and filter by ball, pattern, center, or league; personal arsenal with
maintenance dates; ball detail page; each missed spare linked to its date and ball;
custom date ranges; strike rate by frame number and average per frame; head pin rate and
clean game rate; "what if I made every single-pin spare" average; CSV export.

- Stats gets a filter bar with any saved tag and a custom date range.
- Customize screen to choose, remove, and reorder the cards on Stats and the tiles on
  Home, with a reset to the bowling style's preset.
- Ball detail screen in Arsenal: header and full specs (brand, weight, coverstock, core,
  RG, differential, surface, photo), maintenance log with resurface reminders through
  local notifications, performance as a strike ball and as a spare ball, results by oil
  pattern and center, a strike percentage chart over time, and recent games. A Compare
  table shows all balls side by side.
- Tapping any leave in Stats lists every occurrence with date, event, and ball.
- CSV export of games, frames, and tags through the file exporter, so TestFlight users
  have a manual backup before phase 2.
- Done when every stat renders from fixture data under any combination of filters, and
  an exported CSV opens correctly in Numbers and Excel.

### Phase 2: iCloud backup and sync (1 to 2 weeks)

Features: cloud backup and sync.

- Frontend: sync status in Settings, clear message when no iCloud account is signed in.
- Backend: iCloud and background modes capabilities, CloudKit enabled on the user-data
  SwiftData configuration only (not the reference-data store), CloudKit schema
  initialized in development, reviewed against the domain model rules, then promoted to
  production. Last writer wins is the built-in conflict rule and is acceptable for
  personal data.
- Done when a game entered on one device appears on another with frames in the correct
  order, a fresh install restores full history including photos, and no reference data
  appears in the user's iCloud.
- Gate: first public App Store release happens here.
- Risk: the schema is additive only once promoted. Review the model against every rule
  above before promoting.

### Phase 3: Share and move data (2 to 3 weeks)

Features: shareable score images; import history from other apps.

- Frontend: scorecard image renderer with pins-left marks, shared through the system
  share sheet. CSV import that previews rows, detects duplicates (by entity UUID for
  this app's own export, by date, center, and score for other apps), tags each game with
  its source app, and ends with a summary such as "Imported 1,240 games, 980 with pin
  data".
- Backend: none. Import parsers for this app's own CSV, SnapStrike CSV, and BowlSheet CSV
  live in BowlingData with sample files as test fixtures. PinPal backup import is a
  stretch goal if real users provide sample backup files.
- Done when exporting then re-importing a history produces identical stats, and
  importing the same file twice creates no duplicates.

### Phase 4: Photo scan of the lane monitor (4 to 6 weeks)

Features: photo of the scoreboard turned into a game, with correction and the original
photo kept.

- Frontend: camera or photo picker, a review screen showing the photo beside the
  reconstructed scorecard, tap any frame to correct, save. The original photo is stored
  as a GamePhoto linked to the game.
- On-device pipeline in a new ScanKit package, with two grid-detection paths:
  - iOS 26 and later: Vision `RecognizeDocumentsRequest` to find the score table.
  - iOS 18 to 25: `RecognizeTextRequest` plus ScanKit's own grid detection, clustering
    recognized text boxes into rows (bowlers) and columns (frames).
  - Both paths feed one parser that turns X, /, F, -, and digits into rolls, and the
    BowlingCore engine checks that the reconstructed frames reproduce the printed totals.
- Verification rules: a total mismatch flags the frame. Because a spare frame's total is
  the same whatever the first ball was, a matching total does not prove the first ball
  was read correctly, so any character recognized below a confidence threshold is also
  flagged. Nothing flagged is saved without the bowler confirming it.
- Optional cloud mode: opt-in call to a vision model for dark or animated displays,
  through one serverless function that holds the API key. Decide at this phase whether
  that function is a Supabase Edge Function or a standalone cloud function.
- Abuse protection: the function is reachable without an account and every call costs
  money, so each request carries an App Attest assertion (DeviceCheck as fallback) that
  the function verifies, and calls are rate limited per device per day. The same
  protection is reused by every later serverless function, including the phase 8 AI
  coach.
- Scanned games are count mode (`pinsKnown` false) because pin identity cannot be
  read reliably from a monitor. The stats engine already handles that mode.
- Done when a test set of at least 60 monitor photos (at least 10 from each of Brunswick,
  QubicaAMF, and Steltronic systems, across lighting, angle, and dark or animated
  displays) reconstructs with no silently wrong total, and both grid-detection paths pass
  the same test set.
- Decide monetization before starting this phase.

### Phase 5: League and team (4 to 6 weeks)

Features: league standings; Baker team scoring; Baker for any roster size with individual
stats; several devices scoring one team game.

- Frontend: league setup with handicap rule, roster, and schedule. Standings computed
  from entered scores. Baker mode with configurable roster size and rotation,
  substitutions, and per-bowler stats drawn from their own frames.
- Logic: LeagueKit package with USBC-style handicap math, standings, and Baker rotation.
  Baker reuses the BowlingCore engine with frames owned by different bowlers.
- Multi-device team scoring is the last item and the first that needs people-to-people
  data. SwiftData cannot share records between iCloud accounts, so this item introduces
  the Supabase backend, accounts (Sign in with Apple or email), a shared game table, and
  realtime updates. While a shared game is live the server copy is authoritative; when
  it finishes, each participating device saves its own local copy.
- If this item ships, the account compliance work listed under phase 7 (deletion,
  privacy policy, age gating, under-13 handling) ships with it. School teams are a target
  user for Baker, so under-13 handling is not optional here.
- This item can be deferred to phase 7 to ship the rest of phase 5 without a server.
- Done when a league secretary can run a season's standings from the app, five-, six-,
  and seven-bowler Baker games score correctly in tests, and (if built) two phones
  scoring one team game never lose or duplicate a frame.

### Phase 6: Practice tools (3 to 4 weeks)

Features: manual stopwatch speed; speed and rev rate from recorded video; delayed instant
replay; custom per-frame questions.

- Frontend: stopwatch ball speed with a distance setting, video speed and rev tool where
  the bowler marks release and arrival frames, delayed instant replay with a 5 to 30
  second delay, custom per-frame yes/no questions shown during scoring and summarized in
  Stats.
- Logic: PracticeKit package on AVFoundation. Replay writes the camera feed to short
  segment files on disk and plays back from a moving offset, deleting segments older
  than the delay window. Frames are never buffered in memory. The video tool reports its
  timing resolution (frame rate), since 30 fps limits speed accuracy.
- Backend: none. Videos stay on device and are not synced, with a note to the user.
- Done when replay runs with the configured delay for a 90-minute practice session
  without memory growth or thermal shutdown on the oldest supported iPhone.

### Phase 7: Social and competition (6 to 8 weeks)

Features: follow friends; online tournaments and friend challenges; rankings and
leaderboards; scoring friends' games into their own accounts.

- Accounts: introduced here if phase 5 did not already. Every social feature requires
  one. Local-only use without an account remains possible for all features from phases
  1 to 4 and 6.
- Game invitations:
  - When a session has a bowler other than the owner, the owner can attach an email to
    that bowler, once, and the app remembers it.
  - On finishing the game, the app calls an Edge Function that stores the invitation and
    emails a one-time claim link through the transactional email provider. The app always
    shows "invitation sent".
  - Opening the link in the app while signed in to any account claims the game for that
    account, which works with Hide My Email addresses. If the recipient is signed in,
    the pending invitation also appears in their Home inbox.
  - Accepting copies the game into the recipient's history as a game they own, marked
    "scored by <name>" and attributed to the sender's center, league, and pattern where
    those exist in the recipient's data, otherwise created. Declining discards it. The
    sender's copy is unaffected either way.
  - Opening the link on Android or a desktop shows a web page with the scorecard and
    explains that the app is iOS only.
  - Abuse limits: invitations per sender per day are capped, every email includes an
    opt-out that blocks further invitations to that address, and unclaimed invitations
    and their email addresses are deleted after 30 days.
- Frontend: profile, friend search and follow, feed of friends' recent games, challenge
  creation with format and dates, leaderboards by center and overall, pending invitations
  inbox.
- Backend: Supabase. Tables for profiles, follows, published games, invitations,
  challenges, entries, leaderboard snapshots, blocks. Row-level security so a user reads
  only what they follow, what is public, or invitations addressed to them, and never
  content from users who blocked them. A scheduled function recomputes leaderboards and
  expires invitations. Published games are summaries copied from the device, never the
  source of truth. Custom SMTP is configured before any production email is sent.
- Also required: in-app account deletion, privacy policy covering third-party emails
  entered by users, content reporting, user blocking, age gating with under-13 handling
  (COPPA in the US) and a matching App Store age rating. Get a legal review of consent
  rules for invitation emails in the launch countries.
- Done when two accounts can follow each other, see each other's games, complete a
  challenge, block each other, and a game scored on one phone for the other person
  (including one signed in with Hide My Email) appears in their history after they open
  the claim link and accept.

### Phase 8: Reference and coaching (4 to 6 weeks)

Features: oil pattern library; ball path simulator; catalog of commercial balls; layouts
and drilling specs; bowling alley finder; AI coach. A grab bag; reorder freely.

- Oil pattern library as bundled JSON in the non-synced reference store, referenced from
  user data by `patternKey`. Confirm permission from Kegel or the PBA before bundling
  their published pattern sheets.
- Pattern drawn on a lane, as a teaching view: oil volume per board along the lane length.
  Conditional on the same licensing, and on the pattern data including volume per board
  and distance, not only length and total volume. Limitations shown to the user: the
  drawing is the pattern as published, not the lane as it plays; a center's actual
  pattern can differ from the sheet, and oil moves and breaks down during play.
- Alley finder using MapKit's bowling point-of-interest category (available from iOS
  18). Also lets the user pick a center from the map in the new-session flow.
- Drilling layouts and hand measurements as fields on Ball.
- Ball catalog only if a licensable data source is found; otherwise specs stay
  user-entered on the ball detail page.
- Ball path simulator as a simple two-dimensional model. The matrix notes a competitor's
  developer considers accurate prediction unreliable; present it as illustrative.
- AI coach as a serverless function that receives a stats summary and returns a practice
  plan, with the model key held server-side and the phase 4 App Attest and rate-limit
  protection in front of it.

## Deferred, with reasons

| Feature | Reason |
|---|---|
| Automatic import from the center's scoring system | Needs a data partnership with each scoring vendor |
| Live scoring from other lanes and centers | Same vendor dependency |
| Phone camera ball tracking on a tripod | Research-grade computer vision project |
| Ball data and pinfall stored together in one shot record | Depends on camera or sensor ball tracking |
| Compare yourself with pros | Needs licensed PBA and PWBA data |
| Paying league dues in the app | Payments product for treasurers, not a bowler feature |
| League admin platform | Web product for secretaries |
| USBC digital card and certified average | USBC's own app |
| Coach dashboard | Revisit after phase 7 when accounts exist |
| Sensor installed in the center; gamified practice drills | Need Kegel hardware and API access |
| Predicting ball reaction from ball, revs, and pattern | Unsolved problem per the matrix |

Revisit each after phases 1a through 4 ship.

## Ideas for later: gamification

Candidates only, not committed scope. Each needs its own design before it enters a phase.
Still open: whether gamification mainly brings bowlers back between league nights,
pushes them to improve, or gets them sharing the app.

Rules for any of these:

- Earned achievements are computed from games, never stored, so they need no schema
  change, stay correct when a game is edited, and appear on a new device after sync.
- Reward skill, not volume. No "bowl 50 games this week" goals. Each achievement states
  whether practice games count.

Possible from phase 1 data, on device:

- [ ] Bowling milestones: turkey, hambone, six-pack, nine in a row, first 200, first 250,
      300, 700 and 800 series, clean game, all-spares game, converting the 7-10, the Big
      Four, or the Greek church. Earned retroactively from existing and imported history.
- [ ] Leave collection: every leave the bowler has converted, with unconverted splits
      shown as locked. Built on the leave classifier and leave diagrams.
- [ ] Race against your best game: while scoring, pins ahead or behind your best game at
      the same frame, for example "+12 vs your 245".
- [ ] Season goals: a target average or spare % for a league season, with progress,
      using the league's season dates.
- [ ] Ball milestones: best game on each ball, a hall of fame for retired balls, the
      100th game on a ball.
- [ ] Tenth-frame clutch rating: performance in the tenth frame and in the last frame of
      a series compared with the bowler's other frames.

Needs phase 3 share images:

- [ ] Year in review: a shareable season summary with best game, most-converted leave,
      favorite ball, and longest strike streak.

Needs phase 6 practice tools:

- [ ] Gamified practice drills without a sensor, scored from entered pins: spare
      streaks such as "10 corner pins in a row", with personal bests. Sensor-based drills
      stay deferred with the center sensor.
- [ ] Spare ladder: leaves ordered from easiest to hardest, moving up a rung at a set
      conversion rate such as 8 of 10.
- [ ] Fix my weakest leave: practice targeted at the "left most, made least" leave, with
      its own score.

Needs phase 7 accounts:

- [ ] Head-to-head handicap matches between friends, using the phase 5 handicap math.
- [ ] Team badges for Baker games and league teams.

## Appendix A: Feature to phase mapping

Ranks are from the 52-feature matrix as of 2026-10-08. If the matrix is re-ranked, update
this column; the phase sections above cite features by name only.

| Rank | Feature | Tier | Phase |
|---|---|---|---|
| 1 | Frame-by-frame and pin-by-pin entry | 1 | 1a |
| 2 | Final-score-only entry | 1 | 1a |
| 3 | Average, high game and series, strike % and spare % | 1 | 1a |
| 4 | Cloud backup and sync | 1 | 2 |
| 5 | Offline scoring | 1 | 1a |
| 6 | Photo of the scoreboard turned into a game | 1 | 4 |
| 7 | Automatic import from the center's scoring system | 1 | Deferred |
| 8 | Pin leaves and spare conversion by leave | 1 | 1a |
| 9 | Practice vs competition separation | 1 | 1a |
| 10 | Ball and pattern tagging per game | 1 | 1a |
| 11 | Score friends' games into their own accounts | 2 | 7 |
| 12 | Tag and filter by ball, pattern, center, or league | 2 | 1b |
| 13 | Spare % measured over spare attempts only | 2 | 1a |
| 14 | Makeable spares vs splits | 2 | 1a |
| 15 | League standings in the app | 2 | 5 |
| 16 | Personal arsenal with maintenance dates | 2 | 1b |
| 17 | Ball detail page (specs, setup, and performance per ball) | 2 | 1b |
| 18 | Live scoring from other lanes and centers | 2 | Deferred |
| 19 | Follow friends | 2 | 7 |
| 20 | Each missed spare linked to its date and ball | 2 | 1b |
| 21 | Custom date ranges | 2 | 1b |
| 22 | Shareable score images | 2 | 3 |
| 23 | Several devices scoring one team game | 2 | 5 (or 7) |
| 24 | Baker team scoring | 2 | 5 |
| 25 | Phone camera on a tripod | 3 | Deferred |
| 26 | Speed and rev rate from recorded video | 3 | 6 |
| 27 | Manual stopwatch speed | 3 | 6 |
| 28 | Delayed instant replay | 3 | 6 |
| 29 | Ball data and pinfall stored together in one shot record | 3 | Deferred |
| 30 | Strike rate by frame number, average per frame | 3 | 1b |
| 31 | Head pin rate, clean game rate | 3 | 1b |
| 32 | "What if I made every single-pin spare" average | 3 | 1b |
| 33 | Custom per-frame questions | 3 | 6 |
| 34 | AI coach | 3 | 8 |
| 35 | Baker for 6 or 7 bowlers, with individual stats | 3 | 5 |
| 36 | Online tournaments and friend challenges | 3 | 7 |
| 37 | Rankings and leaderboards | 3 | 7 |
| 38 | Compare yourself with pros | 3 | Deferred |
| 39 | Bowling alley finder | 3 | 8 |
| 40 | CSV export | 4 | 1b |
| 41 | Import history from other apps | 4 | 3 |
| 42 | Oil pattern library | 4 | 8 |
| 43 | Ball path simulator | 4 | 8 |
| 44 | Catalog of commercial balls | 4 | 8 |
| 45 | Layouts and drilling specs | 4 | 8 |
| 46 | Paying league dues in the app | 4 | Deferred |
| 47 | League admin platform | 4 | Deferred |
| 48 | USBC digital card and certified average | 4 | Deferred |
| 49 | Coach dashboard | 4 | Deferred |
| 50 | Sensor installed in the center | 4 | Deferred |
| 51 | Gamified practice drills | 4 | Deferred |
| 52 | Predicting ball reaction from ball, revs, and pattern | 4 | Deferred |

Totals: 40 features planned across phases 1a to 8, 12 deferred.
