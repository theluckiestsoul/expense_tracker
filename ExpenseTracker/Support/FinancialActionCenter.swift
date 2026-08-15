import Foundation

enum FinancialActionKind: String, Equatable {
    case budgetRisk, upcomingBill, unusualExpense, incompleteEntry, savingsGoal
}

struct FinancialAction: Identifiable, Equatable {
    let id: String
    let kind: FinancialActionKind
    let title: String
    let detail: String
    let priority: Int
    let transactionID: UUID?
}

enum FinancialActionCalculator {
    static func actions(
        transactions: [Transaction], monthlyBudget: Double, categoryBudgets: [CategoryBudget],
        schedules: [RecurringTransaction], savingsGoals: [SavingsGoal], currencyCode: String,
        now: Date = .now, calendar: Calendar = .current
    ) -> [FinancialAction] {
        let eligible = transactions.filter {
            !$0.isDeleted && $0.transferID == nil && ($0.currencyCode ?? currencyCode) == currencyCode
        }
        let month = eligible.filter { calendar.isDate($0.transactionDate, equalTo: now, toGranularity: .month) }
        var result: [FinancialAction] = []

        if monthlyBudget > 0 {
            let ratio = month.expenses / monthlyBudget
            if ratio >= 0.8 {
                result.append(.init(id: "monthly-budget", kind: .budgetRisk,
                                    title: ratio >= 1 ? "Monthly budget exceeded" : "Monthly budget is nearly used",
                                    detail: "You have used \(ratio.formatted(.percent.precision(.fractionLength(0)))) of this month’s budget.",
                                    priority: ratio >= 1 ? 100 : 80, transactionID: nil))
            }
        }
        for budget in categoryBudgets where budget.currencyCode == currencyCode && budget.amount > 0 {
            let spent = month.filter { $0.type == .expense && $0.categoryRaw == budget.categoryID }.expenses
            let ratio = spent / budget.amount
            if ratio >= 0.9 {
                result.append(.init(id: "category-\(budget.id)", kind: .budgetRisk,
                                    title: "\(budget.categoryID) budget needs attention",
                                    detail: "\(ratio.formatted(.percent.precision(.fractionLength(0)))) used this month.",
                                    priority: ratio >= 1 ? 95 : 75, transactionID: nil))
            }
        }

        let billEnd = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        for bill in schedules where bill.isActive && bill.type == .expense && bill.currencyCode == currencyCode && bill.nextDate <= billEnd {
            let overdue = bill.nextDate < calendar.startOfDay(for: now)
            result.append(.init(id: "bill-\(bill.id)", kind: .upcomingBill,
                                title: overdue ? "\(bill.name) may be overdue" : "\(bill.name) is due soon",
                                detail: "Due \(bill.nextDate.formatted(date: .abbreviated, time: .omitted)) · \(AppFormat.money(bill.amount, currencyCode: currencyCode))",
                                priority: overdue ? 90 : 65, transactionID: nil))
        }

        for transaction in ReportCalculator.unusualExpenses(candidates: month, history: eligible).prefix(3) {
            result.append(.init(id: "unusual-\(transaction.id)", kind: .unusualExpense,
                                title: "Review unusual expense",
                                detail: "\(transaction.merchant.isEmpty ? transaction.categoryRaw : transaction.merchant) · \(AppFormat.money(transaction.amount, currencyCode: currencyCode))",
                                priority: 70, transactionID: transaction.id))
        }

        if let transaction = eligible.filter({
            $0.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            $0.categoryRaw == ExpenseCategory.other.rawValue || $0.categoryRaw == ExpenseCategory.otherIncome.rawValue
        }).max(by: { $0.transactionDate < $1.transactionDate }) {
            result.append(.init(id: "cleanup-\(transaction.id)", kind: .incompleteEntry,
                                title: "Complete a transaction",
                                detail: "Add a merchant or specific category to improve reports.",
                                priority: 45, transactionID: transaction.id))
        }

        let goalEnd = calendar.date(byAdding: .day, value: 30, to: now) ?? now
        for goal in savingsGoals where goal.currencyCode == currencyCode && goal.remaining > 0 {
            guard let targetDate = goal.targetDate, targetDate <= goalEnd else { continue }
            let overdue = targetDate < calendar.startOfDay(for: now)
            result.append(.init(id: "goal-\(goal.id)", kind: .savingsGoal,
                                title: overdue ? "\(goal.name) target date passed" : "\(goal.name) is due soon",
                                detail: "\(AppFormat.money(goal.remaining, currencyCode: currencyCode)) still needed.",
                                priority: overdue ? 60 : 40, transactionID: nil))
        }
        return result.sorted {
            if $0.priority == $1.priority { return $0.title < $1.title }
            return $0.priority > $1.priority
        }
    }
}
