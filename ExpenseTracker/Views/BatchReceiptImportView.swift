import SwiftUI
import SwiftData
import PhotosUI

private struct ReceiptDraft: Identifiable {
    let id = UUID()
    let imageData: Data
    var result: ReceiptScanResult
}

struct BatchReceiptImportView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @State private var selections: [PhotosPickerItem] = []
    @State private var drafts: [ReceiptDraft] = []
    @State private var scanning = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $selections, maxSelectionCount: 20, matching: .images) {
                    Label("Choose Receipt Images", systemImage: "photo.stack")
                }
                .disabled(scanning)
                Text("Select up to 20 receipts. LedgerLeaf scans each image on your device and creates a reviewable draft.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if scanning { Section { ProgressView("Scanning receipts…") } }
            if !drafts.isEmpty {
                Section("Review \(drafts.count) Receipt\(drafts.count == 1 ? "" : "s")") {
                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Merchant", text: Binding(
                                get: { draft.result.merchant ?? "" },
                                set: { draft.result.merchant = $0 }
                            ))
                            TextField("Amount", value: Binding(
                                get: { draft.result.amount ?? 0 },
                                set: { draft.result.amount = $0 }
                            ), format: .number).keyboardType(.decimalPad)
                            DatePicker("Date", selection: Binding(
                                get: { draft.result.date ?? .now },
                                set: { draft.result.date = $0 }
                            ), displayedComponents: .date)
                        }
                    }
                    Button("Import All Valid Receipts", action: save)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Batch Receipt Scan")
        .onChange(of: selections) { _, values in
            guard !values.isEmpty else { return }
            Task { await scan(values) }
        }
        .alert("Receipt Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    @MainActor private func scan(_ items: [PhotosPickerItem]) async {
        scanning = true; defer { scanning = false }
        var results: [ReceiptDraft] = []
        let scanner = ReceiptScanner()
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let result = try? await scanner.scan(data: data) else { continue }
            results.append(ReceiptDraft(imageData: data, result: result))
        }
        drafts = results
        if results.isEmpty { message = "No readable receipt details were found." }
    }

    private func save() {
        let valid = drafts.filter { ($0.result.amount ?? 0) > 0 }
        guard !valid.isEmpty else { message = "Enter an amount for at least one receipt."; return }
        valid.forEach { draft in
            let transaction = Transaction(amount: draft.result.amount ?? 0, type: .expense, category: .other,
                                          paymentMethod: .other, currencyCode: currencyCode,
                                          transactionDate: draft.result.date ?? .now,
                                          merchant: draft.result.merchant ?? "", notes: "Imported from receipt")
            transaction.receiptImageData = draft.imageData
            context.insert(transaction)
        }
        do {
            try context.save(); drafts.removeAll(); selections.removeAll()
            message = "\(valid.count) receipt\(valid.count == 1 ? "" : "s") imported."
        } catch { message = error.localizedDescription }
    }
}
