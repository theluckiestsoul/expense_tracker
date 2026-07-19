import Foundation
import SwiftData

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .weekly: calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly: calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

struct RecurringTransaction: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var type: TransactionType
    var categoryRaw: String
    var paymentMethod: PaymentMethod
    var currencyCode: String
    var merchant: String
    var notes: String
    var frequency: RecurrenceFrequency
    var nextDate: Date
    var isActive: Bool

    init(id: UUID = UUID(), name: String, amount: Double, type: TransactionType, categoryRaw: String, paymentMethod: PaymentMethod, currencyCode: String, merchant: String, notes: String, frequency: RecurrenceFrequency, nextDate: Date, isActive: Bool = true) {
        self.id = id; self.name = name; self.amount = amount; self.type = type; self.categoryRaw = categoryRaw
        self.paymentMethod = paymentMethod; self.currencyCode = currencyCode; self.merchant = merchant; self.notes = notes
        self.frequency = frequency; self.nextDate = nextDate; self.isActive = isActive
    }
}

enum RecurringTransactionStore {
    static let storageKey = "recurringTransactionsJSON"

    static func decode(_ json: String) -> [RecurringTransaction] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([RecurringTransaction].self, from: data)) ?? []
    }

    static func encode(_ schedules: [RecurringTransaction]) -> String {
        guard let data = try? JSONEncoder().encode(schedules) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

enum RecurringTransactionProcessor {
    @MainActor
    static func processDue(in context: ModelContext, schedulesJSON: String, now: Date = .now, calendar: Calendar = .current) throws -> String {
        var schedules = RecurringTransactionStore.decode(schedulesJSON)
        var inserted = false
        let existing = try context.fetch(FetchDescriptor<Transaction>())
        let existingOccurrences = Set(existing.compactMap { transaction -> String? in
            guard let sourceID = transaction.recurringSourceID else { return nil }
            return "\(sourceID.uuidString)|\(transaction.transactionDate.timeIntervalSinceReferenceDate)"
        })

        for index in schedules.indices where schedules[index].isActive {
            var generated = 0
            while schedules[index].nextDate <= now, generated < 120 {
                let schedule = schedules[index]
                let occurrenceKey = "\(schedule.id.uuidString)|\(schedule.nextDate.timeIntervalSinceReferenceDate)"
                if !existingOccurrences.contains(occurrenceKey) {
                    let fallback = ExpenseCategory.cases(for: schedule.type)[0]
                    let transaction = Transaction(amount: schedule.amount, type: schedule.type, category: fallback, paymentMethod: schedule.paymentMethod, currencyCode: schedule.currencyCode, transactionDate: schedule.nextDate, merchant: schedule.merchant, notes: schedule.notes)
                    transaction.categoryRaw = schedule.categoryRaw
                    transaction.recurringSourceID = schedule.id
                    context.insert(transaction)
                    inserted = true
                }
                guard let followingDate = schedule.frequency.nextDate(after: schedule.nextDate, calendar: calendar) else { break }
                schedules[index].nextDate = followingDate
                generated += 1
            }
        }
        if inserted { try context.save() }
        return RecurringTransactionStore.encode(schedules)
    }
}
