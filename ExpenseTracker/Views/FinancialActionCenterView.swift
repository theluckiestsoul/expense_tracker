import SwiftUI
import SwiftData

struct FinancialActionCenterView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("monthlyBudget") private var monthlyBudget = 0.0
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CategoryBudgetStore.storageKey) private var categoryBudgetsJSON = ""
    @AppStorage(RecurringTransactionStore.storageKey) private var schedulesJSON = ""
    @AppStorage(SavingsGoalStore.storageKey) private var goalsJSON = ""
    @State private var editing: Transaction?

    private var actions: [FinancialAction] {
        FinancialActionCalculator.actions(
            transactions: transactions, monthlyBudget: monthlyBudget,
            categoryBudgets: CategoryBudgetStore.decode(categoryBudgetsJSON),
            schedules: RecurringTransactionStore.decode(schedulesJSON),
            savingsGoals: SavingsGoalStore.decode(goalsJSON), currencyCode: currencyCode
        )
    }
    var body: some View {
        List {
            if actions.isEmpty {
                ContentUnavailableView("You’re All Caught Up", systemImage: "checkmark.circle",
                                       description: Text("LedgerLeaf found no urgent financial actions."))
            } else {
                Section {
                    Text("Actions are ranked by urgency and calculated privately from data on this device.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(actions) { action in
                    Section {
                        destination(for: action)
                    }
                }
            }
        }
        .navigationTitle("Action Center")
        .accessibilityIdentifier("financialActionCenter")
        .sheet(item: $editing) { AddTransactionView(transaction: $0) }
    }

    @ViewBuilder private func destination(for action: FinancialAction) -> some View {
        if let id = action.transactionID, let transaction = transactions.first(where: { $0.id == id }) {
            Button { editing = transaction } label: { actionLabel(action) }.buttonStyle(.plain)
        } else {
            switch action.kind {
            case .budgetRisk:
                NavigationLink { CategoryBudgetsView() } label: { actionLabel(action) }
            case .upcomingBill:
                NavigationLink { RecurringTransactionsView() } label: { actionLabel(action) }
            case .savingsGoal:
                NavigationLink { SavingsGoalsView() } label: { actionLabel(action) }
            case .unusualExpense, .incompleteEntry:
                actionLabel(action)
            }
        }
    }
    private func actionLabel(_ action: FinancialAction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol(for: action.kind)).font(.title3).foregroundStyle(color(for: action.priority)).frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title).font(.headline).foregroundStyle(.primary)
                Text(action.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(.vertical, 4)
    }
    private func symbol(for kind: FinancialActionKind) -> String {
        switch kind {
        case .budgetRisk: "gauge.with.dots.needle.67percent"
        case .upcomingBill: "calendar.badge.exclamationmark"
        case .unusualExpense: "exclamationmark.magnifyingglass"
        case .incompleteEntry: "wand.and.stars"
        case .savingsGoal: "target"
        }
    }
    private func color(for priority: Int) -> Color { priority >= 85 ? .red : (priority >= 60 ? .orange : .blue) }
}
