import SwiftUI

struct BudgetWorkspacesView: View {
    @AppStorage(BudgetWorkspaceStore.storageKey) private var workspacesJSON = ""
    @AppStorage(EnvelopeStore.storageKey) private var envelopesJSON = ""
    @AppStorage("currencyCode") private var defaultCurrency = CurrencyCatalog.defaultCode
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @State private var addingBudget = false
    @State private var editingEnvelope: EnvelopeAllocation?

    private var workspaces: [BudgetWorkspace] { BudgetWorkspaceStore.decode(workspacesJSON) }
    private var envelopes: [EnvelopeAllocation] { EnvelopeStore.decode(envelopesJSON) }
    private var categories: [CategoryPresentation] {
        CustomCategoryCatalog.options(for: .expense, custom: CustomCategoryCatalog.decode(customCategoriesJSON))
    }

    var body: some View {
        List {
            Section("Budgets") {
                if workspaces.isEmpty {
                    Text("Create separate budgets for household, travel, work, or events.")
                        .foregroundStyle(.secondary)
                }
                ForEach(workspaces) { budget in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(budget.name).font(.headline)
                            Spacer()
                            Text(AppFormat.money(budget.amount + budget.carriedAmount, currencyCode: budget.currencyCode))
                        }
                        if budget.rolloverEnabled {
                            Label("Unused amount rolls into the next month", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.onDelete { offsets in
                    var values = workspaces; values.remove(atOffsets: offsets)
                    workspacesJSON = BudgetWorkspaceStore.encode(values)
                }
                Button("Add Budget", systemImage: "plus") { addingBudget = true }
                    .accessibilityIdentifier("addBudgetWorkspace")
            }
            Section("Envelope Allocations") {
                Text("Allocate planned money to individual spending categories.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(categories) { category in
                    let envelope = envelopes.first { $0.categoryID == category.id && $0.currencyCode == defaultCurrency }
                    Button {
                        editingEnvelope = envelope ?? EnvelopeAllocation(
                            categoryID: category.id, currencyCode: defaultCurrency, allocatedAmount: 0)
                    } label: {
                        HStack {
                            Label(category.name, systemImage: category.symbol)
                            Spacer()
                            Text(AppFormat.money(envelope?.allocatedAmount ?? 0, currencyCode: defaultCurrency))
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Budgets & Envelopes")
        .sheet(isPresented: $addingBudget) {
            BudgetWorkspaceEditor(defaultCurrency: defaultCurrency) {
                workspacesJSON = BudgetWorkspaceStore.encode(workspaces + [$0]); addingBudget = false
            }
        }
        .sheet(item: $editingEnvelope) { envelope in
            EnvelopeEditor(envelope: envelope) { updated in
                envelopesJSON = EnvelopeStore.encode(envelopes.filter { $0.id != updated.id } + [updated])
                editingEnvelope = nil
            }
        }
    }
}

private struct BudgetWorkspaceEditor: View {
    @Environment(\.dismiss) private var dismiss
    let defaultCurrency: String
    let onSave: (BudgetWorkspace) -> Void
    @State private var name = ""
    @State private var amount = ""
    @State private var currencyCode: String
    @State private var rollover = false

    init(defaultCurrency: String, onSave: @escaping (BudgetWorkspace) -> Void) {
        self.defaultCurrency = defaultCurrency; self.onSave = onSave
        _currencyCode = State(initialValue: defaultCurrency)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Budget name", text: $name)
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                Picker("Currency", selection: $currencyCode) {
                    ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) }
                }
                Toggle("Roll over unused amount", isOn: $rollover)
            }
            .navigationTitle("New Budget").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = DomainLogic.parseAmount(amount) else { return }
                        onSave(BudgetWorkspace(name: DomainLogic.sanitizedText(name, maximumLength: 40),
                                               amount: value, currencyCode: currencyCode,
                                               categoryIDs: [], rolloverEnabled: rollover))
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                               DomainLogic.parseAmount(amount) == nil)
                }
            }
        }
    }
}

private struct EnvelopeEditor: View {
    @Environment(\.dismiss) private var dismiss
    let envelope: EnvelopeAllocation
    let onSave: (EnvelopeAllocation) -> Void
    @State private var amount: String

    init(envelope: EnvelopeAllocation, onSave: @escaping (EnvelopeAllocation) -> Void) {
        self.envelope = envelope; self.onSave = onSave
        _amount = State(initialValue: envelope.allocatedAmount > 0 ? String(envelope.allocatedAmount) : "")
    }

    var body: some View {
        NavigationStack {
            Form { TextField("Allocated amount", text: $amount).keyboardType(.decimalPad) }
                .navigationTitle("Envelope").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let value = DomainLogic.parseAmount(amount) else { return }
                            var updated = envelope; updated.allocatedAmount = value; onSave(updated)
                        }.disabled(DomainLogic.parseAmount(amount) == nil)
                    }
                }
        }
    }
}
