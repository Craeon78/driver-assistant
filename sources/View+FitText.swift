
import SwiftUI

  

//======================================

// MARK: - View+FitText.swift

//======================================

// 

// overarching display helper for different screen sizes.

  

extension View {

    /// Scales text down to fit within its available space.

    /// Useful for tight UI (e.g. headers, pills, compact rows).

    ///

    /// - Parameters:

    ///   - minScale: Smallest allowed scale factor before truncation would occur.

    ///   - lines: Maximum number of lines to allow.

    func fitText(minScale: CGFloat = 0.6, lines: Int = 1) -> some View {

        self

            .lineLimit(lines)

            .minimumScaleFactor(minScale)

            .allowsTightening(true)

    }

}
