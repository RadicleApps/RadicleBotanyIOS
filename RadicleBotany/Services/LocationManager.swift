import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var error: String?

    /// Cached regional flora project identifier for PlantNet identification
    @Published var regionalProject: String?
    private var lastProjectFetchLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        isLoading = true
        error = nil
        manager.requestLocation()
    }

    /// Returns a bounding box around the current location for geo prediction queries.
    func boundingBox(radiusKm: Double = 25) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard let loc = location else { return nil }
        let latDelta = radiusKm / 111.0
        let lonDelta = radiusKm / (111.0 * cos(loc.coordinate.latitude * .pi / 180))
        return (
            loc.coordinate.latitude - latDelta,
            loc.coordinate.latitude + latDelta,
            loc.coordinate.longitude - lonDelta,
            loc.coordinate.longitude + lonDelta
        )
    }

    /// Fetches and caches the best regional PlantNet flora project for the current location.
    /// Only re-fetches if the user has moved more than 50km from the last fetch.
    func fetchRegionalProjectIfNeeded() async {
        guard let loc = location else { return }

        // Skip if location hasn't changed significantly
        if let lastLoc = lastProjectFetchLocation,
           loc.distance(from: lastLoc) < 50_000 {
            return
        }

        regionalProject = await PlantNetService.shared.fetchRegionalProject(
            lat: loc.coordinate.latitude,
            lon: loc.coordinate.longitude
        )
        lastProjectFetchLocation = loc
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.location = locations.last
            self.isLoading = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error.localizedDescription
            self.isLoading = false
            print("[LocationManager] Location error: \(error.localizedDescription)")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            // Auto-request location when permission is granted
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                self.requestLocation()
            }
        }
    }
}
