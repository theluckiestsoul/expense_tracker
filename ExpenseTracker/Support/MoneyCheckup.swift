import Foundation

struct MoneyCheckupSnapshot {
    let monthExpenses: Double
    let previousMonthExpenses: Double
    let spendingPaceChange: Double?
    let safeDailySpend: Double?
    let projectedMonthExpenses: Double
    let unusualExpenses: [Transaction]
    let topMerchantName: String?
    let topMerchantShare: Double?
    let weekendPremium: Double?
    let incomeVariation: Double?
    let noSpendDays: Int
    let elapsedDays: Int
    let incompleteTransactions: [Transaction]
    let positiveSavingsMonths: Int
    let observedSavingsMonths: Int
}

enum MoneyCheckupCalculator {
    static func snapshot(
        transactions: [Transaction],
        monthlyBudget: Double,
        currencyCode: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MoneyCheckupSnapshot {
        let eligible = transactions.filter {
            !$0.isDeleted && $0.transferID == nil && ($0.currencyCode ?? currencyCode) == currencyCode
        }
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let previousDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let previousInterval = calendar.dateInterval(of: .month, for: previousDate)
        let month = eligible.filter { monthInterval?.contains($0.transactionDate) == true }
        let previousMonth = eligible.filter { previousInterval?.contains($0.transactionDate) == true }
        let monthExpenses = month.expenses
        let previousExpenses = previousMonth.expenses
        let elapsedDays = max(1, calendar.component(.day, from: now))
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? elapsedDays
        let remainingDays = max(1, daysInMonth - elapsedDays + 1)
        let projected = monthExpenses / Double(elapsedDays) * Double(daysInMonth)
        let safeDaily = monthlyBudget > 0 ? max(0, monthlyBudget - monthExpenses) / Double(remainingDays) : nil

        let merchantTotals = ReportCalculator.merchantSpending(transactions: month)
        let topMerchant = merchantTotals.first
        let topMerchantShare = topMerchant.flatMap { monthExpenses > 0 ? $0.amount / monthExpenses : nil }

        let expenses = month.filter { $0.type == .expense }
        let weekend = expenses.filter { calendar.isDateInWeekend($0.transactionDate) }
        let weekday = expenses.filter { !calendar.isDateInWeekend($0.transactionDate) }
        let weekendAverage = averageDailySpend(weekend, calendar: calendar)
        let weekdayAverage = averageDailySpend(weekday, calendar: calendar)
        let weekendPremium = weekdayAverage > 0 ? (weekendAverage - weekdayAverage) / weekdayAverage : nil

        let expenseDays = Set(expenses.map { calendar.startOfDay(for: $0.transactionDate) })
        let noSpendDays = max(0, elapsedDays - expenseDays.count)

        let incomplete = eligible.filter {
            $0.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            $0.categoryRaw == ExpenseCategory.other.rawValue ||
            $0.categoryRaw == ExpenseCategory.otherIncome.rawValue
        }.sorted { $0.transactionDate > $1.transactionDate }

        let monthlyGroups = Dictionary(grouping: eligible) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.transactionDate)) ?? $0.transactionDate
        }
        let recentMonths = monthlyGroups.keys.sorted(by: >).prefix(6)
        let savings = recentMonths.map { date -> Double in
            let values = monthlyGroups[date] ?? []
            return values.income - values.expenses
        }
        let monthlyIncome = recentMonths.map { date in (monthlyGroups[date] ?? []).income }.filter { $0 > 0 }
        let incomeVariation: Double? = {
            guard monthlyIncome.count >= 2 else { return nil }
            let mean = monthlyIncome.reduce(0, +) / Double(monthlyIncome.count)
            guard mean > 0 else { return nil }
            let variance = monthlyIncome.reduce(0) { $0 + pow($1 - mean, 2) } / Double(monthlyIncome.count)
            return sqrt(variance) / mean
        }()

        return MoneyCheckupSnapshot(
            monthExpenses: monthExpenses,
            previousMonthExpenses: previousExpenses,
            spendingPaceChange: ReportCalculator.percentageChange(current: monthExpenses / Double(elapsedDays),
                                                                  previous: previousExpenses / Double(daysInMonth)),
            safeDailySpend: safeDaily,
            projectedMonthExpenses: projected,
            unusualExpenses: Array(ReportCalculator.unusualExpenses(candidates: month, history: eligible).prefix(5)),
            topMerchantName: topMerchant?.merchantName,
            topMerchantShare: topMerchantShare,
            weekendPremium: weekendPremium,
            incomeVariation: incomeVariation,
            noSpendDays: noSpendDays,
            elapsedDays: elapsedDays,
            incompleteTransactions: Array(incomplete.prefix(20)),
            positiveSavingsMonths: savings.filter { $0 > 0 }.count,
            observedSavingsMonths: savings.count
        )
    }

    private static func averageDailySpend(_ transactions: [Transaction], calendar: Calendar) -> Double {
        let groups = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.transactionDate) }
        guard !groups.isEmpty else { return 0 }
        return transactions.expenses / Double(groups.count)
    }
}
