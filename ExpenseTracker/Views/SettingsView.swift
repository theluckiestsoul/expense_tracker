import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @AppStorage("monthlyBudget") private var budget = 30000.0
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(AppLanguage.storageKey) private var languageCode = ""
    @AppStorage(PrivacyLock.storageKey) private var privacyLockEnabled = false
    @State private var exporting = false
    @State private var importing = false
    @State private var selectedCurrency = CurrencyCatalog.defaultCode
    @State private var proposedCurrency: String?
    @State private var confirmingCurrency = false
    @State private var confirmingDeleteAll = false
    @State private var statusMessage: String?
    @State private var statusTitle = "Something Went Wrong"
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
                    TextField("Monthly Budget", value: $budget, format: .number).keyboardType(.decimalPad)
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
                Section("Data & Backup") {
                    Button("Export Data (CSV)") { exporting = true }.disabled(transactions.isEmpty)
                    Button("Import Data (CSV)") { importing = true }
                    Button("Delete All Transactions", role: .destructive) { confirmingDeleteAll = true }.disabled(transactions.isEmpty)
                }
                Section("Help & Legal") {
                    Link("Support", destination: URL(string: "https://github.com/theluckiestsoul/expense_tracker/issues")!)
                    Link("Privacy Policy", destination: URL(string: "https://github.com/theluckiestsoul/expense_tracker/blob/main/PRIVACY.md")!)
                }
                Section("About") {
                    LabeledContent("LedgerLeaf", value: version)
                    LabeledContent("Data Storage", value: AppLanguage.localized("On this device"))
                }
            }.navigationTitle("Settings")
                .onAppear { selectedCurrency = currencyCode }
                .fileExporter(isPresented: $exporting, document: CSVDocument(text: csv), contentType: .commaSeparatedText, defaultFilename: "ledgerleaf-transactions.csv") { result in
                    if case .failure(let error) = result { showError(error) }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                    do { try importCSV(from: result.get()) }
                    catch { showError(error) }
                }
                .confirmationDialog("Change default currency?", isPresented: $confirmingCurrency, titleVisibility: .visible) {
                    Button("Use \(proposedCurrency ?? currencyCode)") { if let proposedCurrency { currencyCode = proposedCurrency; selectedCurrency = proposedCurrency }; self.proposedCurrency = nil }
                    Button("Cancel", role: .cancel) { proposedCurrency = nil; selectedCurrency = currencyCode }
                } message: { Text("Existing transactions keep their original currency. Dashboard and report totals will show the selected currency only.") }
                .confirmationDialog("Delete all transactions?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                    Button("Delete All", role: .destructive, action: deleteAll); Button("Cancel", role: .cancel) {}
                } message: { Text("This permanently deletes \(transactions.count) transaction\(transactions.count == 1 ? "" : "s"). Export a backup first if needed.") }
                .alert(statusTitle, isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(statusMessage ?? "Unknown error") }
        }
    }
    private var csv: String {
        let rows = transactions
            .sorted { $0.transactionDate > $1.transactionDate }
            .map {
                [
                    String($0.amount), $0.currencyCode ?? currencyCode,
                    $0.type.rawValue, $0.category.rawValue, $0.paymentMethod.rawValue,
                    $0.transactionDate.ISO8601Format(), $0.merchant, $0.notes,
                    $0.createdAt.ISO8601Format()
                ]
            }
        return DomainLogic.csv(rows: [DomainLogic.transactionCSVHeaders] + rows)
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

    private func importCSV(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { throw DomainLogic.CSVError.malformed }
        let imported = try CSVBackup.importTransactions(from: text)
        var fingerprints = Set(transactions.map(backupFingerprint))
        var added = 0

        for record in imported where fingerprints.insert(backupFingerprint(record)).inserted {
            let transaction = Transaction(
                amount: record.amount, type: record.type, category: record.category,
                paymentMethod: record.paymentMethod, currencyCode: record.currencyCode,
                transactionDate: record.transactionDate, merchant: record.merchant, notes: record.notes
            )
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
        backupFingerprint(.init(
            amount: transaction.amount, currencyCode: transaction.currencyCode ?? currencyCode,
            type: transaction.type, category: transaction.category, paymentMethod: transaction.paymentMethod,
            transactionDate: transaction.transactionDate, merchant: transaction.merchant,
            notes: transaction.notes, createdAt: transaction.createdAt
        ))
    }

    private func backupFingerprint(_ transaction: CSVBackup.ImportedTransaction) -> String {
        DomainLogic.csv(rows: [[
            String(transaction.amount), transaction.currencyCode, transaction.type.rawValue,
            transaction.category.rawValue, transaction.paymentMethod.rawValue,
            transaction.transactionDate.ISO8601Format(), transaction.merchant,
            transaction.notes, transaction.createdAt.ISO8601Format()
        ]])
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
}
