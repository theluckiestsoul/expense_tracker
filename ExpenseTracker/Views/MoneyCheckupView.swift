import SwiftUI
import SwiftData

struct MoneyCheckupView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage("monthlyBudget") private var monthlyBudget = 0.0
    @State private var editingTransaction: Transaction?

    private var checkup: MoneyCheckupSnapshot {
        MoneyCheckupCalculator.snapshot(
            transactions: transactions,
            monthlyBudget: monthlyBudget,
            currencyCode: currencyCode
        )
    }

    var body: some View {
        List {
            metricSection(
                number: 1, title: "Spending Pace", symbol: "speedometer",
                value: percentText(checkup.spendingPaceChange),
                detail: "Daily spending compared with last month.",
                tint: (checkup.spendingPaceChange ?? 0) <= 0 ? .green : .orange
            )
            metricSection(
                number: 2, title: "Safe Daily Allowance", symbol: "calendar.badge.checkmark",
                value: checkup.safeDailySpend.map { AppFormat.money($0, currencyCode: currencyCode) } ?? "Set a budget",
                detail: "What you can spend per remaining day without exceeding your monthly budget.",
                tint: .blue
            )
            metricSection(
                number: 3, title: "Month-End Projection", symbol: "chart.line.uptrend.xyaxis",
                value: AppFormat.money(checkup.projectedMonthExpenses, currencyCode: currencyCode),
                detail: projectionDetail,
                tint: monthlyBudget > 0 && checkup.projectedMonthExpenses > monthlyBudget ? .orange : .green
            )

            Section {
                if checkup.unusualExpenses.isEmpty {
                    Label("No unusual expenses detected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    ForEach(checkup.unusualExpenses) { transaction in
                        Button { editingTransaction = transaction } label: {
                            transactionLabel(transaction)
                        }.buttonStyle(.plain)
                    }
                }
            } header: { featureHeader(4, "Unusual Expense Watch", "exclamationmark.magnifyingglass") }
              footer: { Text("Compares each expense with earlier transactions in the same category.") }

            metricSection(
                number: 5, title: "Merchant Concentration", symbol: "storefront",
                value: concentrationValue,
                detail: concentrationDetail,
                tint: (checkup.topMerchantShare ?? 0) > 0.4 ? .orange : .purple
            )
            metricSection(
                number: 6, title: "Weekend Premium", symbol: "sun.max",
                value: percentText(checkup.weekendPremium),
                detail: "Difference between average spending on active weekend and weekday days.",
                tint: (checkup.weekendPremium ?? 0) <= 0 ? .green : .orange
            )
            metricSection(
                number: 7, title: "Income Stability", symbol: "waveform.path.ecg",
                value: stabilityValue,
                detail: "Variation in monthly income across up to six recorded months. Lower is steadier.",
                tint: (checkup.incomeVariation ?? 0) < 0.2 ? .green : .orange
            )
            metricSection(
                number: 8, title: "No-Spend Performance", symbol: "moon.stars",
                value: "\(checkup.noSpendDays) of \(checkup.elapsedDays) days",
                detail: "Days this month with no recorded expenses.",
                tint: .indigo
            )

            Section {
                if checkup.incompleteTransactions.isEmpty {
                    Label("All entries are well categorized", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                } else {
                    ForEach(checkup.incompleteTransactions) { transaction in
                        Button { editingTransaction = transaction } label: {
                            transactionLabel(transaction)
                        }.buttonStyle(.plain)
                    }
                }
            } header: { featureHeader(9, "Data Quality Cleanup", "wand.and.stars") }
              footer: { Text("Finds entries with no merchant or a generic Other category. Tap one to fix it.") }

            metricSection(
                number: 10, title: "Savings Consistency", symbol: "chart.bar.fill",
                value: "\(checkup.positiveSavingsMonths) of \(checkup.observedSavingsMonths) months",
                detail: "Recorded months where income was higher than expenses.",
                tint: checkup.positiveSavingsMonths == checkup.observedSavingsMonths ? .green : .blue
            )
        }
        .navigationTitle("Money Checkup")
        .accessibilityIdentifier("moneyCheckup")
        .sheet(item: $editingTransaction) { AddTransactionView(transaction: $0) }
    }

    private var projectionDetail: String {
        guard monthlyBudget > 0 else { return "Estimated from this month’s average daily spending." }
        let difference = monthlyBudget - checkup.projectedMonthExpenses
        return difference >= 0
            ? "On track to finish \(AppFormat.money(difference, currencyCode: currencyCode)) below budget."
            : "At this pace, spending may exceed the budget by \(AppFormat.money(-difference, currencyCode: currencyCode))."
    }
    private var concentrationValue: String {
        guard let name = checkup.topMerchantName, let share = checkup.topMerchantShare else { return "Not enough data" }
        return "\(name) · \(share.formatted(.percent.precision(.fractionLength(0))))"
    }
    private var concentrationDetail: String {
        "Shows how much of this month’s spending went to the top merchant."
    }
    private var stabilityValue: String {
        guard let variation = checkup.incomeVariation else { return "Need 2 months" }
        if variation < 0.1 { return "Very steady" }
        if variation < 0.25 { return "Mostly steady" }
        return "Variable"
    }
    private func percentText(_ value: Double?) -> String {
        guard let value else { return "Not enough data" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }
    private func transactionLabel(_ transaction: Transaction) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.merchant.isEmpty ? transaction.category.displayName : transaction.merchant)
                    .foregroundStyle(.primary)
                Text(transaction.transactionDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(AppFormat.money(transaction.amount, currencyCode: currencyCode))
                .foregroundStyle(.primary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }
    @ViewBuilder private func metricSection(
        number: Int, title: String, symbol: String, value: String, detail: String, tint: Color
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 7) {
                Text(value).font(.title3.bold()).foregroundStyle(tint)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }.padding(.vertical, 3)
        } header: { featureHeader(number, title, symbol) }
    }
    private func featureHeader(_ number: Int, _ title: String, _ symbol: String) -> some View {
        Label("\(number). \(title)", systemImage: symbol)
    }
}
