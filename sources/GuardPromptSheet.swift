
import SwiftUI

  

struct GuardPromptSheet: View {

    @EnvironmentObject var model: AppModel

    let prompt: AppModel.GuardPrompt

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text(prompt.title)

                .font(.title3).bold()

            Text(prompt.message)

                .font(.body)

            Spacer()

            VStack(spacing: 12) {

                ForEach(Array(prompt.actions.enumerated()), id: \.offset) { _, action in

                    Button(role: action.role) {

                        action.handler()

                        model.activeGuardPrompt = nil

                    } label: {

                        Text(action.title).frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.borderedProminent)

                }

            }

        }

        .padding()

        .presentationDetents([.medium])

        .presentationDragIndicator(.visible)

    }

}
