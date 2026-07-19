import SwiftUI
import SwiftData

struct AccountsView: View {
    @Query private var transactions: [Transaction]
    @AppStorage(FinancialAccountStore.storageKey) private var accountsJSON = ""
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @State private var editing: FinancialAccount?
    @State private var adding = false
    private var accounts: [FinancialAccount] { FinancialAccountStore.decode(accountsJSON) }

    var body: some View {
        List {
            ForEach(accounts.filter { !$0.isArchived }) { account in
                Button { editing = account } label: {
                    HStack {
                        Image(systemName: account.type.symbol).frame(width: 34).foregroundStyle(.indigo)
                        VStack(alignment: .leading) { Text(account.name).foregroundStyle(.primary); Text(account.type.title).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text(AppFormat.money(FinancialAccountStore.balance(for: account, transactions: transactions), currencyCode: account.currencyCode)).fontWeight(.semibold)
                    }
                }.accessibilityIdentifier("account_\(account.id)")
            }
        }
        .navigationTitle("Accounts").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityIdentifier("addAccount") }
        .sheet(isPresented: $adding) { AccountEditor(existing: nil, defaultCurrency: currencyCode, onSave: save) }
        .sheet(item: $editing) { AccountEditor(existing: $0, defaultCurrency: currencyCode, onSave: save) }
    }
    private func save(_ account: FinancialAccount) {
        var updated = accounts
        if let index = updated.firstIndex(where: { $0.id == account.id }) { updated[index] = account } else { updated.append(account) }
        accountsJSON = FinancialAccountStore.encode(updated)
    }
}

private struct AccountEditor: View {
    @Environment(\.dismiss) private var dismiss
    let existing: FinancialAccount?
    let onSave: (FinancialAccount) -> Void
    @State private var name: String
    @State private var type: FinancialAccountType
    @State private var currency: String
    @State private var openingBalance: String
    init(existing: FinancialAccount?, defaultCurrency: String, onSave: @escaping (FinancialAccount) -> Void) {
        self.existing = existing; self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _type = State(initialValue: existing?.type ?? .bank)
        _currency = State(initialValue: existing?.currencyCode ?? defaultCurrency)
        _openingBalance = State(initialValue: existing.map { String(format: "%.2f", $0.openingBalance) } ?? "0")
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name", text: $name).accessibilityIdentifier("accountName")
                Picker("Account Type", selection: $type) { ForEach(FinancialAccountType.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) } }
                Picker("Currency", selection: $currency) { ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) } }
                TextField("Opening Balance", text: $openingBalance).keyboardType(.numbersAndPunctuation)
            }.navigationTitle(existing == nil ? "New Account" : "Edit Account").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("saveAccount") }
                }
        }
    }
    private func save() {
        let balance = Double(openingBalance.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")) ?? 0
        onSave(FinancialAccount(id: existing?.id ?? UUID().uuidString, name: DomainLogic.sanitizedText(name, maximumLength: 50), type: type, currencyCode: currency, openingBalance: balance, isArchived: existing?.isArchived ?? false, isDefault: existing?.isDefault ?? false))
        dismiss()
    }
}
