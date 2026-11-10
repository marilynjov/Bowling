import Foundation

/// One CSV file of the export, encoded per RFC 4180 with the format's separator.
struct CSVTable {
    let fileName: String
    let columns: [String]
    var rows: [[String]]
    var format: CSVFormat = .comma

    /// CRLF after every record, the last included. A field holding the separator, a double
    /// quote, CR, or LF is quoted with its quotes doubled; every other field is written as is.
    var encoded: String {
        let separator = String(format.separator)
        return ([columns] + rows).map { $0.map(escape).joined(separator: separator) + "\r\n" }.joined()
    }

    /// UTF-8 with a byte order mark: Excel reads a CSV without one in the system's legacy
    /// encoding, which garbles accented names. Numbers accepts either.
    var data: Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(encoded.utf8)
    }

    private func escape(_ field: String) -> String {
        // Unicode scalars, not Characters: "\r\n" is a single Character and matches neither "\r" nor "\n".
        let separator = format.separator.unicodeScalars.first
        let needsQuotes = field.unicodeScalars.contains { $0 == separator || $0 == "\"" || $0 == "\r" || $0 == "\n" }
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// Excel opens a CSV in columns only when its separator is the region's list separator,
/// which is `;` wherever decimals are written with a comma (Colombia, most of Europe), and
/// it reads "2.52" as text there. So the export follows the device's region (#126). Column
/// names and UUIDs are the same either way; phase 3's import can tell the two apart from the
/// header row, which always holds a separator after "id".
struct CSVFormat: Equatable, Sendable {
    let separator: Character
    let decimalSeparator: String

    static let comma = CSVFormat(separator: ",", decimalSeparator: ".")
    static let semicolon = CSVFormat(separator: ";", decimalSeparator: ",")

    init(separator: Character, decimalSeparator: String) {
        self.separator = separator
        self.decimalSeparator = decimalSeparator
    }

    init(locale: Locale) {
        self = locale.decimalSeparator == "," ? .semicolon : .comma
    }
}
