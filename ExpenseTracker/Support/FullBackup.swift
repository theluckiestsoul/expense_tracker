import Foundation

struct LedgerLeafBackup: Codable, Equatable {
    struct Preferences: Codable, Equatable {
        var currencyCode: String
        var monthlyBudget: Double
        var languageCode: String
        var themeRaw: String? = nil
    }

    struct TransactionRecord: Codable, Equatable {
        var id: UUID
        var amount: Double
        var type: TransactionType
        var categoryRaw: String
        var paymentMethod: PaymentMethod
        var currencyCode: String
        var transactionDate: Date
        var merchant: String
        var notes: String
        var createdAt: Date
        var updatedAt: Date
        var recurringSourceID: UUID?
        var accountID: String?
        var transferID: UUID?

        init(_ transaction: Transaction, fallbackCurrency: String) {
            id = transaction.id; amount = transaction.amount; type = transaction.type
            categoryRaw = transaction.categoryRaw; paymentMethod = transaction.paymentMethod
            currencyCode = transaction.currencyCode ?? fallbackCurrency; transactionDate = transaction.transactionDate
            merchant = transaction.merchant; notes = transaction.notes; createdAt = transaction.createdAt
            updatedAt = transaction.updatedAt; recurringSourceID = transaction.recurringSourceID
            accountID = transaction.accountID; transferID = transaction.transferID
        }
    }

    enum BackupError: LocalizedError, Equatable {
        case unsupportedVersion
        case invalidData

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: "This backup was created by an unsupported LedgerLeaf version."
            case .invalidData: "The LedgerLeaf backup contains invalid or duplicate data."
            }
        }
    }

    var formatVersion: Int
    var exportedAt: Date
    var preferences: Preferences
    var transactions: [TransactionRecord]
    var customCategories: [CustomCategory]
    var accounts: [FinancialAccount]
    var categoryBudgets: [CategoryBudget]
    var savingsGoals: [SavingsGoal]
    var recurringTransactions: [RecurringTransaction]

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> LedgerLeafBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(LedgerLeafBackup.self, from: data)
        try backup.validate()
        return backup
    }

    func validate() throws {
        guard formatVersion == 1 else { throw BackupError.unsupportedVersion }
        let currencies = Set(CurrencyCatalog.all.map(\.code))
        let languages = Set(AppLanguage.supported.map(\.code))
        let accountsByID = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let hasValidAccountReferences = transactions.allSatisfy { transaction in
            guard let accountID = transaction.accountID else { return true }
            return accountsByID[accountID]?.currencyCode == transaction.currencyCode
        } && recurringTransactions.allSatisfy { schedule in
            guard let accountID = schedule.accountID else { return true }
            return accountsByID[accountID]?.currencyCode == schedule.currencyCode
        }
        guard currencies.contains(preferences.currencyCode), languages.contains(preferences.languageCode),
              preferences.themeRaw.map({ AppTheme(rawValue: $0) != nil }) ?? true,
              preferences.monthlyBudget.isFinite, preferences.monthlyBudget >= 0,
              Set(transactions.map(\.id)).count == transactions.count,
              transactions.allSatisfy({ $0.amount.isFinite && $0.amount > 0 && currencies.contains($0.currencyCode) }),
              Set(customCategories.map(\.id)).count == customCategories.count,
              customCategories.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && CustomCategoryCatalog.symbols.contains($0.symbol) && CustomCategoryCatalog.colors.contains($0.colorName) }),
              Set(accounts.map(\.id)).count == accounts.count,
              accounts.allSatisfy({ !$0.id.isEmpty && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.openingBalance.isFinite && currencies.contains($0.currencyCode) }),
              accounts.filter(\.isDefault).count <= 1,
              hasValidAccountReferences,
              Set(categoryBudgets.map(\.id)).count == categoryBudgets.count,
              categoryBudgets.allSatisfy({ $0.amount.isFinite && $0.amount > 0 && currencies.contains($0.currencyCode) }),
              Set(savingsGoals.map(\.id)).count == savingsGoals.count,
              savingsGoals.allSatisfy({ $0.targetAmount.isFinite && $0.targetAmount > 0 && $0.savedAmount.isFinite && $0.savedAmount >= 0 && currencies.contains($0.currencyCode) }),
              Set(recurringTransactions.map(\.id)).count == recurringTransactions.count,
              recurringTransactions.allSatisfy({ $0.amount.isFinite && $0.amount > 0 && currencies.contains($0.currencyCode) }) else {
            throw BackupError.invalidData
        }
    }
}
