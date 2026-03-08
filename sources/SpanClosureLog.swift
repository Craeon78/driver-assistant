
import Foundation

  

//======================================

// MARK: - SpanClosureLog

//======================================

//

// Diagnostic record captured whenever a

// GPS span closes due to an OdoCapture.

//

// This acts as a "black box" for the

// correction-factor learning system,

// allowing inspection of:

//

// • odometer delta

// • raw vs filtered GPS evidence

// • chosen source

// • factor update behaviour

// • maturity state at time of learning

//

// These logs are extremely valuable when

// reviewing real-world runs and tuning

// GPS behaviour.

  

  

struct SpanClosureLog: Codable, Identifiable {

    // MARK: - Identity

    let id: UUID

    let timestamp: Date

    // MARK: - Odometer truth

    let odoDeltaKm: Double

    // MARK: - GPS evidence

    let gpsRawKm: Double

    let gpsFilteredKm: Double?

    let chosenSource: DistanceSource  // e.g. .raw / .filtered

    // MARK: - Factor learning

    let priorFactor: Double

    let updatedFactor: Double

    let maturityState: MaturityState

    // MARK: - Errors (absolute)

    let errorRawKm: Double

    let errorFilteredKm: Double?

    init(

        id: UUID = UUID(),

        timestamp: Date,

        odoDeltaKm: Double,

        gpsRawKm: Double,

        gpsFilteredKm: Double?,

        chosenSource: DistanceSource,

        priorFactor: Double,

        updatedFactor: Double,

        maturityState: MaturityState,

        errorRawKm: Double,

        errorFilteredKm: Double?

    ) {

        self.id = id

        self.timestamp = timestamp

        self.odoDeltaKm = odoDeltaKm

        self.gpsRawKm = gpsRawKm

        self.gpsFilteredKm = gpsFilteredKm

        self.chosenSource = chosenSource

        self.priorFactor = priorFactor

        self.updatedFactor = updatedFactor

        self.maturityState = maturityState

        self.errorRawKm = errorRawKm

        self.errorFilteredKm = errorFilteredKm

    }

}
