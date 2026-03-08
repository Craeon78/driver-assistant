
import SwiftUI

  

struct TruckProfile2DSheet: View {

    var onClose: () -> Void

    var body: some View {

        VStack {

            HStack {

                Button("Close") { onClose() }

                Spacer()

                Text("Truck").font(.headline)

                Spacer()

                // spacer to balance Close button width

                Color.clear.frame(width: 60, height: 1)

            }

            .padding()

            Divider()

            Spacer()

            Text("Truck (placeholder)")

            Spacer()

        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

}
