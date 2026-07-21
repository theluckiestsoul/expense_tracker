import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(RecurringTransactionStore.storageKey) private var recurringTransactionsJSON = ""
    @AppStorage(BillReminderService.enabledKey) private var billRemindersEnabled = false
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.system.rawValue
    @AppStorage(OnboardingCoachMark.completionKey) private var hasCompletedOnboarding = false
    @State private var selection = 0
    @State private var adding = false
    @State private var onboardingStep = 0

    var body: some View {
        TabView(selection: $selection) {
            DashboardView().tabItem { Label("Dashboard", systemImage: "house.fill") }.tag(0)
            TransactionsView().tabItem { Label("Transactions", systemImage: "list.bullet.rectangle.fill") }.tag(1)
            Color.clear.tabItem { Label("Add", systemImage: "plus.app.fill") }.tag(2)
            ReportsView().tabItem { Label("Reports", systemImage: "chart.pie.fill") }.tag(3)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(4)
        }
        .tint(theme.accent)
        .overlayPreferenceValue(CoachMarkTargetKey.self) { targets in
            GeometryReader { proxy in
                if !hasCompletedOnboarding {
                    OnboardingCoachMark(
                        step: onboardingStep,
                        targetRect: onboardingRect(targets: targets, proxy: proxy),
                        containerSize: proxy.size,
                        onPrevious: previousOnboardingStep,
                        onNext: nextOnboardingStep,
                        onSkip: completeOnboarding
                    )
                }
            }
        }
        .onChange(of: selection) { _, value in if value == 2 { adding = true; selection = 0 } }
        .sheet(isPresented: $adding) { AddTransactionView() }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if !completed { onboardingStep = 0; selection = 0 }
        }
        .task {
            try? LegacyDataMigrator.assignMissingCurrencies(in: context, currencyCode: currencyCode)
            processSchedules()
            if billRemindersEnabled { await BillReminderService.schedule(schedulesJSON: recurringTransactionsJSON) }
        }
        .onChange(of: recurringTransactionsJSON) { _, _ in
            processSchedules()
            if billRemindersEnabled { Task { await BillReminderService.schedule(schedulesJSON: recurringTransactionsJSON) } }
        }
    }

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    private func onboardingRect(targets: [CoachMarkTarget: Anchor<CGRect>], proxy: GeometryProxy) -> CGRect {
        if onboardingStep == 0, let anchor = targets[.dashboardSummary] { return proxy[anchor] }
        if onboardingStep == 1, let anchor = targets[.expenseButton] { return proxy[anchor] }
        let tabWidth = proxy.size.width / 5
        let tabIndex = [2: 1, 3: 3, 4: 4][onboardingStep] ?? 0
        return CGRect(x: tabWidth * CGFloat(tabIndex) + 7, y: proxy.size.height - 76,
                      width: tabWidth - 14, height: 62)
    }

    private func nextOnboardingStep() {
        switch onboardingStep {
        case 0: onboardingStep = 1
        case 1: onboardingStep = 2; adding = true
        case 2: onboardingStep = 3; selection = 1
        case 3: onboardingStep = 4; selection = 3
        default: selection = 4; completeOnboarding()
        }
    }

    private func previousOnboardingStep() {
        guard onboardingStep > 0 else { return }
        onboardingStep -= 1
        selection = onboardingStep >= 4 ? 3 : (onboardingStep >= 3 ? 1 : 0)
    }

    private func completeOnboarding() { hasCompletedOnboarding = true }

    private func processSchedules() {
        if let updated = try? RecurringTransactionProcessor.processDue(in: context, schedulesJSON: recurringTransactionsJSON),
           RecurringTransactionStore.decode(updated) != RecurringTransactionStore.decode(recurringTransactionsJSON) {
            recurringTransactionsJSON = updated
        }
    }
}
