
// ProfileEnvelopeV1.swift

import Foundation

  

struct ProfileEnvelopeV1<Payload: Codable>: Codable {

    // Keep this as a literal; no static storage.

    var schemaVersion: Int = 1

    var savedAt: Date = Date()

    var payload: Payload

    init(schemaVersion: Int = 1, savedAt: Date = Date(), payload: Payload) {

        self.schemaVersion = schemaVersion

        self.savedAt = savedAt

        self.payload = payload

    }

}
