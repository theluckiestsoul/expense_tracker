import SwiftUI
import SwiftData

private struct InsightTotal: Identifiable {
    let name: String
    let amount: Double
    var id: String { name }
}

struct AdvancedInsightsView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage("monthlyBudget") private var monthlyBudget = 0.0
    @AppStorage(RecurringTransactionStore.storageKey) private var schedulesJSON = ""

    private var eligible: [Transaction] {
        transactions.filter { !$0.isDeleted && $0.transferID == nil && ($0.currencyCode ?? currencyCode) == currencyCode }
    }
    private var currentYear: [Transaction] { eligible.filter { Calendar.current.isDate($0.transactionDate, equalTo: .now, toGranularity: .year) } }
    private var last30: [Transaction] {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        return eligible.filter { $0.transactionDate >= start }
    }
    private var healthScore: Int {
        let savings = ReportCalculator.savingsRate(income: last30.income, expenses: last30.expenses) ?? -1
        let savingsPoints = max(0, min(50, Int((savings + 0.1) * 100)))
        let budgetPoints = monthlyBudget > 0 ? max(0, min(35, Int((1 - last30.expenses / monthlyBudget) * 35))) : 15
        let trackingPoints = min(15, last30.count)
        return savingsPoints + budgetPoints + trackingPoints
    }
    private var noSpendStreak: Int {
        let expenseDays = Set(eligible.filter { $0.type == .expense }.map { Calendar.current.startOfDay(for: $0.transactionDate) })
        var count = 0; var day = Calendar.current.startOfDay(for: .now)
        while !expenseDays.contains(day), count < 366 {
            count += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
    private var weekdayTotals: [InsightTotal] {
        let symbols = Calendar.current.weekdaySymbols
        return Dictionary(grouping: eligible.filter { $0.type == .expense }) {
            symbols[Calendar.current.component(.weekday, from: $0.transactionDate) - 1]
        }.map { InsightTotal(name: $0.key, amount: $0.value.expenses) }.sorted { $0.amount > $1.amount }
    }
    private var tagTotals: [InsightTotal] {
        var totals: [String: Double] = [:]
        eligible.filter { $0.type == .expense }.forEach { transaction in
            transaction.tags.forEach { totals[$0, default: 0] += transaction.amount }
        }
        return totals.map { InsightTotal(name: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }
    private var subscriptions: [InsightTotal] {
        Dictionary(grouping: eligible.filter { $0.type == .expense && !$0.merchant.isEmpty },
                   by: { MerchantRuleStore.normalizedKey($0.merchant) })
            .compactMap { _, items in
                guard items.count >= 3, let name = items.first?.merchant else { return nil }
                let amounts = items.map(\.amount)
                let average = amounts.reduce(0, +) / Double(amounts.count)
                guard amounts.allSatisfy({ abs($0 - average) <= max(average * 0.2, 1) }) else { return nil }
                return InsightTotal(name: name, amount: average)
            }.sorted { $0.amount > $1.amount }
    }
    private var priceChanges: [InsightTotal] {
        Dictionary(grouping: eligible.filter { $0.type == .expense && !$0.merchant.isEmpty },
                   by: { MerchantRuleStore.normalizedKey($0.merchant) })
            .compactMap { _, items in
                let sorted = items.sorted { $0.transactionDate > $1.transactionDate }
                guard sorted.count >= 3, let latest = sorted.first else { return nil }
                let prior = sorted.dropFirst().map(\.amount)
                let average = prior.reduce(0, +) / Double(prior.count)
                guard latest.amount > average * 1.2 else { return nil }
                return InsightTotal(name: latest.merchant, amount: latest.amount - average)
            }.sorted { $0.amount > $1.amount }
    }
    private var recommendations: [InsightTotal] {
        let start = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .distantPast
        return Dictionary(grouping: eligible.filter { $0.type == .expense && $0.transactionDate >= start }, by: \.categoryRaw)
            .map { InsightTotal(name: $0.key, amount: ceil(($0.value.expenses / 3) * 1.1)) }
            .sorted { $0.amount > $1.amount }
    }
    private var forecast: (income: Double, expense: Double) {
        let dailyIncome = last30.income / 30
        let dailyExpense = last30.expenses / 30
        let end = Calendar.current.date(byAdding: .day, value: 90, to: .now) ?? .now
        let scheduled = RecurringTransactionStore.decode(schedulesJSON).filter {
            $0.isActive && $0.currencyCode == currencyCode && $0.nextDate <= end
        }
        return (dailyIncome * 90 + scheduled.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
                dailyExpense * 90 + scheduled.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount })
    }

    var body: some View {
        List {
            Section("Financial Health") {
                LabeledContent("Health Score", value: "\(healthScore)/100")
                LabeledContent("No-Spend Streak", value: "\(noSpendStreak) day\(noSpendStreak == 1 ? "" : "s")")
                ProgressView(value: Double(healthScore), total: 100)
            }
            Section("90-Day Forecast") {
                LabeledContent("Projected Income", value: AppFormat.money(forecast.income, currencyCode: currencyCode))
                LabeledContent("Projected Expenses", value: AppFormat.money(forecast.expense, currencyCode: currencyCode))
                LabeledContent("Projected Net", value: AppFormat.money(forecast.income - forecast.expense, currencyCode: currencyCode))
            }
            Section("This Year") {
                LabeledContent("Income", value: AppFormat.money(currentYear.income, currencyCode: currencyCode))
                LabeledContent("Expenses", value: AppFormat.money(currentYear.expenses, currencyCode: currencyCode))
                LabeledContent("Savings", value: AppFormat.money(currentYear.income - currentYear.expenses, currencyCode: currencyCode))
            }
            insightSection("Possible Subscriptions", values: subscriptions, detail: "estimated payment")
            insightSection("Price Increases", values: priceChanges, detail: "above prior average")
            insightSection("Suggested Monthly Category Budgets", values: recommendations, detail: "recommended")
            insightSection("Spending by Weekday", values: weekdayTotals, detail: "spent")
            insightSection("Spending by Tag", values: tagTotals, detail: "spent")
            Section("Explore") {
                NavigationLink("Merchant Details") { MerchantDirectoryView() }
                NavigationLink("Bill Calendar") { BillCalendarView() }
            }
        }
        .navigationTitle("Financial Insights")
        .accessibilityIdentifier("advancedInsights")
    }

    @ViewBuilder private func insightSection(_ title: String, values: [InsightTotal], detail: String) -> some View {
        if !values.isEmpty {
            Section(title) {
                ForEach(values.prefix(6)) {
                    LabeledContent($0.name, value: "\(AppFormat.money($0.amount, currencyCode: currencyCode)) \(detail)")
                }
            }
        }
    }
}

private struct MerchantDirectoryView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    private var merchants: [MerchantSpending] {
        ReportCalculator.merchantSpending(transactions: transactions.filter {
            !$0.isDeleted && ($0.currencyCode ?? currencyCode) == currencyCode
        })
    }
    var body: some View {
        List(merchants) { merchant in
            NavigationLink {
                MerchantDetailView(key: merchant.merchantKey, name: merchant.merchantName)
            } label: {
                LabeledContent(merchant.merchantName,
                               value: AppFormat.money(merchant.amount, currencyCode: currencyCode))
            }
        }.navigationTitle("Merchants")
    }
}

private struct MerchantDetailView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    let key: String
    let name: String
    private var matching: [Transaction] {
        transactions.filter { !$0.isDeleted && MerchantRuleStore.normalizedKey($0.merchant) == key }
            .sorted { $0.transactionDate > $1.transactionDate }
    }
    var body: some View {
        List {
            Section {
                LabeledContent("Total", value: AppFormat.money(matching.expenses, currencyCode: currencyCode))
                LabeledContent("Visits", value: "\(matching.count)")
                LabeledContent("Average", value: AppFormat.money(matching.isEmpty ? 0 : matching.expenses / Double(matching.count), currencyCode: currencyCode))
            }
            Section("Transactions") { ForEach(matching) { TransactionRow(transaction: $0) } }
        }.navigationTitle(name)
    }
}

private struct BillCalendarView: View {
    @AppStorage(RecurringTransactionStore.storageKey) private var schedulesJSON = ""
    private var schedules: [RecurringTransaction] {
        RecurringTransactionStore.decode(schedulesJSON).filter(\.isActive).sorted { $0.nextDate < $1.nextDate }
    }
    var body: some View {
        List(schedules) {
            LabeledContent($0.name, value: $0.nextDate.formatted(date: .abbreviated, time: .omitted))
        }.navigationTitle("Bill Calendar")
    }
}
