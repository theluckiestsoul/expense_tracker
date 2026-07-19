import Foundation

enum AppFormat {
    static func money(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(value)"
    }
}

struct CurrencyOption: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
    var label: String { "\(code) — \(name)" }
}

enum CurrencyCatalog {
    static let defaultCode = Locale.current.currency?.identifier ?? "USD"
    static let all: [CurrencyOption] = Locale.commonISOCurrencyCodes
        .map { CurrencyOption(code: $0, name: Locale.current.localizedString(forCurrencyCode: $0) ?? $0) }
        .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
}

extension Array where Element == Transaction {
    var expenses: Double { filter { $0.type == .expense && $0.transferID == nil }.reduce(0) { $0 + $1.amount } }
    var income: Double { filter { $0.type == .income && $0.transferID == nil }.reduce(0) { $0 + $1.amount } }
    func inCurrentMonth() -> [Transaction] { filter { Calendar.current.isDate($0.transactionDate, equalTo: .now, toGranularity: .month) } }
}
