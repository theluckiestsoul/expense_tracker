import SwiftUI

struct SavingsGoalsView: View {
    @AppStorage(SavingsGoalStore.storageKey) private var goalsJSON = ""
    @AppStorage("currencyCode") private var defaultCurrency = CurrencyCatalog.defaultCode
    @State private var editing: SavingsGoal?
    @State private var adding = false

    private var goals: [SavingsGoal] {
        SavingsGoalStore.decode(goalsJSON).sorted { lhs, rhs in
            if lhs.progress == rhs.progress { return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
            return lhs.progress > rhs.progress
        }
    }

    var body: some View {
        List {
            if goals.isEmpty {
                ContentUnavailableView("No Savings Goals", systemImage: "target", description: Text("Create a goal to track progress toward something important."))
            } else {
                ForEach(goals) { goal in
                    Button { editing = goal } label: { goalRow(goal) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("savingsGoal_\(goal.id.uuidString)")
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Savings Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { adding = true } label: { Image(systemName: "plus") }
                .accessibilityIdentifier("addSavingsGoal")
        }
        .sheet(isPresented: $adding) {
            SavingsGoalEditor(goal: nil, defaultCurrency: defaultCurrency, onSave: save)
        }
        .sheet(item: $editing) { goal in
            SavingsGoalEditor(goal: goal, defaultCurrency: defaultCurrency, onSave: save)
        }
    }

    private func goalRow(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(goal.name, systemImage: goal.progress >= 1 ? "checkmark.circle.fill" : "target")
                    .foregroundStyle(goal.progress >= 1 ? .green : .primary)
                Spacer()
                Text(goal.progress, format: .percent.precision(.fractionLength(0))).foregroundStyle(.secondary)
            }
            ProgressView(value: goal.progress).tint(goal.progress >= 1 ? .green : .indigo)
            HStack {
                Text("\(AppFormat.money(goal.savedAmount, currencyCode: goal.currencyCode)) of \(AppFormat.money(goal.targetAmount, currencyCode: goal.currencyCode))")
                Spacer()
                if let date = goal.targetDate { Text(date, format: .dateTime.day().month().year()) }
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }

    private func save(_ goal: SavingsGoal) {
        var updated = SavingsGoalStore.decode(goalsJSON).filter { $0.id != goal.id }
        updated.append(goal)
        goalsJSON = SavingsGoalStore.encode(updated)
    }

    private func delete(at offsets: IndexSet) {
        let removed = Set(offsets.map { goals[$0].id })
        goalsJSON = SavingsGoalStore.encode(SavingsGoalStore.decode(goalsJSON).filter { !removed.contains($0.id) })
    }
}

private struct SavingsGoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    let goal: SavingsGoal?
    let onSave: (SavingsGoal) -> Void
    @State private var name: String
    @State private var targetAmount: String
    @State private var savedAmount: String
    @State private var currencyCode: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @FocusState private var focusedField: Field?

    private enum Field { case name, target, saved }

    init(goal: SavingsGoal?, defaultCurrency: String, onSave: @escaping (SavingsGoal) -> Void) {
        self.goal = goal; self.onSave = onSave
        _name = State(initialValue: goal?.name ?? "")
        _targetAmount = State(initialValue: goal.map { String(format: "%.2f", $0.targetAmount) } ?? "")
        _savedAmount = State(initialValue: goal.map { String(format: "%.2f", $0.savedAmount) } ?? "0")
        _currencyCode = State(initialValue: goal?.currencyCode ?? defaultCurrency)
        _hasTargetDate = State(initialValue: goal?.targetDate != nil)
        _targetDate = State(initialValue: goal?.targetDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now)
    }

    private var parsedTarget: Double? { DomainLogic.parseAmount(targetAmount) }
    private var parsedSaved: Double? {
        let trimmed = savedAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "0" { return 0 }
        return DomainLogic.parseAmount(trimmed)
    }
    private var validName: String { DomainLogic.sanitizedText(name, maximumLength: 50) }
    private var canSave: Bool { !validName.isEmpty && parsedTarget != nil && parsedSaved != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Goal Name", text: $name).focused($focusedField, equals: .name).accessibilityIdentifier("savingsGoalName")
                    Picker("Currency", selection: $currencyCode) { ForEach(CurrencyCatalog.all) { Text($0.label).tag($0.code) } }
                    HStack { Text(currencyCode).foregroundStyle(.secondary); TextField("Target Amount", text: $targetAmount).keyboardType(.decimalPad).focused($focusedField, equals: .target).accessibilityIdentifier("savingsGoalTarget") }
                    HStack { Text(currencyCode).foregroundStyle(.secondary); TextField("Already Saved", text: $savedAmount).keyboardType(.decimalPad).focused($focusedField, equals: .saved).accessibilityIdentifier("savingsGoalSaved") }
                }
                Section("Timeline") {
                    Toggle("Target Date", isOn: $hasTargetDate)
                    if hasTargetDate { DatePicker("Complete By", selection: $targetDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date) }
                }
                Text("Update the saved amount whenever you add to or withdraw from this goal. Goals are stored only on this device.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle(goal == nil ? "New Savings Goal" : "Edit Savings Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave).accessibilityIdentifier("saveSavingsGoal")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } }
            }
            .onAppear { if goal == nil { focusedField = .name } }
        }
    }

    private func save() {
        guard let target = parsedTarget, let saved = parsedSaved else { return }
        onSave(SavingsGoal(id: goal?.id ?? UUID(), name: validName, targetAmount: target, savedAmount: saved,
                           currencyCode: currencyCode, targetDate: hasTargetDate ? targetDate : nil))
        dismiss()
    }
}
