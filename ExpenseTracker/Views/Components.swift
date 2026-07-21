import SwiftUI

struct CategoryIcon: View {
    let category: CategoryPresentation
    var body: some View {
        Image(systemName: category.symbol).foregroundStyle(.white).frame(width: 38, height: 38)
            .background(Color.category(category.colorName), in: Circle())
            .overlay { Circle().stroke(.white.opacity(0.28), lineWidth: 1) }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    @AppStorage("currencyCode") private var fallbackCurrencyCode = CurrencyCatalog.defaultCode
    @AppStorage(CustomCategoryCatalog.storageKey) private var customCategoriesJSON = ""
    private var category: CategoryPresentation { transaction.categoryPresentation(customCategories: CustomCategoryCatalog.decode(customCategoriesJSON)) }
    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: category)
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant.isEmpty ? category.name : transaction.merchant).font(.headline)
                Text(([category.name] + transaction.tags.map { "#\($0)" }).joined(separator: "  "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
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
