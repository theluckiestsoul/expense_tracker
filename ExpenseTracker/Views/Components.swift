import SwiftUI

struct CategoryIcon: View {
    let category: ExpenseCategory
    var body: some View {
        Image(systemName: category.symbol).foregroundStyle(.white).frame(width: 38, height: 38)
            .background(category.isIncome ? .green : .indigo, in: RoundedRectangle(cornerRadius: 11))
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    @AppStorage("currencyCode") private var fallbackCurrencyCode = CurrencyCatalog.defaultCode
    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: transaction.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant.isEmpty ? transaction.category.displayName : transaction.merchant).font(.headline)
                Text(transaction.category.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text((transaction.type == .expense ? "− " : "+ ") + AppFormat.money(transaction.amount, currencyCode: transaction.currencyCode ?? fallbackCurrencyCode))
                    .fontWeight(.semibold).foregroundColor(transaction.type == .expense ? .primary : .green).lineLimit(1).minimumScaleFactor(0.65)
                Text(transaction.transactionDate, style: .time).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: 190, alignment: .trailing)
        }.padding(.vertical, 4).accessibilityElement(children: .combine)
    }
}
