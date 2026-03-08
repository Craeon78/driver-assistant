
import CoreLocation

  

//======================================

// MARK: - SuburbSuggestionManager.swift

//======================================

// 

// utilising gps location to suggest a suburb for odocapture

  

  

final class SuburbSuggestionManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    private let geocoder = CLGeocoder()

    @Published var suggestedSuburb: String? = nil

    @Published var isFetching: Bool = false

    @Published var authorization: CLAuthorizationStatus = .notDetermined

    override init() {

        super.init()

        manager.delegate = self

        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

    }

    func requestPermissionIfNeeded() {

        if manager.authorizationStatus == .notDetermined {

            manager.requestWhenInUseAuthorization()

        }

    }

    func refresh() {

        requestPermissionIfNeeded()

        let auth = manager.authorizationStatus

        guard auth == .authorizedAlways || auth == .authorizedWhenInUse else {

            DispatchQueue.main.async {

                self.suggestedSuburb = nil

                self.isFetching = false

            }

            return

        }

        isFetching = true

        manager.requestLocation() // one-shot

    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {

        DispatchQueue.main.async {

            self.authorization = manager.authorizationStatus

        }

    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        guard let loc = locations.last else {

            DispatchQueue.main.async { self.isFetching = false }

            return

        }

        geocoder.cancelGeocode()

        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in

            let suburb =

            placemarks?.first?.locality

            ?? placemarks?.first?.subLocality

            ?? placemarks?.first?.administrativeArea

            DispatchQueue.main.async {

                self.suggestedSuburb = suburb

                self.isFetching = false

            }

        }

    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {

        DispatchQueue.main.async {

            self.suggestedSuburb = nil

            self.isFetching = false

        }

    }

}
