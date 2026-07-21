import Foundation

struct MerchantRule: Codable, Equatable, Identifiable {
    var id: UUID
    var merchantKey: String
    var merchantName: String
    var type: TransactionType
    var categoryID: String
    var paymentMethod: PaymentMethod
    var updatedAt: Date

    init(id: UUID = UUID(), merchantName: String, type: TransactionType, categoryID: String,
         paymentMethod: PaymentMethod, updatedAt: Date = .now) {
        self.id = id
        self.merchantName = DomainLogic.sanitizedText(merchantName, maximumLength: 80)
        merchantKey = MerchantRuleStore.normalizedKey(merchantName)
        self.type = type
        self.categoryID = categoryID
        self.paymentMethod = paymentMethod
        self.updatedAt = updatedAt
    }
}

enum MerchantRuleStore {
    static let storageKey = "merchantRulesJSON"

    static func normalizedKey(_ merchant: String) -> String {
        merchant
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    static func decode(_ json: String) -> [MerchantRule] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([MerchantRule].self, from: data)) ?? []
    }

    static func encode(_ rules: [MerchantRule]) -> String {
        guard let data = try? JSONEncoder().encode(rules) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func matching(_ merchant: String, in rules: [MerchantRule]) -> MerchantRule? {
        let key = normalizedKey(merchant)
        guard !key.isEmpty else { return nil }
        return rules.first { $0.merchantKey == key }
    }

    static func upserting(_ rule: MerchantRule, in rules: [MerchantRule], limit: Int = 200) -> [MerchantRule] {
        guard !rule.merchantKey.isEmpty else { return rules }
        var updated = rules.filter { $0.merchantKey != rule.merchantKey }
        updated.insert(rule, at: 0)
        return Array(updated.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit))
    }
}
