import BowlingCore
import BowlingData
import BowlingFixtures
import Foundation
import Testing
@testable import Bowling

@Suite struct BallDetailDataTests {
    let ball = BallID()
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Bogota")!
        return calendar
    }()

    /// `count` complete finalOnly games with `ball` as default, one per day, the newest yesterday.
    func games(_ count: Int, ball: BallID? = nil, daysAgo start: Int = 1) -> [GameRecord] {
        (0..<count).map {
            GameRecord(gameIndex: 1, entryMode: .finalOnly, defaultBallID: ball ?? self.ball, finalScore: 180,
                       isComplete: true, sessionDate: now.addingTimeInterval(-86_400 * Double(start + $0)),
                       eventType: .practice)
        }
    }

    func maintenance(games: [GameRecord], events: [MaintenanceRecord] = [], interval: Int? = nil) -> BallMaintenance {
        BallMaintenance(ball: ball, games: games, events: events, resurfaceIntervalGames: interval)
    }

    func data(_ fields: BallFields, isRetired: Bool = false, maintenance: BallMaintenance? = nil) -> BallDetailData {
        let maintenance = maintenance ?? self.maintenance(games: [])
        return BallDetailData(
            fields: fields, isRetired: isRetired,
            report: StatsEngine.ballReport(for: ball, games: [], maintenance: maintenance),
            recentGames: [], filterChips: [], centerNames: [:], patternNames: [:], calendar: calendar,
            locale: Locale(identifier: "en_US")
        )
    }

    @Test func headerLeavesOutUnsetParts() {
        let header = data(BallFields(name: "Phaze", weightPounds: 15)).header
        #expect(header.name == "Phaze")
        #expect(header.subtitle == "15 lb")
        #expect(header.construction == nil)
        #expect(header.surface == nil)
        #expect(header.serial == nil)
        #expect(header.role == "Strike ball")
        #expect(!header.isRetired)
    }

    @Test func headerShowsEveryPart() {
        let fields = BallFields(name: "Phaze", brand: "Storm", weightPounds: 15, coverstock: .reactiveSolid,
                                coreType: .asymmetric, serialNumber: "SN123", surfaceGrit: "2000 Abralon")
        let header = data(fields, isRetired: true).header
        #expect(header.subtitle == "Storm · 15 lb")
        #expect(header.construction == "Reactive solid · Asymmetric")
        #expect(header.surface == "Surface: 2000 Abralon")
        #expect(header.serial == "Serial SN123")
        #expect(header.isRetired)
        #expect(data(BallFields(name: "P", weightPounds: 15, coreType: .pancake)).header.construction == "Pancake")
    }

    @Test func roleTitles() {
        #expect(data(BallFields(name: "P", weightPounds: 15, intendedRole: .spare)).header.role == "Spare ball")
        #expect(data(BallFields(name: "P", weightPounds: 15, intendedRole: .both)).header.role == "Strike and spare")
        #expect(data(BallFields(name: "P", weightPounds: 15, intendedRole: .unknown)).header.role == nil)
    }

    @Test func specsHideEmptyValues() {
        let specs = data(BallFields(name: "P", weightPounds: 15, coreName: "Velocity", rg: 2.48)).specs
        #expect(specs == [.init(label: "Core name", value: "Velocity"), .init(label: "RG", value: "2.48")])
        #expect(data(BallFields(name: "P", weightPounds: 15)).specs.isEmpty)
    }

    @Test func specsOrder() throws {
        let release = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 1, hour: 12)))
        let purchase = try #require(calendar.date(from: DateComponents(year: 2025, month: 6, day: 14)))
        let fields = BallFields(
            name: "P", weightPounds: 15, coverstockName: "TX-16", coreName: "Velocity", rg: 2.48,
            differential: 0.051, intermediateDifferential: 0.015, colorDescription: "Pine", releaseDate: release,
            purchaseDate: purchase, factoryFinish: "1500 Polished", notes: "Benchmark"
        )
        let specs = data(fields).specs
        #expect(specs.map(\.label) == ["Coverstock name", "Core name", "RG", "Differential", "Intermediate differential",
                                       "Factory finish", "Release date", "Purchase date", "Color", "Notes"])
        #expect(specs.first { $0.label == "Release date" }?.value == "March 2025")
        #expect(specs.first { $0.label == "Purchase date" }?.value == "Jun 14, 2025")
        #expect(specs.first { $0.label == "Differential" }?.value == "0.051")
    }

    @Test func maintenanceWithInterval() {
        let m = data(BallFields(name: "P", weightPounds: 15), maintenance: maintenance(games: games(18), interval: 60)).maintenance
        #expect(m.summary == "18 of 60 games since resurface")
        #expect(m.progress == 0.3)
        #expect(!m.isDue)
    }

    @Test func pastIntervalClampsProgress() {
        let m = data(BallFields(name: "P", weightPounds: 15), maintenance: maintenance(games: games(70), interval: 60)).maintenance
        #expect(m.summary == "70 of 60 games since resurface")
        #expect(m.progress == 1)
        #expect(m.isDue)
    }

    @Test func maintenanceWithoutInterval() {
        let resurface = MaintenanceRecord(date: now.addingTimeInterval(-86_400 * 30), kind: .resurface)
        let resurfaced = maintenance(games: games(18), events: [resurface])
        #expect(data(BallFields(name: "P", weightPounds: 15), maintenance: resurfaced).maintenance.summary == "18 games since resurface")
        #expect(data(BallFields(name: "P", weightPounds: 15), maintenance: resurfaced).maintenance.progress == nil)
        let never = data(BallFields(name: "P", weightPounds: 15), maintenance: maintenance(games: games(18))).maintenance
        #expect(never.summary == "Never resurfaced · 18 games")
    }

    @Test func logNewestFirstWithTitles() {
        let events = [
            MaintenanceRecord(date: now.addingTimeInterval(-86_400 * 30), kind: .resurface, surfaceGritAfter: "2000 Abralon"),
            MaintenanceRecord(date: now.addingTimeInterval(-86_400 * 10), kind: .polish, notes: "Shine"),
        ]
        let log = data(BallFields(name: "P", weightPounds: 15), maintenance: maintenance(games: [], events: events)).maintenance.log
        #expect(log.map(\.title) == ["Polish", "Resurface"])
        #expect(log.map(\.detail) == ["Shine", "2000 Abralon"])
        #expect(data(BallFields(name: "P", weightPounds: 15)).maintenance.log.isEmpty)
    }

    // MARK: Task 2

    private let strikeBall = DemoBall.ownerStrike.id
    private let spareBall = DemoBall.ownerSpare.id

    /// The mixed-ball fixture's report for `id`, and the data built from it.
    private func mixed(_ id: BallID, role: BallRole) -> (BallReport, BallDetailData) {
        let games = MixedBallFixture.games(relativeTo: now)
        let events = id == strikeBall ? MixedBallFixture.strikeBallMaintenance(relativeTo: now) : []
        let maintenance = BallMaintenance(ball: id, games: games, events: events,
                                          resurfaceIntervalGames: MixedBallFixture.strikeBallResurfaceInterval)
        let report = StatsEngine.ballReport(for: id, games: games, maintenance: maintenance)
        let data = BallDetailData(
            fields: BallFields(name: "Ball", weightPounds: 15, intendedRole: role), isRetired: false,
            report: report, recentGames: [], filterChips: ["All time"], centerNames: [:], patternNames: [:],
            calendar: calendar, locale: Locale(identifier: "en_US")
        )
        return (report, data)
    }

    /// A report over `games` with `trend` session dates and `events`.
    private func built(games: [GameRecord], events: [MaintenanceRecord] = [], role: BallRole = .strike,
                       recent: [GameRecord] = [], centers: [CenterID: String] = [:],
                       patterns: [OilPatternID: String] = [:]) -> BallDetailData {
        let report = StatsEngine.ballReport(for: ball, games: games, maintenance: maintenance(games: games, events: events))
        return BallDetailData(
            fields: BallFields(name: "Ball", weightPounds: 15, intendedRole: role), isRetired: false,
            report: report, recentGames: recent, filterChips: ["All time"], centerNames: centers,
            patternNames: patterns, calendar: calendar, locale: Locale(identifier: "en_US")
        )
    }

    /// Complete pinByPin strike games with `ball`, one session per day.
    private func strikeGames(days: [Int], center: CenterID? = nil, pattern: OilPatternID? = nil) -> [GameRecord] {
        days.map { day in
            let frames = (1...9).map { FrameRecord(frameIndex: $0, rolls: [RollRecord(rollIndex: 1, pinsDown: .all, pinCount: 10, pinsKnown: true)]) }
                + [FrameRecord(frameIndex: 10, rolls: (1...3).map { RollRecord(rollIndex: $0, pinsDown: .all, pinCount: 10, pinsKnown: true) })]
            return GameRecord(gameIndex: 1, entryMode: .pinByPin, defaultBallID: ball, finalScore: 300, isComplete: true,
                              frames: frames, sessionID: SessionID(),
                              sessionDate: now.addingTimeInterval(-86_400 * Double(day)), eventType: .league,
                              centerID: center, oilPatternID: pattern)
        }
    }

    @Test func mixedBallStrikeBlock() throws {
        let (report, data) = mixed(strikeBall, role: .strike)
        #expect(report.firstBalls > 0)
        let block = try #require(data.performance.first)
        #expect(block.title == "As a strike ball")
        #expect(block.tiles.map(\.title) == ["Strikes", "First ball average", "Head pin", "Average as main ball"])
        #expect(block.tiles[0].value == StatFormat.percent(report.strikes))
        #expect(block.tiles[1].value == StatFormat.average(report.firstBallAverage))
        #expect(block.sample == "\(report.firstBalls) first balls")
        #expect(data.performance.last?.sample == StatFormat.sample(report.spareAttempts, .spareAttempts))
    }

    @Test func mixedBallSpareBlock() throws {
        let (report, data) = mixed(spareBall, role: .spare)
        #expect(report.spareAttempts > 0)
        let block = try #require(data.performance.first)
        #expect(block.title == "As a spare ball")
        #expect(block.tiles.map(\.title) == ["Spares", "Single pins", "Splits"])
        #expect(block.tiles[0].value == StatFormat.percent(report.spares))
        #expect(block.sample == "\(report.spareAttempts) spare attempts")
    }

    @Test func blockOrderFollowsRole() {
        let games = strikeGames(days: [1, 2])
        #expect(built(games: games, role: .strike).performance.map(\.title) == ["As a strike ball", "As a spare ball"])
        #expect(built(games: games, role: .both).performance.map(\.title) == ["As a strike ball", "As a spare ball"])
        #expect(built(games: games, role: .spare).performance.map(\.title) == ["As a spare ball", "As a strike ball"])
    }

    @Test func noGamesHasNoBlocks() {
        let data = built(games: [])
        #expect(data.performance.isEmpty)
        #expect(data.chips == ["All time"])
    }

    @Test func conditionNames() {
        let home = CenterID(), gone = CenterID(), pattern = OilPatternID()
        // Home has more first balls, so it leads; the report breaks ties by UUID.
        let games = strikeGames(days: Array(1...15), center: home, pattern: pattern)
            + strikeGames(days: Array(16...25), center: gone)
        let data = built(games: games, centers: [home: "Home Lanes"], patterns: [pattern: "House"])
        #expect(data.byCenter.map(\.name) == ["Home Lanes", "Other"])
        #expect(data.byPattern.map(\.name) == ["House", "Other"])
        #expect(data.byCenter.first?.strikes == StatFormat.percent(Rate(hits: 1, attempts: 1)))
    }

    @Test func markersStayInsideTheChart() throws {
        let events = [
            MaintenanceRecord(date: now.addingTimeInterval(-86_400 * 30), kind: .resurface),
            MaintenanceRecord(date: now.addingTimeInterval(-86_400 * 4), kind: .resurface),
            MaintenanceRecord(date: now.addingTimeInterval(-86_400 * 2.5), kind: .polish),
        ]
        let trend = try #require(built(games: strikeGames(days: [1, 3, 5]), events: events).trend)
        #expect(trend.points.count == 3)
        #expect(trend.markers.map(\.isResurface) == [true, false])
    }

    @Test func oneSessionIsNotEnough() {
        #expect(built(games: strikeGames(days: [1])).trend == nil)
    }

    @Test func trendAccessibility() throws {
        let trend = try #require(built(games: strikeGames(days: [1, 2])).trend)
        #expect(trend.accessibilityLabel == "Strike rate over 2 sessions, latest \(StatFormat.percent(Rate(hits: 12, attempts: 12))).")
        #expect(trend.points.map(\.percent) == [100, 100])
    }

    @Test func recentRowsText() throws {
        let game = GameRecord(gameIndex: 1, entryMode: .finalOnly, defaultBallID: ball, finalScore: 213, isComplete: true,
                              sessionDate: now, eventType: .league)
        let row = try #require(built(games: [], recent: [game]).recent.first)
        #expect(row.id == game.id)
        #expect(row.score == "213")
        #expect(row.eventType == EventType.league.title)
        #expect(row.date == BallDetailData.Format(calendar: calendar, locale: Locale(identifier: "en_US")).day(now))
    }
}

