import Foundation

struct SavingsGoal: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var targetAmount: Double
    var savedAmount: Double
    var currencyCode: String
    var targetDate: Date?

    var progress: Double { DomainLogic.budgetProgress(spent: savedAmount, budget: targetAmount) }
    var remaining: Double { max(targetAmount - savedAmount, 0) }
}

enum SavingsGoalStore {
    static let storageKey = "savingsGoalsJSON"

    static func decode(_ json: String) -> [SavingsGoal] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([SavingsGoal].self, from: data)) ?? []
    }

    static func encode(_ goals: [SavingsGoal]) -> String {
        guard let data = try? JSONEncoder().encode(goals) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
