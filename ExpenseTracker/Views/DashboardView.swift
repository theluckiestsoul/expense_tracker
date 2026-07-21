import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Transaction.transactionDate, order: .reverse) private var transactions: [Transaction]
    @AppStorage("monthlyBudget") private var budget = 30000.0
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CategoryBudgetStore.storageKey) private var categoryBudgetsJSON = ""
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @AppStorage(SavingsGoalStore.storageKey) private var savingsGoalsJSON = ""
    @AppStorage(RecurringTransactionStore.storageKey) private var recurringTransactionsJSON = ""
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.system.rawValue
    @State private var addingType: TransactionType?
    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }
    private var currencyTransactions: [Transaction] {
        transactions.filter { ($0.currencyCode ?? currencyCode) == currencyCode }
    }
    private var month: [Transaction] { currencyTransactions.inCurrentMonth() }
    private var previousMonthExpenses: Double {
        let calendar = Calendar.current
        guard let currentInterval = calendar.dateInterval(of: .month, for: .now),
              let previousStart = calendar.date(byAdding: .month, value: -1, to: currentInterval.start) else { return 0 }
        return currencyTransactions.filter { $0.transactionDate >= previousStart && $0.transactionDate < currentInterval.start }.expenses
    }
    private var spendingChange: Double? {
        guard previousMonthExpenses > 0 else { return nil }
        return (month.expenses - previousMonthExpenses) / previousMonthExpenses
    }
    private var upcomingBills: [RecurringTransaction] {
        UpcomingBillPlanner.bills(from: RecurringTransactionStore.decode(recurringTransactionsJSON), currencyCode: currencyCode)
    }
    private var savingsGoals: [SavingsGoal] { SavingsGoalStore.decode(savingsGoalsJSON).filter { $0.currencyCode == currencyCode }.sorted { $0.progress > $1.progress } }
    private var ratio: Double { DomainLogic.budgetProgress(spent: month.expenses, budget: budget) }
    private var budgetStatus: DomainLogic.BudgetStatus { DomainLogic.budgetStatus(spent: month.expenses, budget: budget) }
    private var projectedSpend: Double? { DomainLogic.projectedMonthlySpend(spent: month.expenses) }
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hello 👋").font(.title.bold())
                        Text("Here’s your financial overview").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Monthly Spending", systemImage: "leaf.fill")
                                .font(.headline).foregroundStyle(theme.accent)
                            Spacer()
                            if let spendingChange {
                                Label {
                                    Text(spendingChange, format: .percent.precision(.fractionLength(0)))
                                } icon: {
                                    Image(systemName: spendingChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                                }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(spendingChange <= 0 ? .green : .orange)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background((spendingChange <= 0 ? Color.green : Color.orange).opacity(0.1), in: Capsule())
                            }
                        }
                        Text(AppFormat.money(month.expenses, currencyCode: currencyCode))
                            .font(.system(size: 38, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                        Text("of \(AppFormat.money(budget, currencyCode: currencyCode)) budget")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: ratio).tint(theme.accent).scaleEffect(y: 1.35)
                        HStack {
                            Text("\(AppFormat.money(DomainLogic.budgetRemaining(spent: month.expenses, budget: budget), currencyCode: currencyCode)) left to spend")
                                .foregroundStyle(theme.accent)
                            Spacer()
                            Text(ratio, format: .percent.precision(.fractionLength(0)))
                        }.font(.caption.weight(.semibold))
                    }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                        .coachMarkTarget(.dashboardSummary)

                    if budgetStatus == .approaching || budgetStatus == .nearlyReached || budgetStatus == .exceeded {
                        budgetAlert
                    }

                    sectionHeader("Quick Actions")
                    HStack(spacing: 12) {
                        quickAction("Expense", symbol: "arrow.up.right", color: .orange) { addingType = .expense }
                            .coachMarkTarget(.expenseButton)
                        quickAction("Income", symbol: "arrow.down.left", color: .green) { addingType = .income }
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

                    HStack { sectionHeader("Recent Transactions"); NavigationLink("See All") { TransactionsView() }.font(.subheadline.weight(.semibold)) }
                    Group {
                        if currencyTransactions.isEmpty { ContentUnavailableView("No transactions", systemImage: "tray", description: Text("Tap Add to record your first transaction.")) }
                        else { VStack(spacing: 8) { ForEach(Array(currencyTransactions.prefix(4).enumerated()), id: \.element.id) { index, transaction in TransactionRow(transaction: transaction); if index < min(currencyTransactions.count, 4) - 1 { Divider() } } } }
                    }.padding().background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous)).shadow(color: .black.opacity(0.05), radius: 10, y: 5)

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

                    if transactions.contains(where: { ($0.currencyCode ?? currencyCode) != currencyCode }) {
                        Label("Totals include \(currencyCode) transactions only.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding()
            }.background(
                LinearGradient(colors: [theme.accent.opacity(0.08), Color(uiColor: .systemGroupedBackground), Color(uiColor: .systemGroupedBackground)], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            ).navigationTitle("Dashboard").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                            Text("LedgerLeaf")
                        }
                        .font(.headline.weight(.bold)).foregroundStyle(theme.accent).fixedSize()
                    }
                }
                .sheet(item: $addingType) { AddTransactionView(startingType: $0) }
        }
    }
    private func quickAction(_ title: LocalizedStringKey, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol).font(.title2.weight(.semibold))
                    .frame(width: 38, height: 38).background(.white.opacity(0.18), in: Circle())
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16).foregroundStyle(.white)
            .background(LinearGradient(colors: [color.opacity(0.78), color], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: color.opacity(0.2), radius: 8, y: 5)
        }.buttonStyle(.plain)
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
