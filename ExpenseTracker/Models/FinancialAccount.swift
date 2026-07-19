import Foundation

enum FinancialAccountType: String, Codable, CaseIterable, Identifiable {
    case cash, bank, creditCard, wallet
    var id: String { rawValue }
    var title: String { switch self { case .cash: "Cash"; case .bank: "Bank Account"; case .creditCard: "Credit Card"; case .wallet: "Wallet" } }
    var symbol: String { switch self { case .cash: "banknote.fill"; case .bank: "building.columns.fill"; case .creditCard: "creditcard.fill"; case .wallet: "wallet.bifold.fill" } }
}

struct FinancialAccount: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var type: FinancialAccountType
    var currencyCode: String
    var openingBalance: Double
    var isArchived: Bool
    var isDefault: Bool

    init(id: String = UUID().uuidString, name: String, type: FinancialAccountType, currencyCode: String, openingBalance: Double = 0, isArchived: Bool = false, isDefault: Bool = false) {
        self.id = id; self.name = name; self.type = type; self.currencyCode = currencyCode
        self.openingBalance = openingBalance; self.isArchived = isArchived; self.isDefault = isDefault
    }
}

enum FinancialAccountStore {
    static let storageKey = "financialAccountsJSON"
    static func decode(_ json: String) -> [FinancialAccount] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([FinancialAccount].self, from: data)) ?? []
    }
    static func encode(_ accounts: [FinancialAccount]) -> String {
        guard let data = try? JSONEncoder().encode(accounts) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    static func ensuringDefault(in accounts: [FinancialAccount], currencyCode: String) -> [FinancialAccount] {
        guard !accounts.contains(where: \.isDefault) else { return accounts }
        var updated = accounts
        updated.insert(FinancialAccount(name: "Everyday Account", type: .cash, currencyCode: currencyCode, isDefault: true), at: 0)
        return updated
    }
    static func balance(for account: FinancialAccount, transactions: [Transaction]) -> Double {
        let relevant = transactions.filter { transaction in
            matches(transaction, account: account)
                && (transaction.currencyCode ?? account.currencyCode) == account.currencyCode
        }
        let credits = relevant.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let debits = relevant.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        return account.openingBalance + credits - debits
    }
    static func matches(_ transaction: Transaction, account: FinancialAccount) -> Bool {
        transaction.accountID == account.id || (transaction.accountID == nil && account.isDefault)
    }
}

enum AccountTransfer {
    static func transactions(amount: Double, from: FinancialAccount, to: FinancialAccount, date: Date, notes: String) -> [Transaction]? {
        guard amount > 0, amount.isFinite, from.id != to.id, from.currencyCode == to.currencyCode else { return nil }
        let transferID = UUID()
        let debit = Transaction(amount: amount, type: .expense, category: .other, paymentMethod: .bank, currencyCode: from.currencyCode, transactionDate: date, merchant: "Transfer to \(to.name)", notes: notes)
        debit.accountID = from.id; debit.transferID = transferID
        let credit = Transaction(amount: amount, type: .income, category: .otherIncome, paymentMethod: .bank, currencyCode: to.currencyCode, transactionDate: date, merchant: "Transfer from \(from.name)", notes: notes)
        credit.accountID = to.id; credit.transferID = transferID
        return [debit, credit]
    }
}
