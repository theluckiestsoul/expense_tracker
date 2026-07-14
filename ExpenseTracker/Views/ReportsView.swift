import SwiftUI
import SwiftData
import Charts

struct CategorySpend: Identifiable { let category: ExpenseCategory; let amount: Double; var id: String { category.id } }

struct ReportsView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    private var month: [Transaction] { transactions.inCurrentMonth().filter { $0.type == .expense && ($0.currencyCode ?? currencyCode) == currencyCode } }
    private var categories: [CategorySpend] { Dictionary(grouping: month, by: \.category).map { CategorySpend(category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }.sorted { $0.amount > $1.amount } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Total expense").foregroundStyle(.secondary)
                    Text(AppFormat.money(month.expenses, currencyCode: currencyCode)).font(.largeTitle.bold())
                    if categories.isEmpty { ContentUnavailableView("No expense data", systemImage: "chart.pie", description: Text("Add a \(currencyCode) expense to see this month’s report.")) }
                    else { Chart(categories) { item in SectorMark(angle: .value("Amount", item.amount), innerRadius: .ratio(0.62), angularInset: 2).foregroundStyle(by: .value("Category", item.category.rawValue)) }.frame(height: 240).accessibilityLabel("Monthly spending by category") }
                    Text("Top Categories").font(.headline)
                    ForEach(categories) { item in HStack { CategoryIcon(category: item.category); Text(item.category.rawValue); Spacer(); Text(AppFormat.money(item.amount, currencyCode: currencyCode)).fontWeight(.semibold) } }
                }.padding()
            }.navigationTitle("Reports")
        }
    }
}
