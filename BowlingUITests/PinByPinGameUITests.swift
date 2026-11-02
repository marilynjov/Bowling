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

        tap("home.startSession", wait: true)
        tap("newSession.start", wait: true)
        XCTAssertTrue(app.buttons["scoring.next"].waitForExistence(timeout: 5))

        tap("scoring.strike")                                  // 1
        pins(4, 7, 10); tap("scoring.spare")                   // 2
        pins(10); tap("scoring.miss")                          // 3
        tap("scoring.strike")                                  // 4
        tap("scoring.strike")                                  // 5
        pins(7, 10); tap("scoring.spare")                      // 6
        pins(10); tap("scoring.spare")                         // 7
        tap("scoring.strike")                                  // 8
        pins(4, 7, 10); pins(10)                               // 9
        tap("scoring.strike"); tap("scoring.strike"); tap("scoring.strike") // 10

        let score = app.staticTexts["summary.score"]
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        XCTAssertEqual(score.label, "193")
    }

    /// Marks `standing` as the pins left, then records the ball with Next.
    @MainActor
    private func pins(_ standing: Int...) {
        for pin in standing { tap("pin.\(pin)") }
        tap("scoring.next")
    }

    @MainActor
    private func tap(_ identifier: String, wait: Bool = false) {
        let button = app.buttons[identifier]
        if wait { XCTAssertTrue(button.waitForExistence(timeout: 5), "\(identifier) not found") }
        button.tap()
    }
}
