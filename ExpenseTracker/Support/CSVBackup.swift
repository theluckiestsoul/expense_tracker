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
        let createdAt: Date
    }

    static func importTransactions(from text: String) throws -> [ImportedTransaction] {
        let rows = try DomainLogic.parseCSV(text)
        guard let headers = rows.first,
              headers == DomainLogic.transactionCSVHeaders || headers == DomainLogic.legacyTransactionCSVHeaders else { throw DomainLogic.CSVError.invalidHeaders }
        let isLegacy = headers == DomainLogic.legacyTransactionCSVHeaders
        let formatter = ISO8601DateFormatter()
        return try rows.dropFirst().enumerated().map { offset, row in
            let rowNumber = offset + 2
            let expectedCount = isLegacy ? DomainLogic.legacyTransactionCSVHeaders.count : DomainLogic.transactionCSVHeaders.count
            guard row.count == expectedCount,
                  let amount = Double(row[0]), amount.isFinite, amount > 0,
                  CurrencyCatalog.all.contains(where: { $0.code == row[1] }),
                  let type = TransactionType(rawValue: row[2]),
                  let payment = PaymentMethod(rawValue: row[4]),
                  let transactionDate = formatter.date(from: row[5]),
                  let createdAt = formatter.date(from: row[isLegacy ? 8 : 10]) else {
                throw DomainLogic.CSVError.invalidRow(rowNumber)
            }
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
                notes: DomainLogic.sanitizedText(row[7], maximumLength: 240), createdAt: createdAt
            )
        }
    }
}
