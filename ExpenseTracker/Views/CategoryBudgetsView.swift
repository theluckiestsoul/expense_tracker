import SwiftUI

struct CategoryBudgetsView: View {
    @AppStorage(CategoryBudgetStore.storageKey) private var budgetsJSON = ""
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @State private var editingCategory: CategoryPresentation?

    private var budgets: [CategoryBudget] { CategoryBudgetStore.decode(budgetsJSON) }
    private var categories: [CategoryPresentation] {
        CustomCategoryCatalog.options(for: .expense, custom: CustomCategoryCatalog.decode(customCategoriesJSON))
    }

    var body: some View {
        List(categories) { category in
            Button { editingCategory = category } label: {
                HStack(spacing: 12) {
                    CategoryIcon(category: category)
                    Text(category.name).foregroundStyle(.primary)
                    Spacer()
                    if let budget = CategoryBudgetStore.budget(for: category.id, currencyCode: currencyCode, in: budgets) {
                        Text(AppFormat.money(budget.amount, currencyCode: currencyCode)).foregroundStyle(.secondary)
                    } else {
                        Text("Set Budget").foregroundStyle(.indigo)
                    }
                }
            }
            .accessibilityIdentifier("categoryBudget_\(category.id)")
        }
        .navigationTitle("Category Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Text("Monthly limits in \(currencyCode)").font(.footnote).foregroundStyle(.secondary).padding(8)
        }
        .sheet(item: $editingCategory) { category in
            CategoryBudgetEditor(category: category, currencyCode: currencyCode,
                                 existing: CategoryBudgetStore.budget(for: category.id, currencyCode: currencyCode, in: budgets)) { amount in
                save(amount: amount, for: category.id)
            }
        }
    }

    private func save(amount: Double?, for categoryID: String) {
        var updated = budgets.filter { !($0.categoryID == categoryID && $0.currencyCode == currencyCode) }
        if let amount { updated.append(CategoryBudget(categoryID: categoryID, currencyCode: currencyCode, amount: amount)) }
        budgetsJSON = CategoryBudgetStore.encode(updated)
    }
}

private struct CategoryBudgetEditor: View {
    @Environment(\.dismiss) private var dismiss
    let category: CategoryPresentation
    let currencyCode: String
    let existing: CategoryBudget?
    let onSave: (Double?) -> Void
    @State private var amount: String
    @FocusState private var amountFocused: Bool

    init(category: CategoryPresentation, currencyCode: String, existing: CategoryBudget?, onSave: @escaping (Double?) -> Void) {
        self.category = category; self.currencyCode = currencyCode; self.existing = existing; self.onSave = onSave
        _amount = State(initialValue: existing.map { String(format: "%.2f", $0.amount) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Category", value: category.name)
                HStack {
                    Text(currencyCode).foregroundStyle(.secondary)
                    TextField("Monthly Limit", text: $amount)
                        .keyboardType(.decimalPad).focused($amountFocused)
                        .accessibilityIdentifier("categoryBudgetAmount")
                }
                if existing != nil { Button("Remove Budget", role: .destructive) { onSave(nil); dismiss() } }
            }
            .navigationTitle("Monthly Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if let value = DomainLogic.parseAmount(amount) { onSave(value); dismiss() } }
                        .disabled(DomainLogic.parseAmount(amount) == nil)
                        .accessibilityIdentifier("saveCategoryBudget")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { amountFocused = false } }
            }
            .onAppear { amountFocused = true }
        }
    }
}
