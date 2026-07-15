import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Transaction.transactionDate, order: .reverse) private var transactions: [Transaction]
    @AppStorage("monthlyBudget") private var budget = 30000.0
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    private var currencyTransactions: [Transaction] { transactions.filter { ($0.currencyCode ?? currencyCode) == currencyCode } }
    private var month: [Transaction] { currencyTransactions.inCurrentMonth() }
    private var ratio: Double { DomainLogic.budgetProgress(spent: month.expenses, budget: budget) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Total spent this month").foregroundStyle(.white.opacity(0.85))
                        Text(AppFormat.money(month.expenses, currencyCode: currencyCode)).font(.largeTitle.bold()).foregroundStyle(.white)
                        HStack { Text("Monthly budget \(AppFormat.money(budget, currencyCode: currencyCode))"); Spacer(); Text(ratio, format: .percent.precision(.fractionLength(0))) }.font(.caption).foregroundStyle(.white)
                        ProgressView(value: ratio).tint(.white)
                        Text("Remaining  \(AppFormat.money(DomainLogic.budgetRemaining(spent: month.expenses, budget: budget), currencyCode: currencyCode))").fontWeight(.semibold).foregroundStyle(.white)
                    }.padding().background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))

                    HStack { metric("Today’s spending", currencyTransactions.filter { Calendar.current.isDateInToday($0.transactionDate) && $0.type == .expense }.reduce(0) { $0 + $1.amount }); metric("This month income", month.income) }

                    sectionHeader("Recent Transactions")
                    if transactions.isEmpty { ContentUnavailableView("No transactions", systemImage: "tray", description: Text("Tap Add to record your first transaction.")) }
                    else { ForEach(transactions.prefix(5)) { TransactionRow(transaction: $0); Divider() } }
                    if transactions.contains(where: { ($0.currencyCode ?? currencyCode) != currencyCode }) {
                        Label("Totals include \(currencyCode) transactions only.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding()
            }.navigationTitle("Dashboard")
        }
    }
    private func metric(_ title: String, _ value: Double) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.caption).foregroundStyle(.secondary); Text(AppFormat.money(value, currencyCode: currencyCode)).font(.headline).lineLimit(1).minimumScaleFactor(0.6) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.06), radius: 8) }
    private func sectionHeader(_ title: String) -> some View { HStack { Text(title).font(.headline); Spacer() } }
}
