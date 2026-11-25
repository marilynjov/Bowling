import BowlingCore
import Foundation

/// The words for a Stats card: its title on Stats and its one-line description in Customize.
enum StatsCardText {
    static func title(_ card: StatsCardID) -> String {
        switch card {
        case .trendChart: String(localized: "Trend")
        case .leavesTable: String(localized: "Leaves")
        case .leftMostMadeLeast: String(localized: "Left most, made least")
        case .byFrameStrike: String(localized: "Strikes by frame")
        case .byFrameAverage: String(localized: "Average by frame")
        case .whatIfSinglePins: String(localized: "What if")
        default: StatTileContent.make(card, emptyReport)?.title ?? card.rawValue
        }
    }

    /// One plain sentence saying what the card's number is.
    static func description(_ card: StatsCardID) -> String {
        switch card {
        case .average: String(localized: "Your average score per game.")
        case .highGame: String(localized: "Your best single game.")
        case .highSeries: String(localized: "Your best three games in a row.")
        case .trendChart: String(localized: "Your average over time, session by session.")
        case .strikePct: String(localized: "How often you strike when you can.")
        case .sparePct: String(localized: "How often you make a spare when you can.")
        case .fouls: String(localized: "How many times you crossed the foul line.")
        case .openPct: String(localized: "How often a frame ends without a strike or spare.")
        case .cleanGamePct: String(localized: "How often a game has no open frames.")
        case .firstBallAverage: String(localized: "Pins you knock down on your first ball.")
        case .headPinRate: String(localized: "How often your first ball hits the head pin.")
        case .leavesTable: String(localized: "Every leave you have faced and how often you made it.")
        case .leftMostMadeLeast: String(localized: "The leave you left most often and made least.")
        case .splitConversion: String(localized: "How often you convert a split.")
        case .makeableConversion: String(localized: "How often you convert a spare you should make.")
        case .singlePinConversion: String(localized: "How often you convert a single-pin spare.")
        case .byFrameStrike: String(localized: "How often you strike in each frame.")
        case .byFrameAverage: String(localized: "Your average pins on the first ball in each frame.")
        case .whatIfSinglePins: String(localized: "Your average if you made every single-pin spare.")
        }
    }

    static func title(_ group: StatsCardGroup) -> String {
        switch group {
        case .overview: String(localized: "Overview")
        case .trend: String(localized: "Trend")
        case .strikesAndSpares: String(localized: "Strikes and spares")
        case .leaves: String(localized: "Leaves")
        case .byFrame: String(localized: "By frame")
        case .whatIf: String(localized: "What if")
        }
    }

    /// Titles don't depend on the numbers; this report only lets `StatTileContent` name a card.
    static let emptyReport = StatsEngine.report(games: [], filter: StatsFilter(bowlerID: BowlerID()))
}
