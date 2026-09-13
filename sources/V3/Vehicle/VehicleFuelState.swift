import Foundation

/// Vehicle-owned state that must remain independent of transported cargo.
/// The truck's running fuel belongs to Vehicle; Fuel Cargo may consume its mass
/// contribution when calculating combination mass but must not own this truth.
struct VehicleFuelState {
    var fuelStepIndex: Int = 6
    var lazyAxleIsUp = false

    let stepFractions: [Double] = [
        0.0,
        0.25,
        1.0 / 3.0,
        0.5,
        2.0 / 3.0,
        0.75,
        1.0
    ]

    var fraction: Double {
        let index = min(max(fuelStepIndex, 0), stepFractions.count - 1)
        return stepFractions[index]
    }
}
