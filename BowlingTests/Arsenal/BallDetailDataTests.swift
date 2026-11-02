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
}
