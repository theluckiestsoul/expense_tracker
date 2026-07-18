import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    private let transaction: Transaction?
    @State private var type: TransactionType
    @State private var amount: String
    @State private var category: ExpenseCategory
    @State private var payment: PaymentMethod
    @State private var transactionCurrency: String
    @State private var date: Date
    @State private var merchant: String
    @State private var notes: String
    @State private var errorMessage: String?

    init(transaction: Transaction? = nil) {
        self.transaction = transaction
        _type = State(initialValue: transaction?.type ?? .expense)
        _amount = State(initialValue: transaction.map { String(format: "%.2f", $0.amount) } ?? "")
        _category = State(initialValue: transaction?.category ?? .food)
        _payment = State(initialValue: transaction?.paymentMethod ?? .cash)
        _transactionCurrency = State(initialValue: transaction?.currencyCode ?? CurrencyCatalog.defaultCode)
        _date = State(initialValue: transaction?.transactionDate ?? .now)
        _merchant = State(initialValue: transaction?.merchant ?? "")
        _notes = State(initialValue: transaction?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) { ForEach(TransactionType.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    .onChange(of: type) { _, newType in category = ExpenseCategory.cases(for: newType)[0] }
                Section {
                    HStack {
                        Text(transactionCurrency).font(.headline).foregroundStyle(.secondary)
                        TextField("0.00", text: $amount).font(.largeTitle).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("amountField")
                    }
                }
                Section {
                    Picker("Category", selection: $category) { ForEach(ExpenseCategory.cases(for: type)) { Label($0.displayName, systemImage: $0.symbol).tag($0) } }
                    Picker("Payment Method", selection: $payment) { ForEach(PaymentMethod.allCases) { Text($0.displayName).tag($0) } }
                    Picker("Currency", selection: $transactionCurrency) { ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) } }
                    DatePicker("Date", selection: $date)
                    TextField("Merchant / description", text: $merchant).textInputAutocapitalization(.words)
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }.navigationTitle(transaction == nil ? String(localized: "Add Transaction") : String(localized: "Edit Transaction")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(DomainLogic.parseAmount(amount) == nil).accessibilityIdentifier("saveTransactionButton") } }
                .alert("Couldn’t Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Unknown error") }
                .onAppear { if transaction == nil { transactionCurrency = currencyCode } }
        }
    }
    private func save() {
        guard let value = DomainLogic.parseAmount(amount) else { errorMessage = String(localized: "Enter a valid amount greater than zero."); return }
        let cleanMerchant = DomainLogic.sanitizedText(merchant, maximumLength: 80)
        let cleanNotes = DomainLogic.sanitizedText(notes, maximumLength: 500)
        if let transaction {
            transaction.amount = value; transaction.type = type; transaction.category = category
            transaction.paymentMethod = payment; transaction.currencyCode = transactionCurrency
            transaction.transactionDate = date; transaction.merchant = cleanMerchant
            transaction.notes = cleanNotes; transaction.updatedAt = .now
        } else {
            context.insert(Transaction(amount: value, type: type, category: category, paymentMethod: payment, currencyCode: transactionCurrency, transactionDate: date, merchant: cleanMerchant, notes: cleanNotes))
        }
        do { try context.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}
