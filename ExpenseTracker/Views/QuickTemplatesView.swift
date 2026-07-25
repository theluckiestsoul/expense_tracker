import SwiftUI

struct QuickTemplatesView: View {
    @AppStorage(TransactionTemplateStore.storageKey) private var templatesJSON = ""
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @State private var selectedTemplate: TransactionTemplate?

    private var templates: [TransactionTemplate] { TransactionTemplateStore.decode(templatesJSON) }
    private var customCategories: [CustomCategory] { CustomCategoryCatalog.decode(customCategoriesJSON) }

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView("No Quick Templates", systemImage: "bolt.badge.plus",
                                       description: Text("Save a transaction as a template to reuse it in one tap."))
            } else {
                ForEach(templates) { template in
                    Button { selectedTemplate = template } label: {
                        HStack(spacing: 12) {
                            CategoryIcon(category: CustomCategoryCatalog.presentation(
                                for: template.categoryID, type: template.type, custom: customCategories))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.name).font(.headline).foregroundStyle(.primary)
                                Text(template.merchant.isEmpty ? template.type.title : template.merchant)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(AppFormat.money(template.amount, currencyCode: template.currencyCode))
                                .fontWeight(.semibold).foregroundStyle(.primary)
                        }
                    }.buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Quick Templates")
        .sheet(item: $selectedTemplate) { AddTransactionView(template: $0) }
    }

    private func delete(at offsets: IndexSet) {
        var updated = templates
        updated.remove(atOffsets: offsets)
        templatesJSON = TransactionTemplateStore.encode(updated)
    }
}