@Suite struct BallDetailLoadTests {
    let store: BowlingStore
    let owner: BowlerRecord
    let ball: BallID

    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        ball = try store.balls.addBall(BallFields(name: "Phaze", weightPounds: 15)).id
    }

    /// One final-only game of `type` with `ball` as default, `daysAgo` days back; complete
    /// unless `complete` is false. Returns the game's ID.
    @discardableResult
    func game(_ type: EventType = .league, ball: BallID? = nil, daysAgo: Int = 1, score: Int = 200,
              complete: Bool = true) throws -> GameID {
        let id = try store.sessions.startSession(
            SessionMetadata(date: .now.addingTimeInterval(-86_400 * Double(daysAgo)), eventType: type),
            bowlers: [(bowlerID: owner.id, defaultBallID: ball ?? self.ball)], entryMode: .finalOnly
        )
        let game = try #require(try store.sessions.session(id).bowlers.first?.games.first?.id)
        if complete { try store.games.setFinalScore(score, for: game) }
        return game
    }

    func filter(_ types: Set<EventType> = Set(EventType.allCases), bowler: BowlerID? = nil, name: String = "Sam") -> StatsFilterDraft {
        StatsFilterDraft(filter: StatsFilter(eventTypes: types, bowlerID: bowler ?? owner.id), bowlerName: name)
    }

    @Test func unknownBallThrows() {
        #expect(throws: RepositoryError.notFound) {
            try BallDetailData.load(id: BallID(), store: store, filter: filter())
        }
    }

    @Test func recentGamesNewestFirstAtMostTen() throws {
        let ids = try (1...12).map { try game(daysAgo: $0, score: 150 + $0) }
        let recent = try BallDetailData.load(id: ball, store: store, filter: filter()).recent
        #expect(recent.count == 10)
        #expect(recent.map(\.id) == Array(ids.prefix(10)))
    }

    @Test func recentGamesOnlyUseTheBall() throws {
        let other = try store.balls.addBall(BallFields(name: "Pearl", weightPounds: 15)).id
        let mine = try game()
        try game(ball: other, daysAgo: 2)
        #expect(try BallDetailData.load(id: ball, store: store, filter: filter()).recent.map(\.id) == [mine])
    }

    @Test func incompleteGamesAreLeftOut() throws {
        let done = try game(daysAgo: 2)
        try game(daysAgo: 1, complete: false)
        #expect(try BallDetailData.load(id: ball, store: store, filter: filter()).recent.map(\.id) == [done])
    }

    @Test func recentGamesFollowTheFilter() throws {
        let league = try game(.league, daysAgo: 2)
        try game(.practice, daysAgo: 1)
        let data = try BallDetailData.load(id: ball, store: store, filter: filter(EventType.competition))
        #expect(data.recent.map(\.id) == [league])
    }

    @Test func noGamesInFilterKeepsMaintenance() throws {
        try game(.practice, daysAgo: 2)
        try game(.practice, daysAgo: 1)
        let data = try BallDetailData.load(id: ball, store: store, filter: filter(EventType.competition))
        #expect(data.performance.isEmpty)
        #expect(data.recent.isEmpty)
        #expect(data.maintenance.summary == "Never resurfaced · 2 games")
    }

    @Test func friendFilterStillShowsOwnersGames() throws {
        let friend = try store.bowlers.createBowler(name: "Alex")
        let mine = try game()
        let data = try BallDetailData.load(id: ball, store: store, filter: filter(bowler: friend.id, name: "Alex"))
        #expect(data.recent.map(\.id) == [mine])
        #expect(data.chips.contains("Sam"))
        #expect(!data.chips.contains("Alex"))
    }
}
