import Foundation

/// Vehicle-domain identity and physical configuration state.
///
/// Driver-entered odometer observations are evidence/anchors and are intentionally
/// not collapsed into this identity container. Existing AppModel ODO capture remains
/// in place until it can be migrated without changing its authority semantics.
struct VehicleRuntimeState {
    var selectedVehicleLabel: String = "Truck 92"
    var vehicleRegistration: String = "277 WQH"
    var prestartDone = false
}
