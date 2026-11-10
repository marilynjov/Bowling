import Foundation
import SwiftData

extension BowlingStore {
    /// Settings "Export CSV" (§7 Settings 1b): one CSV per entity, zipped, for the system
    /// file exporter or share sheet.
    ///
    /// Column names and order are stable, and every row carries its entity's UUID and the
    /// UUIDs of the rows it points to, so phase 3 can re-import an export without duplicates.
    /// New columns are only ever appended. Photos are not exported.
    ///
    /// Each call writes into its own folder in the temporary directory; the system purges
    /// it, and the caller may delete `url.deletingLastPathComponent()` once the file is sent.
    /// - Parameters:
    ///   - now: Names the zip, "Bowling Export 2026-10-14.zip", in the device's time zone.
    ///   - locale: Where decimals use a comma, columns are separated by `;` and decimals
    ///     written with `,`, so Excel opens the files in columns there (#126).
    /// - Returns: The zip's URL.
    public func exportCSV(now: Date = .now, locale: Locale = .current) throws -> URL {
        try exportCSV(now: now, format: CSVFormat(locale: locale),
                      workspace: FileManager.default.temporaryDirectory.appending(path: "CSVExport-\(UUID().uuidString)"))
    }

    /// - Parameter workspace: The folder the export writes into; deleted if the export fails.
    func exportCSV(now: Date, format: CSVFormat = .comma, workspace: URL) throws -> URL {
        let name = "Bowling Export \(now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day()))"
        do {
            let folder = workspace.appending(path: name)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for table in try csvTables(format: format) {
                try table.data.write(to: folder.appending(path: table.fileName))
            }

            // Reading a folder with `.forUploading` hands the accessor a zip of it, which only
            // lives until the accessor returns, so it is copied out. No third-party zip needed.
            let zip = workspace.appending(path: "\(name).zip")
            var coordinationError: NSError?
            var copyError: (any Error)?
            NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zipped in
                do { try FileManager.default.copyItem(at: zipped, to: zip) } catch { copyError = error }
            }
            if let error = coordinationError ?? copyError { throw error }
            try FileManager.default.removeItem(at: folder)
            return zip
        } catch {
            try? FileManager.default.removeItem(at: workspace)
            throw error
        }
    }

    /// Every exported table, in file order. Games are ordered by session date, lineup, and
    /// game index, and frames and rolls follow their game; everything else by creation.
    /// `format` defaults to commas so tests don't depend on the machine's region.
    func csvTables(format: CSVFormat = .comma) throws -> [CSVTable] {
        let sessions = try context.fetch(FetchDescriptor<Session>())
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
        let sessionOrder = Self.positions(sessions)
        let games = Self.sorted(try context.fetch(FetchDescriptor<Game>())) {
            [$0.session.flatMap { sessionOrder[$0.id] } ?? .max, $0.lineupIndex, $0.gameIndex]
        }
        let gameOrder = Self.positions(games)
        let frames = Self.sorted(try context.fetch(FetchDescriptor<Frame>())) {
            [$0.game.flatMap { gameOrder[$0.id] } ?? .max, $0.frameIndex]
        }
        let frameOrder = Self.positions(frames)
        let rolls = Self.sorted(try context.fetch(FetchDescriptor<Roll>())) {
            [$0.frame.flatMap { frameOrder[$0.id] } ?? .max, $0.rollIndex]
        }

        return [
            CSVTable("bowlers.csv", format: format, try fetchByCreation(Bowler.self), [
                .init("name", \.name), .init("isOwner", \.isOwner), .init("handedness", \.handedness),
                .init("email", \.email), .init("statsProfile", \.statsProfile),
                .init("statsLayout", \.statsLayout), .init("homeLayout", \.homeLayout),
                .init("statsScope", \.statsScope),
            ]),
            CSVTable("sessions.csv", format: format, sessions, [
                .init("date", \.date), .init("eventType", \.eventType),
                .init("centerID") { $0.center?.id }, .init("leagueID") { $0.league?.id },
                .init("oilPatternID") { $0.oilPattern?.id }, .init("lanes", \.lanes), .init("notes", \.notes),
            ]),
            CSVTable("games.csv", format: format, games, [
                .init("sessionID") { $0.session?.id }, .init("bowlerID") { $0.bowlerID },
                .init("gameIndex", \.gameIndex), .init("lineupIndex", \.lineupIndex),
                .init("entryMode", \.entryMode), .init("defaultBallID") { $0.defaultBall?.id },
                .init("finalScore", \.finalScore), .init("isComplete", \.isComplete),
                .init("scanConfidence", \.scanConfidence), .init("invitationStatus", \.invitationStatus),
                .init("scoredByName", \.scoredByName),
            ]),
            CSVTable("frames.csv", format: format, frames, [
                .init("gameID") { $0.game?.id }, .init("frameIndex", \.frameIndex),
                .init("rotationSlot", \.rotationSlot),
            ]),
            CSVTable("rolls.csv", format: format, rolls, [
                .init("frameID") { $0.frame?.id }, .init("rollIndex", \.rollIndex),
                .init("pinsDownMask", \.pinsDownMask), .init("pinCount", \.pinCount),
                .init("pinsKnown", \.pinsKnown), .init("isFoul", \.isFoul), .init("ballID") { $0.ball?.id },
            ]),
            CSVTable("balls.csv", format: format, try fetchByCreation(Ball.self), [
                .init("name", \.name), .init("brand", \.brand), .init("weightPounds", \.weightPounds),
                .init("coverstock", \.coverstock), .init("coverstockName", \.coverstockName),
                .init("coreType", \.coreType), .init("coreName", \.coreName), .init("rg", \.rg),
                .init("differential", \.differential),
                .init("intermediateDifferential", \.intermediateDifferential),
                .init("intendedRole", \.intendedRole), .init("serialNumber", \.serialNumber),
                .init("colorDescription", \.colorDescription), .init("releaseDate", \.releaseDate),
                .init("purchaseDate", \.purchaseDate), .init("factoryFinish", \.factoryFinish),
                .init("surfaceGrit", \.surfaceGrit), .init("resurfaceIntervalGames", \.resurfaceIntervalGames),
                .init("isRetired", \.isRetired), .init("notes", \.notes),
            ]),
            CSVTable("maintenance.csv", format: format, try fetchByCreation(MaintenanceEvent.self), [
                .init("ballID") { $0.ball?.id }, .init("date", \.date), .init("kind", \.kind),
                .init("surfaceGritAfter", \.surfaceGritAfter), .init("gamesOnBallAtTime", \.gamesOnBallAtTime),
                .init("notes", \.notes),
            ]),
            CSVTable("centers.csv", format: format, try fetchByCreation(BowlingCenter.self), [
                .init("name", \.name), .init("notes", \.notes), .init("city", \.city),
                .init("latitude", \.latitude), .init("longitude", \.longitude),
            ]),
            CSVTable("leagues.csv", format: format, try fetchByCreation(League.self), [
                .init("name", \.name), .init("notes", \.notes), .init("centerID") { $0.center?.id },
                .init("seasonLabel", \.seasonLabel), .init("seasonStart", \.seasonStart),
                .init("seasonEnd", \.seasonEnd), .init("gamesPerSession", \.gamesPerSession),
            ]),
            CSVTable("oilPatterns.csv", format: format, try fetchByCreation(OilPattern.self), [
                .init("name", \.name), .init("notes", \.notes), .init("lengthFeet", \.lengthFeet),
                .init("volumeMilliliters", \.volumeMilliliters), .init("patternKey", \.patternKey),
            ]),
        ]
    }

    private func fetchByCreation<Model: ExportedModel>(_ type: Model.Type) throws -> [Model] {
        try context.fetch(FetchDescriptor<Model>())
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    /// Sorts by `key`, then by UUID. Each key is read once rather than on every comparison:
    /// keys read relationships. For 2,000 games and 40,000 rolls in a debug build, comparing
    /// on the fly made `csvTables()` take 9.7 s on the main actor, and this takes 2.9 s, all
    /// of it fetching.
    private static func sorted<Model: ExportedModel>(_ models: [Model], by key: (Model) -> [Int]) -> [Model] {
        models.map { (key: key($0), id: $0.id.uuidString, model: $0) }
            .sorted { $0.key != $1.key ? $0.key.lexicographicallyPrecedes($1.key) : $0.id < $1.id }
            .map(\.model)
    }

    private static func positions<Model: ExportedModel>(_ models: [Model]) -> [UUID: Int] {
        Dictionary(models.enumerated().map { ($1.id, $0) }) { first, _ in first }
    }
}

