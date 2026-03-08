
import Foundation

  

/// Simple 2-threshold hysteresis gate.

/// Example: upper=101, lower=99

/// - When inactive: activates at >= upper

/// - When active:   deactivates at <= lower

struct HysteresisGate {

    let upper: Int

    let lower: Int

    init(upper: Int, lower: Int) {

        precondition(lower < upper, "HysteresisGate: lower must be < upper")

        self.upper = upper

        self.lower = lower

    }

    func nextState(current: Int, isActive: Bool) -> Bool {

        if isActive {

            // stay active unless we're safely below

            return current > lower

        } else {

            // stay inactive unless we're clearly above

            return current >= upper

        }

    }

}
