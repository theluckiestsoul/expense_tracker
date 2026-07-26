import Foundation
import CoreLocation

struct PlaceSuggestion: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
}

@MainActor
final class LocationSuggestionService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var isLoading = false
    @Published private(set) var suggestion: PlaceSuggestion?
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPlace() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location Services are disabled in iOS Settings."
            return
        }
        isLoading = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted:
            isLoading = false
            errorMessage = "Allow location access in Settings to suggest your current place."
        @unknown default:
            isLoading = false
            errorMessage = "Location access is unavailable."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { isLoading = false; return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error { self.errorMessage = error.localizedDescription; return }
                let placemark = placemarks?.first
                let label = Self.placeLabel(name: placemark?.name,
                                            locality: placemark?.locality,
                                            area: placemark?.subAdministrativeArea)
                self.suggestion = PlaceSuggestion(name: label,
                                                  latitude: location.coordinate.latitude,
                                                  longitude: location.coordinate.longitude)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
    }

    static func placeLabel(name: String?, locality: String?, area: String?) -> String {
        [name, locality, area]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "Current Location"
    }
}
