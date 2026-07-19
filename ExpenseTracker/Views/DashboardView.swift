import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Transaction.transactionDate, order: .reverse) private var transactions: [Transaction]
    @AppStorage("monthlyBudget") private var budget = 30000.0
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CategoryBudgetStore.storageKey) private var categoryBudgetsJSON = ""
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @AppStorage(FinancialAccountStore.storageKey) private var accountsJSON = ""
    private var accounts: [FinancialAccount] { FinancialAccountStore.decode(accountsJSON).filter { !$0.isArchived } }
    private var currencyTransactions: [Transaction] { transactions.filter { ($0.currencyCode ?? currencyCode) == currencyCode } }
    private var month: [Transaction] { currencyTransactions.inCurrentMonth() }
    private var ratio: Double { DomainLogic.budgetProgress(spent: month.expenses, budget: budget) }
    private var categoryBudgetProgress: [(CategoryBudget, CategoryPresentation, Double)] {
        let custom = CustomCategoryCatalog.decode(customCategoriesJSON)
        return CategoryBudgetStore.decode(categoryBudgetsJSON)
            .filter { $0.currencyCode == currencyCode }
            .map { item in
                let category = CustomCategoryCatalog.presentation(for: item.categoryID, type: .expense, custom: custom)
                let spent = month.filter { $0.type == .expense && $0.transferID == nil && $0.categoryRaw == item.categoryID }.reduce(0) { $0 + $1.amount }
                return (item, category, spent)
            }
            .sorted { ($0.2 / $0.0.amount) > ($1.2 / $1.0.amount) }
    }

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

                    HStack { metric("Today’s spending", currencyTransactions.filter { Calendar.current.isDateInToday($0.transactionDate) && $0.type == .expense && $0.transferID == nil }.reduce(0) { $0 + $1.amount }); metric("This month income", month.income) }

                    if !accounts.isEmpty {
                        sectionHeader("Accounts")
                        VStack(spacing: 12) {
                            ForEach(accounts) { account in
                                HStack { Label(account.name, systemImage: account.type.symbol); Spacer(); Text(AppFormat.money(FinancialAccountStore.balance(for: account, transactions: transactions), currencyCode: account.currencyCode)).fontWeight(.semibold) }
                            }
                        }.padding().background(.background, in: RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.05), radius: 8)
                    }

                    if !categoryBudgetProgress.isEmpty {
                        sectionHeader("Category Budgets")
                        VStack(spacing: 14) {
                            ForEach(categoryBudgetProgress.prefix(4), id: \.0.id) { item in
                                categoryBudgetRow(budget: item.0, category: item.1, spent: item.2)
                            }
                        }.padding().background(.background, in: RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.05), radius: 8)
                    }

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
    private func metric(_ title: LocalizedStringKey, _ value: Double) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.caption).foregroundStyle(.secondary); Text(AppFormat.money(value, currencyCode: currencyCode)).font(.headline).lineLimit(1).minimumScaleFactor(0.6) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.06), radius: 8) }
    private func sectionHeader(_ title: LocalizedStringKey) -> some View { HStack { Text(title).font(.headline); Spacer() } }
    private func categoryBudgetRow(budget: CategoryBudget, category: CategoryPresentation, spent: Double) -> some View {
        let exceeded = spent > budget.amount
        return VStack(spacing: 6) {
            HStack {
                Label(category.name, systemImage: category.symbol).lineLimit(1)
                Spacer()
                Text("\(AppFormat.money(spent, currencyCode: currencyCode)) / \(AppFormat.money(budget.amount, currencyCode: currencyCode))")
                    .font(.caption).foregroundStyle(exceeded ? .red : .secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            ProgressView(value: DomainLogic.budgetProgress(spent: spent, budget: budget.amount))
                .tint(exceeded ? .red : .indigo)
            if exceeded {
                Text("Over by \(AppFormat.money(spent - budget.amount, currencyCode: currencyCode))")
                    .font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
