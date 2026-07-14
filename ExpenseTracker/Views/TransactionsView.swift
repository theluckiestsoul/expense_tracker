import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.transactionDate, order: .reverse) private var all: [Transaction]
    @State private var filter: TransactionType?
    @State private var search = ""
    @State private var editing: Transaction?
    @State private var pendingDeletion: [Transaction] = []
    @State private var errorMessage: String?
    private var shown: [Transaction] { all.filter { (filter == nil || $0.type == filter) && (search.isEmpty || $0.merchant.localizedCaseInsensitiveContains(search) || $0.category.rawValue.localizedCaseInsensitiveContains(search)) } }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $filter) { Text("All").tag(TransactionType?.none); ForEach(TransactionType.allCases) { Text($0.title).tag(Optional($0)) } }.pickerStyle(.segmented)
                ForEach(shown) { transaction in Button { editing = transaction } label: { TransactionRow(transaction: transaction) }.buttonStyle(.plain) }
                    .onDelete { offsets in pendingDeletion = offsets.map { shown[$0] } }
            }.navigationTitle("Transactions").searchable(text: $search)
                .overlay { if shown.isEmpty { ContentUnavailableView.search(text: search) } }
                .sheet(item: $editing) { AddTransactionView(transaction: $0) }
                .confirmationDialog("Delete \(pendingDeletion.count) transaction\(pendingDeletion.count == 1 ? "" : "s")?", isPresented: Binding(get: { !pendingDeletion.isEmpty }, set: { if !$0 { pendingDeletion = [] } }), titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { deletePending() }; Button("Cancel", role: .cancel) { pendingDeletion = [] }
                } message: { Text("This action can’t be undone.") }
                .alert("Couldn’t Delete", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Unknown error") }
        }
    }
    private func deletePending() {
        pendingDeletion.forEach(context.delete)
        do { try context.save(); pendingDeletion = [] } catch { context.rollback(); errorMessage = error.localizedDescription; pendingDeletion = [] }
    }
}
