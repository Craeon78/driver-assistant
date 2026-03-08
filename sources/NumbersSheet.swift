
import SwiftUI

  

struct NumbersSheet: View {

    var onClose: () -> Void

    var body: some View {

        VStack {

            HStack {

                Button("Close") { onClose() }

                Spacer()

                Text("Numbers").font(.headline)

                Spacer()

                // spacer to balance Close button width

                Color.clear.frame(width: 60, height: 1)

            }

            .padding()

            Divider()

            Spacer()

            Text("Numbers (placeholder)")

            Spacer()

        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

}
