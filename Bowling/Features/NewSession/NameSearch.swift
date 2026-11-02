import Foundation

/// The new-session pickers' search: which rows match, and when to offer Add "<name>".
enum NameSearch {
    /// Everything for blank text; otherwise names containing the trimmed text, ignoring case
    /// and accents. Keeps the order given.
    static func filter<T>(_ items: [T], by text: String, name: (T) -> String) -> [T] {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return items }
        return items.filter { name($0).range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// The trimmed text to create, or nil when it's blank or already exists, ignoring case
    /// and accents (so "cafe lanes" doesn't make a second "Café Lanes").
    static func addName(for text: String, existing: [String]) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return existing.contains { isSame($0, text) } ? nil : text
    }

    /// The first of `items` whose name is the trimmed text, ignoring case and accents.
    static func exactMatch<T>(_ items: [T], for text: String, name: (T) -> String) -> T? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return items.first { isSame(name($0), text) }
    }

    private static func isSame(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}
