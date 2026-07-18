import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    @AppStorage(AppLanguage.storageKey) private var languageCode = ""

    var body: some Scene {
        WindowGroup {
            SecureRootView()
                .environment(\.locale, AppLanguage.locale(for: languageCode))
                .environment(\.layoutDirection, AppLanguage.isRightToLeft(languageCode) ? .rightToLeft : .leftToRight)
                .id(languageCode)
        }
            .modelContainer(for: Transaction.self)
    }
}
