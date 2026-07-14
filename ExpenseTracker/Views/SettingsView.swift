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
    @State private var exporting = false
    @State private var selectedCurrency = CurrencyCatalog.defaultCode
    @State private var proposedCurrency: String?
    @State private var confirmingCurrency = false
    @State private var confirmingDeleteAll = false
    @State private var statusMessage: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    TextField("Monthly Budget", value: $budget, format: .number).keyboardType(.decimalPad)
                    Picker("Default Currency", selection: $selectedCurrency) {
                        ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) }
                    }.onChange(of: selectedCurrency) { oldValue, newValue in
                        guard newValue != currencyCode else { return }
                        if transactions.isEmpty { currencyCode = newValue }
                        else { proposedCurrency = newValue; confirmingCurrency = true; selectedCurrency = oldValue }
                    }
                }
                Section("Data & Backup") {
                    Button("Export Data (CSV)") { exporting = true }.disabled(transactions.isEmpty)
                    Button("Delete All Transactions", role: .destructive) { confirmingDeleteAll = true }.disabled(transactions.isEmpty)
                }
                Section("About") { LabeledContent("Expense Tracker", value: "1.0") }
            }.navigationTitle("Settings")
                .onAppear { selectedCurrency = currencyCode }
                .fileExporter(isPresented: $exporting, document: CSVDocument(text: csv), contentType: .commaSeparatedText, defaultFilename: "expense-tracker-transactions.csv") { result in
                    if case .failure(let error) = result { statusMessage = error.localizedDescription }
                }
                .confirmationDialog("Change default currency?", isPresented: $confirmingCurrency, titleVisibility: .visible) {
                    Button("Use \(proposedCurrency ?? currencyCode)") { if let proposedCurrency { currencyCode = proposedCurrency; selectedCurrency = proposedCurrency }; self.proposedCurrency = nil }
                    Button("Cancel", role: .cancel) { proposedCurrency = nil; selectedCurrency = currencyCode }
                } message: { Text("Existing transactions keep their original currency. Dashboard and report totals will show the selected currency only.") }
                .confirmationDialog("Delete all transactions?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                    Button("Delete All", role: .destructive, action: deleteAll); Button("Cancel", role: .cancel) {}
                } message: { Text("This permanently deletes \(transactions.count) transaction\(transactions.count == 1 ? "" : "s"). Export a backup first if needed.") }
                .alert("Something Went Wrong", isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(statusMessage ?? "Unknown error") }
        }
    }
    private var csv: String {
        let header = ["id", "amount", "currency", "type", "category", "paymentMethod", "date", "merchant", "notes", "createdAt", "updatedAt"]
        let rows = transactions.map { [$0.id.uuidString, String($0.amount), $0.currencyCode ?? currencyCode, $0.type.rawValue, $0.category.rawValue, $0.paymentMethod.rawValue, $0.transactionDate.ISO8601Format(), $0.merchant, $0.notes, $0.createdAt.ISO8601Format(), $0.updatedAt.ISO8601Format()] }
        return DomainLogic.csv(rows: [header] + rows)
    }
    private func deleteAll() {
        transactions.forEach(context.delete)
        do { try context.save() } catch { context.rollback(); statusMessage = error.localizedDescription }
    }
}
