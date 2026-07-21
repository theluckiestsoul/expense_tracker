import SwiftUI
import SwiftData

private enum TransactionDateFilter: String, CaseIterable, Identifiable {
    case all, thisMonth, last30Days, thisYear
    var id: String { rawValue }
    var title: String {
        switch self { case .all: "Any Date"; case .thisMonth: "This Month"; case .last30Days: "Last 30 Days"; case .thisYear: "This Year" }
    }
    func includes(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all: return true
        case .thisMonth: return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .thisYear: return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .last30Days:
            guard let start = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
            return date >= start && date <= now
        }
    }
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.transactionDate, order: .reverse) private var all: [Transaction]
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @State private var filter: TransactionType?
    @State private var search = ""
    @State private var categoryFilter = ""
    @State private var paymentFilter = ""
    @State private var dateFilter = TransactionDateFilter.all
    @State private var showingFilters = false
    @State private var editing: Transaction?
    @State private var duplicating: Transaction?
    @State private var pendingDeletion: [Transaction] = []
    @State private var errorMessage: String?
    private var customCategories: [CustomCategory] { CustomCategoryCatalog.decode(customCategoriesJSON) }
    private var categoryOptions: [CategoryPresentation] {
        let types = filter.map { [$0] } ?? TransactionType.allCases
        return types.flatMap { CustomCategoryCatalog.options(for: $0, custom: customCategories) }
    }
    private var activeFilterCount: Int { (categoryFilter.isEmpty ? 0 : 1) + (paymentFilter.isEmpty ? 0 : 1) + (dateFilter == .all ? 0 : 1) }
    private var shown: [Transaction] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return all.filter { transaction in
            let category = transaction.categoryPresentation(customCategories: customCategories)
            let matchesSearch = term.isEmpty || transaction.merchant.localizedCaseInsensitiveContains(term)
                || transaction.notes.localizedCaseInsensitiveContains(term)
                || category.name.localizedCaseInsensitiveContains(term)
                || transaction.paymentMethod.displayName.localizedCaseInsensitiveContains(term)
            return (filter == nil || transaction.type == filter)
                && (categoryFilter.isEmpty || transaction.categoryRaw == categoryFilter)
                && (paymentFilter.isEmpty || transaction.paymentMethodRaw == paymentFilter)
                && dateFilter.includes(transaction.transactionDate)
                && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $filter) { Text("All").tag(TransactionType?.none); ForEach(TransactionType.allCases) { Text($0.title).tag(Optional($0)) } }.pickerStyle(.segmented)
                    .onChange(of: filter) { _, _ in
                        if !categoryFilter.isEmpty && !categoryOptions.contains(where: { $0.id == categoryFilter }) { categoryFilter = "" }
                    }
                ForEach(shown) { transaction in
                    Button { if transaction.transferID == nil { editing = transaction } } label: { TransactionRow(transaction: transaction) }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if transaction.transferID == nil {
                                Button { duplicating = transaction } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                    .tint(.indigo)
                                    .accessibilityIdentifier("duplicateTransaction_\(transaction.id.uuidString)")
                            }
                        }
                        .contextMenu {
                            if transaction.transferID == nil { Button { duplicating = transaction } label: { Label("Duplicate", systemImage: "plus.square.on.square") } }
                        }
                }
                    .onDelete { offsets in pendingDeletion = offsets.map { shown[$0] } }
            }.navigationTitle("Transactions").searchable(text: $search, prompt: "Merchant, notes, category, payment")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingFilters = true } label: {
                            if activeFilterCount == 0 { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
                            else { Label("Filters (\(activeFilterCount))", systemImage: "line.3.horizontal.decrease.circle.fill") }
                        }.accessibilityIdentifier("transactionFiltersButton")
                    }
                }
                .overlay { if shown.isEmpty { ContentUnavailableView.search(text: search) } }
                .sheet(item: $editing) { AddTransactionView(transaction: $0) }
                .sheet(item: $duplicating) { AddTransactionView(copying: $0) }
                .sheet(isPresented: $showingFilters) {
                    NavigationStack {
                        Form {
                            Picker("Date", selection: $dateFilter) { ForEach(TransactionDateFilter.allCases) { Text($0.title).tag($0) } }
                            Picker("Category", selection: $categoryFilter) {
                                Text("All Categories").tag("")
                                ForEach(categoryOptions) { Text($0.name).tag($0.id) }
                            }
                            Picker("Payment Method", selection: $paymentFilter) {
                                Text("All Payment Methods").tag("")
                                ForEach(PaymentMethod.allCases) { Text($0.displayName).tag($0.rawValue) }
                            }
                            if activeFilterCount > 0 { Button("Clear Filters", role: .destructive) { clearFilters() } }
                        }
                        .navigationTitle("Filter Transactions").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingFilters = false }.accessibilityIdentifier("applyTransactionFilters") } }
                    }
                    .presentationDetents([.medium, .large])
                }
                .confirmationDialog("Delete \(pendingDeletion.count) transaction\(pendingDeletion.count == 1 ? "" : "s")?", isPresented: Binding(get: { !pendingDeletion.isEmpty }, set: { if !$0 { pendingDeletion = [] } }), titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { deletePending() }; Button("Cancel", role: .cancel) { pendingDeletion = [] }
                } message: { Text("This action can’t be undone.") }
                .alert("Couldn’t Delete", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Unknown error") }
        }
    }
    private func deletePending() {
        let transferIDs = Set(pendingDeletion.compactMap(\.transferID))
        let linked = all.filter { transaction in transaction.transferID.map(transferIDs.contains) ?? false }
        Dictionary((pendingDeletion + linked).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.forEach(context.delete)
        do { try context.save(); pendingDeletion = [] } catch { context.rollback(); errorMessage = error.localizedDescription; pendingDeletion = [] }
    }
    private func clearFilters() { categoryFilter = ""; paymentFilter = ""; dateFilter = .all }
}
