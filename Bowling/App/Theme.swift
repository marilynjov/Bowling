import BowlingCore
import DeveloperToolsSupport
import SwiftUI

/// The D1 Teal & Crimson style from #72. Colors live in the asset catalog with light and
/// dark variants and are used through their generated symbols (`.surface`, `.strikeText`,
/// ...); this file adds what the catalog can't say: which color each mark gets, and the
/// text styles. See docs/superpowers/specs/2026-10-14-visual-style-design.md.
enum Theme {
    static func color(for mark: Mark) -> ColorResource {
        switch mark {
        case .strike, .foul: .strikeText
        case .spare: .accentText
        case .count: .ink
        case .gutter: .inkMuted
        }
    }

    static func color(for leave: LeaveKind) -> ColorResource {
        leave == .split ? .cautionText : .ink
    }
}

extension Font {
    /// The game score on Scoring and hero numbers such as the average card.
    static let scoreHero = Font.system(.largeTitle, weight: .heavy)
    /// A stat tile's value.
    static let tileValue = Font.system(.title, weight: .heavy)
    /// X, /, F, and counts in a scorecard frame.
    static let frameMark = Font.system(.body, design: .monospaced, weight: .bold)
    /// A frame's running total.
    static let frameTotal = Font.system(.subheadline, design: .monospaced, weight: .bold)
    /// Sample sizes and other small figures ("24 games", "87 / 127 chances").
    static let figure = Font.system(.caption, design: .monospaced)
    /// The number on a pin.
    static let pinNumber = Font.system(.headline, weight: .bold)
}

extension View {
    /// Uppercase monospaced card label, such as "SCORECARD" or "TOTAL LEFT".
    func monoLabel() -> some View {
        font(.system(.caption, design: .monospaced, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.inkMuted)
    }
}
