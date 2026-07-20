import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static let ledgerLeafBackup = UTType(importedAs: "com.theluckiestsoul.ledgerleaf.backup", conformingTo: .json)
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.ledgerLeafBackup, .json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

private enum CSVExportKind { case transactions, template }

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @AppStorage("monthlyBudget") private var budget = 30000.0
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(AppLanguage.storageKey) private var languageCode = ""
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.system.rawValue
    @AppStorage(PrivacyLock.storageKey) private var privacyLockEnabled = false
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    @AppStorage(RecurringTransactionStore.storageKey) private var recurringTransactionsJSON = ""
    @AppStorage(BillReminderService.enabledKey) private var billRemindersEnabled = false
    @AppStorage(FinancialAccountStore.storageKey) private var accountsJSON = ""
    @AppStorage(CategoryBudgetStore.storageKey) private var categoryBudgetsJSON = ""
    @AppStorage(SavingsGoalStore.storageKey) private var savingsGoalsJSON = ""
    @AppStorage(OnboardingCoachMark.completionKey) private var hasCompletedOnboarding = false
    @State private var exporting = false
    @State private var csvExportKind: CSVExportKind = .transactions
    @State private var importing = false
    @State private var exportingBackup = false
    @State private var importingBackup = false
    @State private var pendingBackup: LedgerLeafBackup?
    @State private var selectedCurrency = CurrencyCatalog.defaultCode
    @State private var proposedCurrency: String?
    @State private var confirmingCurrency = false
    @State private var confirmingDeleteAll = false
    @State private var statusMessage: String?
    @State private var statusTitle = "Something Went Wrong"
    @FocusState private var isBudgetFieldFocused: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Picker("App Language", selection: $languageCode) {
                        ForEach(AppLanguage.supported) { language in
                            if language.code.isEmpty { Text("System Default").tag(language.code) }
                            else { Text(language.name).tag(language.code) }
                        }
                    }
                    Picker("App Theme", selection: $themeRaw) {
                        ForEach(AppTheme.allCases) { theme in Text(theme.title).tag(theme.rawValue) }
                    }
                    .accessibilityIdentifier("appThemePicker")
                    TextField("Monthly Budget", value: $budget, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($isBudgetFieldFocused)
                        .accessibilityIdentifier("monthlyBudgetField")
                    Picker("Default Currency", selection: $selectedCurrency) {
                        ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) }
                    }.onChange(of: selectedCurrency) { oldValue, newValue in
                        guard newValue != currencyCode else { return }
                        if transactions.isEmpty { currencyCode = newValue }
                        else { proposedCurrency = newValue; confirmingCurrency = true; selectedCurrency = oldValue }
                    }
                    Toggle("Privacy Lock", isOn: Binding(
                        get: { privacyLockEnabled },
                        set: { updatePrivacyLock($0) }
                    ))
                }
                Section("Plan & Organize") {
                    NavigationLink("Custom Categories") { CustomCategoriesView() }
                        .accessibilityIdentifier("customCategoriesLink")
                    NavigationLink("Wallets & Accounts") { AccountsView() }
                        .accessibilityIdentifier("accountsLink")
                    NavigationLink("Category Budgets") { CategoryBudgetsView() }
                        .accessibilityIdentifier("categoryBudgetsLink")
                    NavigationLink("Savings Goals") { SavingsGoalsView() }
                        .accessibilityIdentifier("savingsGoalsLink")
                }
                Section("Automation") {
                    Toggle("Bill Reminders", isOn: Binding(
                        get: { billRemindersEnabled },
                        set: { updateBillReminders($0) }
                    ))
                    .accessibilityIdentifier("billRemindersToggle")
                    NavigationLink("Recurring Transactions") { RecurringTransactionsView() }
                        .accessibilityIdentifier("recurringTransactionsLink")
                }
                Section("Data & Backup") {
                    Button("Export Complete Backup") { exportingBackup = true }
                        .accessibilityIdentifier("exportCompleteBackup")
                    Button("Restore Complete Backup") { importingBackup = true }
                        .accessibilityIdentifier("restoreCompleteBackup")
                    Button("Export Transactions (CSV)") { csvExportKind = .transactions; exporting = true }.disabled(transactions.isEmpty)
                    Button("Import Transactions (CSV)") { importing = true }
                    NavigationLink("CSV Import Guide") { CSVImportGuideView(downloadTemplate: { csvExportKind = .template; exporting = true }) }
                        .accessibilityIdentifier("csvImportGuide")
                    Text("CSV imports add transactions only and skip duplicates. Complete Backup includes wallets, budgets, goals, schedules, and preferences.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Delete All Transactions", role: .destructive) { confirmingDeleteAll = true }.disabled(transactions.isEmpty)
                }
                Section("Help & Legal") {
                    Button("View Getting Started Guide") { hasCompletedOnboarding = false }
                        .accessibilityIdentifier("showOnboarding")
                    Link("Support", destination: URL(string: "https://github.com/theluckiestsoul/expense_tracker/issues")!)
                    Link("Privacy Policy", destination: URL(string: "https://github.com/theluckiestsoul/expense_tracker/blob/main/PRIVACY.md")!)
                }
                Section("About") {
                    LabeledContent("LedgerLeaf", value: version)
                    LabeledContent("Data Storage", value: AppLanguage.localized("On this device"))
                }
            }.navigationTitle("Settings")
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isBudgetFieldFocused = false }
                            .accessibilityIdentifier("dismissBudgetKeyboard")
                    }
                }
                .onAppear { selectedCurrency = currencyCode }
                .fileExporter(isPresented: $exporting, document: CSVDocument(text: csvExportText), contentType: .commaSeparatedText, defaultFilename: csvExportFilename) { result in
                    if case .failure(let error) = result { showError(error) }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                    do { try importCSV(from: result.get()) }
                    catch { showError(error) }
                }
                .fileExporter(isPresented: $exportingBackup, document: BackupDocument(data: (try? completeBackup.encoded()) ?? Data()), contentType: .ledgerLeafBackup, defaultFilename: "ledgerleaf-complete-backup") { result in
                    if case .failure(let error) = result { showError(error) }
                }
                .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.ledgerLeafBackup, .json]) { result in
                    do { pendingBackup = try readBackup(from: result.get()) }
                    catch { showError(error) }
                }
                .confirmationDialog("Change default currency?", isPresented: $confirmingCurrency, titleVisibility: .visible) {
                    Button("Use \(proposedCurrency ?? currencyCode)") { if let proposedCurrency { currencyCode = proposedCurrency; selectedCurrency = proposedCurrency }; self.proposedCurrency = nil }
                    Button("Cancel", role: .cancel) { proposedCurrency = nil; selectedCurrency = currencyCode }
                } message: { Text("Existing transactions keep their original currency. Dashboard and report totals will show the selected currency only.") }
                .confirmationDialog("Delete all transactions?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                    Button("Delete All", role: .destructive, action: deleteAll); Button("Cancel", role: .cancel) {}
                } message: { Text("This permanently deletes \(transactions.count) transaction\(transactions.count == 1 ? "" : "s"). Export a backup first if needed.") }
                .confirmationDialog("Replace all LedgerLeaf data?", isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } }), titleVisibility: .visible) {
                    Button("Restore Backup", role: .destructive) { restorePendingBackup() }
                    Button("Cancel", role: .cancel) { pendingBackup = nil }
                } message: { Text("This replaces transactions, wallets, budgets, goals, schedules, and preferences on this device. This action can’t be undone.") }
                .alert(statusTitle, isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(statusMessage ?? "Unknown error") }
        }
    }
    private var csv: String {
        let rows = transactions
            .sorted { $0.transactionDate > $1.transactionDate }
            .map {
                let category = $0.categoryPresentation(customCategories: CustomCategoryCatalog.decode(customCategoriesJSON))
                return [
                    String($0.amount), $0.currencyCode ?? currencyCode,
                    $0.type.rawValue, category.isCustom ? category.name : $0.categoryRaw, $0.paymentMethod.rawValue,
                    $0.transactionDate.ISO8601Format(), $0.merchant, $0.notes,
                    category.symbol, category.colorName,
                    $0.transferID?.uuidString ?? "",
                    $0.createdAt.ISO8601Format()
                ]
            }
        return DomainLogic.csv(rows: [DomainLogic.transactionCSVHeaders] + rows)
    }
    private var csvTemplate: String { DomainLogic.csv(rows: [DomainLogic.transactionCSVHeaders]) }
    private var csvExportText: String { csvExportKind == .template ? csvTemplate : csv }
    private var csvExportFilename: String { csvExportKind == .template ? "ledgerleaf-import-template.csv" : "ledgerleaf-transactions.csv" }
    private var completeBackup: LedgerLeafBackup {
        LedgerLeafBackup(
            formatVersion: 1, exportedAt: .now,
            preferences: .init(currencyCode: currencyCode, monthlyBudget: budget, languageCode: languageCode, themeRaw: themeRaw),
            transactions: transactions.map { .init($0, fallbackCurrency: currencyCode) },
            customCategories: CustomCategoryCatalog.decode(customCategoriesJSON),
            accounts: FinancialAccountStore.decode(accountsJSON),
            categoryBudgets: CategoryBudgetStore.decode(categoryBudgetsJSON),
            savingsGoals: SavingsGoalStore.decode(savingsGoalsJSON),
            recurringTransactions: RecurringTransactionStore.decode(recurringTransactionsJSON)
        )
    }
    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    private func deleteAll() {
        transactions.forEach(context.delete)
        do { try context.save() } catch { context.rollback(); showError(error) }
    }

    private func readBackup(from url: URL) throws -> LedgerLeafBackup {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try LedgerLeafBackup.decoded(from: Data(contentsOf: url))
    }

    private func restorePendingBackup() {
        guard let backup = pendingBackup else { return }
        let existing = Dictionary(transactions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let restoredIDs = Set(backup.transactions.map(\.id))
        transactions.filter { !restoredIDs.contains($0.id) }.forEach(context.delete)
        for record in backup.transactions {
            let transaction = existing[record.id] ?? Transaction(amount: record.amount, type: record.type, category: ExpenseCategory.cases(for: record.type)[0], paymentMethod: record.paymentMethod, currencyCode: record.currencyCode, transactionDate: record.transactionDate, merchant: record.merchant, notes: record.notes)
            transaction.id = record.id; transaction.amount = record.amount; transaction.type = record.type
            transaction.categoryRaw = record.categoryRaw; transaction.paymentMethod = record.paymentMethod
            transaction.currencyCode = record.currencyCode; transaction.transactionDate = record.transactionDate
            transaction.merchant = record.merchant; transaction.notes = record.notes
            transaction.createdAt = record.createdAt; transaction.updatedAt = record.updatedAt
            transaction.recurringSourceID = record.recurringSourceID; transaction.accountID = record.accountID
            transaction.transferID = record.transferID
            if existing[record.id] == nil { context.insert(transaction) }
        }
        do {
            try context.save()
            currencyCode = backup.preferences.currencyCode; selectedCurrency = currencyCode
            budget = backup.preferences.monthlyBudget; languageCode = backup.preferences.languageCode
            if let restoredTheme = backup.preferences.themeRaw { themeRaw = restoredTheme }
            customCategoriesJSON = CustomCategoryCatalog.encode(backup.customCategories)
            accountsJSON = FinancialAccountStore.encode(backup.accounts)
            categoryBudgetsJSON = CategoryBudgetStore.encode(backup.categoryBudgets)
            savingsGoalsJSON = SavingsGoalStore.encode(backup.savingsGoals)
            recurringTransactionsJSON = RecurringTransactionStore.encode(backup.recurringTransactions)
            billRemindersEnabled = false
            pendingBackup = nil; statusTitle = "Restore Complete"
            statusMessage = "Restored \(backup.transactions.count) transactions and all included LedgerLeaf settings. Re-enable reminders if you want notifications on this device."
        } catch { context.rollback(); pendingBackup = nil; showError(error) }
    }

    private func importCSV(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { throw DomainLogic.CSVError.malformed }
        let imported = try CSVBackup.importTransactions(from: text)
        var customCategories = CustomCategoryCatalog.decode(customCategoriesJSON)
        for category in imported.compactMap(\.customCategory) where !customCategories.contains(where: { $0.id == category.id }) {
            customCategories.append(category)
        }
        customCategoriesJSON = CustomCategoryCatalog.encode(customCategories)
        var fingerprints = Set(transactions.map(backupFingerprint))
        var added = 0

        for record in imported where fingerprints.insert(backupFingerprint(record)).inserted {
            let transaction = Transaction(
                amount: record.amount, type: record.type, category: ExpenseCategory.cases(for: record.type)[0],
                paymentMethod: record.paymentMethod, currencyCode: record.currencyCode,
                transactionDate: record.transactionDate, merchant: record.merchant, notes: record.notes
            )
            transaction.categoryRaw = record.categoryRaw
            transaction.transferID = record.transferID
            transaction.createdAt = record.createdAt
            transaction.updatedAt = record.createdAt
            context.insert(transaction)
            added += 1
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
        statusTitle = "Import Complete"
        statusMessage = "Imported \(added) transaction\(added == 1 ? "" : "s"). Skipped \(imported.count - added) duplicate\(imported.count - added == 1 ? "" : "s")."
    }

    private func backupFingerprint(_ transaction: Transaction) -> String {
        backupFingerprint(amount: transaction.amount, currency: transaction.currencyCode ?? currencyCode,
                          type: transaction.type, categoryRaw: transaction.categoryRaw, payment: transaction.paymentMethod,
                          transactionDate: transaction.transactionDate, merchant: transaction.merchant,
                          notes: transaction.notes, transferID: transaction.transferID, createdAt: transaction.createdAt)
    }

    private func backupFingerprint(_ transaction: CSVBackup.ImportedTransaction) -> String {
        backupFingerprint(amount: transaction.amount, currency: transaction.currencyCode,
                          type: transaction.type, categoryRaw: transaction.categoryRaw, payment: transaction.paymentMethod,
                          transactionDate: transaction.transactionDate, merchant: transaction.merchant,
                          notes: transaction.notes, transferID: transaction.transferID, createdAt: transaction.createdAt)
    }

    private func backupFingerprint(amount: Double, currency: String, type: TransactionType, categoryRaw: String, payment: PaymentMethod, transactionDate: Date, merchant: String, notes: String, transferID: UUID?, createdAt: Date) -> String {
        DomainLogic.csv(rows: [[String(amount), currency, type.rawValue, categoryRaw, payment.rawValue,
                                transactionDate.ISO8601Format(), merchant, notes, transferID?.uuidString ?? "", createdAt.ISO8601Format()]])
    }

    private func showError(_ error: Error) {
        statusTitle = "Something Went Wrong"
        statusMessage = error.localizedDescription
    }

    private func updatePrivacyLock(_ enabled: Bool) {
        guard enabled else { privacyLockEnabled = false; return }
        Task { @MainActor in
            do {
                if try await PrivacyLock.authenticate(reason: "Enable privacy lock for LedgerLeaf.") {
                    privacyLockEnabled = true
                }
            } catch { showError(error) }
        }
    }

    private func updateBillReminders(_ enabled: Bool) {
        if !enabled {
            billRemindersEnabled = false
            Task { await BillReminderService.disable() }
            return
        }
        Task { @MainActor in
            do {
                if try await BillReminderService.enableAndSchedule(schedulesJSON: recurringTransactionsJSON) {
                    billRemindersEnabled = true
                } else {
                    billRemindersEnabled = false
                    statusTitle = "Notifications Disabled"
                    statusMessage = "Enable notifications for LedgerLeaf in iPhone Settings to receive bill reminders."
                }
            } catch {
                billRemindersEnabled = false
                showError(error)
            }
        }
    }
}

private struct CSVImportGuideView: View {
    let downloadTemplate: () -> Void

    var body: some View {
        List {
            Section("Recommended") {
                Label("Import a CSV previously exported by LedgerLeaf.", systemImage: "checkmark.shield.fill")
                Text("Imports merge with your current data. Existing transactions are kept and matching duplicates are skipped.")
                    .foregroundStyle(.secondary)
            }
            Section("Create Your Own CSV") {
                Button("Download Empty CSV Template", action: downloadTemplate)
                    .accessibilityIdentifier("downloadCSVTemplate")
                Text("Keep the header row unchanged and add one transaction per row. Spreadsheet apps such as Numbers, Excel, and Google Sheets can edit the file; save it as CSV before importing.")
                LabeledContent("Amount", value: "Positive number, for example 24.50")
                LabeledContent("Currency", value: "Three-letter code, for example USD or INR")
                LabeledContent("Type", value: "expense or income")
                LabeledContent("Dates", value: "ISO 8601, for example 2026-07-19T10:30:00Z")
                LabeledContent("Optional", value: "Merchant, Notes, Transfer ID")
            }
            Section("Columns (in this order)") {
                ForEach(Array(DomainLogic.transactionCSVHeaders.enumerated()), id: \.offset) { index, header in
                    LabeledContent("\(index + 1)", value: header)
                }
            }
            Section("Important") {
                Text("Category and Payment Method values are safest when copied from a LedgerLeaf export. Custom categories also require a supported Category Symbol and Category Color.")
                Text("CSV does not restore wallets or assign imported rows to a wallet. Use Complete Backup when moving all LedgerLeaf data to another device.")
            }
        }
        .navigationTitle("CSV Import Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}
