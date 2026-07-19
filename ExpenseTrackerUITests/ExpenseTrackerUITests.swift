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

    func testCreateCustomExpenseCategory() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-customCategoriesJSON", "[]"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        app.buttons["customCategoriesLink"].tap()
        app.buttons["addCustomCategory_expense"].tap()
        let name = app.textFields["customCategoryName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Pets")
        app.buttons["saveCustomCategory"].tap()
        XCTAssertTrue(app.staticTexts["Pets"].waitForExistence(timeout: 5))
    }

    func testCreateRecurringTransaction() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-recurringTransactionsJSON", "[]"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        app.buttons["recurringTransactionsLink"].tap()
        app.buttons["addRecurringTransaction"].tap()
        let name = app.textFields["recurringName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Monthly Rent")
        let amount = app.textFields["recurringAmount"]
        amount.tap(); amount.typeText("1000")
        app.buttons["saveRecurringTransaction"].tap()
        XCTAssertTrue(app.staticTexts["Monthly Rent"].waitForExistence(timeout: 5))
    }

    func testMonthlyBudgetKeyboardCanBeDismissed() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        let budget = app.textFields["monthlyBudgetField"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5))
        budget.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 3))
        app.buttons["dismissBudgetKeyboard"].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 3))
    }

    func testBillReminderSettingIsAvailable() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["billRemindersToggle"].waitForExistence(timeout: 5))
    }

    func testCreateFinancialAccount() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-financialAccountsJSON", "[]"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        app.buttons["accountsLink"].tap()
        app.buttons["addAccount"].tap()
        let name = app.textFields["accountName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Savings")
        app.buttons["saveAccount"].tap()
        XCTAssertTrue(app.staticTexts["Savings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["transferMoney"].exists)
    }

    func testCreateCategoryBudgetAndOpenTransactionFilters() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-categoryBudgetsJSON", "[]"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        app.buttons["categoryBudgetsLink"].tap()
        let foodBudget = app.buttons["categoryBudget_Food & Dining"]
        XCTAssertTrue(foodBudget.waitForExistence(timeout: 5))
        foodBudget.tap()
        let amount = app.textFields["categoryBudgetAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.typeText("500")
        app.buttons["saveCategoryBudget"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '500'")).element.waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactionFiltersButton"].tap()
        XCTAssertTrue(app.navigationBars["Filter Transactions"].waitForExistence(timeout: 5))
        app.buttons["applyTransactionFilters"].tap()
    }

    func testReportPeriodAndCashFlowEmptyState() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Reports"].tap()
        XCTAssertTrue(app.segmentedControls["reportPeriodPicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cash Flow"].exists)
        XCTAssertTrue(app.staticTexts["Savings Rate"].exists)
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
