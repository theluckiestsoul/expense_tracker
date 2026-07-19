import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(RecurringTransactionStore.storageKey) private var recurringTransactionsJSON = ""
    @State private var selection = 0
    @State private var adding = false

    var body: some View {
        TabView(selection: $selection) {
            DashboardView().tabItem { Label("Dashboard", systemImage: "house.fill") }.tag(0)
            TransactionsView().tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }.tag(1)
            Color.clear.tabItem { Label("Add", systemImage: "plus.circle.fill") }.tag(2)
            ReportsView().tabItem { Label("Reports", systemImage: "chart.bar.fill") }.tag(3)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(4)
        }
        .tint(.indigo)
        .onChange(of: selection) { _, value in if value == 2 { adding = true; selection = 0 } }
        .sheet(isPresented: $adding) { AddTransactionView() }
        .task {
            try? LegacyDataMigrator.assignMissingCurrencies(in: context, currencyCode: currencyCode)
            processSchedules()
        }
        .onChange(of: recurringTransactionsJSON) { _, _ in processSchedules() }
    }

    private func processSchedules() {
        if let updated = try? RecurringTransactionProcessor.processDue(in: context, schedulesJSON: recurringTransactionsJSON),
           RecurringTransactionStore.decode(updated) != RecurringTransactionStore.decode(recurringTransactionsJSON) {
            recurringTransactionsJSON = updated
        }
    }
}
