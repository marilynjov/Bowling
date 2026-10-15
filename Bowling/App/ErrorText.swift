import BowlingData
import Foundation

/// Plain text for the shared error alert.
enum ErrorText {
    static func message(for error: any Error) -> String {
        guard let error = error as? RepositoryError else { return error.localizedDescription }
        return switch error {
        case .notFound:
            String(localized: "That item no longer exists. It may have been deleted.")
        case .invalidGame:
            String(localized: "That roll doesn't fit this frame.")
        case .entryModeLocked:
            String(localized: "The entry mode can't change after the first roll. Clear the game's rolls first.")
        case let .bowlerHasGames(count):
            count == 1
                ? String(localized: "This bowler has 1 game. Delete it first.")
                : String(localized: "This bowler has \(count) games. Delete them first.")
        case .cannotDeleteOwner:
            String(localized: "You can't delete your own profile.")
        case .ownerAlreadyExists:
            String(localized: "Your profile already exists.")
        case .invalidBall(.emptyName):
            String(localized: "Give the ball a name.")
        case .invalidBall(.weightOutOfRange):
            String(localized: "Ball weight must be 6 to 16 pounds.")
        case .invalidBowler(.emptyName):
            String(localized: "Enter a name.")
        case .notFinalOnly:
            String(localized: "This game is scored from its rolls, so its score can't be typed.")
        }
    }
}
