import BowlingCore
import DeveloperToolsSupport
import SwiftUI
import Testing
import UIKit
@testable import Bowling

/// WCAG AA from the style doc: 4.5:1 for text, 3:1 for pins, buttons, and other controls.
@Suite struct ThemeTests {
    struct Pair: CustomTestStringConvertible, Sendable {
        var foreground: String
        var background: String
        var minimum: Double
        var testDescription: String { "\(foreground) on \(background)" }
    }

    nonisolated static let pairs: [Pair] = [
        Pair(foreground: "Ink", background: "Canvas", minimum: 4.5),
        Pair(foreground: "Ink", background: "Surface", minimum: 4.5),
        Pair(foreground: "Ink", background: "Inset", minimum: 4.5),
        Pair(foreground: "InkMuted", background: "Canvas", minimum: 4.5),
        Pair(foreground: "InkMuted", background: "Surface", minimum: 4.5),
        Pair(foreground: "InkMuted", background: "Inset", minimum: 4.5),
        Pair(foreground: "AccentText", background: "Surface", minimum: 4.5),
        Pair(foreground: "AccentText", background: "Inset", minimum: 4.5),
        Pair(foreground: "AccentText", background: "AccentSoft", minimum: 4.5),
        Pair(foreground: "OnAccent", background: "AccentColor", minimum: 4.5),
        Pair(foreground: "StrikeText", background: "Surface", minimum: 4.5),
        Pair(foreground: "StrikeText", background: "Inset", minimum: 4.5),
        Pair(foreground: "StrikeText", background: "StrikeSoft", minimum: 4.5),
        Pair(foreground: "OnStrike", background: "Strike", minimum: 4.5),
        Pair(foreground: "CautionText", background: "Surface", minimum: 4.5),
        Pair(foreground: "CautionText", background: "CautionSoft", minimum: 4.5),
        Pair(foreground: "OnPinStanding", background: "PinStanding", minimum: 4.5),
        Pair(foreground: "PinStanding", background: "Surface", minimum: 3),
        Pair(foreground: "PinOutline", background: "Surface", minimum: 3),
        Pair(foreground: "PinOutline", background: "Inset", minimum: 3),
        Pair(foreground: "AccentColor", background: "Surface", minimum: 3),
        Pair(foreground: "Strike", background: "Surface", minimum: 3),
        Pair(foreground: "Caution", background: "Surface", minimum: 3),
    ]

    @Test(arguments: pairs, [UIUserInterfaceStyle.light, .dark])
    func colorPairMeetsContrast(pair: Pair, style: UIUserInterfaceStyle) throws {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let foreground = try #require(UIColor(named: pair.foreground, in: .main, compatibleWith: traits))
        let background = try #require(UIColor(named: pair.background, in: .main, compatibleWith: traits))
        let ratio = contrast(foreground.resolvedColor(with: traits), background.resolvedColor(with: traits))
        #expect(ratio >= pair.minimum, "\(pair.testDescription) is \(ratio)")
    }

    @Test func marksUseTheirColors() {
        #expect(Theme.color(for: Mark.strike) == .strikeText)
        #expect(Theme.color(for: Mark.foul) == .strikeText)
        #expect(Theme.color(for: Mark.spare) == .accentText)
        #expect(Theme.color(for: Mark.count(7)) == .ink)
        #expect(Theme.color(for: Mark.gutter) == .inkMuted)
    }

    @Test func splitsStandOutFromOtherLeaves() {
        #expect(Theme.color(for: LeaveKind.split) == .cautionText)
        for kind in [LeaveKind.strike, .singlePin, .makeable] {
            #expect(Theme.color(for: kind) == .ink)
        }
    }

    private func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}
