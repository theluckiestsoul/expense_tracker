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
    @AppStorage(RecurringTransactionStore.storageKey) private var recurringTransactionsJSON = ""
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.system.rawValue
    @State private var addingType: TransactionType?
    @State private var transferring = false
    @State private var selectedAccountID = ""
    private var accounts: [FinancialAccount] { FinancialAccountStore.decode(accountsJSON).filter { !$0.isArchived } }
    private var filterAccounts: [FinancialAccount] { accounts.filter { $0.currencyCode == currencyCode } }
    private var selectedAccount: FinancialAccount? { filterAccounts.first { $0.id == selectedAccountID } }
    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }
    private var currencyTransactions: [Transaction] {
        transactions.filter { transaction in
            guard (transaction.currencyCode ?? currencyCode) == currencyCode else { return false }
            guard let selectedAccount else { return true }
            return FinancialAccountStore.matches(transaction, account: selectedAccount)
        }
    }
    private var month: [Transaction] { currencyTransactions.inCurrentMonth() }
    private var upcomingBills: [RecurringTransaction] {
        UpcomingBillPlanner.bills(
            from: RecurringTransactionStore.decode(recurringTransactionsJSON), currencyCode: currencyCode,
            selectedAccountID: selectedAccountID.isEmpty ? nil : selectedAccountID,
            defaultAccountID: accounts.first(where: \.isDefault)?.id
        )
    }
    private var savingsGoals: [SavingsGoal] { SavingsGoalStore.decode(savingsGoalsJSON).filter { $0.currencyCode == currencyCode }.sorted { $0.progress > $1.progress } }
    private var ratio: Double { DomainLogic.budgetProgress(spent: month.expenses, budget: budget) }
    private var budgetStatus: DomainLogic.BudgetStatus { DomainLogic.budgetStatus(spent: month.expenses, budget: budget) }
    private var projectedSpend: Double? { DomainLogic.projectedMonthlySpend(spent: month.expenses) }
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
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.fill").font(.title2).foregroundStyle(.white)
                            .frame(width: 46, height: 46).background(theme.heroColors.first ?? .green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LedgerLeaf").font(.title2.bold()).foregroundStyle(theme.accent)
                            Text("Your financial overview").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if filterAccounts.count > 1 {
                        Picker("Wallet Filter", selection: $selectedAccountID) {
                            Text("All Wallets").tag("")
                            ForEach(filterAccounts) { Text($0.name).tag($0.id) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("dashboardAccountFilter")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label(selectedAccount.map { "This Month · \($0.name)" } ?? "This Month", systemImage: "leaf.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                        Text("Total spent").font(.caption).foregroundStyle(.white.opacity(0.75))
                        Text(AppFormat.money(month.expenses, currencyCode: currencyCode)).font(.largeTitle.bold()).foregroundStyle(.white)
                        HStack { Text("Monthly budget \(AppFormat.money(budget, currencyCode: currencyCode))"); Spacer(); Text(ratio, format: .percent.precision(.fractionLength(0))) }.font(.caption).foregroundStyle(.white)
                        ProgressView(value: ratio).tint(.white)
                        HStack {
                            Label("Remaining \(AppFormat.money(DomainLogic.budgetRemaining(spent: month.expenses, budget: budget), currencyCode: currencyCode))", systemImage: "checkmark.circle.fill")
                            Spacer()
                            Text("Income \(AppFormat.money(month.income, currencyCode: currencyCode))")
                        }.font(.caption.weight(.semibold)).foregroundStyle(.white)
                    }.padding(20).background(LinearGradient(colors: theme.heroColors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: (theme.heroColors.first ?? .green).opacity(0.22), radius: 16, y: 9)
                        .coachMarkTarget(.dashboardSummary)

                    if budgetStatus == .approaching || budgetStatus == .nearlyReached || budgetStatus == .exceeded {
                        budgetAlert
                    }

                    HStack(spacing: 12) {
                        quickAction("Expense", symbol: "arrow.up.right", color: .orange) { addingType = .expense }
                            .coachMarkTarget(.expenseButton)
                        quickAction("Income", symbol: "arrow.down.left", color: .green) { addingType = .income }
                        if canTransfer { quickAction("Transfer", symbol: "arrow.left.arrow.right", color: .indigo) { transferring = true } }
                    }

                    HStack { metric("Today’s spending", currencyTransactions.filter { Calendar.current.isDateInToday($0.transactionDate) && $0.type == .expense && $0.transferID == nil }.reduce(0) { $0 + $1.amount }); metric("Net this month", month.income - month.expenses) }

                    if let projectedSpend, month.expenses > 0 {
                        let atRisk = budget > 0 && projectedSpend > budget
                        HStack(spacing: 14) {
                            Image(systemName: atRisk ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.title2).foregroundStyle(atRisk ? .orange : .green)
                                .frame(width: 44, height: 44)
                                .background((atRisk ? Color.orange : Color.green).opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Monthly Forecast").font(.headline)
                                Text("Projected: \(AppFormat.money(projectedSpend, currencyCode: currencyCode))")
                                    .font(.subheadline).fontWeight(.semibold)
                                Text(atRisk ? "At this pace, spending may exceed your budget." : "Your current spending pace is within budget.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding().background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityIdentifier("monthlySpendingForecast")
                    }

                    if !upcomingBills.isEmpty {
                        HStack {
                            sectionHeader("Upcoming Bills")
                            NavigationLink("See All") { RecurringTransactionsView() }.font(.subheadline)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(upcomingBills.prefix(3).enumerated()), id: \.element.id) { index, bill in
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock").foregroundStyle(theme.accent)
                                        .frame(width: 32, height: 32).background(theme.accent.opacity(0.12), in: Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(bill.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                        Text(dueLabel(for: bill.nextDate)).font(.caption)
                                            .foregroundStyle(bill.nextDate < Calendar.current.startOfDay(for: .now) ? .red : .secondary)
                                    }
                                    Spacer()
                                    Text(AppFormat.money(bill.amount, currencyCode: bill.currencyCode)).fontWeight(.semibold)
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .padding(.vertical, 11)
                                if index < min(upcomingBills.count, 3) - 1 { Divider() }
                            }
                        }
                        .padding(.horizontal).background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityIdentifier("upcomingBillsSection")
                    }

                    if !accounts.isEmpty {
                        HStack { sectionHeader("Wallets & Accounts"); NavigationLink("See All") { AccountsView() }.font(.subheadline) }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                            ForEach(accounts) { account in
                                Button {
                                    guard account.currencyCode == currencyCode else { return }
                                    selectedAccountID = selectedAccountID == account.id ? "" : account.id
                                } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: account.type.symbol).font(.title3).foregroundStyle(theme.accent)
                                    Text(account.name).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    Text(AppFormat.money(FinancialAccountStore.balance(for: account, transactions: transactions), currencyCode: account.currencyCode)).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                                }.frame(width: 180, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedAccountID == account.id ? theme.accent : .clear, lineWidth: 2))
                                }.buttonStyle(.plain)
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
                        if currencyTransactions.isEmpty { ContentUnavailableView("No transactions", systemImage: "tray", description: Text("Tap Add to record your first transaction.")) }
                        else { VStack(spacing: 8) { ForEach(Array(currencyTransactions.prefix(4).enumerated()), id: \.element.id) { index, transaction in TransactionRow(transaction: transaction); if index < min(currencyTransactions.count, 4) - 1 { Divider() } } } }
                    }.padding().background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    if transactions.contains(where: { ($0.currencyCode ?? currencyCode) != currencyCode }) {
                        Label("Totals include \(currencyCode) transactions only.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding()
            }.background(
                LinearGradient(colors: [theme.accent.opacity(0.08), Color(uiColor: .systemGroupedBackground), Color(uiColor: .systemGroupedBackground)], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            ).navigationTitle("Dashboard")
                .sheet(item: $addingType) { AddTransactionView(startingType: $0) }
                .sheet(isPresented: $transferring) { TransferView() }
                .onChange(of: accountsJSON) { _, _ in if selectedAccount == nil { selectedAccountID = "" } }
        }
    }
    private func quickAction(_ title: LocalizedStringKey, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 7) { Image(systemName: symbol).font(.headline); Text(title).font(.caption.weight(.medium)).lineLimit(1) }.frame(maxWidth: .infinity).padding(.vertical, 12).foregroundStyle(color).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous)) }.buttonStyle(.plain)
    }
    private func metric(_ title: LocalizedStringKey, _ value: Double) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.caption).foregroundStyle(.secondary); Text(AppFormat.money(value, currencyCode: currencyCode)).font(.headline).lineLimit(1).minimumScaleFactor(0.6) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    private func sectionHeader(_ title: LocalizedStringKey) -> some View { HStack { Text(title).font(.headline); Spacer() } }
    private var budgetAlert: some View {
        let exceeded = budgetStatus == .exceeded
        let nearlyReached = budgetStatus == .nearlyReached
        let color: Color = exceeded ? .red : .orange
        let title = exceeded ? "Monthly budget exceeded" : (nearlyReached ? "Monthly budget nearly reached" : "Monthly budget is at 75%")
        let detail = exceeded
            ? "Over by \(AppFormat.money(max(month.expenses - budget, 0), currencyCode: currencyCode))"
            : "\(AppFormat.money(DomainLogic.budgetRemaining(spent: month.expenses, budget: budget), currencyCode: currencyCode)) remaining"
        return HStack(spacing: 12) {
            Image(systemName: exceeded ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.title2).foregroundStyle(color)
                .frame(width: 42, height: 42).background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding().background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("monthlyBudgetAlert")
    }
    private func dueLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        if date < start { return AppLanguage.localized("Overdue") }
        if calendar.isDateInToday(date) { return AppLanguage.localized("Due today") }
        if calendar.isDateInTomorrow(date) { return AppLanguage.localized("Due tomorrow") }
        return "\(AppLanguage.localized("Due")) \(date.formatted(date: .abbreviated, time: .omitted))"
    }
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
