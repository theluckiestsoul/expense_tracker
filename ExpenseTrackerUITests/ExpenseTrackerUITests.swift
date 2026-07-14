import XCTest

final class ExpenseTrackerUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testPrimaryNavigationAndAddForm() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Transactions"].exists)
        XCTAssertTrue(app.tabBars.buttons["Reports"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        app.tabBars.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Add Transaction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["amountField"].exists)
        XCTAssertFalse(app.buttons["saveTransactionButton"].isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 5))
    }
}
