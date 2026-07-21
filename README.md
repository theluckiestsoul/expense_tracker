# LedgerLeaf

A private, local-first iPhone money tracker built with SwiftUI, SwiftData, and Swift Charts.

LedgerLeaf uses a leaf-led navigation identity and circular category markers to keep its interface visually distinct from generic expense trackers while retaining familiar iOS accessibility labels.

The dashboard emphasizes monthly health, one-tap expense and income entry, compact metrics, and concise planning sections. A calendar-aware monthly forecast projects end-of-month spending and warns when the current pace may exceed the budget. Budget alerts highlight the 75%, 90%, and exceeded thresholds without interrupting the user. Settings separates preferences, planning, automation, backup, and legal tasks to reduce visual density.

LedgerLeaf uses a consistent leaf wordmark, a soft theme-aware background, elevated financial cards, high-contrast quick actions, and a familiar five-item tab menu while preserving native iOS navigation and accessibility behavior.

First launch includes an accessible live coach-mark guide. It dims the real interface, spotlights one actionable control at a time, moves between app functions with Previous and Next, and can be reopened from Settings.

Users can choose System, Leaf, Ocean, Sunset, or Monochrome themes. Themes update the app accent and dashboard identity while preserving semantic income, expense, warning, and success colors.

LedgerLeaf supports separate built-in and custom income/expense categories. Custom categories can use personalized names, icons, and colors, and can be archived without changing historical transactions. CSV backups include the custom-category metadata and remain compatible with older LedgerLeaf exports.

Recurring transactions can automatically record weekly, monthly, or yearly income and expenses such as salary, rent, and subscriptions. Schedules support custom categories, pause/resume, editing, missed-period catch-up, and duplicate-safe generation.

The dashboard shows active recurring expenses due within the next 30 days, ordered by due date and filtered by the selected currency. Today, tomorrow, and overdue states are called out clearly.

Monthly category budgets are currency-specific and appear on the dashboard with progress and overspending indicators. Transaction search covers merchants, notes, categories, and payment methods, with additional category, payment-method, and date-range filters.

Existing income and expenses can be duplicated from the transaction list using a leading swipe or long press. LedgerLeaf copies the details into a review form with today's date and always creates a separate transaction.

Receipt scanning uses Apple's photo picker and on-device Vision OCR to suggest the total, merchant, and date from a receipt image. Suggestions remain editable, and the selected image is neither uploaded nor stored.

Optional Smart Merchant Rules remember a merchant’s transaction type, category, and payment method. Matching happens on-device, suggestions remain editable before saving, and learned rules can be reviewed or deleted from Settings.

Transaction tags add flexible labels such as work, tax, vacation, or reimbursable. Tags appear in transaction rows, participate in search and filters, and are preserved in CSV exports and complete backups.

Reports support weekly, monthly, yearly, and all-time views with income-versus-expense cash-flow charts, net cash flow, savings rate, period-aware category breakdowns, and income/spending comparisons against the previous matching period.

Optional bill reminders schedule private, on-device notifications one day before active recurring expenses. Notification access is requested only when the user enables Bill Reminders in Settings.

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

Transactions retain their original ISO currency, while dashboard and report totals use the selected default currency. Data and preferences stay on device with SwiftData/AppStorage. CSV export uses the system share sheet. Settings includes a CSV import guide and a header-only template; CSV imports merge transactions and skip duplicates. The app does not track users or transmit personal data.

Complete LedgerLeaf backups preserve transactions, custom categories, budgets, savings goals, recurring schedules, and core preferences in one versioned JSON file. Legacy account metadata remains readable when restoring backups created by earlier versions. Restore validates the full file and asks before replacing local data; biometric and notification permissions remain specific to each device.
