import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct StatFormatTests {
    let us = Locale(identifier: "en_US")

    @Test func percents() {
        #expect(StatFormat.percent(Rate(hits: 89, attempts: 216), locale: us) == "41%")
        #expect(StatFormat.percent(Rate(hits: 0, attempts: 0), locale: us) == "–")
        #expect(StatFormat.percent(Rate(hits: 199, attempts: 200), locale: us) == "99%")   // Review Focus 1
        #expect(StatFormat.percent(Rate(hits: 200, attempts: 200), locale: us) == "100%")
        #expect(StatFormat.percent(Rate(hits: 1, attempts: 201), locale: us) == "1%")
        #expect(StatFormat.percent(Rate(hits: 0, attempts: 201), locale: us) == "0%")
    }
    @Test func averages() {
        #expect(StatFormat.average(Mean(total: 4464, count: 24), locale: us) == "186")
        #expect(StatFormat.average(Mean(total: 373, count: 2), locale: us) == "186.5")
        #expect(StatFormat.average(Mean(total: 0, count: 0), locale: us) == "–")
    }
    @Test func followsTheLocale() {
        let colombia = Locale(identifier: "es_CO")
        #expect(StatFormat.average(Mean(total: 373, count: 2), locale: colombia) == "186,5")
        #expect(StatFormat.percent(Rate(hits: 89, attempts: 216), locale: colombia) == "41%")
    }
    @Test func samples() {
        #expect(StatFormat.sample(1, .games) == "1 game")
        #expect(StatFormat.sample(24, .games) == "24 games")
        #expect(StatFormat.sample(216, .frames) == "216 frames")
        #expect(StatFormat.sample(1, .chances) == "1 chance")
        #expect(StatFormat.sample(0, .games) == "No games yet")
        #expect(StatFormat.sample(0, .frames) == "No frames yet")
        #expect(StatFormat.sample(0, .chances) == "No chances yet")
    }
}
