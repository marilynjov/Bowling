import BowlingCore
import BowlingFixtures
import Foundation
import Testing
@testable import BowlingData

/// Settings "Export CSV" (§7 Settings 1b, §9 "CSV export"). Expected counts are counted by
/// hand from the scoresheets in BowlingFixtures/DemoGames.swift.
@MainActor @Suite struct CSVExportTests {
    let store: BowlingStore
    let tables: [String: CSVTable]

    init() throws {
        store = try BowlingStore.demo(now: DemoFixture.referenceDate)
        tables = Dictionary(uniqueKeysWithValues: try store.csvTables().map { ($0.fileName, $0) })
    }

    private func table(_ name: String) throws -> CSVTable {
        try #require(tables[name])
    }

    private func ids(_ name: String, column: String = "id") throws -> [String] {
        let table = try table(name)
        return try table.rows.map { try table.value($0, column) }
    }

    // MARK: Columns

    @Test func filesAndColumnsAreStable() throws {
        let common = ["id", "createdAt", "updatedAt", "remoteID"]
        let expected: [(String, [String])] = [
            ("bowlers.csv", common + [
                "name", "isOwner", "handedness", "email", "statsProfile", "statsLayout",
                "homeLayout", "statsScope",
            ]),
            ("sessions.csv", common + [
                "date", "eventType", "centerID", "leagueID", "oilPatternID", "lanes", "notes",
            ]),
            ("games.csv", common + [
                "sessionID", "bowlerID", "gameIndex", "lineupIndex", "entryMode", "defaultBallID",
                "finalScore", "isComplete", "scanConfidence", "invitationStatus", "scoredByName",
            ]),
            ("frames.csv", common + ["gameID", "frameIndex", "rotationSlot"]),
            ("rolls.csv", common + [
                "frameID", "rollIndex", "pinsDownMask", "pinCount", "pinsKnown", "isFoul", "ballID",
            ]),
            ("balls.csv", common + [
                "name", "brand", "weightPounds", "coverstock", "coverstockName", "coreType",
                "coreName", "rg", "differential", "intermediateDifferential", "intendedRole",
                "serialNumber", "colorDescription", "releaseDate", "purchaseDate", "factoryFinish",
                "surfaceGrit", "resurfaceIntervalGames", "isRetired", "notes",
            ]),
            ("maintenance.csv", common + [
                "ballID", "date", "kind", "surfaceGritAfter", "gamesOnBallAtTime", "notes",
            ]),
            ("centers.csv", common + ["name", "notes", "city", "latitude", "longitude"]),
            ("leagues.csv", common + [
                "name", "notes", "centerID", "seasonLabel", "seasonStart", "seasonEnd", "gamesPerSession",
            ]),
            ("oilPatterns.csv", common + ["name", "notes", "lengthFeet", "volumeMilliliters", "patternKey"]),
        ]
        #expect(try store.csvTables().map(\.fileName) == expected.map(\.0))
        for (name, columns) in expected {
            #expect(try table(name).columns == columns, "\(name)")
        }
    }

    @Test func everyRowHasOneFieldPerColumn() {
        for table in tables.values {
            #expect(table.rows.allSatisfy { $0.count == table.columns.count }, "\(table.fileName)")
        }
    }

    // MARK: Row counts

    /// frames: 4 finalOnly games (tournament3, earlyLeague3, casualOuting1, friendCasual2)
    /// have none, 17 complete scored games have 10, practiceInProgress has 5:
    /// 17 * 10 + 5 = 175.
    ///
    /// rolls, per game in DemoGame order, one per roll token in its scoresheet:
    /// leagueNight 18 + 16 + 19 = 53; partner 16 + 18 + 17 = 51; tournament 12 + 16 + 0 + 17
    /// = 45; earlyLeague 21 + 18 + 0 = 39; practice 17 + 17 = 34; casualOuting 0 + 18 = 18;
    /// practiceInProgress 7; friendCasual 17 + 0 = 17; friendPractice 18 + 19 = 37.
    /// 53 + 51 + 45 + 39 + 34 + 18 + 7 + 17 + 37 = 301.
    /// (tournament1 is 9 strikes + 3 in frame 10 = 12; earlyLeague1 is 9 * 2 + 3 = 21.)
    @Test(arguments: [
        ("bowlers.csv", 3), ("sessions.csv", 8), ("games.csv", 22), ("frames.csv", 175),
        ("rolls.csv", 301), ("balls.csv", 3), ("maintenance.csv", 0), ("centers.csv", 0),
        ("leagues.csv", 0), ("oilPatterns.csv", 0),
    ])
    func demoStoreRowCounts(_ name: String, _ count: Int) throws {
        #expect(try table(name).rows.count == count)
    }

