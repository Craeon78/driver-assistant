
import SwiftUI

  

extension FatigueRuleStatus {

    var uiColor: Color {

        switch self {

        case .ok:      return .green

        case .warning: return .orange

        case .over:    return .red

        }

    }

}
