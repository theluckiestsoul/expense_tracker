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
    @AppStorage(SavingsGoalStore.storageKey) private var savingsGoalsJSON = ""
    @State private var addingType: TransactionType?
    @State private var transferring = false
    private var accounts: [FinancialAccount] { FinancialAccountStore.decode(accountsJSON).filter { !$0.isArchived } }
    private var currencyTransactions: [Transaction] { transactions.filter { ($0.currencyCode ?? currencyCode) == currencyCode } }
    private var month: [Transaction] { currencyTransactions.inCurrentMonth() }
    private var savingsGoals: [SavingsGoal] { SavingsGoalStore.decode(savingsGoalsJSON).filter { $0.currencyCode == currencyCode }.sorted { $0.progress > $1.progress } }
    private var ratio: Double { DomainLogic.budgetProgress(spent: month.expenses, budget: budget) }
    private var canTransfer: Bool { accounts.contains { source in accounts.contains { $0.id != source.id && $0.currencyCode == source.currencyCode } } }
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
                LazyVStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("This Month", systemImage: "leaf.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                        Text("Total spent").font(.caption).foregroundStyle(.white.opacity(0.75))
                        Text(AppFormat.money(month.expenses, currencyCode: currencyCode)).font(.largeTitle.bold()).foregroundStyle(.white)
                        HStack { Text("Monthly budget \(AppFormat.money(budget, currencyCode: currencyCode))"); Spacer(); Text(ratio, format: .percent.precision(.fractionLength(0))) }.font(.caption).foregroundStyle(.white)
                        ProgressView(value: ratio).tint(.white)
                        HStack {
                            Label("Remaining \(AppFormat.money(DomainLogic.budgetRemaining(spent: month.expenses, budget: budget), currencyCode: currencyCode))", systemImage: "checkmark.circle.fill")
                            Spacer()
                            Text("Income \(AppFormat.money(month.income, currencyCode: currencyCode))")
                        }.font(.caption.weight(.semibold)).foregroundStyle(.white)
                    }.padding(20).background(LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    HStack(spacing: 12) {
                        quickAction("Expense", symbol: "arrow.up.right", color: .orange) { addingType = .expense }
                        quickAction("Income", symbol: "arrow.down.left", color: .green) { addingType = .income }
                        if canTransfer { quickAction("Transfer", symbol: "arrow.left.arrow.right", color: .indigo) { transferring = true } }
                    }

                    HStack { metric("Today’s spending", currencyTransactions.filter { Calendar.current.isDateInToday($0.transactionDate) && $0.type == .expense && $0.transferID == nil }.reduce(0) { $0 + $1.amount }); metric("Net this month", month.income - month.expenses) }

                    if !accounts.isEmpty {
                        HStack { sectionHeader("Wallets & Accounts"); NavigationLink("See All") { AccountsView() }.font(.subheadline) }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                            ForEach(accounts) { account in
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: account.type.symbol).font(.title3).foregroundStyle(.indigo)
                                    Text(account.name).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    Text(AppFormat.money(FinancialAccountStore.balance(for: account, transactions: transactions), currencyCode: account.currencyCode)).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                                }.frame(width: 180, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            }
                        }
                    }

                    if !categoryBudgetProgress.isEmpty {
                        sectionHeader("Category Budgets")
                        VStack(spacing: 14) {
                            ForEach(categoryBudgetProgress.prefix(4), id: \.0.id) { item in
                                categoryBudgetRow(budget: item.0, category: item.1, spent: item.2)
                            }
                        }.padding().background(.background, in: RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.05), radius: 8)
                    }

                    if !savingsGoals.isEmpty {
                        sectionHeader("Savings Goals")
                        VStack(spacing: 14) {
                            ForEach(savingsGoals.prefix(3)) { goal in
                                VStack(spacing: 6) {
                                    HStack { Label(goal.name, systemImage: goal.progress >= 1 ? "checkmark.circle.fill" : "target"); Spacer(); Text(goal.progress, format: .percent.precision(.fractionLength(0))).foregroundStyle(.secondary) }
                                    ProgressView(value: goal.progress).tint(goal.progress >= 1 ? .green : .indigo)
                                    Text("Remaining \(AppFormat.money(goal.remaining, currencyCode: goal.currencyCode))").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }.padding().background(.background, in: RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.05), radius: 8)
                    }

                    HStack { sectionHeader("Recent Transactions"); NavigationLink("See All") { TransactionsView() }.font(.subheadline) }
                    Group {
                        if transactions.isEmpty { ContentUnavailableView("No transactions", systemImage: "tray", description: Text("Tap Add to record your first transaction.")) }
                        else { VStack(spacing: 8) { ForEach(Array(transactions.prefix(4).enumerated()), id: \.element.id) { index, transaction in TransactionRow(transaction: transaction); if index < min(transactions.count, 4) - 1 { Divider() } } } }
                    }.padding().background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    if transactions.contains(where: { ($0.currencyCode ?? currencyCode) != currencyCode }) {
                        Label("Totals include \(currencyCode) transactions only.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding()
            }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Dashboard")
                .sheet(item: $addingType) { AddTransactionView(startingType: $0) }
                .sheet(isPresented: $transferring) { TransferView() }
        }
    }
    private func quickAction(_ title: LocalizedStringKey, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 7) { Image(systemName: symbol).font(.headline); Text(title).font(.caption.weight(.medium)).lineLimit(1) }.frame(maxWidth: .infinity).padding(.vertical, 12).foregroundStyle(color).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous)) }.buttonStyle(.plain)
    }
    private func metric(_ title: LocalizedStringKey, _ value: Double) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.caption).foregroundStyle(.secondary); Text(AppFormat.money(value, currencyCode: currencyCode)).font(.headline).lineLimit(1).minimumScaleFactor(0.6) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
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
