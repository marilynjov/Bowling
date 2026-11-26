import XCTest

/// The done criterion for Customize (#36): a changed layout survives a relaunch, and Reset to
/// preset brings the preset back. Runs against the on-disk store (`-persistentStore`), so it
/// resets first. It ends with the bowling style it found and both layouts on their preset; a
/// layout customized before the run is not preserved.
@MainActor
final class CustomizeUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-uiTesting", "-persistentStore"]
    }

    // MARK: Helpers

    /// A StatTile (Home) or Stats card, which VoiceOver reads as "Title, value, sample".
    private func card(_ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
    }

    /// Scrolls the screen from top to bottom looking for the card.
    private func isShowing(_ title: String) -> Bool {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<6 { scroll.swipeDown() }
        for _ in 0..<8 {
            if card(title).exists { return true }
            scroll.swipeUp()
        }
        return card(title).exists
    }

    private func waitForHome() {
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 15), "Home has no Edit button")
    }

    private func openSheet(_ opener: XCUIElement, title: String) {
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "No button opens \(title)")
        opener.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), "\(title) did not open")
    }

    private func tapAdd(_ title: String) {
        let add = app.buttons["Add \(title)"]
        for _ in 0..<10 where !add.exists { app.swipeUp() }
        XCTAssertTrue(add.exists, "No Add \(title) row")
        add.tap()
    }

    private func remove(_ title: String) {
        let row = app.cells.containing(.staticText, identifier: title).firstMatch
        for _ in 0..<5 where !row.exists { app.swipeDown() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No row for \(title)")
        // The red minus is an unlabelled image in edit mode; tapping it reveals Delete.
        row.images["remove"].firstMatch.tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No Delete button for \(title)")
        confirm.tap()
    }

    /// Reset to preset, confirmed. The button is disabled when the layout already is the preset.
    private func resetToPreset() {
        let reset = app.buttons["Reset to preset"]
        for _ in 0..<12 where !reset.exists { app.swipeUp() }
        XCTAssertTrue(reset.exists, "No Reset to preset button")
        reset.tap()
        // The dialog's destructive action shares the title; it is the last match.
        let confirm = app.buttons.matching(identifier: "Reset to preset").element(boundBy: 1)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No reset confirmation")
        confirm.tap()
    }

    /// On an open Customize sheet: Reset to preset if it is enabled, otherwise Cancel. Never
    /// asserts, so teardown can use it. Leaves the sheet closed.
    private func resetIfCustomized() {
        let reset = app.buttons["Reset to preset"]
        for _ in 0..<12 where !reset.exists { app.swipeUp() }
        if reset.exists, reset.isEnabled {
            reset.tap()
            let confirm = app.buttons.matching(identifier: "Reset to preset").element(boundBy: 1)
            if confirm.waitForExistence(timeout: 5) { confirm.tap() }
        }
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    }

    /// Clears a previous run: reset if the layout is customized, then close the sheet.
    private func clearPreviousRun(open: () -> Void) {
        open()
        resetIfCustomized()
    }

    /// "Keep my layout" is the dialog's cancel action. Where the dialog is a popover (anchored to
    /// the picker) iOS leaves the cancel button out and tapping outside dismisses it instead.
    private func keepMyLayout() {
        let keep = app.buttons["Keep my layout"]
        if keep.exists {
            keep.tap()
        } else {
            let dismiss = app.otherElements["PopoverDismissRegion"]
            XCTAssertTrue(dismiss.waitForExistence(timeout: 5), "No way to dismiss the style prompt")
            dismiss.tap()
        }
        XCTAssertTrue(app.staticTexts["Use the stats for your new bowling style?"].waitForNonExistence(timeout: 5))
    }

    // MARK: Settings

    private var styleButton: XCUIElement {
        // The picker's label carries its current choice: "Bowling style, League".
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Bowling style'")).firstMatch
    }

    private func openSettings() {
        app.buttons["Settings"].tap()
        XCTAssertTrue(styleButton.waitForExistence(timeout: 10), "Settings has no Bowling style")
    }

    private func closeSettings() {
        app.navigationBars.buttons.firstMatch.tap()
        waitForHome()
    }

    private func currentStyle() -> String {
        styleButton.label.replacingOccurrences(of: "Bowling style, ", with: "")
    }

    /// Picks a style; a customized layout asks what to do, and this keeps it.
    private func chooseStyle(_ name: String) {
        styleButton.tap()
        app.buttons[name].tap()
        if app.staticTexts["Use the stats for your new bowling style?"].waitForExistence(timeout: 5) {
            keepMyLayout()
        }
    }

    // MARK: Test

    func testLayoutSurvivesRelaunchAndReset() throws {
        app.launch()
        waitForHome()
        // The store outlives runs, so pin the style the presets below assume (League) and
        // put it back at the end.
        openSettings()
        let original = currentStyle()
        chooseStyle("League")
        closeSettings()
        // Leave the store as found even if an assertion stops the run.
        addTeardownBlock { [self] in
            // Keep going after a failure so the style is still restored.
            continueAfterFailure = true
            app.terminate()
            app.launch()
            guard app.buttons["Edit"].waitForExistence(timeout: 15) else {
                return XCTFail("Teardown: Home did not load; style \(original) not restored")
            }
            app.buttons["Edit"].tap()
            resetIfCustomized()
            app.tabBars.buttons["Stats"].tap()
            guard app.buttons["Customize"].waitForExistence(timeout: 10) else {
                return XCTFail("Teardown: Stats did not load; style \(original) not restored")
            }
            app.buttons["Customize"].tap()
            resetIfCustomized()
            app.tabBars.buttons["Home"].tap()
            guard app.buttons["Settings"].waitForExistence(timeout: 10) else {
                return XCTFail("Teardown: no Settings button; style \(original) not restored")
            }
            openSettings()
            chooseStyle(original)
            XCTAssertEqual(currentStyle(), original, "Teardown: style not restored")
        }

        try homeFlow()
        try settingsPrompt()
        try statsFlow()

        app.tabBars.buttons["Home"].tap()
        openSettings()
        chooseStyle(original)
    }

    private func homeFlow() throws {
        let edit = app.buttons["Edit"]
        clearPreviousRun { edit.tap() }
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        XCTAssertTrue(isShowing("Average"), "Preset Home lacks Average")

        // Cancel throws the draft away.
        openSheet(edit, title: "Customize Home")
        tapAdd("Fouls")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        XCTAssertFalse(isShowing("Fouls"), "Cancel kept Fouls")

        // Save keeps the change.
        openSheet(edit, title: "Customize Home")
        tapAdd("Fouls")
        remove("Average")
        app.buttons["Save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        XCTAssertTrue(isShowing("Fouls"), "Home lacks Fouls after Save")
        XCTAssertFalse(isShowing("Average"), "Home still shows Average after Save")

        // And so does a relaunch.
        app.terminate()
        app.launch()
        waitForHome()
        XCTAssertTrue(isShowing("Fouls"), "Home lacks Fouls after relaunch")
        XCTAssertFalse(isShowing("Average"), "Home shows Average after relaunch")
    }

    /// A customized layout survives a change of bowling style when the player keeps it.
    private func settingsPrompt() throws {
        openSettings()
        let prompt = app.staticTexts["Use the stats for your new bowling style?"]
        styleButton.tap()
        app.buttons["Competitive"].tap()
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), "No prompt after changing style")
        keepMyLayout()
        XCTAssertEqual(currentStyle(), "Competitive")

        // Back to League, keeping the layout again.
        chooseStyle("League")
        XCTAssertEqual(currentStyle(), "League")

        closeSettings()
        XCTAssertTrue(isShowing("Fouls"), "Keep my layout lost the customized Home")
        XCTAssertFalse(isShowing("Average"), "Keep my layout brought Average back")

        // Reset to preset, confirmed.
        openSheet(app.buttons["Edit"], title: "Customize Home")
        resetToPreset()
        waitForHome()
        XCTAssertTrue(isShowing("Average"), "Average is not back after Reset")
        XCTAssertFalse(isShowing("Fouls"), "Fouls is still there after Reset")
        app.terminate()
        app.launch()
        waitForHome()
        XCTAssertTrue(isShowing("Average"), "Preset did not survive a relaunch")
    }

    // MARK: Stats

    private func statsFlow() throws {
        app.tabBars.buttons["Stats"].tap()
        let customize = app.buttons["Customize"]
        clearPreviousRun { openSheet(customize, title: "Customize Stats") }
        XCTAssertTrue(customize.waitForExistence(timeout: 10))
        XCTAssertTrue(isShowing("Average"), "Preset Stats lacks Average")
        XCTAssertFalse(isShowing("Fouls"), "Preset Stats already shows Fouls")

        openSheet(customize, title: "Customize Stats")
        tapAdd("Fouls")
        remove("Average")
        app.buttons["Save"].tap()
        XCTAssertTrue(customize.waitForExistence(timeout: 10))
        XCTAssertTrue(isShowing("Fouls"), "Stats lacks Fouls after Save")
        XCTAssertFalse(isShowing("Average"), "Stats still shows Average after Save")

        app.terminate()
        app.launch()
        waitForHome()
        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(isShowing("Fouls"), "Stats lacks Fouls after relaunch")
        XCTAssertFalse(isShowing("Average"), "Stats shows Average after relaunch")

        openSheet(customize, title: "Customize Stats")
        resetToPreset()
        XCTAssertTrue(customize.waitForExistence(timeout: 10))
        XCTAssertTrue(isShowing("Average"), "Average is not back on Stats after Reset")
        XCTAssertFalse(isShowing("Fouls"), "Fouls is still on Stats after Reset")
    }
}
