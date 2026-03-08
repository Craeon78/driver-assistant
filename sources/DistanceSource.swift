
import Foundation

  

//======================================

// MARK: - DistanceSource

//======================================

//

// Identifies which GPS evidence stream

// was selected at span closure.

//

// The engine tracks both raw and filtered

// distance during an open span. When the

// driver performs an OdoCapture the engine

// evaluates which source best matches the

// odometer truth anchor.

//

// This enum records the winning source.

//

  

enum DistanceSource: String, Codable, CaseIterable {

    case raw

    case filtered

}
