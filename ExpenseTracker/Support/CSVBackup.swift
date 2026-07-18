import Foundation

enum CSVBackup {
    struct ImportedTransaction: Hashable {
        let amount: Double
        let currencyCode: String
        let type: TransactionType
        let category: ExpenseCategory
        let paymentMethod: PaymentMethod
        let transactionDate: Date
        let merchant: String
        let notes: String
        let createdAt: Date
    }

    static func importTransactions(from text: String) throws -> [ImportedTransaction] {
        let rows = try DomainLogic.parseCSV(text)
        guard rows.first == DomainLogic.transactionCSVHeaders else { throw DomainLogic.CSVError.invalidHeaders }
        let formatter = ISO8601DateFormatter()
        return try rows.dropFirst().enumerated().map { offset, row in
            let rowNumber = offset + 2
            guard row.count == DomainLogic.transactionCSVHeaders.count,
                  let amount = Double(row[0]), amount.isFinite, amount > 0,
                  CurrencyCatalog.all.contains(where: { $0.code == row[1] }),
                  let type = TransactionType(rawValue: row[2]),
                  let category = ExpenseCategory(rawValue: row[3]),
                  ExpenseCategory.cases(for: type).contains(category),
                  let payment = PaymentMethod(rawValue: row[4]),
                  let transactionDate = formatter.date(from: row[5]),
                  let createdAt = formatter.date(from: row[8]) else {
                throw DomainLogic.CSVError.invalidRow(rowNumber)
            }
            return ImportedTransaction(
                amount: amount, currencyCode: row[1], type: type, category: category,
                paymentMethod: payment, transactionDate: transactionDate,
                merchant: DomainLogic.sanitizedText(row[6], maximumLength: 80),
                notes: DomainLogic.sanitizedText(row[7], maximumLength: 240), createdAt: createdAt
            )
        }
    }
}
