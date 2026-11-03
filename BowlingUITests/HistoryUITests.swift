import XCTest

/// Opens a saved game through History's list, session and game screens (#134): each one
/// loads in a `.task` that never ran while its body was still empty.
final class HistoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testQuickScoreOpensThroughHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["Quick score"].tap()
        // The sheet's only field; its "Score" title isn't exposed as a label.
        let score = app.textFields.firstMatch
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        score.tap()
        score.typeText("187")
        app.buttons["Save"].tap()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5), "History has no title")
        let session = app.buttons.matching(NSPredicate(format: "label CONTAINS '187'")).firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 5), "History lists no session")
        session.tap()

        let game = app.buttons["Game 1, 187"]
        XCTAssertTrue(game.waitForExistence(timeout: 5), "Session detail shows no game")
        // A tap while the session screen is still sliding in is dropped.
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: game)
        wait(for: [hittable], timeout: 5)
        game.tap()

        XCTAssertTrue(app.buttons["Delete game"].waitForExistence(timeout: 5), "Game detail is blank")
    }
}
