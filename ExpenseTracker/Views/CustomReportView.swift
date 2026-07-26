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
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var exportingPDF = false

    private var selected: [Transaction] {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
        return transactions.filter {
            !$0.isDeleted && $0.transferID == nil && ($0.currencyCode ?? currencyCode) == currencyCode &&
            $0.transactionDate >= Calendar.current.startOfDay(for: startDate) && $0.transactionDate < end
        }
    }
    private var merchants: [MerchantSpending] { Array(ReportCalculator.merchantSpending(transactions: selected).prefix(5)) }
    private var pdfData: Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { context in
            context.beginPage()
            let title = "LedgerLeaf Financial Report"
            let range = "\(startDate.formatted(date: .long, time: .omitted)) – \(endDate.formatted(date: .long, time: .omitted))"
            let body = """
            \(title)

            \(range)

            Income: \(AppFormat.money(selected.income, currencyCode: currencyCode))
            Expenses: \(AppFormat.money(selected.expenses, currencyCode: currencyCode))
            Net: \(AppFormat.money(selected.income - selected.expenses, currencyCode: currencyCode))
            Transactions: \(selected.count)

            Top merchants:
            \(merchants.map { "\($0.merchantName): \(AppFormat.money($0.amount, currencyCode: currencyCode))" }.joined(separator: "\n"))

            Generated privately on device by LedgerLeaf.
            """
            body.draw(in: CGRect(x: 48, y: 48, width: 516, height: 696),
                      withAttributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.label])
        }
    }

    var body: some View {
        Form {
            Section("Date Range") {
                DatePicker("Start", selection: $startDate, in: ...endDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
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
            Section {
                Button("Export PDF Report", systemImage: "doc.richtext") { exportingPDF = true }
                    .disabled(selected.isEmpty)
                    .accessibilityIdentifier("exportPDFReport")
            }
        }
        .navigationTitle("Custom Report")
        .fileExporter(isPresented: $exportingPDF, document: PDFReportDocument(data: pdfData),
                      contentType: .pdf, defaultFilename: "ledgerleaf-report") { _ in }
    }
}
