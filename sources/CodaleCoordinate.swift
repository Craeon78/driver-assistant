
import Foundation

import CoreLocation

  

/// CLLocationCoordinate2D is NOT Codable. This is the tiny wrapper we persist instead.

struct CodableCoordinate: Codable, Hashable {

    var latitude: Double

    var longitude: Double

    init(latitude: Double, longitude: Double) {

        self.latitude = latitude

        self.longitude = longitude

    }

    init(_ coord: CLLocationCoordinate2D) {

        self.latitude = coord.latitude

        self.longitude = coord.longitude

    }

    var cl: CLLocationCoordinate2D {

        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

    }

}
