import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.deletedAt, order: .reverse) private var transactions: [Transaction]
    @State private var permanentlyDeleting: Transaction?
    @State private var errorMessage: String?

    private var deleted: [Transaction] { transactions.filter(\.isDeleted) }

    var body: some View {
        List {
            if deleted.isEmpty {
                ContentUnavailableView("Trash Is Empty", systemImage: "trash",
                                       description: Text("Deleted transactions remain here until permanently removed."))
            } else {
                ForEach(deleted) { transaction in
                    TransactionRow(transaction: transaction)
                        .swipeActions(edge: .leading) {
                            Button("Restore", systemImage: "arrow.uturn.backward") { restore(transaction) }.tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete Forever", systemImage: "trash", role: .destructive) {
                                permanentlyDeleting = transaction
                            }
                        }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .confirmationDialog("Permanently delete this transaction?", isPresented: Binding(
            get: { permanentlyDeleting != nil }, set: { if !$0 { permanentlyDeleting = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Forever", role: .destructive) {
                if let transaction = permanentlyDeleting { context.delete(transaction); save() }
                permanentlyDeleting = nil
            }
            Button("Cancel", role: .cancel) { permanentlyDeleting = nil }
        } message: { Text("This action can’t be undone.") }
        .alert("Couldn’t Update Trash", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func restore(_ transaction: Transaction) {
        transaction.deletedAt = nil
        transaction.updatedAt = .now
        save()
    }

    private func save() {
        do { try context.save() }
        catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}
