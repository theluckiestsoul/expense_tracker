import Foundation

struct TransactionTemplate: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var type: TransactionType
    var categoryID: String
    var paymentMethod: PaymentMethod
    var currencyCode: String
    var merchant: String
    var notes: String
    var tags: [String]
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, amount: Double, type: TransactionType, categoryID: String,
         paymentMethod: PaymentMethod, currencyCode: String, merchant: String, notes: String,
         tags: [String], updatedAt: Date = .now) {
        self.id = id
        self.name = DomainLogic.sanitizedText(name, maximumLength: 40)
        self.amount = amount
        self.type = type
        self.categoryID = categoryID
        self.paymentMethod = paymentMethod
        self.currencyCode = currencyCode
        self.merchant = DomainLogic.sanitizedText(merchant, maximumLength: 80)
        self.notes = DomainLogic.sanitizedText(notes, maximumLength: 500)
        self.tags = TransactionTags.normalized(tags)
        self.updatedAt = updatedAt
    }
}

enum TransactionTemplateStore {
    static let storageKey = "transactionTemplatesJSON"

    static func decode(_ json: String) -> [TransactionTemplate] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([TransactionTemplate].self, from: data)) ?? []
    }

    static func encode(_ templates: [TransactionTemplate]) -> String {
        guard let data = try? JSONEncoder().encode(templates) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func upserting(_ template: TransactionTemplate, in templates: [TransactionTemplate],
                           limit: Int = 30) -> [TransactionTemplate] {
        ([template] + templates.filter { $0.id != template.id })
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(max(1, limit)).map { $0 }
    }

    static func isValid(_ template: TransactionTemplate) -> Bool {
        !template.name.isEmpty && template.amount.isFinite && template.amount > 0 &&
        CurrencyCatalog.all.contains(where: { $0.code == template.currencyCode }) &&
        !template.categoryID.isEmpty && TransactionTags.normalized(template.tags) == template.tags
    }
}
