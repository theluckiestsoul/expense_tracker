import Foundation
import CoreLocation

struct LocationSpendCluster: Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let expenses: Double
    let income: Double
    let transactionIDs: [UUID]
    var count: Int { transactionIDs.count }
}

enum LocationSpendingCalculator {
    static func clusters(from transactions: [Transaction], currencyCode: String, radiusMeters: Double = 175) -> [LocationSpendCluster] {
        struct Builder {
            var name: String; var latitude: Double; var longitude: Double
            var expenses = 0.0; var income = 0.0; var ids: [UUID] = []; var coordinateCount = 1
        }
        var builders: [Builder] = []
        let eligible = transactions.filter {
            !$0.isDeleted && $0.transferID == nil && ($0.currencyCode ?? currencyCode) == currencyCode &&
            ($0.latitude?.isFinite == true) && ($0.longitude?.isFinite == true) &&
            (-90...90).contains($0.latitude ?? 999) && (-180...180).contains($0.longitude ?? 999)
        }
        for transaction in eligible {
            guard let latitude = transaction.latitude, let longitude = transaction.longitude else { continue }
            let storedName = transaction.locationName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (storedName?.isEmpty == false ? storedName : nil) ?? (transaction.merchant.isEmpty ? "Saved Place" : transaction.merchant)
            let nameKey = MerchantRuleStore.normalizedKey(name)
            let index = builders.firstIndex {
                MerchantRuleStore.normalizedKey($0.name) == nameKey ||
                distance(latitude, longitude, $0.latitude, $0.longitude) <= radiusMeters
            }
            if let index {
                let count = Double(builders[index].coordinateCount)
                builders[index].latitude = (builders[index].latitude * count + latitude) / (count + 1)
                builders[index].longitude = (builders[index].longitude * count + longitude) / (count + 1)
                builders[index].coordinateCount += 1; builders[index].ids.append(transaction.id)
                if transaction.type == .expense { builders[index].expenses += transaction.amount }
                else { builders[index].income += transaction.amount }
            } else {
                builders.append(Builder(name: name, latitude: latitude, longitude: longitude,
                                        expenses: transaction.type == .expense ? transaction.amount : 0,
                                        income: transaction.type == .income ? transaction.amount : 0,
                                        ids: [transaction.id]))
            }
        }
        return builders.map {
            let coordinateKey = "\(String(format: "%.4f", $0.latitude)),\(String(format: "%.4f", $0.longitude))"
            return LocationSpendCluster(id: "\(MerchantRuleStore.normalizedKey($0.name))|\(coordinateKey)",
                                        name: $0.name, latitude: $0.latitude, longitude: $0.longitude,
                                        expenses: $0.expenses, income: $0.income, transactionIDs: $0.ids)
        }.sorted {
            if $0.expenses == $1.expenses { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return $0.expenses > $1.expenses
        }
    }

    private static func distance(_ latitude1: Double, _ longitude1: Double, _ latitude2: Double, _ longitude2: Double) -> Double {
        CLLocation(latitude: latitude1, longitude: longitude1)
            .distance(from: CLLocation(latitude: latitude2, longitude: longitude2))
    }
}
