import Foundation

struct CategoryBudget: Codable, Hashable, Identifiable {
    var categoryID: String
    var currencyCode: String
    var amount: Double

    var id: String { "\(currencyCode)|\(categoryID)" }
}

enum CategoryBudgetStore {
    static let storageKey = "categoryBudgetsJSON"

    static func decode(_ json: String) -> [CategoryBudget] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([CategoryBudget].self, from: data)) ?? []
    }

    static func encode(_ budgets: [CategoryBudget]) -> String {
        guard let data = try? JSONEncoder().encode(budgets) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func budget(for categoryID: String, currencyCode: String, in budgets: [CategoryBudget]) -> CategoryBudget? {
        budgets.first { $0.categoryID == categoryID && $0.currencyCode == currencyCode }
    }
}
