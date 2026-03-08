
import SwiftUI

  

enum CommandSection: String, Identifiable {

    case menu, journal, truck, numbers

    var id: String { rawValue }

}

  

struct CommandView: View {

    @State private var section: CommandSection = .menu

    var body: some View {

        ZStack {

            switch section {

            case .menu:

                menu

            case .journal:

                JournalSheet(onClose: { section = .menu })

            case .truck:

                TruckProfile2DSheet(onClose: { section = .menu })

            case .numbers:

                NumbersSheet(onClose: { section = .menu })

            }

        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

    private var menu: some View {

        VStack(spacing: 16) {

            Text("Command").font(.largeTitle.bold())

            Text("Pick a module.").foregroundStyle(.secondary)

            VStack(spacing: 12) {

                Button("Journal") { section = .journal }

                Button("Truck")   { section = .truck }

                Button("Numbers") { section = .numbers }

            }

            .buttonStyle(.borderedProminent)

            Spacer()

        }

        .padding()

    }

}
