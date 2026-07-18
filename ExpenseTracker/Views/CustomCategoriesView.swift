import SwiftUI

struct CustomCategoriesView: View {
    @AppStorage(CustomCategoryCatalog.storageKey) private var categoriesJSON = ""
    @State private var editing: CustomCategory?
    @State private var addingType: TransactionType?

    private var categories: [CustomCategory] { CustomCategoryCatalog.decode(categoriesJSON) }

    var body: some View {
        List {
            ForEach(TransactionType.allCases) { type in
                Section {
                    let matching = categories.filter { $0.type == type }
                    if matching.isEmpty {
                        Text("No custom categories").foregroundStyle(.secondary)
                    }
                    ForEach(matching) { category in
                        Button { editing = category } label: {
                            HStack {
                                Image(systemName: category.symbol).foregroundStyle(.white).frame(width: 34, height: 34)
                                    .background(Color.category(category.colorName), in: RoundedRectangle(cornerRadius: 9))
                                Text(category.name).foregroundStyle(.primary)
                                Spacer()
                                if category.isArchived { Text("Archived").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        .swipeActions {
                            Button(category.isArchived ? "Restore" : "Archive") { setArchived(category, !category.isArchived) }
                                .tint(category.isArchived ? .green : .orange)
                        }
                    }
                    Button("Add \(type.title) Category", systemImage: "plus") { addingType = type }
                        .accessibilityIdentifier("addCustomCategory_\(type.rawValue)")
                } header: { Text(type.title) }
            }
        }
        .navigationTitle("Custom Categories")
        .sheet(item: $addingType) { CategoryEditorView(type: $0, existing: nil, existingCategories: categories, onSave: save) }
        .sheet(item: $editing) { CategoryEditorView(type: $0.type, existing: $0, existingCategories: categories, onSave: save) }
    }

    private func save(_ category: CustomCategory) {
        var updated = categories
        if let index = updated.firstIndex(where: { $0.id == category.id }) { updated[index] = category }
        else { updated.append(category) }
        categoriesJSON = CustomCategoryCatalog.encode(updated)
    }

    private func setArchived(_ category: CustomCategory, _ archived: Bool) {
        var updated = categories
        guard let index = updated.firstIndex(where: { $0.id == category.id }) else { return }
        updated[index].isArchived = archived
        categoriesJSON = CustomCategoryCatalog.encode(updated)
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let type: TransactionType
    let existing: CustomCategory?
    let existingCategories: [CustomCategory]
    let onSave: (CustomCategory) -> Void
    @State private var name: String
    @State private var symbol: String
    @State private var colorName: String
    @State private var errorMessage: String?

    init(type: TransactionType, existing: CustomCategory?, existingCategories: [CustomCategory], onSave: @escaping (CustomCategory) -> Void) {
        self.type = type; self.existing = existing; self.existingCategories = existingCategories; self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _symbol = State(initialValue: existing?.symbol ?? CustomCategoryCatalog.symbols[0])
        _colorName = State(initialValue: existing?.colorName ?? (type == .income ? "green" : "indigo"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $name).textInputAutocapitalization(.words)
                        .accessibilityIdentifier("customCategoryName")
                    Picker("Icon", selection: $symbol) {
                        ForEach(CustomCategoryCatalog.symbols, id: \.self) { Image(systemName: $0).tag($0) }
                    }
                    Picker("Color", selection: $colorName) {
                        ForEach(CustomCategoryCatalog.colors, id: \.self) { color in
                            Label(color.capitalized, systemImage: "circle.fill").foregroundStyle(Color.category(color)).tag(color)
                        }
                    }
                }
                Section("Preview") {
                    HStack {
                        Image(systemName: symbol).foregroundStyle(.white).frame(width: 38, height: 38)
                            .background(Color.category(colorName), in: RoundedRectangle(cornerRadius: 11))
                        Text(name.isEmpty ? "Category Name" : name)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("saveCustomCategory") }
            }
            .alert("Couldn’t Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "Unknown error") }
        }
    }

    private func save() {
        let cleanName = DomainLogic.sanitizedText(name, maximumLength: 40)
        let conflictsWithCustom = existingCategories.contains { $0.type == type && $0.id != existing?.id && $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame }
        let conflictsWithBuiltIn = ExpenseCategory.cases(for: type).contains { $0.rawValue.localizedCaseInsensitiveCompare(cleanName) == .orderedSame || $0.displayName.localizedCaseInsensitiveCompare(cleanName) == .orderedSame }
        guard !conflictsWithCustom, !conflictsWithBuiltIn else {
            errorMessage = "A category with this name already exists."
            return
        }
        onSave(CustomCategory(id: existing?.id ?? "custom:\(UUID().uuidString)", name: cleanName, type: type, symbol: symbol, colorName: colorName, isArchived: existing?.isArchived ?? false))
        dismiss()
    }
}
