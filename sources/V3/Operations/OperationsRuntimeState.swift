import Foundation

/// Existing operational UI/prompt state grouped under the V3 Operations owner.
/// This introduces no new operational behaviour and does not alter Driver work/rest truth.
struct OperationsRuntimeState {
    var pendingStartShiftCapture = false
    var pendingEndShiftCapture = false

    var showStoppedNudgeInLoad = false
    var stoppedStartAt: Date?
    var lastStoppedNudgeAt: Date?

    var movementStartAt: Date?
    var lastNudgeAt: Date?

    var isShowingIncidentSheet = false
    var incidentDraft: IncidentReport?
    var lastIncidentAdvicePlan: IncidentAdvicePlan?
}
