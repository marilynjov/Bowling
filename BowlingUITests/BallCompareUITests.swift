import XCTest

/// Compare sorts by every column (#31), run on an iPhone SE to be the done check: each
/// column shows through the Columns menu, its header sorts high to low, then low to high.
final class BallCompareUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSortsByEveryColumn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoStore"]
        app.launch()

        app.tabBars.buttons["Arsenal"].tap()
        let compare = app.navigationBars.buttons["Compare"]
        XCTAssertTrue(compare.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilHittable(compare))
        compare.tap()
        XCTAssertTrue(app.navigationBars["Compare"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(rows(app).count, 2, "The demo has fewer than two active balls")

        // Compact width starts on Average, Strike % and Spare %.
        for (title, hidden) in [("Games", true), ("Average", false), ("Strike %", false),
                                ("First ball", true), ("Spare %", false)] {
            if hidden { toggleColumn(title, in: app) }
            let header = self.header(title, in: app)
            XCTAssertTrue(waitUntilHittable(header), "\(title) header isn't on screen")

            header.tap()
            XCTAssertEqual(header.value as? String, "Sorted high to low", title)
            XCTAssertEqual(figures(title, in: app), figures(title, in: app).sorted(by: >), "\(title) high to low")

            header.tap()
            XCTAssertEqual(header.value as? String, "Sorted low to high", title)
            XCTAssertEqual(figures(title, in: app), figures(title, in: app).sorted(), "\(title) low to high")

            if hidden { toggleColumn(title, in: app) }
        }

        header("Ball", in: app).tap()
        let names = rows(app).map { String($0.split(separator: ",")[0]) }
        XCTAssertEqual(names, names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    /// The rows' labels, top to bottom: "Phaze II, 12 games, Average 196.5 over 10, ...".
    @MainActor
    private func rows(_ app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "label CONTAINS ' games, '")).allElementsBoundByIndex.map { $0.label }
    }

    /// Each row's figure for `title`, top to bottom; balls with none ("Strike % none") left
    /// out, since they go last both ways.
    @MainActor
    private func figures(_ title: String, in app: XCUIApplication) -> [Double] {
        rows(app).compactMap { label in
            let parts = label.components(separatedBy: ", ")
            let text: String?
            if title == "Games" {
                text = parts.first { $0.hasSuffix(" games") }?.replacingOccurrences(of: " games", with: "")
            } else {
                text = parts.first { $0.hasPrefix(title + " ") && $0.contains(" over ") }
                    .map { $0.dropFirst(title.count + 1).components(separatedBy: " over ")[0] }
            }
            return text.flatMap { Double($0.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: "")) }
        }
    }

    @MainActor
    private func toggleColumn(_ title: String, in app: XCUIApplication) {
        app.navigationBars.buttons["Columns"].tap()
        // The menu's toggle, not the column's header of the same name.
        let item = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != 'compare.header'", title)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No \(title) in the Columns menu")
        item.tap()
        // A menu toggle can leave the menu open; a tap on the title closes it.
        if item.exists, item.isHittable {
            app.navigationBars["Compare"].staticTexts["Compare"].tap()
        }
    }

    @MainActor
    private func header(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier == 'compare.header'", title)).firstMatch
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement) -> Bool {
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: element)
        return XCTWaiter().wait(for: [hittable], timeout: 5) == .completed
    }
}
