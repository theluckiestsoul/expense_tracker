import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: Transaction.self)
    }
}
