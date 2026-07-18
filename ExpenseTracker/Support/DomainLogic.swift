import Foundation

enum DomainLogic {
    static let transactionCSVHeaders = [
        "Amount", "Currency", "Type", "Category", "Payment Method",
        "Transaction Date", "Merchant", "Notes", "Date Added"
    ]

    static func parseAmount(_ input: String, decimalSeparator: String = Locale.current.decimalSeparator ?? ".") -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        guard normalized.filter({ $0 == "." }).count <= 1,
              normalized.allSatisfy({ $0.isNumber || $0 == "." }),
              let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }

    static func sanitizedText(_ value: String, maximumLength: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumLength))
    }

    static func budgetProgress(spent: Double, budget: Double) -> Double {
        guard budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }

    static func budgetRemaining(spent: Double, budget: Double) -> Double {
        max(budget - spent, 0)
    }

    static func csvField(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func csv(rows: [[String]]) -> String {
        rows.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\n")
    }
}
