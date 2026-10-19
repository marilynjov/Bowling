import Foundation

/// One CSV file of the export, encoded per RFC 4180.
struct CSVTable {
    let fileName: String
    let columns: [String]
    var rows: [[String]]

    /// CRLF after every record, the last included. A field holding a comma, a double quote,
    /// CR, or LF is quoted with its quotes doubled; every other field is written as is.
    var encoded: String {
        ([columns] + rows).map { $0.map(Self.escape).joined(separator: ",") + "\r\n" }.joined()
    }

    /// UTF-8 with a byte order mark: Excel reads a CSV without one in the system's legacy
    /// encoding, which garbles accented names. Numbers accepts either.
    var data: Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(encoded.utf8)
    }

    private static func escape(_ field: String) -> String {
        // Unicode scalars, not Characters: "\r\n" is a single Character and matches neither "\r" nor "\n".
        let needsQuotes = field.unicodeScalars.contains { $0 == "," || $0 == "\"" || $0 == "\r" || $0 == "\n" }
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
