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
}
