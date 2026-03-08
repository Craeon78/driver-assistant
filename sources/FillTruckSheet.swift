
import SwiftUI

  

//======================================

// MARK: - Fill Truck Sheet (Multi-Terminal Loading)

//======================================

//

// Purpose:

// - Record a partial load at a specific terminal

// - Allows multi-stop loading with distinct terminal/load code per fill

// - Creates confirmed load snapshot WITHOUT clearing compartments

//

// Workflow:

// 1. Driver loads at Terminal A (e.g. BP)

// 2. Presses "Fill Truck"

// 3. Enters terminal/load code for THIS fill

// 4. Press "Record Fill" → creates confirmed load

// 5. Compartments retain current litres (not cleared)

// 6. Driver drives to Terminal B (e.g. Chevron)

// 7. Adds more litres to compartments

// 8. Presses "Fill Truck" again

// 9. Different terminal/load code for THIS fill

// 10. Result: TWO confirmed loads with distinct terminals

//

// Difference from "Confirm this load":

// - "Confirm this load" assumes ONE terminal per full load

// - "Fill Truck" allows MULTIPLE terminals in one run

//

//======================================

  

struct FillTruckSheet: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    // Sheet-local draft fields (don't mutate model until "Record Fill")

    @State private var fillTerminalName: String = ""

    @State private var fillLoadCode: String = ""

    // For display only

    private var currentLitresPerComp: [(name: String, product: String, litres: Int)] {

        model.compartments.compactMap { comp in

            guard let product = comp.selectedProduct else { return nil }

            let litres = Int(comp.litresText) ?? 0

            guard litres > 0 else { return nil }

            return (comp.name, product.shortName, litres)

        }

    }

    private var totalLitres: Int {

        currentLitresPerComp.reduce(0) { $0 + $1.litres }

    }

    private var canRecord: Bool {

        !fillTerminalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&

        !fillLoadCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&

        totalLitres > 0

    }

    var body: some View {

        NavigationView {

            Form {

                Section(header: Text("This Fill")) {

                    TextField("Terminal", text: $fillTerminalName)

                        .textInputAutocapitalization(.words)

                    TextField("Load Code", text: $fillLoadCode)

                        .keyboardType(.numberPad)

                }

                Section(header: Text("Current On-Truck Litres")) {

                    if currentLitresPerComp.isEmpty {

                        Text("No products loaded")

                            .foregroundColor(.secondary)

                    } else {

                        ForEach(currentLitresPerComp, id: \.name) { comp in

                            HStack {

                                Text(comp.name)

                                    .frame(width: 40, alignment: .leading)

                                Text(comp.product)

                                    .frame(width: 60, alignment: .leading)

                                Spacer()

                                Text("\(comp.litres) L")

                                    .bold()

                            }

                            .font(.caption)

                        }

                        Divider()

                        HStack {

                            Text("Total")

                                .bold()

                            Spacer()

                            Text("\(totalLitres) L")

                                .bold()

                        }

                        .font(.subheadline)

                    }

                }

                Section {

                    Text("This records a partial load at this terminal. Compartments will NOT be cleared. You can load more at another terminal and record another fill.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

            }

            .navigationTitle("Fill Truck")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") { dismiss() }

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Record Fill") {

                        recordFill()

                        dismiss()

                    }

                    .disabled(!canRecord)

                }

            }

        }

        .presentationDetents([.medium])

        .presentationDragIndicator(.visible)

        .onAppear {

            // Pre-fill from last known values

            fillTerminalName = model.terminalName

            fillLoadCode = model.loadCode

        }

    }

    private func recordFill() {

        // Create a confirmed load snapshot using the SHEET's terminal/load code

        // (not model.terminalName/loadCode)

        let confirmTime = Date()

        // Ensure we're in Loading segment

        if model.isOnDuty {

            model.isDriving = false

            model.isOnBreak = false

            model.startActivity(.workLoad, at: confirmTime)

        }

        // Build compartment snapshots (same logic as confirmCurrentLoad)

        var compSnapshots: [ConfirmedCompartment] = []

        for comp in model.compartments {

            let litres = Double(comp.litresText) ?? 0

            guard litres > 0, let product = comp.selectedProduct else { continue }

            let sgValue = model.sg(for: product)

            let mass = litres * sgValue

            let snap = ConfirmedCompartment(

                name: comp.name,

                sfl: comp.capacityLitres,

                productShort: product.shortName,

                sg: sgValue,

                litres: litres,

                massKg: mass

            )

            compSnapshots.append(snap)

        }

        // Use SHEET values (not model values)

        let load = ConfirmedLoad(

            timestamp: confirmTime,

            mode: .loadConfirmed,

            terminalName: fillTerminalName.trimmingCharacters(in: .whitespacesAndNewlines),

            loadCode: fillLoadCode.trimmingCharacters(in: .whitespacesAndNewlines),

            vehicleId: model.vehicleId,

            driverName: model.settings.driverName,

            compartments: compSnapshots,

            totalLitres: model.totalLitres,

            totalMassKg: model.totalMassKg,

            steerKg: model.steerLoadedKg,

            driveKg: model.driveLoadedKg,

            gvmKg: model.gvmLoadedKg

        )

        model.confirmedLoads.append(load)

        // Log event

        model.logEvent(.load, note: "Fill @ \(fillTerminalName)", at: confirmTime)

        // DO NOT clear compartments (that's the point of "Fill Truck")

        // DO NOT set suppressPlacardUntilNextConfirm

    }

}

  

#Preview {

    FillTruckSheet()

        .environmentObject(AppModel())

}
