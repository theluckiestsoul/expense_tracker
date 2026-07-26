import AppIntents

struct OpenQuickEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a LedgerLeaf Transaction"
    static let description = IntentDescription("Opens LedgerLeaf's typed and voice quick entry.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "openQuickEntryFromShortcut")
        return .result()
    }
}

struct OpenReceiptScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a Receipt in LedgerLeaf"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "openReceiptScannerFromShortcut")
        return .result()
    }
}

struct LedgerLeafAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenQuickEntryIntent(),
                    phrases: ["Add a transaction in \(.applicationName)", "Quick entry in \(.applicationName)"],
                    shortTitle: "Add Transaction", systemImageName: "plus.circle.fill")
        AppShortcut(intent: OpenReceiptScannerIntent(),
                    phrases: ["Scan a receipt in \(.applicationName)"],
                    shortTitle: "Scan Receipt", systemImageName: "doc.text.viewfinder")
    }
}
