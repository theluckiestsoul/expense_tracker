import SwiftUI

enum CoachMarkTarget: Hashable {
    case dashboardSummary
    case expenseButton
}

struct CoachMarkTargetKey: PreferenceKey {
    static var defaultValue: [CoachMarkTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachMarkTarget: Anchor<CGRect>], nextValue: () -> [CoachMarkTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    func coachMarkTarget(_ target: CoachMarkTarget) -> some View {
        anchorPreference(key: CoachMarkTargetKey.self, value: .bounds) { [target: $0] }
    }
}

struct OnboardingCoachMark: View {
    static let completionKey = "hasCompletedOnboarding"

    struct Step {
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        let symbol: String
    }

    static let steps = [
        Step(title: "Your financial overview", detail: "Start here to see this month’s spending, income, budget progress, and forecast.", symbol: "leaf.fill"),
        Step(title: "Add your first expense", detail: "Tap the highlighted button to record an amount, category, merchant, or receipt.", symbol: "arrow.up.right"),
        Step(title: "Find every transaction", detail: "Transactions lets you search, filter, edit, duplicate, and delete your records.", symbol: "arrow.up.arrow.down.circle.fill"),
        Step(title: "Understand your habits", detail: "Reports compares periods and shows cash flow, savings rate, and category trends.", symbol: "chart.line.uptrend.xyaxis"),
        Step(title: "Make LedgerLeaf yours", detail: "Settings contains language, currency, themes, budgets, reminders, backups, and the optional accounts feature.", symbol: "slider.horizontal.3")
    ]

    let step: Int
    let targetRect: CGRect
    let containerSize: CGSize
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    private var item: Step { Self.steps[step] }
    private var spotlight: CGRect { targetRect.insetBy(dx: -8, dy: -7) }
    private var cardWidth: CGFloat { min(containerSize.width - 32, 390) }
    private var cardY: CGFloat {
        let estimatedHeight: CGFloat = 218
        let below = spotlight.maxY + 18 + estimatedHeight / 2
        if below < containerSize.height - 30 { return below }
        return max(estimatedHeight / 2 + 70, spotlight.minY - 18 - estimatedHeight / 2)
    }

    var body: some View {
        ZStack {
            ZStack {
                Color.black.opacity(0.72)
                RoundedRectangle(cornerRadius: min(spotlight.height / 3, 22), style: .continuous)
                    .frame(width: spotlight.width, height: spotlight.height)
                    .position(x: spotlight.midX, y: spotlight.midY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .ignoresSafeArea()

            RoundedRectangle(cornerRadius: min(spotlight.height / 3, 22), style: .continuous)
                .stroke(Color.orange.opacity(0.95), lineWidth: 2)
                .shadow(color: .orange.opacity(0.75), radius: 10)
                .frame(width: spotlight.width, height: spotlight.height)
                .position(x: spotlight.midX, y: spotlight.midY)

            Button(action: onNext) { Color.clear }
                .frame(width: spotlight.width, height: spotlight.height)
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .position(x: spotlight.midX, y: spotlight.midY)
                .accessibilityLabel(item.title)
                .accessibilityHint("Opens this feature and continues the guide")
                .accessibilityIdentifier("coachMarkTarget")

            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: item.symbol).foregroundStyle(.orange)
                    Spacer()
                    Text("\(step + 1) of \(Self.steps.count)").font(.caption).foregroundStyle(.secondary)
                }
                Text(item.title).font(.title3.bold())
                Text(item.detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button("Previous", action: onPrevious).buttonStyle(.bordered).disabled(step == 0)
                        .accessibilityIdentifier("onboardingPrevious")
                    Button(step == Self.steps.count - 1 ? "Finish" : "Next", action: onNext)
                        .buttonStyle(.borderedProminent).tint(.indigo).frame(maxWidth: .infinity)
                        .accessibilityIdentifier(step == Self.steps.count - 1 ? "finishOnboarding" : "onboardingNext")
                }
                .controlSize(.large)
            }
            .padding(20)
            .frame(width: cardWidth)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.25)))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .position(x: containerSize.width / 2, y: cardY)

            VStack {
                HStack { Spacer(); Button("Skip", action: onSkip).fontWeight(.semibold).foregroundStyle(.white).accessibilityIdentifier("skipOnboarding") }
                Spacer()
            }
            .padding(.horizontal, 22).padding(.top, 8)
        }
    }
}
