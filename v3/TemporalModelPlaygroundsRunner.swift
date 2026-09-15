import Foundation

public enum TemporalModelPlaygroundsRunner {
    public static func runGate() -> String {
        TemporalModelGateTests.runAll()
    }
}
