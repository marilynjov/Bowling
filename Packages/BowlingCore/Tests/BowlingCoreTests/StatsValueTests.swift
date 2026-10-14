import Testing
import BowlingCore

@Suite struct StatsValueTests {
    @Test func rateValueIsHitsOverAttempts() {
        #expect(Rate(hits: 3, attempts: 4).value == 0.75)
    }

    // §8: stats on zero games never show NaN or divide by zero.
    @Test func rateWithoutAttemptsHasNoValue() {
        #expect(Rate(hits: 0, attempts: 0).value == nil)
    }

    @Test func meanValueIsTotalOverCount() {
        #expect(Mean(total: 450, count: 3).value == 150)
    }

    @Test func meanWithoutCountHasNoValue() {
        #expect(Mean(total: 0, count: 0).value == nil)
    }
}
