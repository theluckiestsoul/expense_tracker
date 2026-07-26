import Foundation

struct QuickEntryDraft: Equatable {
    var amount: Double
    var type: TransactionType
    var category: ExpenseCategory
    var paymentMethod: PaymentMethod
    var merchant: String
    var date: Date
    var notes: String
}

enum QuickEntryParser {
    static func parse(_ input: String, now: Date = .now, calendar: Calendar = .current) -> QuickEntryDraft? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let pattern = #"(?<![\p{L}\d])(?:₹|\$|€|£|¥|Rs\.?\s*)?(\d[\d,]*(?:\.\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let amountRange = Range(match.range(at: 1), in: text),
              let amount = Double(text[amountRange].replacingOccurrences(of: ",", with: "")),
              amount > 0 else { return nil }

        let lower = text.lowercased()
        let type: TransactionType = lower.contains("income") || lower.contains("salary") || lower.contains("received") ? .income : .expense
        let category = category(for: lower, type: type)
        let payment = PaymentMethod.allCases.first { lower.contains($0.rawValue.lowercased()) }
            ?? (lower.contains("upi") ? .upi : lower.contains("wallet") ? .mobileWallet : .other)
        let date: Date
        if lower.contains("yesterday") {
            date = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        } else if lower.contains("tomorrow") {
            date = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        } else {
            date = now
        }
        let merchant = merchant(in: text, amountRange: amountRange)
        return QuickEntryDraft(amount: amount, type: type, category: category, paymentMethod: payment,
                               merchant: merchant, date: date, notes: text)
    }

    private static func category(for text: String, type: TransactionType) -> ExpenseCategory {
        if type == .income {
            if text.contains("salary") { return .salary }
            if text.contains("freelance") { return .freelance }
            if text.contains("refund") { return .refund }
            return .otherIncome
        }
        let matches: [(ExpenseCategory, [String])] = [
            (.food, ["food", "lunch", "dinner", "breakfast", "coffee", "restaurant", "grocery"]),
            (.travel, ["travel", "taxi", "uber", "fuel", "petrol", "train", "flight"]),
            (.shopping, ["shopping", "clothes", "store"]),
            (.bills, ["bill", "electricity", "internet", "rent", "phone"]),
            (.health, ["health", "doctor", "medicine", "pharmacy"]),
            (.entertainment, ["movie", "cinema", "game", "concert"]),
            (.education, ["book", "course", "school", "tuition"])
        ]
        return matches.first(where: { $0.1.contains(where: text.contains) })?.0 ?? .other
    }

    private static func merchant(in text: String, amountRange: Range<String.Index>) -> String {
        let tail = String(text[amountRange.upperBound...])
        if let range = tail.range(of: #"\b(?:at|from)\s+(.+?)(?=\s+(?:today|yesterday|tomorrow|using|via|by)\b|$)"#,
                                  options: [.regularExpression, .caseInsensitive]) {
            let phrase = String(tail[range])
            return phrase.replacingOccurrences(of: #"^(?:at|from)\s+"#, with: "",
                                               options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let prefix = String(text[..<amountRange.lowerBound])
            .replacingOccurrences(of: #"\b(?:spent|paid|expense|income|received)\b"#, with: "",
                                  options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(prefix.prefix(80))
    }
}
