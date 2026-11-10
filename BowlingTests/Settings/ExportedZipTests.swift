import BowlingCore
import BowlingData
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Bowling

@Suite struct ExportedZipTests {
    let store: BowlingStore

    init() throws {
        store = try BowlingStore(inMemory: true)
        try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
    }

    @Test func exportsADatedZip() throws {
        let export = try ExportedZip(store: store)
        defer { export.discard() }
        #expect(FileManager.default.fileExists(atPath: export.url.path(percentEncoded: false)))
        #expect(export.url.lastPathComponent.hasPrefix("Bowling Export "))
        #expect(UTType(filenameExtension: export.url.pathExtension) == .zip)
    }

    @Test func discardRemovesTheExportFolder() throws {
        let export = try ExportedZip(store: store)
        let folder = export.url.deletingLastPathComponent()
        export.discard()
        #expect(!FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))
    }
}
