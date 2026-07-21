import SwiftUI
import SwiftData
import Charts

struct CategorySpend: Identifiable { let category: CategoryPresentation; let amount: Double; var id: String { category.id } }

struct ReportsView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @State private var selectedType: TransactionType = .expense
    @State private var period: ReportPeriod = .month
    @State private var insightTransaction: Transaction?

    private var eligibleTransactions: [Transaction] {
        transactions.filter { $0.transferID == nil && ($0.currencyCode ?? currencyCode) == currencyCode }
    }

    private var periodTransactions: [Transaction] {
        eligibleTransactions.filter { period.includes($0.transactionDate) }
    }
    private var previousTransactions: [Transaction] {
        eligibleTransactions.filter { period.includes($0.transactionDate, offset: -1) }
    }
    private var selectedTransactions: [Transaction] { periodTransactions.filter { $0.type == selectedType } }
    private var customCategories: [CustomCategory] { CustomCategoryCatalog.decode(customCategoriesJSON) }
    private var categories: [CategorySpend] {
        Dictionary(grouping: selectedTransactions) { $0.categoryPresentation(customCategories: customCategories) }
            .map { CategorySpend(category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    private var cashFlow: [CashFlowPoint] { ReportCalculator.cashFlow(transactions: periodTransactions, period: period) }
    private var savingsRate: Double? { ReportCalculator.savingsRate(income: periodTransactions.income, expenses: periodTransactions.expenses) }
    private var largestCategoryIncrease: CategorySpendingChange? {
        ReportCalculator.categoryIncreases(current: periodTransactions, previous: previousTransactions).first
    }
    private var unusualExpenses: [Transaction] {
        Array(ReportCalculator.unusualExpenses(candidates: periodTransactions, history: eligibleTransactions).prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Report Period", selection: $period) {
                        ForEach(ReportPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("reportPeriodPicker")

                    HStack(spacing: 12) {
                        totalCard(title: "Expense", amount: periodTransactions.expenses, color: .red)
                        totalCard(title: "Income", amount: periodTransactions.income, color: .green)
                    }
                    HStack(spacing: 12) {
                        totalCard(title: "Net", amount: periodTransactions.income - periodTransactions.expenses,
                                  color: periodTransactions.income >= periodTransactions.expenses ? .green : .red)
                        rateCard
                    }

                    if period != .all {
                        Text("Compared with Previous \(period.title)").font(.headline)
                        HStack(spacing: 12) {
                            comparisonCard(title: "Spending", current: periodTransactions.expenses,
                                           previous: previousTransactions.expenses, lowerIsBetter: true)
                            comparisonCard(title: "Income", current: periodTransactions.income,
                                           previous: previousTransactions.income, lowerIsBetter: false)
                        }
                        .accessibilityIdentifier("reportPeriodComparison")
                    }

                    spendingInsights

                    Text("Cash Flow").font(.headline)
                    if cashFlow.isEmpty {
                        ContentUnavailableView("No cash flow", systemImage: "chart.xyaxis.line", description: Text("Add income or expenses for this period."))
                    } else {
                        Chart(cashFlow) { point in
                            BarMark(x: .value("Date", point.date, unit: period.bucketComponent), y: .value("Amount", point.amount))
                                .position(by: .value("Type", point.type.title))
                                .foregroundStyle(by: .value("Type", point.type.title))
                        }
                        .chartForegroundStyleScale([AppLanguage.localized("Expense"): Color.red, AppLanguage.localized("Income"): Color.green])
                        .frame(height: 220)
                        .accessibilityLabel("Income and expenses over time")
                        .accessibilityIdentifier("cashFlowChart")
                    }

                    Picker("Type", selection: $selectedType) {
                        ForEach(TransactionType.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)

                    if categories.isEmpty {
                        ContentUnavailableView("No transactions", systemImage: "chart.pie", description: Text("Tap Add to record your first transaction."))
                    } else {
                        Chart(categories) { item in
                            SectorMark(angle: .value("Amount", item.amount), innerRadius: .ratio(0.62), angularInset: 2)
                                .foregroundStyle(by: .value("Category", item.category.name))
                        }.frame(height: 240).accessibilityLabel("Transactions by category")
                    }
                    Text("Top Categories").font(.headline)
                    ForEach(categories) { item in
                        HStack { CategoryIcon(category: item.category); Text(item.category.name); Spacer(); Text(AppFormat.money(item.amount, currencyCode: currencyCode)).fontWeight(.semibold) }
                    }
                    if transactions.contains(where: { ($0.currencyCode ?? currencyCode) != currencyCode }) {
                        Label("Reports include \(currencyCode) transactions only.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding()
            }.navigationTitle("Reports")
                .sheet(item: $insightTransaction) { AddTransactionView(transaction: $0) }
        }
    }

    private var spendingInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Insights").font(.headline)
            if period == .all {
                Label("Choose Week, Month, or Year to compare spending patterns.", systemImage: "lightbulb")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if largestCategoryIncrease == nil && unusualExpenses.isEmpty {
                Label("No notable spending changes yet", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                if let change = largestCategoryIncrease {
                    let category = CustomCategoryCatalog.presentation(for: change.categoryID, type: .expense, custom: customCategories)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(category.name) increased by \(AppFormat.money(change.increase, currencyCode: currencyCode))")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("\(change.percentageChange.formatted(.percent.precision(.fractionLength(0)))) more than the previous \(period.title.lowercased()).")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(unusualExpenses) { transaction in
                    Button { insightTransaction = transaction } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.magnifyingglass").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Unusual \(transaction.categoryPresentation(customCategories: customCategories).name) expense")
                                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                                Text("\(transaction.merchant.isEmpty ? "Transaction" : transaction.merchant) · \(AppFormat.money(transaction.amount, currencyCode: currencyCode))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("spendingInsights")
    }

    private var rateCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Savings Rate").font(.caption).foregroundStyle(.secondary)
            if let savingsRate { Text(savingsRate, format: .percent.precision(.fractionLength(0))).font(.headline).foregroundStyle(savingsRate >= 0 ? .green : .red) }
            else { Text("—").font(.headline).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func totalCard(title: LocalizedStringKey, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(AppFormat.money(amount, currencyCode: currencyCode)).font(.headline).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.65)
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func comparisonCard(title: LocalizedStringKey, current: Double, previous: Double, lowerIsBetter: Bool) -> some View {
        let change = ReportCalculator.percentageChange(current: current, previous: previous)
        let favorable = change.map { lowerIsBetter ? $0 <= 0 : $0 >= 0 } ?? false
        return VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let change {
                Label(change.formatted(.percent.precision(.fractionLength(0))),
                      systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.headline).foregroundStyle(favorable ? .green : .orange)
            } else {
                Text("No previous data").font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Previous: \(AppFormat.money(previous, currencyCode: currencyCode))")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
