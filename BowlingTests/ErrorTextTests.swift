import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct ErrorTextTests {
    @Test(arguments: [
        (RepositoryError.notFound, "That item no longer exists. It may have been deleted."),
        (.invalidGame([]), "That roll doesn't fit this frame."),
        (.entryModeLocked, "The entry mode can't change after the first roll. Clear the game's rolls first."),
        (.cannotDeleteOwner, "You can't delete your own profile."),
        (.ownerAlreadyExists, "Your profile already exists."),
        (.invalidBall(.emptyName), "Give the ball a name."),
        (.invalidBall(.weightOutOfRange), "Ball weight must be 6 to 16 pounds."),
        (.invalidBowler(.emptyName), "Enter a name."),
        (.invalidMaintenance(.dateInFuture), "The maintenance date can't be in the future."),
        (.invalidMaintenance(.unknownKind), "Choose a maintenance type."),
        (.invalidPlace(.emptyName), "Enter a name."),
        (.notFinalOnly, "This game is scored from its rolls, so its score can't be typed."),
    ])
    func everyRepositoryErrorHasText(error: RepositoryError, text: String) {
        #expect(ErrorText.message(for: error) == text)
    }

    @Test func bowlerHasGamesPluralizes() {
        #expect(ErrorText.message(for: RepositoryError.bowlerHasGames(count: 1)) == "This bowler has 1 game. Delete it first.")
        #expect(ErrorText.message(for: RepositoryError.bowlerHasGames(count: 3)) == "This bowler has 3 games. Delete them first.")
    }

    @Test func otherErrorsUseTheirDescription() {
        struct Boom: LocalizedError {
            var errorDescription: String? { "Disk full" }
        }
        #expect(ErrorText.message(for: Boom()) == "Disk full")
    }
}
