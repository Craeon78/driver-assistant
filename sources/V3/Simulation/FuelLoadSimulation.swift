import Foundation

/// V3 Simulation projection for a Fuel draft load.
/// Pure calculation only: Simulation does not own or mutate operational truth.
enum FuelLoadSimulation {
    static func result(
        for template: LoadTemplate,
        products: [Product],
        truck: TruckConfig
    ) -> MassSimulationResult {
        MassSimulationLogic.simulate(
            template: template,
            products: products,
            truck: truck
        )
    }
}
