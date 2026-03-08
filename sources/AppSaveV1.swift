
import Foundation

  

//======================================

// MARK: - AppSaveV1 (Session Autosave Payload)

//======================================

//

// Purpose:

// - Capture the minimum "session state" needed to survive a crash.

// - Restore timeline + confirmed loads + odometer anchors consistently.

//

// Notes:

// - This is NOT long-term history storage yet.

// - Keep it boring and reliable.

  

struct AppSaveV1: Codable {

    // Schema

    let schemaVersion: Int

    let savedAt: Date

    //=========================

    // Timeline / shift engine

    //=========================

    var isOnDuty: Bool

    var isDriving: Bool

    var isOnBreak: Bool

    var currentActivity: ActivityType

    var currentSegmentStart: Date?

    var runningSegmentID: UUID?

    var segmentsToday: [ActivitySegment]

    var gpsShiftMetersLive: Double 

    //=========================

    // Timeline events

    //=========================

    var events: [ShiftEvent]

    //=========================

    // Loads (authoritative session history)

    //=========================

    var confirmedLoads: [ConfirmedLoad]

    //=========================

    // Odo + location snapshots

    //=========================

    var odoText: String

    var odoLocationRecords: [OdoLocationRecord]

    var lastOdoCaptureTime: Date?

    //=========================

    // GPS/ODO distance engine anchors

    //=========================

    var gpsKmSinceLastOdoBySegment: [UUID: Double]

    var finalisedKmBySegment: [UUID: Double]

    var lastOdoAnchorRecordID: UUID?

    var lastOdoAnchorKm: Int?

    var lastOdoAnchorKmCorrectionFactor: Double

    //=========================

    // Load tab draft state (practical recovery)

    //=========================

    var isUnloadMode: Bool

    var compartments: [CompartmentModel]

    var lazyAxleIsUp: Bool

    var fuelStepIndex: Int

    // Optional: keep settings if DriverSettings is Codable (it should be).

    var settings: DriverSettings

}

  

//======================================

// MARK: - Build / Apply

//======================================

  

@MainActor

extension AppSaveV1 {

    static let currentSchemaVersion = 1

    static func build(from model: AppModel) -> AppSaveV1 {

        AppSaveV1(

            schemaVersion: currentSchemaVersion,

            savedAt: Date(),

            isOnDuty: model.isOnDuty,

            isDriving: model.isDriving,

            isOnBreak: model.isOnBreak,

            currentActivity: model.currentActivity,

            currentSegmentStart: model.currentSegmentStart,

            runningSegmentID: model.runningSegmentID,

            segmentsToday: model.segmentsToday,

            gpsShiftMetersLive: model.gpsShiftMetersLive, 

            events: model.events,

            confirmedLoads: model.confirmedLoads,

            odoText: model.odoText,

            odoLocationRecords: model.odoLocationRecords,

            lastOdoCaptureTime: model.lastOdoCaptureTime,

            gpsKmSinceLastOdoBySegment: model.gpsKmSinceLastOdoBySegment,

            finalisedKmBySegment: model.finalisedKmBySegment,

            lastOdoAnchorRecordID: model.lastOdoAnchorRecordID,

            lastOdoAnchorKm: model.lastOdoAnchorKm,

            lastOdoAnchorKmCorrectionFactor: model.kmCorrectionFactor,

            isUnloadMode: model.isUnloadMode,

            compartments: model.compartments,

            lazyAxleIsUp: model.lazyAxleIsUp,

            fuelStepIndex: model.fuelStepIndex,

            settings: model.settings

        )

    }

    func apply(to model: AppModel) {

        // Do NOT restore any transient UI sheet state (prompts, pending closures, etc.)

        // Restore only "real" session state.

        model.isOnDuty = isOnDuty

        model.isDriving = isDriving

        model.isOnBreak = isOnBreak

        model.currentActivity = currentActivity

        model.currentSegmentStart = currentSegmentStart

        model.runningSegmentID = runningSegmentID

        model.segmentsToday = segmentsToday

        model.gpsShiftMetersLive = gpsShiftMetersLive

        model.events = events

        model.confirmedLoads = confirmedLoads

        model.odoText = odoText

        model.odoLocationRecords = odoLocationRecords

        model.lastOdoCaptureTime = lastOdoCaptureTime

        model.gpsKmSinceLastOdoBySegment = gpsKmSinceLastOdoBySegment

        model.finalisedKmBySegment = finalisedKmBySegment

  

        model.lastOdoAnchorRecordID = lastOdoAnchorRecordID

        model.lastOdoAnchorKm = lastOdoAnchorKm

        model.kmCorrectionFactor = lastOdoAnchorKmCorrectionFactor

        model.isUnloadMode = isUnloadMode

        model.compartments = compartments

        model.lazyAxleIsUp = lazyAxleIsUp

        model.fuelStepIndex = fuelStepIndex

        model.settings = settings

        // Safety: after restore, ensure lastTick doesn’t create weird deltas.

        model.lastTick = Date()

    }

}
