import SwiftUI
import SwiftData

struct SpendingCalendarView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var calendar: Calendar { .current }
    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth) ?? DateInterval(start: displayedMonth, duration: 1)
    }
    private var monthExpenses: [Transaction] {
        transactions.filter {
            !$0.isDeleted && $0.type == .expense && $0.transferID == nil && ($0.currencyCode ?? currencyCode) == currencyCode &&
            monthInterval.contains($0.transactionDate)
        }
    }
    private var totalsByDay: [Date: Double] {
        Dictionary(grouping: monthExpenses, by: { calendar.startOfDay(for: $0.transactionDate) })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }
    private var maximumDailySpend: Double { totalsByDay.values.max() ?? 0 }
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }
    private var days: [Date?] {
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        return Array(repeating: nil, count: leading) + (0..<count).map {
            calendar.date(byAdding: .day, value: $0, to: monthInterval.start)
        }
    }
    private var selectedTransactions: [Transaction] {
        guard let selectedDate else { return [] }
        return monthExpenses.filter { calendar.isDate($0.transactionDate, inSameDayAs: selectedDate) }
            .sorted { $0.transactionDate > $1.transactionDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                        .disabled(calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month))
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) {
                        Text($0).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(height: 54)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("spendingCalendarGrid")

                HStack {
                    Text("Monthly spending").foregroundStyle(.secondary)
                    Spacer()
                    Text(AppFormat.money(monthExpenses.expenses, currencyCode: currencyCode)).fontWeight(.semibold)
                }.padding(.horizontal)

                if let selectedDate {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedDate.formatted(date: .complete, time: .omitted)).font(.headline)
                        if selectedTransactions.isEmpty {
                            Text("No expenses on this day.").foregroundStyle(.secondary)
                        } else {
                            ForEach(selectedTransactions) { TransactionRow(transaction: $0) }
                        }
                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding()
        }
        .navigationTitle("Spending Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dayCell(_ date: Date) -> some View {
        let amount = totalsByDay[calendar.startOfDay(for: date)] ?? 0
        let intensity = maximumDailySpend > 0 ? amount / maximumDailySpend : 0
        let selected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        return Button { selectedDate = date } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day())).font(.caption.weight(.semibold))
                Circle().fill(amount > 0 ? Color.orange : Color.clear).frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.orange.opacity(amount > 0 ? 0.12 + 0.55 * intensity : 0),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(date: .long, time: .omitted)), \(AppFormat.money(amount, currencyCode: currencyCode)) spent")
    }

    private func moveMonth(_ value: Int) {
        if let month = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = month
            selectedDate = nil
        }
    }
}
