import SwiftUI

struct OnboardingView: View {
    static let completionKey = "hasCompletedOnboarding"

    struct Page: Identifiable {
        let id: Int
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        let symbol: String
        let color: Color
    }

    private let pages: [Page] = [
        Page(id: 0, title: "Welcome to LedgerLeaf", detail: "Track spending, income, budgets, and savings privately on your device.", symbol: "leaf.fill", color: .green),
        Page(id: 1, title: "See Your Month at a Glance", detail: "The Dashboard shows spending, income, budget progress, upcoming bills, and your monthly forecast.", symbol: "chart.pie.fill", color: .indigo),
        Page(id: 2, title: "Record Money in Seconds", detail: "Tap Add to save an expense or income. You can also scan a receipt to fill in its amount, merchant, and date.", symbol: "square.and.pencil", color: .orange),
        Page(id: 3, title: "Accounts Are Optional", detail: "Use accounts only when you want separate balances for cash, banks, cards, or digital wallets. Otherwise, leave transactions unassigned.", symbol: "wallet.bifold.fill", color: .blue),
        Page(id: 4, title: "Understand Your Habits", detail: "Reports compare periods, show cash flow and savings rate, and let you filter by wallet.", symbol: "chart.line.uptrend.xyaxis", color: .purple),
        Page(id: 5, title: "Make It Yours", detail: "Open Settings to choose your language, currency, theme, budgets, reminders, backups, and privacy lock.", symbol: "slider.horizontal.3", color: .teal)
    ]

    let onFinish: () -> Void
    @State private var page = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onFinish)
                        .accessibilityIdentifier("skipOnboarding")
                }
                .padding(.horizontal).padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(pages) { item in
                        VStack(spacing: 28) {
                            Spacer()
                            Image(systemName: item.symbol)
                                .font(.system(size: 62, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 132, height: 132)
                                .background(item.color.gradient, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                                .shadow(color: item.color.opacity(0.25), radius: 18, y: 10)
                            VStack(spacing: 12) {
                                Text(item.title).font(.title2.bold()).multilineTextAlignment(.center)
                                Text(item.detail).font(.body).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center).lineSpacing(4)
                            }
                            .padding(.horizontal, 30)
                            Spacer()
                        }
                        .tag(item.id)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("onboardingPage_\(item.id)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages) { item in
                        Capsule().fill(item.id == page ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: item.id == page ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: page)
                    }
                }
                .accessibilityLabel("Step \(page + 1) of \(pages.count)")
                .padding(.bottom, 24)

                HStack(spacing: 12) {
                    Button("Previous") { withAnimation { page -= 1 } }
                        .buttonStyle(.bordered).disabled(page == 0)
                        .accessibilityIdentifier("onboardingPrevious")
                    Button(page == pages.count - 1 ? "Start Using LedgerLeaf" : "Next") {
                        if page == pages.count - 1 { onFinish() }
                        else { withAnimation { page += 1 } }
                    }
                    .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    .accessibilityIdentifier(page == pages.count - 1 ? "finishOnboarding" : "onboardingNext")
                }
                .controlSize(.large).padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .interactiveDismissDisabled()
    }
}
