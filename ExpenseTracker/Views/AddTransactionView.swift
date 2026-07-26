import SwiftUI
import SwiftData
import PhotosUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var existingTransactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @AppStorage(MerchantRuleStore.storageKey) private var merchantRulesJSON = ""
    @AppStorage(TransactionTemplateStore.storageKey) private var templatesJSON = ""
    @AppStorage(SavingsGoalStore.storageKey) private var savingsGoalsJSON = ""
    private let transaction: Transaction?
    private let isDuplicate: Bool
    private let isTemplate: Bool
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
    @State private var saveAsTemplate = false
    @State private var templateName = ""
    @State private var receiptImageData: Data?
    @State private var splits: [TransactionSplit]
    @State private var refundForID: UUID?
    @State private var showingSplitEditor = false
    @State private var contributionGoalID = ""
    @State private var locationName = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @StateObject private var locationService = LocationSuggestionService()
    @State private var duplicateMatch: Transaction?
    @State private var bypassDuplicateCheck = false
    private let receiptScanner = ReceiptScanner()

    init(transaction: Transaction? = nil) {
        self.transaction = transaction
        self.isDuplicate = false
        self.isTemplate = false
        _type = State(initialValue: transaction?.type ?? .expense)
        _amount = State(initialValue: transaction.map { String(format: "%.2f", $0.amount) } ?? "")
        _categoryID = State(initialValue: transaction?.categoryRaw ?? ExpenseCategory.food.rawValue)
        _payment = State(initialValue: transaction?.paymentMethod ?? .cash)
        _transactionCurrency = State(initialValue: transaction?.currencyCode ?? CurrencyCatalog.defaultCode)
        _date = State(initialValue: transaction?.transactionDate ?? .now)
        _merchant = State(initialValue: transaction?.merchant ?? "")
        _notes = State(initialValue: transaction?.notes ?? "")
        _tagsText = State(initialValue: transaction?.tags.joined(separator: ", ") ?? "")
        _receiptImageData = State(initialValue: transaction?.receiptImageData)
        _splits = State(initialValue: transaction?.splits ?? [])
        _refundForID = State(initialValue: transaction?.refundForID)
        _contributionGoalID = State(initialValue: "")
    }

    init(startingType: TransactionType) {
        self.transaction = nil; self.isDuplicate = false; self.isTemplate = false
        _type = State(initialValue: startingType)
        _amount = State(initialValue: "")
        _categoryID = State(initialValue: ExpenseCategory.cases(for: startingType)[0].rawValue)
        _payment = State(initialValue: .cash); _transactionCurrency = State(initialValue: CurrencyCatalog.defaultCode)
        _date = State(initialValue: .now); _merchant = State(initialValue: ""); _notes = State(initialValue: "")
        _tagsText = State(initialValue: "")
        _receiptImageData = State(initialValue: nil); _splits = State(initialValue: []); _refundForID = State(initialValue: nil)
        _contributionGoalID = State(initialValue: "")
    }

    init(copying source: Transaction) {
        self.transaction = nil
        self.isDuplicate = true
        self.isTemplate = false
        _type = State(initialValue: source.type)
        _amount = State(initialValue: String(format: "%.2f", source.amount))
        _categoryID = State(initialValue: source.categoryRaw)
        _payment = State(initialValue: source.paymentMethod)
        _transactionCurrency = State(initialValue: source.currencyCode ?? CurrencyCatalog.defaultCode)
        _date = State(initialValue: .now)
        _merchant = State(initialValue: source.merchant)
        _notes = State(initialValue: source.notes)
        _tagsText = State(initialValue: source.tags.joined(separator: ", "))
        _receiptImageData = State(initialValue: source.receiptImageData); _splits = State(initialValue: source.splits); _refundForID = State(initialValue: nil)
        _contributionGoalID = State(initialValue: "")
    }

    init(template: TransactionTemplate) {
        self.transaction = nil
        self.isDuplicate = true
        self.isTemplate = true
        _type = State(initialValue: template.type)
        _amount = State(initialValue: String(format: "%.2f", template.amount))
        _categoryID = State(initialValue: template.categoryID)
        _payment = State(initialValue: template.paymentMethod)
        _transactionCurrency = State(initialValue: template.currencyCode)
        _date = State(initialValue: .now)
        _merchant = State(initialValue: template.merchant)
        _notes = State(initialValue: template.notes)
        _tagsText = State(initialValue: template.tags.joined(separator: ", "))
        _receiptImageData = State(initialValue: nil); _splits = State(initialValue: []); _refundForID = State(initialValue: nil)
        _contributionGoalID = State(initialValue: "")
    }

    init(refunding source: Transaction) {
        self.transaction = nil; self.isDuplicate = true; self.isTemplate = false
        _type = State(initialValue: .income)
        _amount = State(initialValue: String(format: "%.2f", source.amount))
        _categoryID = State(initialValue: ExpenseCategory.refund.rawValue)
        _payment = State(initialValue: source.paymentMethod)
        _transactionCurrency = State(initialValue: source.currencyCode ?? CurrencyCatalog.defaultCode)
        _date = State(initialValue: .now); _merchant = State(initialValue: source.merchant)
        _notes = State(initialValue: "Refund for transaction on \(source.transactionDate.formatted(date: .abbreviated, time: .omitted))")
        _tagsText = State(initialValue: source.tags.joined(separator: ", "))
        _receiptImageData = State(initialValue: nil); _splits = State(initialValue: []); _refundForID = State(initialValue: source.id)
        _contributionGoalID = State(initialValue: "")
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
                    if receiptImageData != nil {
                        HStack {
                            Label("Receipt attached", systemImage: "paperclip")
                            Spacer()
                            Button("Remove", role: .destructive) { receiptImageData = nil }
                        }
                    }
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
                    Button {
                        locationService.requestPlace()
                    } label: {
                        Label(locationService.isLoading ? "Finding Nearby Place…" : "Use Current Place",
                              systemImage: "location.fill")
                    }
                    .disabled(locationService.isLoading)
                    .accessibilityIdentifier("useCurrentPlace")
                    if !locationName.isEmpty {
                        LabeledContent("Attached Place", value: locationName)
                    }
                }
                Section("Optional") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                    TextField("Tags (comma separated)", text: $tagsText)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("transactionTagsField")
                    if !suggestedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestedTags, id: \.self) { tag in
                                    Button("#\(tag)") { toggleSuggestedTag(tag) }
                                        .buttonStyle(.bordered)
                                        .tint(TransactionTags.parse(tagsText).contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) ? .accentColor : .secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("suggestedTransactionTags")
                    }
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
                if transaction == nil && !isTemplate {
                    Section("Quick Template") {
                        Toggle("Save as a reusable template", isOn: $saveAsTemplate)
                            .accessibilityIdentifier("saveAsTemplateToggle")
                        if saveAsTemplate {
                            TextField("Template name", text: $templateName)
                                .accessibilityIdentifier("templateNameField")
                        }
                    }
                }
                if type == .expense {
                    Section("Split Transaction") {
                        Button(splits.isEmpty ? "Split Across Categories" : "Edit \(splits.count) Splits") {
                            showingSplitEditor = true
                        }
                        .accessibilityIdentifier("splitTransactionButton")
                        if !splits.isEmpty {
                            ForEach(splits) { split in
                                HStack {
                                    Text(CustomCategoryCatalog.presentation(
                                        for: split.categoryID, type: .expense,
                                        custom: CustomCategoryCatalog.decode(customCategoriesJSON)).name)
                                    Spacer()
                                    Text(AppFormat.money(split.amount, currencyCode: transactionCurrency))
                                }.font(.caption)
                            }
                        }
                    }
                }
                if transaction == nil && type == .expense && !matchingSavingsGoals.isEmpty {
                    Section("Savings Goal") {
                        Picker("Count toward goal", selection: $contributionGoalID) {
                            Text("None").tag("")
                            ForEach(matchingSavingsGoals) { Text($0.name).tag($0.id.uuidString) }
                        }
                        Text("The transaction amount will also be added to the selected goal’s progress.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let transaction, !transaction.revisionHistory.isEmpty {
                    Section("History") {
                        NavigationLink("View Change History") { TransactionHistoryView(transaction: transaction) }
                    }
                }
            }.navigationTitle(isTemplate ? "Use Quick Template" : (isDuplicate ? "Duplicate Transaction" : (transaction == nil ? AppLanguage.localized("Add Transaction") : AppLanguage.localized("Edit Transaction")))).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(DomainLogic.parseAmount(amount) == nil).accessibilityIdentifier("saveTransactionButton") } }
                .alert(alertTitle, isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Unknown error") }
                .confirmationDialog("Possible Duplicate", isPresented: Binding(
                    get: { duplicateMatch != nil },
                    set: { if !$0 { duplicateMatch = nil } }
                ), titleVisibility: .visible) {
                    Button("Save Anyway") {
                        duplicateMatch = nil
                        bypassDuplicateCheck = true
                        save()
                    }
                    Button("Review Entry", role: .cancel) { duplicateMatch = nil }
                } message: {
                    if let duplicateMatch {
                        Text("A matching \(duplicateMatch.type.title.lowercased()) from \(duplicateMatch.transactionDate.formatted(date: .abbreviated, time: .omitted)) already exists.")
                    }
                }
                .onChange(of: receiptItem) { _, item in if let item { scanReceipt(item) } }
                .onAppear { if transaction == nil && !isDuplicate { transactionCurrency = currencyCode } }
                .onAppear {
                    locationName = transaction?.locationName ?? ""
                    latitude = transaction?.latitude
                    longitude = transaction?.longitude
                }
                .onChange(of: locationService.suggestion) { _, suggestion in
                    guard let suggestion else { return }
                    locationName = suggestion.name
                    latitude = suggestion.latitude
                    longitude = suggestion.longitude
                    if merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        merchant = suggestion.name
                    }
                }
                .onChange(of: locationService.errorMessage) { _, message in
                    guard let message else { return }
                    alertTitle = "Location Unavailable"
                    errorMessage = message
                    locationService.errorMessage = nil
                }
                .sheet(isPresented: $showingSplitEditor) {
                    SplitTransactionEditor(total: DomainLogic.parseAmount(amount) ?? 0,
                                           currencyCode: transactionCurrency, initialSplits: splits) {
                        splits = $0
                    }
                }
        }
    }
    private func save() {
        guard let value = DomainLogic.parseAmount(amount) else { alertTitle = "Couldn’t Save"; errorMessage = AppLanguage.localized("Enter a valid amount greater than zero."); return }
        let cleanMerchant = DomainLogic.sanitizedText(merchant, maximumLength: 80)
        let cleanNotes = DomainLogic.sanitizedText(notes, maximumLength: 500)
        let cleanTemplateName = DomainLogic.sanitizedText(templateName, maximumLength: 40)
        guard !saveAsTemplate || !cleanTemplateName.isEmpty else {
            alertTitle = "Template Name Required"
            errorMessage = "Enter a name for this reusable template."
            return
        }
        guard splits.isEmpty || TransactionMetadata.validSplits(splits, total: value) else {
            alertTitle = "Split Amounts Don’t Match"
            errorMessage = "Split amounts must add up to \(AppFormat.money(value, currencyCode: transactionCurrency))."
            return
        }
        if transaction == nil && !bypassDuplicateCheck,
           let match = DuplicateTransactionDetector.likelyDuplicate(
            amount: value, type: type, currencyCode: transactionCurrency, date: date,
            merchant: cleanMerchant, categoryID: categoryID, among: existingTransactions) {
            duplicateMatch = match
            return
        }
        bypassDuplicateCheck = false
        if let transaction {
            transaction.recordRevision()
            transaction.amount = value; transaction.type = type; transaction.categoryRaw = categoryID
            transaction.paymentMethod = payment; transaction.currencyCode = transactionCurrency
            transaction.transactionDate = date; transaction.merchant = cleanMerchant
            transaction.notes = cleanNotes; transaction.updatedAt = .now
            transaction.tags = TransactionTags.parse(tagsText)
            transaction.receiptImageData = receiptImageData
            transaction.splits = splits
            transaction.locationName = locationName.isEmpty ? nil : locationName
            transaction.latitude = latitude
            transaction.longitude = longitude
        } else {
            let newTransaction = Transaction(amount: value, type: type, category: ExpenseCategory.cases(for: type)[0], paymentMethod: payment, currencyCode: transactionCurrency, transactionDate: date, merchant: cleanMerchant, notes: cleanNotes)
            newTransaction.categoryRaw = categoryID
            newTransaction.tags = TransactionTags.parse(tagsText)
            newTransaction.receiptImageData = receiptImageData
            newTransaction.splits = splits
            newTransaction.refundForID = refundForID
            newTransaction.locationName = locationName.isEmpty ? nil : locationName
            newTransaction.latitude = latitude
            newTransaction.longitude = longitude
            context.insert(newTransaction)
        }
        do {
            try context.save()
            if rememberMerchant, !cleanMerchant.isEmpty {
                let rule = MerchantRule(merchantName: cleanMerchant, type: type, categoryID: categoryID, paymentMethod: payment)
                merchantRulesJSON = MerchantRuleStore.encode(MerchantRuleStore.upserting(rule, in: MerchantRuleStore.decode(merchantRulesJSON)))
            }
            if saveAsTemplate {
                let template = TransactionTemplate(
                    name: cleanTemplateName, amount: value, type: type, categoryID: categoryID,
                    paymentMethod: payment, currencyCode: transactionCurrency, merchant: cleanMerchant,
                    notes: cleanNotes, tags: TransactionTags.parse(tagsText))
                templatesJSON = TransactionTemplateStore.encode(
                    TransactionTemplateStore.upserting(template, in: TransactionTemplateStore.decode(templatesJSON)))
            }
            if let goalID = UUID(uuidString: contributionGoalID) {
                var goals = SavingsGoalStore.decode(savingsGoalsJSON)
                if let index = goals.firstIndex(where: { $0.id == goalID && $0.currencyCode == transactionCurrency }) {
                    goals[index].savedAmount += value
                    savingsGoalsJSON = SavingsGoalStore.encode(goals)
                }
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
                receiptImageData = data
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

    private var suggestedTags: [String] {
        let counts = Dictionary(grouping: existingTransactions.filter { !$0.isDeleted }.flatMap(\.tags), by: { $0.lowercased() })
        return counts.sorted {
            if $0.value.count == $1.value.count { return $0.key < $1.key }
            return $0.value.count > $1.value.count
        }.prefix(6).compactMap { $0.value.first }
    }
    private var matchingSavingsGoals: [SavingsGoal] {
        SavingsGoalStore.decode(savingsGoalsJSON).filter {
            $0.currencyCode == transactionCurrency && $0.savedAmount < $0.targetAmount
        }
    }

    private func toggleSuggestedTag(_ tag: String) {
        var tags = TransactionTags.parse(tagsText)
        if let index = tags.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            tags.remove(at: index)
        } else {
            tags.append(tag)
        }
        tagsText = TransactionTags.normalized(tags).joined(separator: ", ")
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
