import Testing
@testable import BowlingData

@Test func moduleIsLinkedWithCore() {
    #expect(BowlingDataModule.name == "BowlingData")
    #expect(BowlingDataModule.coreName == "BowlingCore")
}
