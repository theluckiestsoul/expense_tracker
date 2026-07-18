import Foundation
import SwiftUI

struct CustomCategory: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var type: TransactionType
    var symbol: String
    var colorName: String
    var isArchived: Bool

    init(id: String = "custom:\(UUID().uuidString)", name: String, type: TransactionType, symbol: String, colorName: String, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.symbol = symbol
        self.colorName = colorName
        self.isArchived = isArchived
    }
}

struct CategoryPresentation: Identifiable, Hashable {
    let id: String
    let name: String
    let type: TransactionType
    let symbol: String
    let colorName: String
    let isCustom: Bool
}

enum CustomCategoryCatalog {
    static let storageKey = "customCategoriesJSON"
    static let symbols = ["tag.fill", "cart.fill", "fork.knife", "car.fill", "house.fill", "heart.fill", "gift.fill", "briefcase.fill", "graduationcap.fill", "airplane", "pawprint.fill", "gamecontroller.fill", "dumbbell.fill", "creditcard.fill", "star.fill"]
    static let colors = ["indigo", "blue", "teal", "green", "orange", "pink", "purple", "red", "brown", "gray"]

    static func decode(_ json: String) -> [CustomCategory] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([CustomCategory].self, from: data)) ?? []
    }

    static func encode(_ categories: [CustomCategory]) -> String {
        guard let data = try? JSONEncoder().encode(categories) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func options(for type: TransactionType, custom: [CustomCategory], includeArchivedID: String? = nil) -> [CategoryPresentation] {
        let builtIn = ExpenseCategory.cases(for: type).map { $0.presentation }
        let userDefined = custom.filter { $0.type == type && (!$0.isArchived || $0.id == includeArchivedID) }.map(\.presentation)
        return builtIn + userDefined.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func presentation(for rawValue: String, type: TransactionType, custom: [CustomCategory]) -> CategoryPresentation {
        if let builtIn = ExpenseCategory(rawValue: rawValue), ExpenseCategory.cases(for: type).contains(builtIn) { return builtIn.presentation }
        if let category = custom.first(where: { $0.id == rawValue }) { return category.presentation }
        return (type == .income ? ExpenseCategory.otherIncome : ExpenseCategory.other).presentation
    }
}

extension ExpenseCategory {
    var presentation: CategoryPresentation {
        CategoryPresentation(id: rawValue, name: displayName, type: isIncome ? .income : .expense, symbol: symbol, colorName: isIncome ? "green" : "indigo", isCustom: false)
    }
}

extension CustomCategory {
    var presentation: CategoryPresentation {
        CategoryPresentation(id: id, name: name, type: type, symbol: symbol, colorName: colorName, isCustom: true)
    }
}

extension Color {
    static func category(_ name: String) -> Color {
        switch name {
        case "blue": .blue; case "teal": .teal; case "green": .green; case "orange": .orange
        case "pink": .pink; case "purple": .purple; case "red": .red; case "brown": .brown
        case "gray": .gray; default: .indigo
        }
    }
}
