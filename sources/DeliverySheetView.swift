
import SwiftUI

  

//======================================

// MARK: - DeliverySheetView workflow (important note)

//======================================

//

// Current (pre-persistence, Phase 1):

// - Compartment-first workflow:

//     Compartment → Litres delivered

// - Optimised for speed during unload planning.

// - Directly mutates “remaining litres” on the load plan.

// - Assumes one product per compartment and simple delivery scenarios.

//

// Planned (post-persistence, Phase 3+):

// - Product-first, customer-centric workflow:

//     Customer → Product → Litres → Compartments

// - Support for:

//     • Multiple products delivered to the same customer

//     • Single product delivered from multiple compartments

//     • Multiple delivery lines per stop

// - Delivery becomes a first-class record (`DeliveryRecord` / `DeliveryLine`)

//   rather than a simple subtraction from remaining litres.

// - UI will likely become a multi-step sheet or modal stack.

//

// This file intentionally remains simple until:

// - Persistence is in place

// - Delivery history & reconciliation matter

// - Driver value outweighs added UI complexity

//======================================

  

struct DeliverySheetView: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCompName: String = ""

    @State private var litresText: String = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case litres }

    // Sanitise to digits-only so "1,000" or accidental characters don’t break parsing.

    private var litresDelivered: Int {

        let digits = litresText.filter { $0.isNumber }

        return Int(digits) ?? 0

    }

    private var canApply: Bool {

        !selectedCompName.isEmpty && litresDelivered > 0

    }

    var body: some View {

        NavigationView {

            Form {

                Section(header: Text("What are you doing?")) {

                    Text("Record delivery (litres delivered). The app will subtract it from remaining litres.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

                Section(header: Text("Compartment")) {

                    Picker("Compartment", selection: $selectedCompName) {

                        ForEach(model.compartments.map(\.name), id: \.self) { name in

                            Text(name).tag(name)

                        }

                    }

                    .pickerStyle(.menu)

                    .onChange(of: selectedCompName) { _, newValue in

                        guard !newValue.isEmpty else { return }

                        // ✅ after menu closes, jump focus to litres

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {

                            focusedField = .litres

                        }

                    }

                }

                Section(header: Text("Litres delivered")) {

                    TextField("0", text: $litresText)

                        .keyboardType(.numberPad)

                        .textInputAutocapitalization(.never)

                        .autocorrectionDisabled()

                        .focused($focusedField, equals: .litres)

                        .onChange(of: litresText) { _, newValue in

                            // Digits only; allow empty while typing.

                            let digits = newValue.filter { $0.isNumber }

                            if digits != newValue { litresText = digits }

                        }

                }

                Section {

                    Text("Tip: You can still type Remaining L directly on the main screen (override), but delivery is the normal driver workflow.")

                        .font(.caption2)

                        .foregroundColor(.secondary)

                }

            }

            .navigationTitle("Record delivery")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") { dismiss() }

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Apply") {

                        model.applyDelivery(

                            compName: selectedCompName,

                            litresDelivered: litresDelivered

                        )

                        dismiss()

                    }

                    .disabled(!canApply)

                }

                // ✅ Done button for numberPad

                ToolbarItemGroup(placement: .keyboard) {

                    Spacer()

                    Button("Done") { focusedField = nil }

                }

            }

            .onAppear {

                // Default selection for speed (avoid blank state).

                if selectedCompName.isEmpty {

                    selectedCompName = model.compartments.first?.name ?? ""

                }

                // ✅ if we already have a selection, focus litres immediately

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {

                    if !selectedCompName.isEmpty {

                        focusedField = .litres

                    }

                }

            }

        }

        .presentationDetents([.medium])

        .presentationDragIndicator(.visible)

        .scrollDismissesKeyboard(.interactively)

    }

}
