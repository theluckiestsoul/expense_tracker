import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BankCSVImportView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(BankImportProfileStore.storageKey) private var profilesJSON = ""
    @State private var importing = false
    @State private var rows: [[String]] = []
    @State private var amountColumn = ""
    @State private var dateColumn = ""
    @State private var merchantColumn = ""
    @State private var typeColumn = ""
    @State private var dateFormat = "yyyy-MM-dd"
    @State private var profileName = ""
    @State private var message: String?

    private var headers: [String] { rows.first ?? [] }
    private var profiles: [BankImportProfile] { BankImportProfileStore.decode(profilesJSON) }

    var body: some View {
        Form {
            Section {
                Button("Choose Bank CSV", systemImage: "tablecells") { importing = true }
                if rows.count > 1 { Text("\(rows.count - 1) rows loaded").foregroundStyle(.secondary) }
            }
            if !headers.isEmpty {
                Section("Map Columns") {
                    columnPicker("Amount", selection: $amountColumn, optional: false)
                    columnPicker("Date", selection: $dateColumn, optional: false)
                    columnPicker("Merchant", selection: $merchantColumn, optional: false)
                    columnPicker("Type", selection: $typeColumn, optional: true)
                    TextField("Date format", text: $dateFormat)
                    Text("Examples: yyyy-MM-dd, dd/MM/yyyy, MM/dd/yyyy")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Reusable Profile") {
                    TextField("Profile name (optional)", text: $profileName)
                    if !profiles.isEmpty {
                        Menu("Load Saved Profile") {
                            ForEach(profiles) { profile in Button(profile.name) { apply(profile) } }
                        }
                    }
                }
                Button("Import \(rows.count - 1) Transactions") { importMappedRows() }
                    .disabled(amountColumn.isEmpty || dateColumn.isEmpty || merchantColumn.isEmpty)
                    .accessibilityIdentifier("importMappedBankCSV")
            }
        }
        .navigationTitle("Bank CSV Mapping")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let text = String(data: try Data(contentsOf: url), encoding: .utf8) else {
                    throw DomainLogic.CSVError.malformed
                }
                rows = try DomainLogic.parseCSV(text)
                if let headers = rows.first {
                    amountColumn = guess(headers, terms: ["amount", "value", "debit"])
                    dateColumn = guess(headers, terms: ["date", "posted"])
                    merchantColumn = guess(headers, terms: ["merchant", "description", "narration", "details"])
                    typeColumn = guess(headers, terms: ["type", "debit/credit", "dr/cr"])
                }
            } catch { message = error.localizedDescription }
        }
        .alert("Bank Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func columnPicker(_ title: String, selection: Binding<String>, optional: Bool) -> some View {
        Picker(title, selection: selection) {
            if optional { Text("Not provided").tag("") }
            ForEach(headers, id: \.self) { Text($0).tag($0) }
        }
    }

    private func guess(_ headers: [String], terms: [String]) -> String {
        headers.first { header in terms.contains { header.localizedCaseInsensitiveContains($0) } } ?? ""
    }

    private func apply(_ profile: BankImportProfile) {
        amountColumn = profile.amountColumn; dateColumn = profile.dateColumn
        merchantColumn = profile.merchantColumn; typeColumn = profile.typeColumn ?? ""
        dateFormat = profile.dateFormat; profileName = profile.name
    }

    private func importMappedRows() {
        guard let amountIndex = headers.firstIndex(of: amountColumn),
              let dateIndex = headers.firstIndex(of: dateColumn),
              let merchantIndex = headers.firstIndex(of: merchantColumn) else { return }
        let typeIndex = headers.firstIndex(of: typeColumn)
        let formatter = DateFormatter(); formatter.dateFormat = dateFormat; formatter.locale = Locale(identifier: "en_US_POSIX")
        var imported = 0
        for row in rows.dropFirst() where row.count == headers.count {
            let rawAmount = row[amountIndex].replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: currencyCode, with: "").trimmingCharacters(in: .whitespaces)
            guard let signed = Double(rawAmount), signed.isFinite, signed != 0,
                  let date = formatter.date(from: row[dateIndex]) else { continue }
            let typeText = typeIndex.map { row[$0].lowercased() } ?? ""
            let type: TransactionType = signed < 0 || typeText.contains("debit") || typeText == "dr" ? .expense : .income
            let category = ExpenseCategory.cases(for: type)[0]
            context.insert(Transaction(amount: abs(signed), type: type, category: category, paymentMethod: .bank,
                                       currencyCode: currencyCode, transactionDate: date,
                                       merchant: DomainLogic.sanitizedText(row[merchantIndex], maximumLength: 80)))
            imported += 1
        }
        do {
            try context.save()
            if !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let profile = BankImportProfile(name: DomainLogic.sanitizedText(profileName, maximumLength: 40),
                    amountColumn: amountColumn, dateColumn: dateColumn, merchantColumn: merchantColumn,
                    typeColumn: typeColumn.isEmpty ? nil : typeColumn, dateFormat: dateFormat)
                profilesJSON = BankImportProfileStore.encode(profiles.filter { $0.name != profile.name } + [profile])
            }
            message = "Imported \(imported) transaction\(imported == 1 ? "" : "s")."
        } catch { context.rollback(); message = error.localizedDescription }
    }
}
