import Foundation

/// One-way boundary adapter: Fuel resolves evidenced mass; Vehicle receives only generic kg.
/// Vehicle does not inspect FuelProduct, density, CargoKind, or FuelCommittedState.
public enum FuelVehicleMassAdapter {
    public static func transportedMass(from state: FuelCommittedState) throws -> [TransportedCompartmentMass] {
        try FuelMassProjector.project(state).map {
            TransportedCompartmentMass(compartmentID: $0.compartmentID, massKg: $0.massKg)
        }
    }
}