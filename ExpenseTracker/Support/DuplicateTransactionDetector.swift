import Foundation

enum DuplicateTransactionDetector {
    static func likelyDuplicate(amount: Double,
                                type: TransactionType,
                                currencyCode: String,
                                date: Date,
                                merchant: String,
                                categoryID: String,
                                among transactions: [Transaction],
                                calendar: Calendar = .current) -> Transaction? {
        let merchantKey = MerchantRuleStore.normalizedKey(merchant)
        return transactions
            .filter { !$0.isDeleted && $0.transferID == nil }
            .filter { $0.type == type && ($0.currencyCode ?? currencyCode) == currencyCode }
            .filter { abs($0.amount - amount) < 0.005 }
            .filter {
                abs(calendar.dateComponents([.day],
                                            from: calendar.startOfDay(for: $0.transactionDate),
                                            to: calendar.startOfDay(for: date)).day ?? .max) <= 2
            }
            .filter {
                let existingMerchant = MerchantRuleStore.normalizedKey($0.merchant)
                if !merchantKey.isEmpty || !existingMerchant.isEmpty {
                    return merchantKey == existingMerchant
                }
                return $0.categoryRaw == categoryID && calendar.isDate($0.transactionDate, inSameDayAs: date)
            }
            .min { first, second in
                abs(first.transactionDate.timeIntervalSince(date)) < abs(second.transactionDate.timeIntervalSince(date))
            }
    }
}
