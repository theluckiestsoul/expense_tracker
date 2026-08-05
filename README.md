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

Receipt scanning uses Apple's photo picker and on-device Vision OCR to suggest the total, merchant, and date from a receipt image. Suggestions remain editable, receipt images can be retained with the transaction, and batch import can review up to 20 receipts without uploading them.

Optional Smart Merchant Rules remember a merchant’s transaction type, category, and payment method. Matching happens on-device, suggestions remain editable before saving, and learned rules can be reviewed or deleted from Settings.

Transaction tags add flexible labels such as work, tax, vacation, or reimbursable. Tags appear in transaction rows, participate in search and filters, and are preserved in CSV exports and complete backups.

On-device Spending Insights highlight the category with the largest increase from the previous period and flag unusually large expenses against the user’s own category history. Tapping an unusual expense opens it for review or correction.

Quick Templates let users save a complete income or expense entry and reuse it from the dashboard or Settings. Frequently used tags appear as one-tap suggestions while entering a transaction, reducing repetitive typing without sending history off device.

Reports include top-merchant summaries and a browsable monthly spending calendar with intensity-based daily cells and per-day transaction details.

Transaction selection supports safely tagging or deleting multiple records in one operation. Bulk tags are merged with existing labels, and destructive actions still require confirmation.

Individual transactions can be deleted with a familiar trailing swipe or from the long-press menu. LedgerLeaf asks for confirmation before removing the entry.

Deletion is recoverable from Recently Deleted. Edits retain a bounded change history, refunds can link back to their original expense, and one payment can be split across multiple categories.

Quick Entry understands phrases such as “Lunch 350 at Green Cafe yesterday using UPI,” supports optional voice dictation, and is available through Siri and Shortcuts. Recognition and parsing happen on the device.

Optional nearby-place assistance can attach the current place to a transaction and fill an empty merchant field. It requests location only after the user taps the control and never tracks in the background.

Before a new entry is saved, duplicate protection checks amount, currency, type, date, and merchant or category. Likely repeats are shown for review, while intentional duplicates can still be saved.

Advanced planning includes multiple named budgets, envelope allocations, savings contributions, reusable bank-CSV column profiles, exact-date custom reports, and shareable PDF summaries. Password-encrypted complete backups use authenticated encryption.

The Financial Insights hub provides a financial-health score, no-spend streak, 90-day cash-flow forecast, annual summary, likely-subscription detection, price-change alerts, suggested category budgets, merchant details, tag and weekday analysis, and a bill calendar.

The 10-point Money Checkup adds spending pace, a safe daily allowance, month-end projection, unusual-expense review, merchant concentration, weekend premium, income stability, no-spend performance, tappable data-quality cleanup, and six-month savings consistency.

Reports support weekly, monthly, yearly, and all-time views with income-versus-expense cash-flow charts, net cash flow, savings rate, period-aware category breakdowns, and income/spending comparisons against the previous matching period. The custom report builder combines quick or exact date ranges with type, category, and merchant filters; configurations can be saved and the filtered result exported as PDF or CSV.

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

Transactions retain their original ISO currency, while dashboard and report totals use the selected default currency. Data and preferences stay on device with SwiftData/AppStorage. CSV export uses the system share sheet. Settings includes a CSV import guide, a header-only template, and a flexible bank CSV mapper; imports merge transactions and skip duplicates. The app does not track users or transmit personal data. The optional privacy shield hides financial details in the iOS app switcher.

Complete LedgerLeaf backups preserve transactions, custom categories, budgets, savings goals, recurring schedules, and core preferences in one versioned JSON file. Legacy account metadata remains readable when restoring backups created by earlier versions. Restore validates the full file and asks before replacing local data; biometric and notification permissions remain specific to each device.
