import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense, income
    var id: String { rawValue }
    var title: String {
        switch self {
        case .expense: AppLanguage.localized("Expense")
        case .income: AppLanguage.localized("Income")
        }
    }
}

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "Food & Dining", travel = "Travel", shopping = "Shopping"
    case bills = "Bills & Utilities", health = "Health", entertainment = "Entertainment"
    case education = "Education", other = "Other Expense"
    case salary = "Salary", freelance = "Freelance", business = "Business"
    case investments = "Investments", gifts = "Gifts", refund = "Refund"
    case otherIncome = "Other Income"
    var id: String { rawValue }
    static let expenseCases: [ExpenseCategory] = [.food, .travel, .shopping, .bills, .health, .entertainment, .education, .other]
    static let incomeCases: [ExpenseCategory] = [.salary, .freelance, .business, .investments, .gifts, .refund, .otherIncome]
    static func cases(for type: TransactionType) -> [ExpenseCategory] { type == .expense ? expenseCases : incomeCases }
    var isIncome: Bool { Self.incomeCases.contains(self) }
    var displayName: String {
        switch self {
        case .food: AppLanguage.localized("Food & Dining")
        case .travel: AppLanguage.localized("Travel")
        case .shopping: AppLanguage.localized("Shopping")
        case .bills: AppLanguage.localized("Bills & Utilities")
        case .health: AppLanguage.localized("Health")
        case .entertainment: AppLanguage.localized("Entertainment")
        case .education: AppLanguage.localized("Education")
        case .other: AppLanguage.localized("Other Expense")
        case .salary: AppLanguage.localized("Salary")
        case .freelance: AppLanguage.localized("Freelance")
        case .business: AppLanguage.localized("Business")
        case .investments: AppLanguage.localized("Investments")
        case .gifts: AppLanguage.localized("Gifts")
        case .refund: AppLanguage.localized("Refund")
        case .otherIncome: AppLanguage.localized("Other Income")
        }
    }
    var symbol: String {
        switch self {
        case .food: "fork.knife"; case .travel: "car.fill"; case .shopping: "cart.fill"
        case .bills: "bolt.fill"; case .health: "heart.fill"; case .entertainment: "film.fill"
        case .education: "graduationcap.fill"; case .other: "square.grid.2x2.fill"
        case .salary: "briefcase.fill"; case .freelance: "laptopcomputer"; case .business: "building.2.fill"
        case .investments: "chart.line.uptrend.xyaxis"; case .gifts: "gift.fill"; case .refund: "arrow.uturn.backward.circle.fill"
        case .otherIncome: "plus.circle.fill"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash", card = "Card", bank = "Bank Transfer", mobileWallet = "Mobile Wallet"
    case upi = "UPI", cheque = "Cheque", other = "Other"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cash: AppLanguage.localized("Cash")
        case .card: AppLanguage.localized("Card")
        case .bank: AppLanguage.localized("Bank Transfer")
        case .mobileWallet: AppLanguage.localized("Mobile Wallet")
        case .upi: AppLanguage.localized("UPI")
        case .cheque: AppLanguage.localized("Cheque")
        case .other: AppLanguage.localized("Other")
        }
    }
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var typeRaw: String
    var categoryRaw: String
    var paymentMethodRaw: String
    var currencyCode: String?
    var transactionDate: Date
    var merchant: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var recurringSourceID: UUID?

    var type: TransactionType { get { TransactionType(rawValue: typeRaw) ?? .expense } set { typeRaw = newValue.rawValue } }
    var category: ExpenseCategory {
        get {
            if categoryRaw == "Other" { return type == .income ? .otherIncome : .other }
            let fallback: ExpenseCategory = type == .income ? .otherIncome : .other
            guard let stored = ExpenseCategory(rawValue: categoryRaw), ExpenseCategory.cases(for: type).contains(stored) else { return fallback }
            return stored
        }
        set { categoryRaw = newValue.rawValue }
    }
    func categoryPresentation(customCategories: [CustomCategory]) -> CategoryPresentation {
        CustomCategoryCatalog.presentation(for: categoryRaw, type: type, custom: customCategories)
    }
    var paymentMethod: PaymentMethod { get { PaymentMethod(rawValue: paymentMethodRaw) ?? .upi } set { paymentMethodRaw = newValue.rawValue } }

    init(amount: Double, type: TransactionType, category: ExpenseCategory, paymentMethod: PaymentMethod, currencyCode: String, transactionDate: Date, merchant: String, notes: String = "") {
        id = UUID(); self.amount = amount; typeRaw = type.rawValue; categoryRaw = category.rawValue
        paymentMethodRaw = paymentMethod.rawValue; self.currencyCode = currencyCode; self.transactionDate = transactionDate
        self.merchant = merchant; self.notes = notes; createdAt = .now; updatedAt = .now; recurringSourceID = nil
    }
}

enum LegacyDataMigrator {
    @MainActor
    static func assignMissingCurrencies(in context: ModelContext, currencyCode: String) throws {
        let missing = try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.currencyCode == nil }))
        guard !missing.isEmpty else { return }
        missing.forEach { $0.currencyCode = currencyCode; $0.updatedAt = .now }
        try context.save()
    }
}
