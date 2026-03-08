
import Foundation

  

//======================================

// MARK: - MaturityState

//======================================

//

// Represents the confidence level of the

// GPS correction factor learning system.

//

// The state influences:

//

// • how aggressively the factor updates

// • how frequently the app suggests

//   optional OdoCapture anchors

//

// States progress as the engine gathers

// more span closures with stable results.

//

  

enum MaturityState: String, Codable, CaseIterable {

    case embryonic      // new truck / driver / calibration reset

    case stabilising    // learning but starting to settle

    case mature         // very stable correction factor

    case drifting       // variance increasing again

}
