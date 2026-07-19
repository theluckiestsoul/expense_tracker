import XCTest

final class ExpenseTrackerUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func configuredApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        return app
    }

    func testFirstLaunchOnboardingSupportsNextPreviousAndFinish() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-hasCompletedOnboarding", "NO"]
        app.launch()

        XCTAssertTrue(app.otherElements["onboardingPage_0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboardingPrevious"].isEnabled)
        app.buttons["onboardingNext"].tap()
        XCTAssertTrue(app.otherElements["onboardingPage_1"].waitForExistence(timeout: 5))
        app.buttons["onboardingPrevious"].tap()
        XCTAssertTrue(app.otherElements["onboardingPage_0"].waitForExistence(timeout: 5))
        for _ in 0..<5 { app.buttons["onboardingNext"].tap() }
        XCTAssertTrue(app.buttons["finishOnboarding"].waitForExistence(timeout: 5))
        app.buttons["finishOnboarding"].tap()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 10))
    }

    func testPrimaryNavigationAndAddForm() {
        let app = configuredApp()
        app.launch()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Transactions"].exists)
        XCTAssertTrue(app.tabBars.buttons["Reports"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        app.tabBars.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Add Transaction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["amountField"].exists)
        XCTAssertTrue(app.buttons["scanReceipt"].exists)
        XCTAssertFalse(app.buttons["saveTransactionButton"].isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 5))
    }

    func testDeviceLanguageSelectsSupportedLocalization() {
        let app = configuredApp()
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Resumen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Transacciones"].exists)
        XCTAssertTrue(app.buttons["Informes"].exists)
        XCTAssertTrue(app.buttons["Ajustes"].exists)
    }

    func testCreateCustomExpenseCategory() {
        let app = configuredApp()
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
        let app = configuredApp()
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
        let app = configuredApp()
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
        let app = configuredApp()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        let reminders = app.switches["billRemindersToggle"]
        if !reminders.exists { app.swipeUp() }
        XCTAssertTrue(reminders.waitForExistence(timeout: 5))
        let exportBackup = app.buttons["exportCompleteBackup"]
        if !exportBackup.exists { app.swipeUp() }
        XCTAssertTrue(exportBackup.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["restoreCompleteBackup"].exists)
    }

    func testCreateFinancialAccount() {
        let app = configuredApp()
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

    func testCreateSavingsGoal() {
        let app = configuredApp()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-savingsGoalsJSON", "[]"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        app.buttons["savingsGoalsLink"].tap()
        app.buttons["addSavingsGoal"].tap()
        let name = app.textFields["savingsGoalName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Emergency Fund")
        let target = app.textFields["savingsGoalTarget"]
        target.tap(); target.typeText("10000")
        app.buttons["saveSavingsGoal"].tap()
        XCTAssertTrue(app.staticTexts["Emergency Fund"].waitForExistence(timeout: 5))
    }

    func testCreateCategoryBudgetAndOpenTransactionFilters() {
        let app = configuredApp()
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
        let app = configuredApp()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Reports"].tap()
        XCTAssertTrue(app.segmentedControls["reportPeriodPicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cash Flow"].exists)
        XCTAssertTrue(app.staticTexts["Savings Rate"].exists)
        XCTAssertTrue(app.staticTexts["Compared with Previous Month"].exists)
    }

    func testPersianLocalization() {
        let app = configuredApp()
        app.launchArguments += ["-AppleLanguages", "(fa)", "-AppleLocale", "fa_IR"]
        app.launch()

        XCTAssertTrue(app.navigationBars["داشبورد"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["معاملات"].exists)
        XCTAssertTrue(app.buttons["گزارش ها"].exists)
        XCTAssertTrue(app.buttons["تنظیمات"].exists)
    }

    func testBengaliLocalization() {
        let app = configuredApp()
        app.launchArguments += ["-AppleLanguages", "(bn)", "-AppleLocale", "bn_IN"]
        app.launch()

        XCTAssertTrue(app.navigationBars["ড্যাশবোর্ড"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["লেনদেন"].exists)
        XCTAssertTrue(app.buttons["রিপোর্ট"].exists)
        XCTAssertTrue(app.buttons["সেটিংস"].exists)
    }

    func testOdiaLocalization() {
        let app = configuredApp()
        app.launchArguments += ["-AppleLanguages", "(or)", "-AppleLocale", "or_IN"]
        app.launch()

        XCTAssertTrue(app.navigationBars["ଡ୍ୟାସବୋର୍ଡ"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["କାରବାର"].exists)
        XCTAssertTrue(app.buttons["ରିପୋର୍ଟ"].exists)
        XCTAssertTrue(app.buttons["ସେଟିଂସ୍"].exists)
    }
}
