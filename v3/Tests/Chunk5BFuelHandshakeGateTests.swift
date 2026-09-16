import Foundation

/// Chunk 5B gate. Fuel is tested as a client of the 5A Cargo socket,
/// while the existing 5A non-fuel gate remains an independent regression gate.
public enum Chunk5BFuelHandshakeGateTests {
    public static func run() -> [String] {
        var results: [String] = ["=== V3 Chunk 5B Fuel/Cargo Handshake Gate ==="]
        results.append(contentsOf: TestFuel.run())
        results.append(contentsOf: Chunk5BFuelMassProjectionTests.run())

        // 5A must remain healthy after Fuel is introduced. This is deliberately
        // called rather than copied so the original non-fuel contract stays the tripwire.
        let cargoResults = Chunk5CargoFoundationGateTests.run()
        let cargoPassed = cargoResults.last == "GATE PASS"
        results.append("\(cargoPassed ? "PASS" : "FAIL") — existing 5A non-fuel Cargo gate remains green")

        let failed = results.contains { $0.hasPrefix("FAIL") }
        results.append("---")
        results.append(failed ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
