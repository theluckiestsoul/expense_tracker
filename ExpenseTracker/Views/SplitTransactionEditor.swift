import SwiftUI

struct SplitTransactionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    let total: Double
    let currencyCode: String
    let onSave: ([TransactionSplit]) -> Void
    @State private var splits: [TransactionSplit]

    init(total: Double, currencyCode: String, initialSplits: [TransactionSplit],
         onSave: @escaping ([TransactionSplit]) -> Void) {
        self.total = total; self.currencyCode = currencyCode; self.onSave = onSave
        _splits = State(initialValue: initialSplits.isEmpty
                        ? [TransactionSplit(categoryID: ExpenseCategory.food.rawValue, amount: total)]
                        : initialSplits)
    }

    private var categories: [CategoryPresentation] {
        CustomCategoryCatalog.options(for: .expense, custom: CustomCategoryCatalog.decode(customCategoriesJSON))
    }
    private var allocated: Double { splits.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Transaction Total", value: AppFormat.money(total, currencyCode: currencyCode))
                    LabeledContent("Allocated", value: AppFormat.money(allocated, currencyCode: currencyCode))
                    LabeledContent("Remaining", value: AppFormat.money(total - allocated, currencyCode: currencyCode))
                }
                Section("Categories") {
                    ForEach($splits) { $split in
                        VStack {
                            Picker("Category", selection: $split.categoryID) {
                                ForEach(categories) { Text($0.name).tag($0.id) }
                            }
                            TextField("Amount", value: $split.amount, format: .number)
                                .keyboardType(.decimalPad)
                        }
                    }.onDelete { splits.remove(atOffsets: $0) }
                    Button("Add Split", systemImage: "plus") {
                        splits.append(TransactionSplit(categoryID: ExpenseCategory.other.rawValue,
                                                       amount: max(total - allocated, 0)))
                    }
                }
            }
            .navigationTitle("Split Transaction").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(splits); dismiss() }
                        .disabled(!TransactionMetadata.validSplits(splits, total: total))
                        .accessibilityIdentifier("saveTransactionSplits")
                }
            }
        }
    }
}
