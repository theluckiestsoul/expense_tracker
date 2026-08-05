import Foundation

enum CustomReportDateRange: String, Codable, CaseIterable, Identifiable {
    case last7Days, last30Days, thisMonth, lastMonth, thisYear, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .last7Days: "Last 7 Days"
        case .last30Days: "Last 30 Days"
        case .thisMonth: "This Month"
        case .lastMonth: "Last Month"
        case .thisYear: "This Year"
        case .custom: "Custom Dates"
        }
    }

    func dates(now: Date = .now, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .last7Days:
            return (calendar.date(byAdding: .day, value: -6, to: today) ?? today, today)
        case .last30Days:
            return (calendar.date(byAdding: .day, value: -29, to: today) ?? today, today)
        case .thisMonth:
            return (calendar.dateInterval(of: .month, for: today)?.start ?? today, today)
        case .lastMonth:
            guard let prior = calendar.date(byAdding: .month, value: -1, to: today),
                  let interval = calendar.dateInterval(of: .month, for: prior) else { return nil }
            return (interval.start, calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end)
        case .thisYear:
            return (calendar.dateInterval(of: .year, for: today)?.start ?? today, today)
        case .custom:
            return nil
        }
    }
}

struct CustomReportPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var dateRange: CustomReportDateRange
    var startDate: Date
    var endDate: Date
    var typeRaw: String
    var categoryID: String
    var merchantQuery: String
}

enum CustomReportPresetStore {
    static let storageKey = "customReportPresetsJSON"
    static let maximumCount = 20
    static func decode(_ value: String) -> [CustomReportPreset] {
        guard let data = value.data(using: .utf8),
              let presets = try? JSONDecoder().decode([CustomReportPreset].self, from: data) else { return [] }
        return Array(presets.prefix(maximumCount))
    }
    static func encode(_ presets: [CustomReportPreset]) -> String {
        guard let data = try? JSONEncoder().encode(Array(presets.prefix(maximumCount))) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    static func saving(_ preset: CustomReportPreset, in presets: [CustomReportPreset]) -> [CustomReportPreset] {
        var result = presets.filter { $0.id != preset.id && $0.name.caseInsensitiveCompare(preset.name) != .orderedSame }
        result.insert(preset, at: 0)
        return Array(result.prefix(maximumCount))
    }
}

enum CustomReportFilter {
    static func transactions(
        from transactions: [Transaction], currencyCode: String,
        startDate: Date, endDate: Date, typeRaw: String,
        categoryID: String, merchantQuery: String,
        calendar: Calendar = .current
    ) -> [Transaction] {
        let start = calendar.startOfDay(for: min(startDate, endDate))
        let finalDay = calendar.startOfDay(for: max(startDate, endDate))
        let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: finalDay) ?? finalDay
        let query = MerchantRuleStore.normalizedKey(merchantQuery)
        return transactions.filter {
            !$0.isDeleted && $0.transferID == nil && ($0.currencyCode ?? currencyCode) == currencyCode &&
            $0.transactionDate >= start && $0.transactionDate < exclusiveEnd &&
            (typeRaw == "all" || $0.typeRaw == typeRaw) &&
            (categoryID == "all" || $0.categoryRaw == categoryID) &&
            (query.isEmpty || MerchantRuleStore.normalizedKey($0.merchant).contains(query))
        }.sorted { $0.transactionDate > $1.transactionDate }
    }
}
