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

#if DEBUG
private struct ThemePreview: View {
    private let swatches: [(String, ColorResource)] = [
        ("Canvas", .canvas), ("Surface", .surface), ("Inset", .inset), ("Hairline", .hairline),
        ("Ink", .ink), ("InkMuted", .inkMuted), ("AccentColor", .accent), ("AccentText", .accentText),
        ("AccentSoft", .accentSoft), ("OnAccent", .onAccent), ("Strike", .strike), ("StrikeText", .strikeText),
        ("StrikeSoft", .strikeSoft), ("OnStrike", .onStrike), ("Caution", .caution), ("CautionText", .cautionText),
        ("CautionSoft", .cautionSoft), ("PinStanding", .pinStanding), ("OnPinStanding", .onPinStanding),
        ("PinOutline", .pinOutline),
    ]
    private let marks: [Mark] = [.strike, .count(9), .spare, .foul, .count(7), .gutter]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Colors").monoLabel()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(swatches, id: \.0) { name, color in
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(color))
                                .stroke(.hairline)
                                .frame(height: 36)
                            Text(name).font(.figure).foregroundStyle(.inkMuted)
                        }
                    }
                }

                Text("Marks").monoLabel()
                HStack(spacing: 12) {
                    ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                        Text(symbol(mark)).font(.frameMark).foregroundStyle(Color(Theme.color(for: mark)))
                    }
                    Text("7-10").font(.frameMark).foregroundStyle(Color(Theme.color(for: LeaveKind.split)))
                }

                Text("Text styles").monoLabel()
                VStack(alignment: .leading, spacing: 6) {
                    Text("105").font(.scoreHero).foregroundStyle(.accentText)
                    Text("68.5%").font(.tileValue)
                    Text("Frame total 98").font(.frameTotal)
                    Text("87 / 127 chances").font(.figure).foregroundStyle(.inkMuted)
                    Text("10").font(.pinNumber)
                }

                Text("Buttons and pins").monoLabel()
                HStack(spacing: 8) {
                    Text("STRIKE").fontWeight(.heavy).foregroundStyle(.onStrike)
                        .frame(maxWidth: .infinity, minHeight: 54).background(.strike, in: .rect(cornerRadius: 12))
                    Text("/ SPARE").fontWeight(.heavy).foregroundStyle(.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 54).background(.accent, in: .rect(cornerRadius: 12))
                }
                HStack(spacing: 16) {
                    Text("6").font(.pinNumber).foregroundStyle(.onPinStanding)
                        .frame(width: 48, height: 48).background(.pinStanding, in: .circle)
                    Text("5").font(.pinNumber).foregroundStyle(.inkMuted)
                        .frame(width: 48, height: 48).overlay(Circle().stroke(.pinOutline, lineWidth: 1.5))
                }
            }
            .padding(16)
            .background(.surface, in: .rect(cornerRadius: 14))
            .padding(16)
        }
        .background(.canvas)
    }

    private func symbol(_ mark: Mark) -> String {
        switch mark {
        case .strike: "X"
        case .spare: "/"
        case .foul: "F"
        case .gutter: "-"
        case .count(let n): "\(n)"
        }
    }
}

#Preview("Theme, light") { ThemePreview().preferredColorScheme(.light) }
#Preview("Theme, dark") { ThemePreview().preferredColorScheme(.dark) }
#endif
