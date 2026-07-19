import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @AppStorage(FinancialAccountStore.storageKey) private var accountsJSON = ""
    private let transaction: Transaction?
    @State private var type: TransactionType
    @State private var amount: String
    @State private var categoryID: String
    @State private var payment: PaymentMethod
    @State private var transactionCurrency: String
    @State private var date: Date
    @State private var merchant: String
    @State private var notes: String
    @State private var accountID: String
    @State private var errorMessage: String?

    init(transaction: Transaction? = nil) {
        self.transaction = transaction
        _type = State(initialValue: transaction?.type ?? .expense)
        _amount = State(initialValue: transaction.map { String(format: "%.2f", $0.amount) } ?? "")
        _categoryID = State(initialValue: transaction?.categoryRaw ?? ExpenseCategory.food.rawValue)
        _payment = State(initialValue: transaction?.paymentMethod ?? .cash)
        _transactionCurrency = State(initialValue: transaction?.currencyCode ?? CurrencyCatalog.defaultCode)
        _date = State(initialValue: transaction?.transactionDate ?? .now)
        _merchant = State(initialValue: transaction?.merchant ?? "")
        _notes = State(initialValue: transaction?.notes ?? "")
        _accountID = State(initialValue: transaction?.accountID ?? "")
    }

    private var accounts: [FinancialAccount] { FinancialAccountStore.decode(accountsJSON).filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) { ForEach(TransactionType.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    .onChange(of: type) { _, newType in categoryID = categoryOptions(for: newType).first?.id ?? ExpenseCategory.cases(for: newType)[0].rawValue }
                Section {
                    HStack {
                        Text(transactionCurrency).font(.headline).foregroundStyle(.secondary)
                        TextField("0.00", text: $amount).font(.largeTitle).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("amountField")
                    }
                }
                Section {
                    Picker("Account", selection: $accountID) {
                        ForEach(accounts) { account in Text("\(account.name) (\(account.currencyCode))").tag(account.id) }
                    }.onChange(of: accountID) { _, value in
                        if let account = accounts.first(where: { $0.id == value }) { transactionCurrency = account.currencyCode }
                    }
                    Picker("Category", selection: $categoryID) {
                        ForEach(categoryOptions(for: type)) { category in
                            Label(category.name, systemImage: category.symbol).tag(category.id)
                        }
                    }
                    Picker("Payment Method", selection: $payment) { ForEach(PaymentMethod.allCases) { Text($0.displayName).tag($0) } }
                    Picker("Currency", selection: $transactionCurrency) { ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) } }
                    DatePicker("Date", selection: $date)
                    TextField("Merchant / description", text: $merchant).textInputAutocapitalization(.words)
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }.navigationTitle(transaction == nil ? AppLanguage.localized("Add Transaction") : AppLanguage.localized("Edit Transaction")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(DomainLogic.parseAmount(amount) == nil).accessibilityIdentifier("saveTransactionButton") } }
                .alert("Couldn’t Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Unknown error") }
                .onAppear {
                    if accountID.isEmpty { accountID = accounts.first(where: \.isDefault)?.id ?? accounts.first?.id ?? "" }
                    if let account = accounts.first(where: { $0.id == accountID }) { transactionCurrency = account.currencyCode }
                    else if transaction == nil { transactionCurrency = currencyCode }
                }
        }
    }
    private func save() {
        guard let value = DomainLogic.parseAmount(amount) else { errorMessage = AppLanguage.localized("Enter a valid amount greater than zero."); return }
        let cleanMerchant = DomainLogic.sanitizedText(merchant, maximumLength: 80)
        let cleanNotes = DomainLogic.sanitizedText(notes, maximumLength: 500)
        if let transaction {
            transaction.amount = value; transaction.type = type; transaction.categoryRaw = categoryID
            transaction.paymentMethod = payment; transaction.currencyCode = transactionCurrency
            transaction.transactionDate = date; transaction.merchant = cleanMerchant
            transaction.notes = cleanNotes; transaction.updatedAt = .now
            transaction.accountID = accountID.isEmpty ? nil : accountID
        } else {
            let newTransaction = Transaction(amount: value, type: type, category: ExpenseCategory.cases(for: type)[0], paymentMethod: payment, currencyCode: transactionCurrency, transactionDate: date, merchant: cleanMerchant, notes: cleanNotes)
            newTransaction.categoryRaw = categoryID
            newTransaction.accountID = accountID.isEmpty ? nil : accountID
            context.insert(newTransaction)
        }
        do { try context.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }

    private func categoryOptions(for type: TransactionType) -> [CategoryPresentation] {
        CustomCategoryCatalog.options(for: type, custom: CustomCategoryCatalog.decode(customCategoriesJSON), includeArchivedID: transaction?.categoryRaw)
    }
}
