import XCTest

/// Plays one pin-by-pin game through the real controls and checks the summary's score.
/// `UITestGameTests` enters the same game through the model. "Tap standing": the pins
/// tapped are the ones left standing.
///
/// | Frame | 1 | 2   | 3   | 4  | 5  | 6   | 7   | 8   | 9   | 10    |
/// | Rolls | X | 7 / | 9 - | X  | X  | 8 / | 9 / | X   | 7 2 | X X X |
/// | Total | 20| 39  | 48  | 76 | 96 | 115 | 135 | 154 | 163 | 193   |
final class PinByPinGameUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFullGameShowsTheFinalScore() throws {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let flow = GameFlow(app: app)

        flow.startSession()

        flow.tap("scoring.strike")                              // 1
        flow.pins(4, 7, 10); flow.tap("scoring.spare")          // 2
        flow.pins(10); flow.tap("scoring.miss")                 // 3
        flow.tap("scoring.strike")                              // 4
        flow.tap("scoring.strike")                              // 5
        flow.pins(7, 10); flow.tap("scoring.spare")             // 6
        flow.pins(10); flow.tap("scoring.spare")                // 7
        flow.tap("scoring.strike")                              // 8
        flow.pins(4, 7, 10); flow.pins(10)                      // 9
        flow.tap("scoring.strike"); flow.tap("scoring.strike"); flow.tap("scoring.strike") // 10

        let score = app.staticTexts["summary.score"]
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        XCTAssertEqual(score.label, "193")
    }
}
