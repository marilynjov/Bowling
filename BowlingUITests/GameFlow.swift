import XCTest

/// The taps a UI test uses to play a game, shared by `PinByPinGameUITests` and
/// `AccessibilityAuditUITests` so both enter balls the same way. "Tap standing": the pins
/// tapped are the ones left standing.
@MainActor
struct GameFlow {
    let app: XCUIApplication

    /// Home › Start session › Start, then waits for Scoring.
    func startSession() {
        tap("home.startSession", wait: true)
        tap("newSession.start", wait: true)
        XCTAssertTrue(app.buttons["scoring.next"].waitForExistence(timeout: 5))
    }

    /// Marks `standing` as the pins left, then records the ball with Next.
    func pins(_ standing: Int...) {
        for pin in standing { tap("pin.\(pin)") }
        tap("scoring.next")
    }

    func tap(_ identifier: String, wait: Bool = false) {
        let button = app.buttons[identifier]
        if wait { XCTAssertTrue(button.waitForExistence(timeout: 5), "\(identifier) not found") }
        button.tap()
    }
}
