
import UIKit
// This is here as a just in case
// iPad for testing doesn’t use haptics 

enum Haptics {

    static func heavyImpact() {

        let gen = UIImpactFeedbackGenerator(style: .heavy)

        gen.prepare()

        gen.impactOccurred()

    }

}
