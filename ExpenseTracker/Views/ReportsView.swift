import SwiftUI
import SwiftData
import Charts

struct CategorySpend: Identifiable { let category: ExpenseCategory; let amount: Double; var id: String { category.id } }

struct ReportsView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @State private var selectedType: TransactionType = .expense
    private var month: [Transaction] { transactions.inCurrentMonth().filter { ($0.currencyCode ?? currencyCode) == currencyCode } }
    private var selectedTransactions: [Transaction] { month.filter { $0.type == selectedType } }
    private var categories: [CategorySpend] { Dictionary(grouping: selectedTransactions, by: \.category).map { CategorySpend(category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }.sorted { $0.amount > $1.amount } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        totalCard(title: "Expense", amount: month.expenses, color: .red)
                        totalCard(title: "Income", amount: month.income, color: .green)
                    }
                    Picker("Type", selection: $selectedType) {
                        ForEach(TransactionType.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if categories.isEmpty { ContentUnavailableView("No transactions", systemImage: "chart.pie", description: Text("Tap Add to record your first transaction.")) }
                    else { Chart(categories) { item in SectorMark(angle: .value("Amount", item.amount), innerRadius: .ratio(0.62), angularInset: 2).foregroundStyle(by: .value("Category", item.category.displayName)) }.frame(height: 240).accessibilityLabel("Monthly spending by category") }
                    Text("Top Categories").font(.headline)
                    ForEach(categories) { item in HStack { CategoryIcon(category: item.category); Text(item.category.displayName); Spacer(); Text(AppFormat.money(item.amount, currencyCode: currencyCode)).fontWeight(.semibold) } }
                }.padding()
            }.navigationTitle("Reports")
        }
    }

    private func totalCard(title: LocalizedStringKey, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(AppFormat.money(amount, currencyCode: currencyCode)).font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
