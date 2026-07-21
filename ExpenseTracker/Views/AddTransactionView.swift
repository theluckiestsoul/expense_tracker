import SwiftUI
import SwiftData
import PhotosUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @AppStorage(MerchantRuleStore.storageKey) private var merchantRulesJSON = ""
    private let transaction: Transaction?
    private let isDuplicate: Bool
    @State private var type: TransactionType
    @State private var amount: String
    @State private var categoryID: String
    @State private var payment: PaymentMethod
    @State private var transactionCurrency: String
    @State private var date: Date
    @State private var merchant: String
    @State private var notes: String
    @State private var tagsText: String
    @State private var errorMessage: String?
    @State private var alertTitle = "Couldn’t Save"
    @State private var receiptItem: PhotosPickerItem?
    @State private var isScanningReceipt = false
    @State private var rememberMerchant = false
    @State private var appliedRuleKey = ""
    private let receiptScanner = ReceiptScanner()

    init(transaction: Transaction? = nil) {
        self.transaction = transaction
        self.isDuplicate = false
        _type = State(initialValue: transaction?.type ?? .expense)
        _amount = State(initialValue: transaction.map { String(format: "%.2f", $0.amount) } ?? "")
        _categoryID = State(initialValue: transaction?.categoryRaw ?? ExpenseCategory.food.rawValue)
        _payment = State(initialValue: transaction?.paymentMethod ?? .cash)
        _transactionCurrency = State(initialValue: transaction?.currencyCode ?? CurrencyCatalog.defaultCode)
        _date = State(initialValue: transaction?.transactionDate ?? .now)
        _merchant = State(initialValue: transaction?.merchant ?? "")
        _notes = State(initialValue: transaction?.notes ?? "")
        _tagsText = State(initialValue: transaction?.tags.joined(separator: ", ") ?? "")
    }

    init(startingType: TransactionType) {
        self.transaction = nil; self.isDuplicate = false
        _type = State(initialValue: startingType)
        _amount = State(initialValue: "")
        _categoryID = State(initialValue: ExpenseCategory.cases(for: startingType)[0].rawValue)
        _payment = State(initialValue: .cash); _transactionCurrency = State(initialValue: CurrencyCatalog.defaultCode)
        _date = State(initialValue: .now); _merchant = State(initialValue: ""); _notes = State(initialValue: "")
        _tagsText = State(initialValue: "")
    }

    init(copying source: Transaction) {
        self.transaction = nil
        self.isDuplicate = true
        _type = State(initialValue: source.type)
        _amount = State(initialValue: String(format: "%.2f", source.amount))
        _categoryID = State(initialValue: source.categoryRaw)
        _payment = State(initialValue: source.paymentMethod)
        _transactionCurrency = State(initialValue: source.currencyCode ?? CurrencyCatalog.defaultCode)
        _date = State(initialValue: .now)
        _merchant = State(initialValue: source.merchant)
        _notes = State(initialValue: source.notes)
        _tagsText = State(initialValue: source.tags.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: Binding(
                    get: { type },
                    set: { newType in
                        type = newType
                        categoryID = categoryOptions(for: newType).first?.id ?? ExpenseCategory.cases(for: newType)[0].rawValue
                    }
                )) { ForEach(TransactionType.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Section("Amount") {
                    HStack {
                        Text(transactionCurrency).font(.headline).foregroundStyle(.secondary)
                        TextField("0.00", text: $amount).font(.largeTitle).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("amountField")
                    }
                    PhotosPicker(selection: $receiptItem, matching: .images) {
                        Label(isScanningReceipt ? "Scanning Receipt…" : "Scan Receipt or Image", systemImage: "doc.text.viewfinder")
                    }
                    .disabled(isScanningReceipt)
                    .accessibilityIdentifier("scanReceipt")
                    if isScanningReceipt { ProgressView().frame(maxWidth: .infinity) }
                }
                Section("Details") {
                    Picker("Category", selection: $categoryID) {
                        ForEach(categoryOptions(for: type)) { category in
                            Label(category.name, systemImage: category.symbol).tag(category.id)
                        }
                    }
                    Picker("Payment Method", selection: $payment) { ForEach(PaymentMethod.allCases) { Text($0.displayName).tag($0) } }
                    Picker("Currency", selection: $transactionCurrency) { ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) } }
                    DatePicker("Date", selection: $date)
                    TextField("Merchant / description", text: $merchant).textInputAutocapitalization(.words)
                        .accessibilityIdentifier("merchantField")
                        .onChange(of: merchant) { _, value in applyRule(for: value) }
                }
                Section("Optional") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                    TextField("Tags (comma separated)", text: $tagsText)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("transactionTagsField")
                    Text("Add up to 8 labels, such as work, tax, vacation, or reimbursable.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !MerchantRuleStore.normalizedKey(merchant).isEmpty {
                        Toggle("Remember choices for this merchant", isOn: $rememberMerchant)
                            .accessibilityIdentifier("rememberMerchantRule")
                        if !appliedRuleKey.isEmpty {
                            Label("Saved merchant rule applied", systemImage: "wand.and.stars")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.navigationTitle(isDuplicate ? "Duplicate Transaction" : (transaction == nil ? AppLanguage.localized("Add Transaction") : AppLanguage.localized("Edit Transaction"))).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(DomainLogic.parseAmount(amount) == nil).accessibilityIdentifier("saveTransactionButton") } }
                .alert(alertTitle, isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Unknown error") }
                .onChange(of: receiptItem) { _, item in if let item { scanReceipt(item) } }
                .onAppear { if transaction == nil && !isDuplicate { transactionCurrency = currencyCode } }
        }
    }
    private func save() {
        guard let value = DomainLogic.parseAmount(amount) else { alertTitle = "Couldn’t Save"; errorMessage = AppLanguage.localized("Enter a valid amount greater than zero."); return }
        let cleanMerchant = DomainLogic.sanitizedText(merchant, maximumLength: 80)
        let cleanNotes = DomainLogic.sanitizedText(notes, maximumLength: 500)
        if let transaction {
            transaction.amount = value; transaction.type = type; transaction.categoryRaw = categoryID
            transaction.paymentMethod = payment; transaction.currencyCode = transactionCurrency
            transaction.transactionDate = date; transaction.merchant = cleanMerchant
            transaction.notes = cleanNotes; transaction.updatedAt = .now
            transaction.tags = TransactionTags.parse(tagsText)
        } else {
            let newTransaction = Transaction(amount: value, type: type, category: ExpenseCategory.cases(for: type)[0], paymentMethod: payment, currencyCode: transactionCurrency, transactionDate: date, merchant: cleanMerchant, notes: cleanNotes)
            newTransaction.categoryRaw = categoryID
            newTransaction.tags = TransactionTags.parse(tagsText)
            context.insert(newTransaction)
        }
        do {
            try context.save()
            if rememberMerchant, !cleanMerchant.isEmpty {
                let rule = MerchantRule(merchantName: cleanMerchant, type: type, categoryID: categoryID, paymentMethod: payment)
                merchantRulesJSON = MerchantRuleStore.encode(MerchantRuleStore.upserting(rule, in: MerchantRuleStore.decode(merchantRulesJSON)))
            }
            dismiss()
        } catch { alertTitle = "Couldn’t Save"; errorMessage = error.localizedDescription }
    }

    private func scanReceipt(_ item: PhotosPickerItem) {
        isScanningReceipt = true
        Task { @MainActor in
            defer { isScanningReceipt = false; receiptItem = nil }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw ReceiptScanner.ScanError.invalidImage }
                let result = try await receiptScanner.scan(data: data)
                if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let scanned = result.amount { amount = String(format: "%.2f", scanned) }
                if merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let scanned = result.merchant { merchant = scanned }
                if let scanned = result.date { date = scanned }
            } catch { alertTitle = "Receipt Not Recognized"; errorMessage = error.localizedDescription }
        }
    }

    private func categoryOptions(for type: TransactionType) -> [CategoryPresentation] {
        CustomCategoryCatalog.options(for: type, custom: CustomCategoryCatalog.decode(customCategoriesJSON), includeArchivedID: categoryID)
    }

    private func applyRule(for merchant: String) {
        guard transaction == nil, !isDuplicate else { return }
        let merchantKey = MerchantRuleStore.normalizedKey(merchant)
        guard let rule = MerchantRuleStore.matching(merchant, in: MerchantRuleStore.decode(merchantRulesJSON)) else {
            if !appliedRuleKey.isEmpty, merchantKey != appliedRuleKey {
                appliedRuleKey = ""
                rememberMerchant = false
            }
            return
        }
        guard rule.merchantKey != appliedRuleKey else { return }
        type = rule.type
        let options = categoryOptions(for: rule.type)
        categoryID = options.contains(where: { $0.id == rule.categoryID }) ? rule.categoryID : (options.first?.id ?? ExpenseCategory.cases(for: rule.type)[0].rawValue)
        payment = rule.paymentMethod
        rememberMerchant = true
        appliedRuleKey = rule.merchantKey
    }
}
