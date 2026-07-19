import SwiftUI
import SwiftData

struct TransferView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(FinancialAccountStore.storageKey) private var accountsJSON = ""
    @State private var fromID = ""
    @State private var toID = ""
    @State private var amount = ""
    @State private var date = Date.now
    @State private var notes = ""
    @State private var errorMessage: String?
    private var accounts: [FinancialAccount] { FinancialAccountStore.decode(accountsJSON).filter { !$0.isArchived } }
    private var from: FinancialAccount? { accounts.first { $0.id == fromID } }
    private var validDestinations: [FinancialAccount] { accounts.filter { $0.id != fromID && $0.currencyCode == from?.currencyCode } }
    private var canSave: Bool { from != nil && validDestinations.contains(where: { $0.id == toID }) && DomainLogic.parseAmount(amount) != nil }

    var body: some View {
        NavigationStack {
            Form {
                if accounts.count < 2 {
                    ContentUnavailableView("Two Accounts Required", systemImage: "arrow.left.arrow.right", description: Text("Create another account before recording a transfer."))
                } else {
                    Picker("From Account", selection: $fromID) { ForEach(accounts) { Text("\($0.name) (\($0.currencyCode))").tag($0.id) } }
                        .onChange(of: fromID) { _, _ in if !validDestinations.contains(where: { $0.id == toID }) { toID = validDestinations.first?.id ?? "" } }
                    Picker("To Account", selection: $toID) { ForEach(validDestinations) { Text($0.name).tag($0.id) } }
                    HStack { Text(from?.currencyCode ?? "—").foregroundStyle(.secondary); TextField("Amount", text: $amount).keyboardType(.decimalPad).accessibilityIdentifier("transferAmount") }
                    DatePicker("Date", selection: $date)
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
                    if from != nil && validDestinations.isEmpty { Label("Transfers require two accounts with the same currency.", systemImage: "info.circle").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Transfer Money").navigationBarTitleDisplayMode(.inline)
            .onAppear { fromID = accounts.first?.id ?? ""; toID = validDestinations.first?.id ?? "" }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!canSave).accessibilityIdentifier("saveTransfer") }
            }
            .alert("Couldn’t Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "Unknown error") }
        }
    }

    private func save() {
        guard let from, let to = accounts.first(where: { $0.id == toID }), from.currencyCode == to.currencyCode,
              let value = DomainLogic.parseAmount(amount) else { return }
        let cleanNotes = DomainLogic.sanitizedText(notes, maximumLength: 500)
        guard let transactions = AccountTransfer.transactions(amount: value, from: from, to: to, date: date, notes: cleanNotes) else { return }
        transactions.forEach(context.insert)
        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}
