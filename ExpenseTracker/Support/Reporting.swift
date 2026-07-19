import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case week, month, year, all
    var id: String { rawValue }
    var title: String {
        switch self { case .week: "Week"; case .month: "Month"; case .year: "Year"; case .all: "All" }
    }

    func includes(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        switch self {
        case .week: return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month: return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .year: return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .all: return true
        }
    }

    func interval(offset: Int = 0, now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        let component: Calendar.Component
        switch self {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        case .all: return nil
        }
        guard let shifted = calendar.date(byAdding: component, value: offset, to: now) else { return nil }
        return calendar.dateInterval(of: component, for: shifted)
    }

    func includes(_ date: Date, offset: Int, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let interval = interval(offset: offset, now: now, calendar: calendar) else { return self == .all }
        return date >= interval.start && date < interval.end
    }

    var bucketComponent: Calendar.Component { self == .year || self == .all ? .month : .day }
}

struct CashFlowPoint: Identifiable, Equatable {
    let date: Date
    let type: TransactionType
    let amount: Double
    var id: String { "\(date.timeIntervalSinceReferenceDate)-\(type.rawValue)" }
}

enum ReportCalculator {
    static func percentageChange(current: Double, previous: Double) -> Double? {
        guard previous > 0, current.isFinite, previous.isFinite else { return nil }
        return (current - previous) / previous
    }

    static func savingsRate(income: Double, expenses: Double) -> Double? {
        guard income > 0 else { return nil }
        return (income - expenses) / income
    }

    static func cashFlow(transactions: [Transaction], period: ReportPeriod, now: Date = .now, calendar: Calendar = .current) -> [CashFlowPoint] {
        let filtered = transactions.filter { period.includes($0.transactionDate, now: now, calendar: calendar) }
        let grouped = Dictionary(grouping: filtered) { transaction -> Date in
            let components: Set<Calendar.Component> = period.bucketComponent == .month ? [.year, .month] : [.year, .month, .day]
            return calendar.date(from: calendar.dateComponents(components, from: transaction.transactionDate)) ?? transaction.transactionDate
        }
        var points: [CashFlowPoint] = []
        for (date, items) in grouped {
            for type in TransactionType.allCases {
                let matching = items.filter { $0.type == type }
                let amount = matching.reduce(0.0) { partial, transaction in partial + transaction.amount }
                if amount > 0 { points.append(CashFlowPoint(date: date, type: type, amount: amount)) }
            }
        }
        return points.sorted { lhs, rhs in
            if lhs.date == rhs.date { return lhs.type.rawValue < rhs.type.rawValue }
            return lhs.date < rhs.date
        }
    }
}
