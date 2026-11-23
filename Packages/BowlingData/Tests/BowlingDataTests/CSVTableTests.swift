import Foundation
import Testing
@testable import BowlingData

/// RFC 4180 encoding: CRLF after every record, and a field that holds a comma, a double
/// quote, CR, or LF is wrapped in double quotes with each inner quote doubled.
@Suite struct CSVTableTests {
    @Test func plainFieldsAreWrittenAsIs() {
        let table = CSVTable(fileName: "t.csv", columns: ["id", "name"], rows: [["1", "Sam"], ["2", ""]])
        #expect(table.encoded == "id,name\r\n1,Sam\r\n2,\r\n")
    }

    @Test func aTableWithNoRowsIsTheHeaderOnly() {
        let table = CSVTable(fileName: "t.csv", columns: ["id", "notes"], rows: [])
        #expect(table.encoded == "id,notes\r\n")
    }

    @Test(arguments: [
        ("a,b", "\"a,b\""),
        ("say \"hi\"", "\"say \"\"hi\"\"\""),
        ("line1\nline2", "\"line1\nline2\""),
        ("line1\r\nline2", "\"line1\r\nline2\""),
        ("\"", "\"\"\"\""),
        (" padded ", " padded "),
    ])
    func fieldsWithCommasQuotesOrNewlinesAreQuoted(_ field: String, _ expected: String) {
        let table = CSVTable(fileName: "t.csv", columns: ["notes"], rows: [[field]])
        #expect(table.encoded == "notes\r\n\(expected)\r\n")
    }

    @Test func theSemicolonFormatSeparatesWithSemicolons() {
        let table = CSVTable(fileName: "t.csv", columns: ["id", "name"], rows: [["1", "Sam"]], format: .semicolon)
        #expect(table.encoded == "id;name\r\n1;Sam\r\n")
    }

    @Test(arguments: [
        ("a;b", "\"a;b\""),
        ("a,b", "a,b"),
        ("say \"hi\"", "\"say \"\"hi\"\"\""),
    ])
    func theSemicolonFormatQuotesFieldsWithASemicolon(_ field: String, _ expected: String) {
        let table = CSVTable(fileName: "t.csv", columns: ["notes"], rows: [[field]], format: .semicolon)
        #expect(table.encoded == "notes\r\n\(expected)\r\n")
    }

    /// Excel takes its column separator from the region: `;` where decimals use a comma (#126).
    @Test(arguments: [
        ("en_US", CSVFormat.comma), ("en_GB", .comma), ("en_CO", .semicolon), ("es_CO", .semicolon),
        ("de_DE", .semicolon),
    ])
    func theFormatFollowsTheLocalesDecimalSeparator(_ identifier: String, _ expected: CSVFormat) {
        #expect(CSVFormat(locale: Locale(identifier: identifier)) == expected)
    }

    // A non-ASCII name, so the encoding question is not hypothetical.
    @Test func dataIsUTF8WithAByteOrderMarkSoExcelReadsAccents() {
        let table = CSVTable(fileName: "t.csv", columns: ["name"], rows: [["José"]])
        let data = table.data
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(String(decoding: data.dropFirst(3), as: UTF8.self) == "name\r\nJosé\r\n")
    }
}
