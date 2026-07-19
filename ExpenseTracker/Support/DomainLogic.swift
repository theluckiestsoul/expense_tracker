import Foundation

enum DomainLogic {
    enum BudgetStatus: Equatable {
        case disabled
        case onTrack
        case approaching
        case nearlyReached
        case exceeded
    }

    enum CSVError: LocalizedError, Equatable {
        case malformed
        case invalidHeaders
        case invalidRow(Int)

        var errorDescription: String? {
            switch self {
            case .malformed: "The CSV file is malformed."
            case .invalidHeaders: "This file is not a LedgerLeaf CSV backup."
            case .invalidRow(let row): "Transaction row \(row) contains invalid data."
            }
        }
    }

    static let transactionCSVHeaders = [
        "Amount", "Currency", "Type", "Category", "Payment Method",
        "Transaction Date", "Merchant", "Notes", "Category Symbol", "Category Color", "Transfer ID", "Date Added"
    ]
    static let previousTransactionCSVHeaders = [
        "Amount", "Currency", "Type", "Category", "Payment Method",
        "Transaction Date", "Merchant", "Notes", "Category Symbol", "Category Color", "Date Added"
    ]
    static let legacyTransactionCSVHeaders = [
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

    static func budgetStatus(spent: Double, budget: Double) -> BudgetStatus {
        guard spent.isFinite, budget.isFinite, budget > 0 else { return .disabled }
        let progress = max(spent, 0) / budget
        return switch progress {
        case 1...: .exceeded
        case 0.9...: .nearlyReached
        case 0.75...: .approaching
        default: .onTrack
        }
    }

    static func projectedMonthlySpend(spent: Double, now: Date = .now, calendar: Calendar = .current) -> Double? {
        guard spent.isFinite, spent >= 0,
              let dayRange = calendar.range(of: .day, in: .month, for: now) else { return nil }
        let elapsedDays = calendar.component(.day, from: now)
        guard elapsedDays > 0, !dayRange.isEmpty else { return nil }
        return spent / Double(elapsedDays) * Double(dayRange.count)
    }

    static func csvField(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func csv(rows: [[String]]) -> String {
        rows.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\n")
    }

    static func parseCSV(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        let characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if insideQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\""); index += 1
                    } else { insideQuotes = false }
                } else { field.append(character) }
            } else {
                switch character {
                case "\"":
                    guard field.isEmpty else { throw CSVError.malformed }
                    insideQuotes = true
                case ",": row.append(field); field = ""
                case "\n":
                    row.append(field); rows.append(row); row = []; field = ""
                default: field.append(character)
                }
            }
            index += 1
        }
        guard !insideQuotes else { throw CSVError.malformed }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
