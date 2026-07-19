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

    private var periodTransactions: [Transaction] {
        transactions.filter { ($0.currencyCode ?? currencyCode) == currencyCode && period.includes($0.transactionDate) }
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
        }
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
}