/// The fields §3.1 puts on every entity, which lead every exported table.
private protocol ExportedModel: PersistentModel {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var remoteID: String? { get }
}

extension Bowler: ExportedModel {}
extension Session: ExportedModel {}
extension Game: ExportedModel {}
extension Frame: ExportedModel {}
extension Roll: ExportedModel {}
extension Ball: ExportedModel {}
extension MaintenanceEvent: ExportedModel {}
extension BowlingCenter: ExportedModel {}
extension League: ExportedModel {}
extension OilPattern: ExportedModel {}

private struct CSVColumn<Model> {
    let name: String
    let field: (Model, CSVFormat) -> String

    init<Value: CSVField>(_ name: String, _ value: @escaping (Model) -> Value) {
        self.name = name
        field = { value($0).csvField($1) }
    }
}

extension CSVTable {
    fileprivate init<Model: ExportedModel>(
        _ fileName: String, format: CSVFormat, _ models: [Model], _ columns: [CSVColumn<Model>]
    ) {
        let all: [CSVColumn<Model>] = [
            .init("id", \.id), .init("createdAt", \.createdAt), .init("updatedAt", \.updatedAt),
            .init("remoteID", \.remoteID),
        ] + columns
        self.init(fileName: fileName, columns: all.map(\.name),
                  rows: models.map { model in all.map { $0.field(model, format) } }, format: format)
    }
}

/// How a stored value is written. Nil is an empty field; enums are their stored raw string,
/// so a value from a newer app version is exported unchanged.
private protocol CSVField {
    func csvField(_ format: CSVFormat) -> String
}

extension String: CSVField {
    func csvField(_ format: CSVFormat) -> String { self }
}

extension Int: CSVField {
    func csvField(_ format: CSVFormat) -> String { String(self) }
}

/// "true" and "false", which Numbers and Excel both read as booleans.
extension Bool: CSVField {
    func csvField(_ format: CSVFormat) -> String { self ? "true" : "false" }
}

/// The shortest decimal that reads back as the same Double, with the format's decimal
/// separator: "2.52", or "2,52" in a `;` file.
extension Double: CSVField {
    func csvField(_ format: CSVFormat) -> String {
        String(self).replacingOccurrences(of: ".", with: format.decimalSeparator)
    }
}

extension UUID: CSVField {
    func csvField(_ format: CSVFormat) -> String { uuidString }
}

/// ISO 8601 in UTC with milliseconds, for example "2026-10-12T12:00:00.000Z", so the
/// export reads the same on every device and `createdAt` ties stay ordered on re-import.
extension Date: CSVField {
    func csvField(_ format: CSVFormat) -> String { formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)) }
}

extension Optional: CSVField where Wrapped: CSVField {
    func csvField(_ format: CSVFormat) -> String { self?.csvField(format) ?? "" }
}
