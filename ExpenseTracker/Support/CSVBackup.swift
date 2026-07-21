import Foundation

enum CSVBackup {
    struct ImportedTransaction: Hashable {
        let amount: Double
        let currencyCode: String
        let type: TransactionType
        let categoryRaw: String
        let customCategory: CustomCategory?
        let paymentMethod: PaymentMethod
        let transactionDate: Date
        let merchant: String
        let notes: String
        let transferID: UUID?
        let tags: [String]
        let createdAt: Date
    }

    static func importTransactions(from text: String) throws -> [ImportedTransaction] {
        let rows = try DomainLogic.parseCSV(text)
        guard let headers = rows.first,
              [DomainLogic.transactionCSVHeaders, DomainLogic.transferTransactionCSVHeaders, DomainLogic.previousTransactionCSVHeaders, DomainLogic.legacyTransactionCSVHeaders].contains(headers) else {
            throw DomainLogic.CSVError.invalidHeaders
        }
        let isLegacy = headers == DomainLogic.legacyTransactionCSVHeaders
        let includesTransferID = headers == DomainLogic.transactionCSVHeaders || headers == DomainLogic.transferTransactionCSVHeaders
        let includesTags = headers == DomainLogic.transactionCSVHeaders
        let formatter = ISO8601DateFormatter()
        return try rows.dropFirst().enumerated().map { offset, row in
            let rowNumber = offset + 2
            let expectedCount = headers.count
            guard row.count == expectedCount,
                  let amount = Double(row[0]), amount.isFinite, amount > 0,
                  CurrencyCatalog.all.contains(where: { $0.code == row[1] }),
                  let type = TransactionType(rawValue: row[2]),
                  let payment = PaymentMethod(rawValue: row[4]),
                  let transactionDate = formatter.date(from: row[5]),
                  let createdAt = formatter.date(from: row[row.count - 1]) else {
                throw DomainLogic.CSVError.invalidRow(rowNumber)
            }
            let transferID: UUID?
            if includesTransferID, !row[10].isEmpty {
                guard let parsed = UUID(uuidString: row[10]) else { throw DomainLogic.CSVError.invalidRow(rowNumber) }
                transferID = parsed
            } else {
                transferID = nil
            }
            let tags = includesTags ? TransactionTags.parse(row[11]) : []
            let categoryRaw: String
            let customCategory: CustomCategory?
            if let category = ExpenseCategory(rawValue: row[3]), ExpenseCategory.cases(for: type).contains(category) {
                categoryRaw = category.rawValue
                customCategory = nil
            } else {
                guard !isLegacy, !row[3].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      CustomCategoryCatalog.symbols.contains(row[8]),
                      CustomCategoryCatalog.colors.contains(row[9]) else { throw DomainLogic.CSVError.invalidRow(rowNumber) }
                let name = DomainLogic.sanitizedText(row[3], maximumLength: 40)
                let stableKey = Data("\(type.rawValue):\(name.lowercased())".utf8).base64EncodedString()
                categoryRaw = "custom:import:\(stableKey)"
                customCategory = CustomCategory(id: categoryRaw, name: name, type: type, symbol: row[8], colorName: row[9])
            }
            return ImportedTransaction(
                amount: amount, currencyCode: row[1], type: type, categoryRaw: categoryRaw, customCategory: customCategory,
                paymentMethod: payment, transactionDate: transactionDate,
                merchant: DomainLogic.sanitizedText(row[6], maximumLength: 80),
                notes: DomainLogic.sanitizedText(row[7], maximumLength: 240), transferID: transferID,
                tags: tags, createdAt: createdAt
            )
        }
    }
}
