import SwiftUI
import SwiftData
import MapKit

struct SpendingMapView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @State private var dateRange: CustomReportDateRange = .last30Days
    @State private var categoryID = "all"
    @State private var selectedClusterID: String?
    @State private var position: MapCameraPosition = .automatic

    private var filtered: [Transaction] {
        let dates = dateRange.dates() ?? (.distantPast, .now)
        return CustomReportFilter.transactions(from: transactions, currencyCode: currencyCode,
                                               startDate: dates.start, endDate: dates.end,
                                               typeRaw: "all", categoryID: categoryID, merchantQuery: "")
    }
    private var clusters: [LocationSpendCluster] { LocationSpendingCalculator.clusters(from: filtered, currencyCode: currencyCode) }
    private var selectedCluster: LocationSpendCluster? { clusters.first { $0.id == selectedClusterID } }
    private var categories: [String] {
        Array(Set(transactions.filter { $0.latitude != nil && !$0.isDeleted }.map(\.categoryRaw))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if clusters.isEmpty {
                ContentUnavailableView("No Saved Places", systemImage: "map",
                                       description: Text("Attach a place while adding a transaction, or change the filters."))
            } else {
                Map(position: $position, selection: $selectedClusterID) {
                    ForEach(clusters) { cluster in
                        Annotation(cluster.name, coordinate: CLLocationCoordinate2D(latitude: cluster.latitude, longitude: cluster.longitude)) {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill").font(.title).foregroundStyle(.red)
                                Text(AppFormat.money(cluster.expenses, currencyCode: currencyCode))
                                    .font(.caption2.bold()).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(.regularMaterial, in: Capsule())
                            }
                        }.tag(cluster.id)
                    }
                }
                .mapControls { MapCompass(); MapScaleView(); MapUserLocationButton() }
                .frame(minHeight: 330)
                List(clusters) { cluster in
                    Button { selectedClusterID = cluster.id } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(.red).frame(width: 30)
                            VStack(alignment: .leading) {
                                Text(cluster.name).foregroundStyle(.primary)
                                Text("\(cluster.count) transaction\(cluster.count == 1 ? "" : "s")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(AppFormat.money(cluster.expenses, currencyCode: currencyCode)).fontWeight(.semibold).foregroundStyle(.primary)
                        }
                    }.buttonStyle(.plain)
                }.listStyle(.plain).frame(maxHeight: 260)
            }
        }
        .navigationTitle("Spending Map")
        .accessibilityIdentifier("spendingMap")
        .sheet(item: Binding(get: { selectedCluster }, set: { if $0 == nil { selectedClusterID = nil } })) { cluster in
            PlaceSpendingDetailView(cluster: cluster, transactions: transactions, currencyCode: currencyCode)
        }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            Picker("Date Range", selection: $dateRange) {
                ForEach(CustomReportDateRange.allCases.filter { $0 != .custom }) { Text($0.title).tag($0) }
            }.pickerStyle(.menu)
            Picker("Category", selection: $categoryID) {
                Text("All Categories").tag("all")
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.menu)
            HStack {
                LabeledContent("Places", value: "\(clusters.count)")
                Divider()
                LabeledContent("Mapped spending", value: AppFormat.money(clusters.reduce(0) { $0 + $1.expenses }, currencyCode: currencyCode))
            }.font(.caption)
        }.padding(.horizontal).padding(.vertical, 8).background(.bar)
    }
}

private struct PlaceSpendingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let cluster: LocationSpendCluster; let transactions: [Transaction]; let currencyCode: String
    @State private var editing: Transaction?
    private var matching: [Transaction] {
        let ids = Set(cluster.transactionIDs)
        return transactions.filter { ids.contains($0.id) }.sorted { $0.transactionDate > $1.transactionDate }
    }
    var body: some View {
        NavigationStack {
            List {
                Section("Place Summary") {
                    LabeledContent("Expenses", value: AppFormat.money(cluster.expenses, currencyCode: currencyCode))
                    LabeledContent("Income", value: AppFormat.money(cluster.income, currencyCode: currencyCode))
                    LabeledContent("Transactions", value: "\(cluster.count)")
                }
                Section("Transactions") {
                    ForEach(matching) { transaction in
                        Button { editing = transaction } label: { TransactionRow(transaction: transaction) }.buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(cluster.name)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { AddTransactionView(transaction: $0) }
        }
    }
}
