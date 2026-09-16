import Foundation

public enum TestFuel {
    public static func run() -> [String] {
        var results: [String] = []
        func check(_ name: String, _ body: () throws -> Bool) {
            do { results.append("\(try body() ? "PASS" : "FAIL") — \(name)") }
            catch { results.append("FAIL — \(name): \(error)") }
        }

        let c1 = CanonicalID.fresh()
        let c2 = CanonicalID.fresh()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let diesel = FuelProduct(name: "Ultimate Diesel", code: "xls", family: .diesel, kilogramsPerLitre: 0.84)
        let petrol = FuelProduct(name: "ULP 91", code: "ulp91", family: .petrol, kilogramsPerLitre: 0.74)

        check("Fuel adapts to generic CargoKind") {
            diesel.cargoKind.kind == "fuel.xls" && diesel.cargoKind.unitName == "L"
        }

        check("load/unload truth remains in generic CargoLedger") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            try ledger.append(FuelCargoAdapter.load(product: diesel, litres: 1_000, into: c1, occurredAt: now))
            try ledger.append(FuelCargoAdapter.delivery(product: diesel, litres: 300, from: c1, occurredAt: now.addingTimeInterval(1)))
            return try ledger.state(compartmentID: c1).quantity?.units == 700
        }

        check("zero litres retains diesel residue until degas") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            try ledger.append(FuelCargoAdapter.load(product: diesel, litres: 500, into: c1, occurredAt: now))
            try ledger.append(FuelCargoAdapter.delivery(product: diesel, litres: 500, from: c1, occurredAt: now.addingTimeInterval(1)))
            let entered = FuelStateEvent(kind: .productEntered, compartmentID: c1, productID: diesel.id, family: diesel.family, occurredAt: now)
            let before = try FuelProjector.project(cargoLedger: ledger, fuelEvents: [entered])[0]
            let degas = FuelStateEvent(kind: .degas, compartmentID: c1, occurredAt: now.addingTimeInterval(2))
            let after = try FuelProjector.project(cargoLedger: ledger, fuelEvents: [entered, degas])[0]
            return before.liquid == nil && before.residual == .diesel(productID: diesel.id) && after.residual == .clear
        }

        check("petrol zero litres retains vapour") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            try ledger.append(FuelCargoAdapter.load(product: petrol, litres: 500, into: c1, occurredAt: now))
            try ledger.append(FuelCargoAdapter.delivery(product: petrol, litres: 500, from: c1, occurredAt: now.addingTimeInterval(1)))
            let entered = FuelStateEvent(kind: .productEntered, compartmentID: c1, productID: petrol.id, family: petrol.family, occurredAt: now)
            let state = try FuelProjector.project(cargoLedger: ledger, fuelEvents: [entered])[0]
            return state.liquid == nil && state.residual == .petrolVapour(productID: petrol.id)
        }

        check("density derives mass through generic quantity") {
            let quantity = CargoQuantity(cargo: diesel.cargoKind, units: 1_000)
            return quantity.massKg == 840
        }

        check("reload appends rather than overwrites") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            try ledger.append(FuelCargoAdapter.load(product: diesel, litres: 1_000, into: c1, occurredAt: now))
            try ledger.append(FuelCargoAdapter.delivery(product: diesel, litres: 600, from: c1, occurredAt: now.addingTimeInterval(1)))
            try ledger.append(FuelCargoAdapter.load(product: diesel, litres: 500, into: c1, occurredAt: now.addingTimeInterval(2)))
            return ledger.transactions.count == 3 && (try ledger.state(compartmentID: c1).quantity?.units == 900)
        }

        check("running tank customer delivery is generic unload") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            try ledger.append(FuelCargoAdapter.load(product: diesel, litres: 3_600, into: c1, occurredAt: now))
            let runningTank = FuelCargoAdapter.delivery(product: diesel, litres: 300, from: c1, occurredAt: now.addingTimeInterval(1), destinationDescription: "Customer: Vehicle / Running Tank")
            try ledger.append(runningTank)
            return runningTank.kind == .unload && runningTank.destinationCompartmentID == nil && (try ledger.state(compartmentID: c1).quantity?.units == 3_300)
        }

        check("generic transfer remains generic") {
            var ledger = try CargoLedger(limits: [
                CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000),
                CargoCompartmentLimit(compartmentID: c2, capacityUnits: 5_000)
            ])
            try ledger.append(FuelCargoAdapter.load(product: diesel, litres: 1_000, into: c1, occurredAt: now))
            try ledger.append(FuelCargoAdapter.transfer(product: diesel, litres: 250, from: c1, to: c2, occurredAt: now.addingTimeInterval(1)))
            return (try ledger.state(compartmentID: c1).quantity?.units == 750) && (try ledger.state(compartmentID: c2).quantity?.units == 250)
        }

        check("correction preserves original and appends inverse") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let wrong = FuelCargoAdapter.load(product: diesel, litres: 1_000, into: c1, occurredAt: now)
            try ledger.append(wrong)
            try ledger.append(FuelCargoAdapter.correction(of: wrong, occurredAt: now.addingTimeInterval(1), note: "Recorded quantity wrong"))
            return ledger.transactions.count == 2 && ledger.transactions[0].id == wrong.id && (try ledger.state(compartmentID: c1).quantity == nil)
        }

        return results
    }
}
