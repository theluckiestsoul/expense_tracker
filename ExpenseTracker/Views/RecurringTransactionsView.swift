import SwiftUI

struct RecurringTransactionsView: View {
    @AppStorage(RecurringTransactionStore.storageKey) private var schedulesJSON = ""
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @State private var editing: RecurringTransaction?
    @State private var adding = false

    private var schedules: [RecurringTransaction] { RecurringTransactionStore.decode(schedulesJSON) }
    private var customCategories: [CustomCategory] { CustomCategoryCatalog.decode(customCategoriesJSON) }

    var body: some View {
        List {
            if schedules.isEmpty {
                ContentUnavailableView("No Recurring Transactions", systemImage: "arrow.trianglehead.2.clockwise.rotate.90", description: Text("Add salary, rent, subscriptions, or other repeating transactions."))
            }
            ForEach(schedules) { schedule in
                Button { editing = schedule } label: {
                    let category = CustomCategoryCatalog.presentation(for: schedule.categoryRaw, type: schedule.type, custom: customCategories)
                    HStack(spacing: 12) {
                        CategoryIcon(category: category)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(schedule.name).font(.headline).foregroundStyle(.primary)
                            Text("\(schedule.frequency.title) · Next \(schedule.nextDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(AppFormat.money(schedule.amount, currencyCode: schedule.currencyCode)).fontWeight(.semibold)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button(schedule.isActive ? "Pause" : "Resume") { setActive(schedule, !schedule.isActive) }
                        .tint(schedule.isActive ? .orange : .green)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) { delete(schedule) }
                }
            }
        }
        .navigationTitle("Recurring Transactions")
        .toolbar { Button("Add", systemImage: "plus") { adding = true }.accessibilityIdentifier("addRecurringTransaction") }
        .sheet(isPresented: $adding) { RecurringTransactionEditor(existing: nil, onSave: save) }
        .sheet(item: $editing) { RecurringTransactionEditor(existing: $0, onSave: save) }
    }

    private func save(_ schedule: RecurringTransaction) {
        var updated = schedules
        if let index = updated.firstIndex(where: { $0.id == schedule.id }) { updated[index] = schedule }
        else { updated.append(schedule) }
        schedulesJSON = RecurringTransactionStore.encode(updated)
    }

    private func setActive(_ schedule: RecurringTransaction, _ active: Bool) {
        var updated = schedules
        guard let index = updated.firstIndex(where: { $0.id == schedule.id }) else { return }
        updated[index].isActive = active
        schedulesJSON = RecurringTransactionStore.encode(updated)
    }

    private func delete(_ schedule: RecurringTransaction) {
        schedulesJSON = RecurringTransactionStore.encode(schedules.filter { $0.id != schedule.id })
    }
}

private struct RecurringTransactionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var defaultCurrency = CurrencyCatalog.defaultCode
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    let existing: RecurringTransaction?
    let onSave: (RecurringTransaction) -> Void
    @State private var name: String
    @State private var amount: String
    @State private var type: TransactionType
    @State private var categoryRaw: String
    @State private var payment: PaymentMethod
    @State private var currency: String
    @State private var merchant: String
    @State private var notes: String
    @State private var frequency: RecurrenceFrequency
    @State private var nextDate: Date
    @State private var errorMessage: String?

    init(existing: RecurringTransaction?, onSave: @escaping (RecurringTransaction) -> Void) {
        self.existing = existing; self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _amount = State(initialValue: existing.map { String(format: "%.2f", $0.amount) } ?? "")
        _type = State(initialValue: existing?.type ?? .expense)
        _categoryRaw = State(initialValue: existing?.categoryRaw ?? ExpenseCategory.food.rawValue)
        _payment = State(initialValue: existing?.paymentMethod ?? .cash)
        _currency = State(initialValue: existing?.currencyCode ?? CurrencyCatalog.defaultCode)
        _merchant = State(initialValue: existing?.merchant ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _frequency = State(initialValue: existing?.frequency ?? .monthly)
        _nextDate = State(initialValue: existing?.nextDate ?? Calendar.current.startOfDay(for: .now))
    }

    private var categoryOptions: [CategoryPresentation] {
        CustomCategoryCatalog.options(for: type, custom: CustomCategoryCatalog.decode(customCategoriesJSON), includeArchivedID: existing?.categoryRaw)
    }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) { ForEach(TransactionType.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, value in categoryRaw = CustomCategoryCatalog.options(for: value, custom: CustomCategoryCatalog.decode(customCategoriesJSON)).first?.id ?? ExpenseCategory.cases(for: value)[0].rawValue }
                TextField("Schedule Name", text: $name).textInputAutocapitalization(.words).accessibilityIdentifier("recurringName")
                HStack {
                    Text(currency).foregroundStyle(.secondary)
                    TextField("0.00", text: $amount).keyboardType(.decimalPad).accessibilityIdentifier("recurringAmount")
                }
                Picker("Category", selection: $categoryRaw) { ForEach(categoryOptions) { Label($0.name, systemImage: $0.symbol).tag($0.id) } }
                Picker("Payment Method", selection: $payment) { ForEach(PaymentMethod.allCases) { Text($0.displayName).tag($0) } }
                Picker("Currency", selection: $currency) { ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) } }
                Picker("Repeats", selection: $frequency) { ForEach(RecurrenceFrequency.allCases) { Text($0.title).tag($0) } }
                DatePicker("Next Date", selection: $nextDate, displayedComponents: .date)
                TextField("Merchant / description", text: $merchant)
                TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
            }
            .navigationTitle(existing == nil ? "New Recurring Transaction" : "Edit Recurring Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if existing == nil { currency = defaultCurrency } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || DomainLogic.parseAmount(amount) == nil).accessibilityIdentifier("saveRecurringTransaction") }
            }
            .alert("Couldn’t Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "Unknown error") }
        }
    }

    private func save() {
        guard let value = DomainLogic.parseAmount(amount) else { errorMessage = "Enter a valid amount greater than zero."; return }
        onSave(RecurringTransaction(id: existing?.id ?? UUID(), name: DomainLogic.sanitizedText(name, maximumLength: 50), amount: value, type: type, categoryRaw: categoryRaw, paymentMethod: payment, currencyCode: currency, merchant: DomainLogic.sanitizedText(merchant, maximumLength: 80), notes: DomainLogic.sanitizedText(notes, maximumLength: 500), frequency: frequency, nextDate: Calendar.current.startOfDay(for: nextDate), isActive: existing?.isActive ?? true, accountID: existing?.accountID))
        dismiss()
    }
}
