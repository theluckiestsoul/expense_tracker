import XCTest
import SwiftData
@testable import ExpenseTracker

final class ExpenseTrackerTests: XCTestCase {
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
                   "pawprint.fill", "orange", date.ISO8601Format()]
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
