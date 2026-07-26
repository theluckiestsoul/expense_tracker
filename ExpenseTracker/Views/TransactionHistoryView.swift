import SwiftUI
import SwiftData

struct TransactionHistoryView: View {
    @Environment(\.modelContext) private var context
    let transaction: Transaction
    @State private var restoring: TransactionRevision?
    @State private var errorMessage: String?

    var body: some View {
        List(transaction.revisionHistory.reversed()) { revision in
            Button { restoring = revision } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(AppFormat.money(revision.amount,
                                             currencyCode: transaction.currencyCode ?? CurrencyCatalog.defaultCode))
                            .fontWeight(.semibold)
                        Spacer()
                        Text(revision.changedAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(revision.type.title) · \(revision.merchant)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.buttonStyle(.plain)
        }
        .navigationTitle("Change History")
        .confirmationDialog("Restore this version?", isPresented: Binding(
            get: { restoring != nil }, set: { if !$0 { restoring = nil } }
        ), titleVisibility: .visible) {
            Button("Restore") {
                guard let revision = restoring else { return }
                transaction.recordRevision()
                transaction.restore(revision)
                do { try context.save() } catch { context.rollback(); errorMessage = error.localizedDescription }
                restoring = nil
            }
            Button("Cancel", role: .cancel) { restoring = nil }
        }
        .alert("Couldn’t Restore", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
}