    // MARK: UUIDs

    @Test func fixtureEntitiesKeepTheirUUIDs() throws {
        #expect(Set(try ids("bowlers.csv")) == Set(DemoBowler.allCases.map(\.id.uuidString)))
        #expect(Set(try ids("sessions.csv")) == Set(DemoSession.allCases.map(\.id.uuidString)))
        #expect(Set(try ids("games.csv")) == Set(DemoGame.allCases.map(\.id.uuidString)))
        #expect(Set(try ids("balls.csv")) == Set(DemoBall.allCases.map(\.id.uuidString)))
    }

    /// Every entity's UUID appears once in the whole export (§11 1b done criteria).
    @Test func everyUUIDIsUniqueAcrossFiles() throws {
        let all = try tables.keys.flatMap { try ids($0) }
        #expect(all.count == 3 + 8 + 22 + 175 + 301 + 3)
        #expect(Set(all).count == all.count)
        #expect(all.allSatisfy { UUID(uuidString: $0) != nil })
    }

    @Test func framesAndRollsPointAtExportedParents() throws {
        #expect(Set(try ids("frames.csv", column: "gameID")).isSubset(of: Set(try ids("games.csv"))))
        #expect(Set(try ids("rolls.csv", column: "frameID")) == Set(try ids("frames.csv")))
        let ballIDs = Set(try ids("balls.csv") + [""])
        #expect(Set(try ids("games.csv", column: "defaultBallID")).isSubset(of: ballIDs))
        #expect(Set(try ids("rolls.csv", column: "ballID")).isSubset(of: ballIDs))
    }

    @Test func framesPerGame() throws {
        let perGame = Dictionary(grouping: try ids("frames.csv", column: "gameID"), by: \.self).mapValues(\.count)
        let finalOnly: [DemoGame] = [.tournament3, .earlyLeague3, .casualOuting1, .friendCasual2]
        for game in DemoGame.allCases {
            let expected = finalOnly.contains(game) ? nil : game == .practiceInProgress ? 5 : 10
            #expect(perGame[game.id.uuidString] == expected, "\(game)")
        }
    }

    // MARK: Row order

    /// Sessions oldest first, by `daysAgo` descending: casualOuting 40, friendPractice 20,
    /// earlyLeague 16, tournament 9, practice 5, friendCasual 3, leagueNight 2,
    /// practiceInProgress 0. Within leagueNight the owner is lineup 1 and the partner 2.
    /// 2 + 2 + 3 + 4 + 2 + 2 + 6 + 1 = 22 games.
    @Test func gamesFollowSessionDateLineupAndGameIndex() throws {
        let expected: [DemoGame] = [
            .casualOuting1, .casualOuting2, .friendPractice1, .friendPractice2,
            .earlyLeague1, .earlyLeague2, .earlyLeague3,
            .tournament1, .tournament2, .tournament3, .tournament4,
            .practice1, .practice2, .friendCasual1, .friendCasual2,
            .leagueNight1, .leagueNight2, .leagueNight3,
            .leagueNightPartner1, .leagueNightPartner2, .leagueNightPartner3,
            .practiceInProgress,
        ]
        #expect(try ids("games.csv") == expected.map(\.id.uuidString))
    }

