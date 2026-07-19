import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(RecurringTransactionStore.storageKey) private var recurringTransactionsJSON = ""
    @AppStorage(BillReminderService.enabledKey) private var billRemindersEnabled = false
    @AppStorage(FinancialAccountStore.storageKey) private var accountsJSON = ""
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.system.rawValue
    @State private var selection = 0
    @State private var adding = false

    var body: some View {
        TabView(selection: $selection) {
            DashboardView().tabItem { Label("Dashboard", systemImage: "leaf.fill") }.tag(0)
            TransactionsView().tabItem { Label("Transactions", systemImage: "arrow.up.arrow.down.circle.fill") }.tag(1)
            Color.clear.tabItem { Label("Add", systemImage: "square.and.pencil") }.tag(2)
            ReportsView().tabItem { Label("Reports", systemImage: "chart.line.uptrend.xyaxis") }.tag(3)
            SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(4)
        }
        .tint(theme.accent)
        .onChange(of: selection) { _, value in if value == 2 { adding = true; selection = 0 } }
        .sheet(isPresented: $adding) { AddTransactionView() }
        .task {
            try? LegacyDataMigrator.assignMissingCurrencies(in: context, currencyCode: currencyCode)
            let accounts = FinancialAccountStore.ensuringDefault(in: FinancialAccountStore.decode(accountsJSON), currencyCode: currencyCode)
            if accounts != FinancialAccountStore.decode(accountsJSON) { accountsJSON = FinancialAccountStore.encode(accounts) }
            processSchedules()
            if billRemindersEnabled { await BillReminderService.schedule(schedulesJSON: recurringTransactionsJSON) }
        }
        .onChange(of: recurringTransactionsJSON) { _, _ in
            processSchedules()
            if billRemindersEnabled { Task { await BillReminderService.schedule(schedulesJSON: recurringTransactionsJSON) } }
        }
    }

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    private func processSchedules() {
        if let updated = try? RecurringTransactionProcessor.processDue(in: context, schedulesJSON: recurringTransactionsJSON),
           RecurringTransactionStore.decode(updated) != RecurringTransactionStore.decode(recurringTransactionsJSON) {
            recurringTransactionsJSON = updated
        }
    }
}
