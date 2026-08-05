import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct PDFReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct CustomReportView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CustomReportPresetStore.storageKey) private var presetsJSON = ""
    @State private var dateRange: CustomReportDateRange = .last30Days
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var typeRaw = "all"
    @State private var categoryID = "all"
    @State private var merchantQuery = ""
    @State private var exportingPDF = false
    @State private var exportingCSV = false
    @State private var namingPreset = false
    @State private var presetName = ""

    private var selected: [Transaction] {
        CustomReportFilter.transactions(
            from: transactions, currencyCode: currencyCode, startDate: startDate, endDate: endDate,
            typeRaw: typeRaw, categoryID: categoryID, merchantQuery: merchantQuery
        )
    }
    private var presets: [CustomReportPreset] { CustomReportPresetStore.decode(presetsJSON) }
    private var categoryChoices: [String] {
        let stored = Set(transactions.filter { !$0.isDeleted }.map(\.categoryRaw))
        return Array(stored.union(ExpenseCategory.allCases.map(\.rawValue))).sorted()
    }
    private var merchants: [MerchantSpending] { Array(ReportCalculator.merchantSpending(transactions: selected).prefix(8)) }
    private var pdfData: Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { context in
            context.beginPage()
            let lines = selected.prefix(18).map {
                "\($0.transactionDate.formatted(date: .abbreviated, time: .omitted))  \($0.merchant.isEmpty ? $0.categoryRaw : $0.merchant)  \(AppFormat.money($0.amount, currencyCode: currencyCode))"
            }.joined(separator: "\n")
            let body = """
            LedgerLeaf Custom Report

            \(startDate.formatted(date: .long, time: .omitted)) – \(endDate.formatted(date: .long, time: .omitted))
            Filters: \(typeLabel), \(categoryID == "all" ? "All categories" : categoryID)\(merchantQuery.isEmpty ? "" : ", merchant contains “\(merchantQuery)”")

            Income: \(AppFormat.money(selected.income, currencyCode: currencyCode))
            Expenses: \(AppFormat.money(selected.expenses, currencyCode: currencyCode))
            Net: \(AppFormat.money(selected.income - selected.expenses, currencyCode: currencyCode))
            Transactions: \(selected.count)

            Recent matching transactions:
            \(lines)

            Generated privately on device by LedgerLeaf.
            """
            body.draw(in: CGRect(x: 42, y: 42, width: 528, height: 708),
                      withAttributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.label])
        }
    }
    private var csv: String {
        let rows = selected.map {
            [$0.transactionDate.ISO8601Format(), $0.type.rawValue, String($0.amount), $0.currencyCode ?? currencyCode,
             $0.categoryRaw, $0.merchant, $0.paymentMethod.rawValue, $0.notes]
        }
        return DomainLogic.csv(rows: [["Date", "Type", "Amount", "Currency", "Category", "Merchant", "Payment Method", "Notes"]] + rows)
    }
    private var typeLabel: String {
        typeRaw == "all" ? "All types" : (TransactionType(rawValue: typeRaw)?.title ?? typeRaw)
    }

    var body: some View {
        Form {
            if !presets.isEmpty {
                Section("Saved Reports") {
                    ForEach(presets) { preset in
                        Button { apply(preset) } label: {
                            Label(preset.name, systemImage: "doc.text.magnifyingglass")
                        }.foregroundStyle(.primary)
                    }.onDelete(perform: deletePresets)
                }
            }
            Section("Date Filter") {
                Picker("Range", selection: $dateRange) {
                    ForEach(CustomReportDateRange.allCases) { Text($0.title).tag($0) }
                }.onChange(of: dateRange) { _, value in apply(value) }
                if dateRange == .custom {
                    DatePicker("Start", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                } else {
                    LabeledContent("From", value: startDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Through", value: endDate.formatted(date: .abbreviated, time: .omitted))
                }
            }
            Section("Report Filters") {
                Picker("Transaction Type", selection: $typeRaw) {
                    Text("All Types").tag("all")
                    ForEach(TransactionType.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Category", selection: $categoryID) {
                    Text("All Categories").tag("all")
                    ForEach(categoryChoices, id: \.self) { Text($0).tag($0) }
                }
                TextField("Merchant contains", text: $merchantQuery)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
            }
            Section("Summary") {
                LabeledContent("Income", value: AppFormat.money(selected.income, currencyCode: currencyCode))
                LabeledContent("Expenses", value: AppFormat.money(selected.expenses, currencyCode: currencyCode))
                LabeledContent("Net", value: AppFormat.money(selected.income - selected.expenses, currencyCode: currencyCode))
                LabeledContent("Transactions", value: "\(selected.count)")
            }
            if !merchants.isEmpty {
                Section("Top Merchants") {
                    ForEach(merchants) { LabeledContent($0.merchantName, value: AppFormat.money($0.amount, currencyCode: currencyCode)) }
                }
            }
            Section("Generate Report") {
                Button("Save Report Setup", systemImage: "bookmark") { presetName = ""; namingPreset = true }
                Button("Export PDF Report", systemImage: "doc.richtext") { exportingPDF = true }.disabled(selected.isEmpty)
                Button("Export Filtered CSV", systemImage: "tablecells") { exportingCSV = true }.disabled(selected.isEmpty)
            }
        }
        .navigationTitle("Custom Report")
        .onAppear { apply(dateRange) }
        .alert("Name This Report", isPresented: $namingPreset) {
            TextField("Report name", text: $presetName)
            Button("Save") { savePreset() }.disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: { Text("Save these dates and filters so you can generate the report again.") }
        .fileExporter(isPresented: $exportingPDF, document: PDFReportDocument(data: pdfData),
                      contentType: .pdf, defaultFilename: "ledgerleaf-custom-report") { _ in }
        .fileExporter(isPresented: $exportingCSV, document: CSVDocument(text: csv),
                      contentType: .commaSeparatedText, defaultFilename: "ledgerleaf-custom-report") { _ in }
    }

    private func apply(_ range: CustomReportDateRange) {
        guard let dates = range.dates() else { return }
        startDate = dates.start; endDate = dates.end
    }
    private func apply(_ preset: CustomReportPreset) {
        dateRange = preset.dateRange; startDate = preset.startDate; endDate = preset.endDate
        typeRaw = preset.typeRaw; categoryID = preset.categoryID; merchantQuery = preset.merchantQuery
    }
    private func savePreset() {
        let preset = CustomReportPreset(
            id: UUID(), name: presetName.trimmingCharacters(in: .whitespacesAndNewlines),
            dateRange: dateRange, startDate: startDate, endDate: endDate,
            typeRaw: typeRaw, categoryID: categoryID, merchantQuery: merchantQuery
        )
        presetsJSON = CustomReportPresetStore.encode(CustomReportPresetStore.saving(preset, in: presets))
    }
    private func deletePresets(at offsets: IndexSet) {
        var values = presets; values.remove(atOffsets: offsets)
        presetsJSON = CustomReportPresetStore.encode(values)
    }
}
