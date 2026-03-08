
// DriverProfilePayloadV1.swift

import Foundation

  

struct DriverProfilePayloadV1: Codable {

    var driverName: String = "Cory Olsen"

    enum LicenceType: String, Codable, CaseIterable {

        case mr = "MR"

        case hr = "HR"

        case hc = "HC"

        case mc = "MC"

    }

    enum LicenceHoursMode: String, Codable, CaseIterable {

        case standard = "Standard"

        case bfm = "BFM"

        case afm = "AFM"

    }

    enum CrewMode: String, Codable, CaseIterable {

        case solo = "solo"

        case twoUp = "two_up"

    }

    var licenceType: LicenceType = .hc

    var licenceHoursMode: LicenceHoursMode = .standard

    var crewMode: CrewMode = .solo

    var isOwnerDriver: Bool = false

}
