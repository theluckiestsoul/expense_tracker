# LedgerLeaf

A private, local-first iPhone money tracker built with SwiftUI, SwiftData, and Swift Charts.

LedgerLeaf supports separate built-in and custom income/expense categories. Custom categories can use personalized names, icons, and colors, and can be archived without changing historical transactions. CSV backups include the custom-category metadata and remain compatible with older LedgerLeaf exports.

Recurring transactions can automatically record weekly, monthly, or yearly income and expenses such as salary, rent, and subscriptions. Schedules support custom categories, pause/resume, editing, missed-period catch-up, and duplicate-safe generation.

Monthly category budgets are currency-specific and appear on the dashboard with progress and overspending indicators. Transaction search covers merchants, notes, categories, and payment methods, with additional category, payment-method, and date-range filters.

Existing income and expenses can be duplicated from the transaction list using a leading swipe or long press. LedgerLeaf copies the details into a review form with today's date and always creates a separate transaction; linked account transfers cannot be duplicated.

Reports support weekly, monthly, yearly, and all-time views with income-versus-expense cash-flow charts, net cash flow, savings rate, and period-aware category breakdowns.

Optional bill reminders schedule private, on-device notifications one day before active recurring expenses. Notification access is requested only when the user enables Bill Reminders in Settings.

Optional Wallets & Accounts represent where money is kept or owed, such as cash, a bank account, a credit card, or a digital wallet. LedgerLeaf handles the single default wallet automatically and shows account selection only after another one is created. Balances can use independent currencies, appear on the dashboard, and support transaction filtering.

Same-currency account transfers update both balances using a linked debit and credit. Transfers are excluded from spending, income, budgets, savings rate, and reports, and deleting either side removes the complete transfer.

Savings goals track target and saved amounts in any supported currency, with an optional completion date. Goal progress appears on the dashboard and can be updated from Settings; all goal data remains on the device.

The interface automatically follows the user's supported iOS language. Current localizations include English, Persian, Spanish, French, Brazilian Portuguese, Simplified Chinese, Arabic, and 20 scheduled languages of India: Assamese, Bengali, Dogri, Gujarati, Hindi, Kannada, Konkani, Maithili, Malayalam, Manipuri, Marathi, Nepali, Odia, Punjabi, Sanskrit, Santali, Sindhi, Tamil, Telugu, and Urdu. English is used as the fallback for other languages. Bodo and Kashmiri are temporarily unavailable until genuine native translations replace the previous fallback copies.

## Run

1. Install Xcode 16 or newer with an iOS 17+ simulator.
2. Run `make run`, or open `ExpenseTracker.xcodeproj` and run the `ExpenseTracker` scheme.

## Development commands

- `make check` validates the project, asset catalogs, and Swift syntax.
- `make test` runs portable domain tests without requiring the iOS SDK.
- `make build` compiles a simulator-compatible app without tying the build to one installed runtime.
- `make run` launches on `iPhone 17 Pro` by default.
- `make smoke` launches the app, captures a screenshot, and checks runtime error logs.
- `make release` compiles the optimized Release configuration.
- Override the device with `make run SIMULATOR='iPhone 15'`.
- `make doctor` reports whether the required Apple tools are installed.

Transactions retain their original ISO currency, while dashboard and report totals use the selected default currency. Data and preferences stay on device with SwiftData/AppStorage. CSV export uses the system share sheet. The app does not track users or transmit personal data.