    /// leagueNight1 is "10 /^", "X", "7-10 7", "2-8 /", "F /", "X", "X", "3-6-10 10",
    /// "1-2-10 10", "X 10 /": 2 + 1 + 2 + 2 + 2 + 1 + 1 + 2 + 2 + 3 = 18 rolls.
    @Test func framesAndRollsFollowTheirIndexes() throws {
        let frames = try table("frames.csv")
        let gameFrames = try frames.rows.filter { try frames.value($0, "gameID") == DemoGame.leagueNight1.id.uuidString }
        #expect(try gameFrames.map { try frames.value($0, "frameIndex") } == (1...10).map(String.init))

        let frameIndex = try Dictionary(uniqueKeysWithValues: gameFrames.map { ($0[0], try frames.value($0, "frameIndex")) })
        let rolls = try table("rolls.csv")
        let order = try rolls.rows.compactMap { row in
            try frameIndex[rolls.value(row, "frameID")].map { "\($0).\(try rolls.value(row, "rollIndex"))" }
        }
        #expect(order == [
            "1.1", "1.2", "2.1", "3.1", "3.2", "4.1", "4.2", "5.1", "5.2", "6.1", "7.1",
            "8.1", "8.2", "9.1", "9.2", "10.1", "10.2", "10.3",
        ])
    }

    // MARK: Values

    @Test func ownerRow() throws {
        let table = try table("bowlers.csv")
        let row = try #require(table.rows.first { $0[0] == DemoBowler.owner.id.uuidString })
        #expect(try table.value(row, "name") == "Sam Rivera")
        #expect(try table.value(row, "isOwner") == "true")
        #expect(try table.value(row, "handedness") == "right")
        #expect(try table.value(row, "statsProfile") == "league")
        #expect(try table.value(row, "email") == "")
        #expect(try table.value(row, "remoteID") == "")
    }

    /// leagueNight is 2 days before 2026-10-14 12:00 UTC.
    @Test func sessionDateIsISO8601InUTC() throws {
        let table = try table("sessions.csv")
        let row = try #require(table.rows.first { $0[0] == DemoSession.leagueNight.id.uuidString })
        #expect(try table.value(row, "date") == "2026-10-12T12:00:00.000Z")
        #expect(try table.value(row, "eventType") == "league")
        #expect(try table.value(row, "centerID") == "")
    }

    @Test func perfectGameRow() throws {
        let table = try table("games.csv")
        let row = try #require(table.rows.first { $0[0] == DemoGame.tournament1.id.uuidString })
        #expect(try table.value(row, "sessionID") == DemoSession.tournament.id.uuidString)
        #expect(try table.value(row, "bowlerID") == DemoBowler.owner.id.uuidString)
        #expect(try table.value(row, "gameIndex") == "1")
        #expect(try table.value(row, "lineupIndex") == "1")
        #expect(try table.value(row, "entryMode") == "pinByPin")
        #expect(try table.value(row, "defaultBallID") == DemoBall.ownerStrike.id.uuidString)
        #expect(try table.value(row, "finalScore") == "300")
        #expect(try table.value(row, "isComplete") == "true")
        #expect(try table.value(row, "scanConfidence") == "")
        #expect(try table.value(row, "invitationStatus") == "none")
    }

    /// leagueNight1 frame 1 is "10 /^": ball 1 leaves the 10, so pins 1-9 fall, mask
    /// 2^9 - 1 = 511; ball 2 takes the 10 (bit 9, 512) with the spare ball override.
    @Test func overrideRollRows() throws {
        let frames = try table("frames.csv")
        let frame = try #require(frames.rows.first {
            $0[frames.columns.firstIndex(of: "gameID")!] == DemoGame.leagueNight1.id.uuidString
                && $0[frames.columns.firstIndex(of: "frameIndex")!] == "1"
        })
        let rolls = try table("rolls.csv")
        let frameRolls = try rolls.rows.filter { try rolls.value($0, "frameID") == frame[0] }
            .sorted { $0[rolls.columns.firstIndex(of: "rollIndex")!] < $1[rolls.columns.firstIndex(of: "rollIndex")!] }
        #expect(try frameRolls.map { try rolls.value($0, "pinsDownMask") } == ["511", "512"])
        #expect(try frameRolls.map { try rolls.value($0, "pinCount") } == ["9", "1"])
        #expect(try frameRolls.map { try rolls.value($0, "pinsKnown") } == ["true", "true"])
        #expect(try frameRolls.map { try rolls.value($0, "isFoul") } == ["false", "false"])
        #expect(try frameRolls.map { try rolls.value($0, "ballID") } == ["", DemoBall.ownerSpare.id.uuidString])
    }

    // MARK: Entities the demo store lacks

    @Test func placesAndMaintenanceAreExported() throws {
        let store = try BowlingStore(inMemory: true)
        let center = try store.sessions.createCenter(name: "Bowl, Inc.")
        let league = try store.sessions.createLeague(name: "Tuesday \"Trios\"", centerID: center)
        let pattern = try store.sessions.createOilPattern(name: "House")
        let ball = try store.balls.addBall(name: "Phaze II", weightPounds: 15, intendedRole: .strike, brand: "Storm")
        let event = MaintenanceEvent(date: DemoFixture.referenceDate, kind: .resurface)
        event.notes = "Abralon 500,\nthen 2000"
        event.gamesOnBallAtTime = 60
        store.context.insert(event)
        event.ball = try store.context.ball(ball.id)
        try store.context.save()

        let tables = Dictionary(uniqueKeysWithValues: try store.csvTables().map { ($0.fileName, $0) })
        let centers = try #require(tables["centers.csv"])
        #expect(try centers.rows.map { try centers.value($0, "name") } == ["Bowl, Inc."])
        #expect(centers.rows.map { $0[0] } == [center.uuidString])
        let leagues = try #require(tables["leagues.csv"])
        #expect(try leagues.rows.map { try leagues.value($0, "centerID") } == [center.uuidString])
        #expect(try leagues.rows.map { try leagues.value($0, "gamesPerSession") } == ["3"])
        #expect(leagues.rows.map { $0[0] } == [league.uuidString])
        #expect(try #require(tables["oilPatterns.csv"]).rows.map { $0[0] } == [pattern.uuidString])

        let maintenance = try #require(tables["maintenance.csv"])
        let row = try #require(maintenance.rows.first)
        #expect(maintenance.rows.count == 1)
        #expect(row[0] == event.id.uuidString)
        #expect(try maintenance.value(row, "ballID") == ball.id.uuidString)
        #expect(try maintenance.value(row, "date") == "2026-10-14T12:00:00.000Z")
        #expect(try maintenance.value(row, "kind") == "resurface")
        #expect(try maintenance.value(row, "gamesOnBallAtTime") == "60")
        #expect(maintenance.encoded.contains("\"Abralon 500,\nthen 2000\"\r\n"))
        #expect(leagues.encoded.contains(",\"Tuesday \"\"Trios\"\"\","))
    }

    // MARK: Zip

    @Test func exportWritesAZipNamedForTheDay() throws {
        let url = try store.exportCSV(now: DemoFixture.referenceDate)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(url.lastPathComponent == "Bowling Export 2026-10-14.zip")
        let data = try Data(contentsOf: url)
        #expect(Array(data.prefix(4)) == [0x50, 0x4B, 0x03, 0x04])  // "PK\3\4", a zip local file header
    }

    @Test func eachExportGetsItsOwnFolder() throws {
        let first = try store.exportCSV(now: DemoFixture.referenceDate)
        let second = try store.exportCSV(now: DemoFixture.referenceDate)
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }
        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path))
    }

    /// A file already where the zip goes makes the copy out of the coordinator fail, after
    /// the CSVs are written.
    @Test func failedExportRemovesItsFolder() throws {
        let workspace = FileManager.default.temporaryDirectory.appending(path: "CSVExportTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: workspace) }
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try Data().write(to: workspace.appending(path: "Bowling Export 2026-10-14.zip"))

        #expect(throws: (any Error).self) { try store.exportCSV(now: DemoFixture.referenceDate, workspace: workspace) }
        #expect(!FileManager.default.fileExists(atPath: workspace.path))
    }

    #if os(macOS)
    @Test func zipHoldsEveryFileByteForByte() throws {
        let url = try store.exportCSV(now: DemoFixture.referenceDate)
        let unzipped = url.deletingLastPathComponent().appending(path: "unzipped")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let unzip = Process()
        unzip.executableURL = URL(filePath: "/usr/bin/unzip")
        unzip.arguments = ["-q", url.path, "-d", unzipped.path]
        try unzip.run()
        unzip.waitUntilExit()
        #expect(unzip.terminationStatus == 0)

        let folder = unzipped.appending(path: "Bowling Export 2026-10-14")
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(names == tables.keys.sorted())
        for (name, table) in tables {
            #expect(try Data(contentsOf: folder.appending(path: name)) == table.data, "\(name)")
        }
    }
    #endif
}

extension CSVTable {
    func value(_ row: [String], _ column: String) throws -> String {
        row[try #require(columns.firstIndex(of: column), "\(fileName) has no \(column)")]
    }
}
