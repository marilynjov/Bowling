import Foundation
import Testing

/// The source String Catalog. The app bundle carries only the compiled `.strings`, so the
/// tests read the committed file next to the sources.
enum StringCatalog {
    struct Entry {
        var extractionState: String?
        var hasPluralVariants: Bool
    }

    static let url = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Bowling/Localizable.xcstrings")

    static func load() throws -> (sourceLanguage: String, strings: [String: Entry]) {
        let json = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        let strings = json["strings"] as? [String: [String: Any]] ?? [:]
        return (
            json["sourceLanguage"] as? String ?? "",
            strings.mapValues { entry in
                let english = (entry["localizations"] as? [String: Any])?["en"] as? [String: Any]
                let plural = (english?["variations"] as? [String: Any])?["plural"] as? [String: Any]
                return Entry(
                    extractionState: entry["extractionState"] as? String,
                    hasPluralVariants: plural?["one"] != nil && plural?["other"] != nil
                )
            }
        )
    }
}

@Suite struct StringCatalogTests {
    @Test func catalogExistsAndIsEnglish() throws {
        let catalog = try StringCatalog.load()
        #expect(catalog.sourceLanguage == "en")
        #expect(catalog.strings.count > 100)
    }

    @Test func noKeyIsStale() throws {
        let stale = try StringCatalog.load().strings.filter { $0.value.extractionState == "stale" }.keys
        #expect(stale.isEmpty, "Stale keys: \(stale.sorted())")
    }

    @Test(arguments: ["Strike", "Spare", "Miss", "Foul", "Undo", "Next", "No ball", "Center", "League",
                      "Oil pattern", "Continue"])
    func catalogHasTheFixedTitles(key: String) throws {
        #expect(try StringCatalog.load().strings[key] != nil)
    }

    @Test(arguments: ["Start session", "New session", "Game complete", "Pin %lld, standing"])
    func appCopyIsInTheCatalog(key: String) throws {
        #expect(try StringCatalog.load().strings[key] != nil)
    }
}
