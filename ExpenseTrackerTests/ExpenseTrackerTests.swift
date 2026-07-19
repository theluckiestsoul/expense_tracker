import XCTest
import SwiftData
@testable import ExpenseTracker

final class ExpenseTrackerTests: XCTestCase {
    func testCompleteBackupRoundTripsAndRejectsInvalidData() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transaction = Transaction(amount: 25, type: .expense, category: .food, paymentMethod: .card,
                                      currencyCode: "USD", transactionDate: fixedDate, merchant: "Cafe")
        transaction.createdAt = fixedDate; transaction.updatedAt = fixedDate
        let backup = LedgerLeafBackup(formatVersion: 1, exportedAt: fixedDate,
            preferences: .init(currencyCode: "USD", monthlyBudget: 2_000, languageCode: "en"),
            transactions: [.init(transaction, fallbackCurrency: "USD")], customCategories: [],
            accounts: [FinancialAccount(name: "Cash", type: .cash, currencyCode: "USD")],
            categoryBudgets: [], savingsGoals: [], recurringTransactions: [])
        XCTAssertEqual(try LedgerLeafBackup.decoded(from: backup.encoded()), backup)

        var invalid = backup
        invalid.transactions.append(invalid.transactions[0])
        XCTAssertThrowsError(try LedgerLeafBackup.decoded(from: invalid.encoded())) {
            XCTAssertEqual($0 as? LedgerLeafBackup.BackupError, .invalidData)
        }
        invalid = backup; invalid.formatVersion = 99
        XCTAssertThrowsError(try LedgerLeafBackup.decoded(from: invalid.encoded())) {
            XCTAssertEqual($0 as? LedgerLeafBackup.BackupError, .unsupportedVersion)
        }
    }

    func testTransactionDuplicationCopiesDetailsButNotIdentityOrTransferState() {
        let original = Transaction(amount: 18.5, type: .expense, category: .food, paymentMethod: .card,
                                   currencyCode: "EUR", transactionDate: .distantPast, merchant: "Cafe", notes: "Lunch")
        original.accountID = "wallet"
        let copyDate = Date(timeIntervalSince1970: 1_700_000_000)
        let copy = original.duplicated(date: copyDate)

        XCTAssertNotNil(copy)
        XCTAssertNotEqual(copy?.id, original.id)
        XCTAssertEqual(copy?.amount, original.amount)
        XCTAssertEqual(copy?.categoryRaw, original.categoryRaw)
        XCTAssertEqual(copy?.accountID, original.accountID)
        XCTAssertEqual(copy?.transactionDate, copyDate)
        XCTAssertNil(copy?.transferID)

        original.transferID = UUID()
        XCTAssertNil(original.duplicated())
    }

    func testSavingsGoalsRoundTripAndCalculateProgress() {
        let goal = SavingsGoal(id: UUID(), name: "Emergency Fund", targetAmount: 10_000, savedAmount: 2_500, currencyCode: "USD", targetDate: nil)
        let restored = SavingsGoalStore.decode(SavingsGoalStore.encode([goal]))
        XCTAssertEqual(restored, [goal])
        XCTAssertEqual(restored[0].progress, 0.25)
        XCTAssertEqual(restored[0].remaining, 7_500)

        let complete = SavingsGoal(id: UUID(), name: "Trip", targetAmount: 1_000, savedAmount: 1_200, currencyCode: "EUR", targetDate: nil)
        XCTAssertEqual(complete.progress, 1)
        XCTAssertEqual(complete.remaining, 0)
    }

    func testAmountParsingAndCSVEncoding() {
        XCTAssertEqual(DomainLogic.parseAmount("42.50", decimalSeparator: "."), 42.5)
        XCTAssertEqual(DomainLogic.parseAmount("42,50", decimalSeparator: ","), 42.5)
        XCTAssertNil(DomainLogic.parseAmount("-1", decimalSeparator: "."))
        XCTAssertEqual(DomainLogic.csv(rows: [["a,b", "c\"d"]]), "\"a,b\",\"c\"\"d\"")
        XCTAssertEqual(DomainLogic.transactionCSVHeaders.last, "Date Added")
        XCTAssertFalse(DomainLogic.transactionCSVHeaders.contains("id"))
        XCTAssertFalse(DomainLogic.transactionCSVHeaders.contains("updatedAt"))
    }

    func testCSVBackupCanBeRestored() throws {
        let transactionDate = Date(timeIntervalSince1970: 1_700_000_000)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_100)
        let row = [
            "42.5", "EUR", "expense", "Food & Dining", "Card",
            transactionDate.ISO8601Format(), "Cafe, Central", "He said \"hello\"",
            "fork.knife", "indigo",
            "",
            createdAt.ISO8601Format()
        ]
        let backup = DomainLogic.csv(rows: [DomainLogic.transactionCSVHeaders, row])
        let restored = try CSVBackup.importTransactions(from: backup)

        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].amount, 42.5)
        XCTAssertEqual(restored[0].currencyCode, "EUR")
        XCTAssertEqual(restored[0].categoryRaw, ExpenseCategory.food.rawValue)
        XCTAssertEqual(restored[0].merchant, "Cafe, Central")
        XCTAssertEqual(restored[0].notes, "He said \"hello\"")
    }

    func testCustomCategoryRoundTripsThroughCSV() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let row = ["10.0", "USD", "expense", "Pets", "Cash", date.ISO8601Format(), "", "",
                   "pawprint.fill", "orange", "", date.ISO8601Format()]
        let restored = try CSVBackup.importTransactions(from: DomainLogic.csv(rows: [DomainLogic.transactionCSVHeaders, row]))

        XCTAssertTrue(restored.first?.categoryRaw.hasPrefix("custom:import:") == true)
        XCTAssertEqual(restored.first?.customCategory?.name, "Pets")
        XCTAssertEqual(restored.first?.customCategory?.symbol, "pawprint.fill")
    }

    func testLegacyCSVBackupStillImports() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let row = ["10.0", "USD", "income", "Salary", "Bank Transfer", date.ISO8601Format(), "Employer", "", date.ISO8601Format()]
        let restored = try CSVBackup.importTransactions(from: DomainLogic.csv(rows: [DomainLogic.legacyTransactionCSVHeaders, row]))
        XCTAssertEqual(restored.first?.categoryRaw, ExpenseCategory.salary.rawValue)
    }

    func testPreviousCSVBackupStillImportsAndTransferIDRoundTrips() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let previousRow = ["10.0", "USD", "expense", "Food & Dining", "Cash", date.ISO8601Format(), "Cafe", "",
                           "fork.knife", "indigo", date.ISO8601Format()]
        let previous = try CSVBackup.importTransactions(from: DomainLogic.csv(rows: [DomainLogic.previousTransactionCSVHeaders, previousRow]))
        XCTAssertNil(previous.first?.transferID)

        let transferID = UUID()
        let currentRow = ["10.0", "USD", "expense", "Other Expense", "Bank Transfer", date.ISO8601Format(), "Transfer", "",
                          "ellipsis.circle.fill", "gray", transferID.uuidString, date.ISO8601Format()]
        let current = try CSVBackup.importTransactions(from: DomainLogic.csv(rows: [DomainLogic.transactionCSVHeaders, currentRow]))
        XCTAssertEqual(current.first?.transferID, transferID)
    }

    func testCSVRestoreRejectsUnknownAndMalformedFiles() {
        XCTAssertThrowsError(try CSVBackup.importTransactions(from: "\"Not\",\"LedgerLeaf\"")) {
            XCTAssertEqual($0 as? DomainLogic.CSVError, .invalidHeaders)
        }
        XCTAssertThrowsError(try DomainLogic.parseCSV("\"unfinished")) {
            XCTAssertEqual($0 as? DomainLogic.CSVError, .malformed)
        }
    }

    func testCategorySetsNeverOverlap() {
        XCTAssertTrue(Set(ExpenseCategory.expenseCases).isDisjoint(with: Set(ExpenseCategory.incomeCases)))
        XCTAssertTrue(ExpenseCategory.expenseCases.allSatisfy { !$0.isIncome })
        XCTAssertTrue(ExpenseCategory.incomeCases.allSatisfy(\.isIncome))
    }

    func testCategoryBudgetsRoundTripAndRemainCurrencySpecific() {
        let source = [
            CategoryBudget(categoryID: ExpenseCategory.food.rawValue, currencyCode: "USD", amount: 500),
            CategoryBudget(categoryID: ExpenseCategory.food.rawValue, currencyCode: "INR", amount: 10_000)
        ]
        let restored = CategoryBudgetStore.decode(CategoryBudgetStore.encode(source))

        XCTAssertEqual(Set(restored), Set(source))
        XCTAssertEqual(CategoryBudgetStore.budget(for: ExpenseCategory.food.rawValue, currencyCode: "USD", in: restored)?.amount, 500)
        XCTAssertEqual(CategoryBudgetStore.budget(for: ExpenseCategory.food.rawValue, currencyCode: "INR", in: restored)?.amount, 10_000)
        XCTAssertNil(CategoryBudgetStore.budget(for: ExpenseCategory.food.rawValue, currencyCode: "EUR", in: restored))
    }

    func testReportCashFlowAndSavingsRate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let january10 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let january11 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 11))!
        let february1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let income = Transaction(amount: 1_000, type: .income, category: .salary, paymentMethod: .bank, currencyCode: "USD", transactionDate: january10, merchant: "Employer")
        let food = Transaction(amount: 200, type: .expense, category: .food, paymentMethod: .card, currencyCode: "USD", transactionDate: january10, merchant: "Market")
        let travel = Transaction(amount: 100, type: .expense, category: .travel, paymentMethod: .cash, currencyCode: "USD", transactionDate: january11, merchant: "Metro")

        let daily = ReportCalculator.cashFlow(transactions: [income, food, travel], period: .month, now: january11, calendar: calendar)
        XCTAssertEqual(daily.count, 3)
        XCTAssertEqual(daily.first { $0.date == january10 && $0.type == .income }?.amount, 1_000)
        XCTAssertEqual(daily.first { $0.date == january10 && $0.type == .expense }?.amount, 200)
        XCTAssertEqual(ReportCalculator.savingsRate(income: 1_000, expenses: 300), 0.7)
        XCTAssertNil(ReportCalculator.savingsRate(income: 0, expenses: 300))
        XCTAssertFalse(ReportPeriod.month.includes(february1, now: january11, calendar: calendar))
    }

    func testBillRemindersIncludeOnlyFutureActiveExpenses() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 8))!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 12))!
        let expense = RecurringTransaction(name: "Rent", amount: 900, type: .expense, categoryRaw: ExpenseCategory.bills.rawValue, paymentMethod: .bank, currencyCode: "USD", merchant: "Landlord", notes: "", frequency: .monthly, nextDate: dueDate)
        let income = RecurringTransaction(name: "Salary", amount: 2_000, type: .income, categoryRaw: ExpenseCategory.salary.rawValue, paymentMethod: .bank, currencyCode: "USD", merchant: "Employer", notes: "", frequency: .monthly, nextDate: dueDate)
        var paused = expense
        paused.id = UUID(); paused.name = "Paused Bill"; paused.isActive = false

        let plans = BillReminderPlanner.plans(for: [expense, income, paused], now: now, calendar: calendar)
        XCTAssertEqual(plans.count, 1)
        XCTAssertTrue(plans[0].identifier.hasPrefix(BillReminderPlanner.identifierPrefix))
        XCTAssertTrue(plans[0].body.contains("Rent"))
        XCTAssertEqual(calendar.component(.day, from: plans[0].fireDate), 11)
        XCTAssertEqual(calendar.component(.hour, from: plans[0].fireDate), 9)
    }

    func testAccountMigrationAndBalances() {
        let accounts = FinancialAccountStore.ensuringDefault(in: [], currencyCode: "USD")
        XCTAssertEqual(accounts.count, 1)
        XCTAssertTrue(accounts[0].isDefault)
        let income = Transaction(amount: 500, type: .income, category: .salary, paymentMethod: .bank, currencyCode: "USD", transactionDate: .now, merchant: "Employer")
        let expense = Transaction(amount: 125, type: .expense, category: .food, paymentMethod: .card, currencyCode: "USD", transactionDate: .now, merchant: "Market")
        let other = FinancialAccount(name: "Euro Wallet", type: .wallet, currencyCode: "EUR", openingBalance: 50)
        let euroExpense = Transaction(amount: 10, type: .expense, category: .travel, paymentMethod: .cash, currencyCode: "EUR", transactionDate: .now, merchant: "Metro")
        euroExpense.accountID = other.id

        XCTAssertEqual(FinancialAccountStore.balance(for: accounts[0], transactions: [income, expense, euroExpense]), 375)
        XCTAssertEqual(FinancialAccountStore.balance(for: other, transactions: [income, expense, euroExpense]), 40)
        XCTAssertEqual(FinancialAccountStore.decode(FinancialAccountStore.encode(accounts)), accounts)
    }

    func testTransfersMoveBalancesWithoutChangingIncomeOrExpenses() {
        let cash = FinancialAccount(name: "Cash", type: .cash, currencyCode: "USD", openingBalance: 500)
        let bank = FinancialAccount(name: "Bank", type: .bank, currencyCode: "USD", openingBalance: 1_000)
        let euro = FinancialAccount(name: "Euro", type: .bank, currencyCode: "EUR")
        let transfer = AccountTransfer.transactions(amount: 200, from: bank, to: cash, date: .now, notes: "ATM")!

        XCTAssertEqual(transfer.count, 2)
        XCTAssertEqual(transfer[0].transferID, transfer[1].transferID)
        XCTAssertEqual(FinancialAccountStore.balance(for: bank, transactions: transfer), 800)
        XCTAssertEqual(FinancialAccountStore.balance(for: cash, transactions: transfer), 700)
        XCTAssertEqual(transfer.income, 0)
        XCTAssertEqual(transfer.expenses, 0)
        XCTAssertNil(AccountTransfer.transactions(amount: 10, from: bank, to: euro, date: .now, notes: ""))
    }

    func testMismatchedCategoryFallsBackSafely() {
        let transaction = Transaction(amount: 1, type: .income, category: .food, paymentMethod: .cash, currencyCode: "USD", transactionDate: .now, merchant: "")
        XCTAssertEqual(transaction.category, .otherIncome)
    }

    @MainActor
    func testTransactionPersistsCurrency() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, configurations: configuration)
        let context = container.mainContext
        context.insert(Transaction(amount: 12.5, type: .expense, category: .food, paymentMethod: .card, currencyCode: "EUR", transactionDate: .now, merchant: "Cafe"))
        try context.save()
        let saved = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.currencyCode, "EUR")
        XCTAssertEqual(saved.first?.category, .food)
    }

    @MainActor
    func testRecurringGenerationIsDuplicateSafe() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, configurations: configuration)
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let schedule = RecurringTransaction(name: "Rent", amount: 1000, type: .expense, categoryRaw: ExpenseCategory.bills.rawValue, paymentMethod: .bank, currencyCode: "USD", merchant: "Landlord", notes: "", frequency: .monthly, nextDate: start)
        let originalJSON = RecurringTransactionStore.encode([schedule])

        let updatedJSON = try RecurringTransactionProcessor.processDue(in: context, schedulesJSON: originalJSON, now: now, calendar: calendar)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).count, 3)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Transaction>()).allSatisfy { $0.recurringSourceID == schedule.id })
        XCTAssertTrue(RecurringTransactionStore.decode(updatedJSON)[0].nextDate > now)

        _ = try RecurringTransactionProcessor.processDue(in: context, schedulesJSON: originalJSON, now: now, calendar: calendar)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).count, 3)
    }
}
