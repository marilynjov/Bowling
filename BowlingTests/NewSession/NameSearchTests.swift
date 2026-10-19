import Testing
@testable import Bowling

@Suite struct NameSearchTests {
    @Test func emptySearchShowsEverything() {
        #expect(NameSearch.filter(["B", "A"], by: "  ", name: { $0 }) == ["B", "A"])
    }

    @Test func searchIgnoresCaseAndAccents() {
        let names = ["Café Lanes", "Sunset Lanes", "AMF"]
        #expect(NameSearch.filter(names, by: "cafe", name: { $0 }) == ["Café Lanes"])
        #expect(NameSearch.filter(names, by: " lanes", name: { $0 }) == ["Café Lanes", "Sunset Lanes"])
    }

    @Test func addNameIsTrimmed() {
        #expect(NameSearch.addName(for: "  Sunset Lanes \n", existing: []) == "Sunset Lanes")
    }

    @Test func noAddRowForBlankText() {
        #expect(NameSearch.addName(for: " \t", existing: []) == nil)
    }

    @Test func noAddRowForAnExistingNameInAnyCase() {
        #expect(NameSearch.addName(for: "sunset lanes", existing: ["Sunset Lanes"]) == nil)
        #expect(NameSearch.addName(for: "Sunset", existing: ["Sunset Lanes"]) == "Sunset")
    }

    @Test func noAddRowForAnExistingNameWithoutItsAccents() {
        #expect(NameSearch.addName(for: "cafe lanes", existing: ["Café Lanes"]) == nil)
    }
}
