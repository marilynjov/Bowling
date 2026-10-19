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
    /// The repository's create calls don't trim, so this is the name to pass them.
    static func addName(for text: String, existing: [String]) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let taken = existing.contains { $0.compare(text, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        return taken ? nil : text
    }
}
