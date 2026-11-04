import BowlingData
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The "Export CSV" zip (spec §7 Settings 1b), handed to the system file exporter.
struct ExportedZip: Transferable {
    let url: URL

    @MainActor init(store: BowlingStore) throws {
        url = try store.exportCSV()
    }

    /// Deletes the export's temporary folder, once the exporter is done with the zip.
    func discard() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .zip) { SentTransferredFile($0.url) }
    }
}
