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

    func testDeviceLanguageSelectsSupportedLocalization() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Resumen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Transacciones"].exists)
        XCTAssertTrue(app.buttons["Informes"].exists)
        XCTAssertTrue(app.buttons["Ajustes"].exists)
    }

    func testPersianLocalization() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(fa)", "-AppleLocale", "fa_IR"]
        app.launch()

        XCTAssertTrue(app.navigationBars["داشبورد"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["معاملات"].exists)
        XCTAssertTrue(app.buttons["گزارش ها"].exists)
        XCTAssertTrue(app.buttons["تنظیمات"].exists)
    }

    func testBengaliLocalization() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(bn)", "-AppleLocale", "bn_IN"]
        app.launch()

        XCTAssertTrue(app.navigationBars["ড্যাশবোর্ড"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["লেনদেন"].exists)
        XCTAssertTrue(app.buttons["রিপোর্ট"].exists)
        XCTAssertTrue(app.buttons["সেটিংস"].exists)
    }

    func testOdiaLocalization() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(or)", "-AppleLocale", "or_IN"]
        app.launch()

        XCTAssertTrue(app.navigationBars["ଡ୍ୟାସବୋର୍ଡ"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["କାରବାର"].exists)
        XCTAssertTrue(app.buttons["ରିପୋର୍ଟ"].exists)
        XCTAssertTrue(app.buttons["ସେଟିଂସ୍"].exists)
    }
}
