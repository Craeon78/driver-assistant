import Foundation

/// Vehicle-domain state. Vehicle identity and physical configuration belong
/// here rather than inside a cargo module.
struct VehicleRuntimeState {
    var selectedVehicleLabel: String = "Truck 92"
    var vehicleRegistration: String = "277 WQH"
    var odometerText: String = ""
    var prestartDone = false
}
