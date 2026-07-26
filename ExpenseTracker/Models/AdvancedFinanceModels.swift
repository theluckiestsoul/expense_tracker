import Foundation

struct TransactionSplit: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var categoryID: String
    var amount: Double
    var note: String = ""
}

struct TransactionRevision: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var changedAt: Date
    var amount: Double
    var type: TransactionType
    var categoryID: String
    var paymentMethod: PaymentMethod
    var merchant: String
    var notes: String
    var tags: [String]
}

enum TransactionMetadata {
    static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: String?) -> T? {
        guard let value, let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func validSplits(_ splits: [TransactionSplit], total: Double) -> Bool {
        !splits.isEmpty && splits.allSatisfy {
            $0.amount.isFinite && $0.amount > 0 && !$0.categoryID.isEmpty
        } && abs(splits.reduce(0) { $0 + $1.amount } - total) < 0.005
    }
}

struct BudgetWorkspace: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var currencyCode: String
    var categoryIDs: [String]
    var rolloverEnabled: Bool
    var carriedAmount: Double = 0
}

enum BudgetWorkspaceStore {
    static let storageKey = "budgetWorkspacesJSON"
    static func decode(_ json: String) -> [BudgetWorkspace] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([BudgetWorkspace].self, from: data)) ?? []
    }
    static func encode(_ values: [BudgetWorkspace]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

struct EnvelopeAllocation: Codable, Equatable, Identifiable {
    var id: String { "\(currencyCode)|\(categoryID)" }
    var categoryID: String
    var currencyCode: String
    var allocatedAmount: Double
}

enum EnvelopeStore {
    static let storageKey = "envelopeAllocationsJSON"
    static func decode(_ json: String) -> [EnvelopeAllocation] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([EnvelopeAllocation].self, from: data)) ?? []
    }
    static func encode(_ values: [EnvelopeAllocation]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

struct BankImportProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var amountColumn: String
    var dateColumn: String
    var merchantColumn: String
    var typeColumn: String?
    var dateFormat: String
}

enum BankImportProfileStore {
    static let storageKey = "bankImportProfilesJSON"
    static func decode(_ json: String) -> [BankImportProfile] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([BankImportProfile].self, from: data)) ?? []
    }
    static func encode(_ values: [BankImportProfile]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
