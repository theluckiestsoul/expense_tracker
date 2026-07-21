import SwiftUI

struct MerchantRulesView: View {
    @AppStorage(MerchantRuleStore.storageKey) private var rulesJSON = ""
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""

    private var rules: [MerchantRule] { MerchantRuleStore.decode(rulesJSON).sorted { $0.updatedAt > $1.updatedAt } }
    private var customCategories: [CustomCategory] { CustomCategoryCatalog.decode(customCategoriesJSON) }

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView("No Merchant Rules", systemImage: "wand.and.stars",
                                       description: Text("Save a transaction with ‘Remember choices for this merchant’ to create a rule."))
            }
            ForEach(rules) { rule in
                let category = CustomCategoryCatalog.presentation(for: rule.categoryID, type: rule.type, custom: customCategories)
                HStack(spacing: 12) {
                    CategoryIcon(category: category)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rule.merchantName).font(.headline)
                        Text("\(rule.type.title) · \(category.name) · \(rule.paymentMethod.displayName)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Merchant Rules")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func delete(at offsets: IndexSet) {
        let removedIDs = Set(offsets.map { rules[$0].id })
        rulesJSON = MerchantRuleStore.encode(rules.filter { !removedIDs.contains($0.id) })
    }
}
