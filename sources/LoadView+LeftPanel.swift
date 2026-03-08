
import SwiftUI

  

//======================================

// MARK: - Load Screen Left Panel

//======================================

//

// Purpose:

// - Left side of LoadView split layout

// - Contains mode picker, templates, quick actions, header fields, compartment grid

//

// Ownership:

// - This is a PARTIAL of LoadPlanView (not a standalone screen)

// - Shares @EnvironmentObject and @FocusState.Binding with parent

//

// Responsibilities:

// - Mode toggle (Load plan vs Unload planning)

// - Template application

// - Quick actions (Deliver / Full Unload / Degas)

// - Header fields (Load Code, Terminal, Vehicle, Driver)

// - Compartment editing grid (product picker + litres)

// - SG adjustment sliders (per product)

//

// Design notes:

// - Compartment edits auto-trigger activity segment switching (context-based)

// - Delivery sheet is a modal launched from here

// - Blend helper widget embedded in left panel

//

//======================================

  

struct LoadLeftPanel: View {

    @EnvironmentObject var model: AppModel

    @FocusState.Binding var focusedField: LoadPlanView.Field?

    @State private var showDeliverySheet = false

    @State private var showFillTruckSheet = false

    var body: some View {

        Form {

            modeSection

            modeHelpSection

            quickActionsSection

            terminalHeaderSection

            blendSection

            truckInfoSection

            sgSection

            compartmentsSection

        }

        .onChange(of: focusedField) { _, newFocus in

            guard newFocus != nil else { return }

            let expected = model.isUnloadMode ? ActivityType.workUnload : ActivityType.workLoad

            if model.currentActivity != expected {

                model.promptToSwitchSegmentForEditing(to: expected)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusedField = nil }

            }

        }

        .sheet(isPresented: $showDeliverySheet) {

            DeliverySheetView().environmentObject(model)

        }

        .sheet(isPresented: $showFillTruckSheet) {

            FillTruckSheet().environmentObject(model)

        }

    }

}

  

// MARK: - Sections (split for compiler sanity)

  

private extension LoadLeftPanel {

    var modeSection: some View {

        Picker("Mode", selection: $model.isUnloadMode) {

            Text("Load plan").tag(false)

            Text("Unload planning").tag(true)

        }

        .pickerStyle(.segmented)

        .onChange(of: model.isUnloadMode) { _, newValue in

            model.handleModeToggleAttempt(newIsUnloadMode: newValue)

        }

    }

    var modeHelpSection: some View {

        Section {

            Text(model.isUnloadMode

                 ? "UNLOAD PLANNING: Enter remaining litres or use Record delivery. Placard updates as remaining changes."

                 : "LOAD PLAN: Draft your load. Placard should reflect LAST CONFIRMED until you press Confirm.")

            .font(.caption)

            .foregroundColor(model.isUnloadMode ? .orange : .blue)

        }

    }

    var quickActionsSection: some View {

        Section(header: Text("Quick actions & templates")) {

            if model.isUnloadMode {

                Button("Record Partial delivery") { showDeliverySheet = true }

                    .buttonStyle(.borderedProminent)

                Button("Full unload (clear litres)") { model.fullUnload() }

                    .buttonStyle(.bordered)

                Button("Degassed (clear all)") { model.degasTruck() }

                    .buttonStyle(.borderedProminent)

                    .tint(.red)

            } else {

                Button("Fill Truck") { showFillTruckSheet = true }

                    .buttonStyle(.borderedProminent)

                Text("Record partial load at this terminal (multi-stop loading)")

                    .font(.caption2)

                    .foregroundColor(.secondary)

                Divider()

                templateMenus

            }

        }

    }

    @ViewBuilder

    var templateMenus: some View {

        if model.savedTemplates.isEmpty && model.typicalLoadTemplates.isEmpty {

            Text("No templates yet.")

                .font(.caption)

                .foregroundColor(.secondary)

        } else {

            if !model.savedTemplates.isEmpty {

                Menu("Apply template") {

                    ForEach(model.savedTemplates) { t in

                        Button(t.name) { model.applyTemplateToLoadPlan(t) }

                    }

                }

                Text("Applies a saved template from Simulation.")

                    .font(.caption2)

                    .foregroundColor(.secondary)

            }

            if !model.typicalLoadTemplates.isEmpty {

                Menu("Apply typical load") {

                    ForEach(model.typicalLoadTemplates) { template in

                        Button(template.name) { model.applyTypicalLoad(template) }

                    }

                }

                Text("Applies a built-in pattern (temporary until persistence).")

                    .font(.caption2)

                    .foregroundColor(.secondary)

            }

        }

    }

    var terminalHeaderSection: some View {

        Section("Terminal") {

            TextField("Load code", text: $model.loadCode)

                .keyboardType(.numberPad)

                .focused($focusedField, equals: .loadCode)

                .onChange(of: model.loadCode) { _, _ in

                    model.resolveLoadCodeAutofill()

                }

            if !model.loadAccountCandidates.isEmpty {

                Picker("Account", selection: accountSelection) {

                    Text("— choose —").tag(UUID?.none)

                    ForEach(model.loadAccountCandidates) { acct in

                        Text(accountRowText(for: acct))

                            .tag(UUID?.some(acct.id))

                    }

                }

            } else {

                HStack { Text("Supplier"); Spacer(); Text(model.supplierNameDisplay).foregroundColor(.secondary) }

                HStack { Text("Terminal");  Spacer(); Text(model.terminalNameDisplay).foregroundColor(.secondary) }

                HStack { Text("Role");      Spacer(); Text(model.billingRoleDisplay).foregroundColor(.secondary) }

                if let hint = model.loadAccountResolveHint {

                    Text(hint).font(.caption).foregroundColor(.orange)

                }

            }

            TextField("Vehicle ID", text: $model.vehicleId)

                .focused($focusedField, equals: .vehicleId)

            TextField("Driver", text: $model.settings.driverName)

                .focused($focusedField, equals: .driverName)

        }

    }

    func accountRowText(for acct: LoadAccount) -> String {

        let termShort = model.terminals.first(where: { $0.id == acct.terminalID })?.shortName ?? "—"

        return "\(acct.label) • \(acct.billingRole.rawValue) • \(termShort)"

    }

    var accountSelection: Binding<UUID?> {

        Binding(

            get: { model.resolvedLoadAccountID },

            set: { newID in

                model.resolvedLoadAccountID = newID

                guard let newID,

                      let chosen = model.loadAccounts.first(where: { $0.id == newID }) else { return }

                model.resolvedTerminalID = chosen.terminalID

                model.terminalName = model.terminalNameDisplay // bridge

                model.loadAccountCandidates = []

                model.loadAccountResolveHint = nil

            }

        )

    }

    var blendSection: some View {

        Section(header: Text("Blend helper")) { BlendWidget() }

    }

    var truckInfoSection: some View {

        Section(header: Text("Truck 92 – Load Plan")) {

            Text("Safe fills per compartment (SFL) are fixed for this truck.")

                .font(.caption)

                .foregroundColor(.secondary)

                .fixedSize(horizontal: false, vertical: true)

        }

    }

    var sgSection: some View {

        Section(header: Text("SG (per product)")) {

            let usedCodes = Set(model.compartments.compactMap { $0.selectedProduct?.code })

            let selectedProducts = FuelProducts.all.filter { usedCodes.contains($0.code) }

            if selectedProducts.isEmpty {

                Text("Select products below to adjust SG.")

                    .font(.caption)

                    .foregroundColor(.secondary)

            } else {

                ForEach(selectedProducts, id: \.id) { product in

                    SGRow(product: product)

                        .environmentObject(model)

                }

            }

        }

    }

    var compartmentsSection: some View {

        Section(header: Text("Compartments (match paper sheet)")) {

            ForEach(model.compartments.indices, id: \.self) { index in

                CompartmentRow(index: index, isUnloadMode: model.isUnloadMode, focusedField: $focusedField)

                    .environmentObject(model)

            }

        }

    }

}

  

// MARK: - Subviews

  

private struct SGRow: View {

    @EnvironmentObject var model: AppModel

    let product: Product

    var body: some View {

        VStack(alignment: .leading, spacing: 4) {

            Text("\(product.shortName) SG").font(.subheadline)

            let binding = Binding<Double>(

                get: { model.sg(for: product) },

                set: { model.setSg($0, for: product) }

            )

            Slider(value: binding, in: product.sgMin...product.sgMax, step: 0.0001)

            HStack {

                Text(String(format: "Min %.4f", product.sgMin)).font(.caption2).foregroundColor(.secondary)

                Spacer()

                Text(String(format: "Current %.4f", model.sg(for: product))).font(.caption)

                Spacer()

                Text(String(format: "Max %.4f", product.sgMax)).font(.caption2).foregroundColor(.secondary)

            }

        }

        .padding(.vertical, 4)

    }

}

  

private struct CompartmentRow: View {

    @EnvironmentObject var model: AppModel

    let index: Int

    let isUnloadMode: Bool

    let focusedField: FocusState<LoadPlanView.Field?>.Binding

    var body: some View {

        VStack(alignment: .leading) {

            HStack {

                Text(model.compartments[index].name).font(.headline)

                Spacer()

                Text("SFL \(model.compartments[index].capacityLitres) L")

                    .font(.caption)

                    .foregroundColor(.secondary)

            }

            Picker("Product", selection: productCodeBinding) {

                Text("None").tag(String?.none)

                ForEach(FuelProducts.all, id: \.code) { product in

                    Text(product.name).tag(String?.some(product.code))

                }

            }

            .pickerStyle(.menu)

            HStack {

                Text(isUnloadMode ? "Remaining L" : "Litres")

                TextField("0", text: litresBinding)

                    .keyboardType(.numberPad)

                    .focused(focusedField, equals: .litres(index))

            }

        }

        .padding(.vertical, 4)

    }

    var productCodeBinding: Binding<String?> {

        Binding(

            get: { model.compartments[index].selectedProduct?.code },

            set: { newCode in

                if let code = newCode,

                   let p = FuelProducts.all.first(where: { $0.code == code }) {

                    model.compartments[index].selectedProduct = p

                } else {

                    model.compartments[index].selectedProduct = nil

                }

            }

        )

    }

    var litresBinding: Binding<String> {

        Binding(

            get: { model.compartments[index].litresText },

            set: { newValue in

                let digits = newValue.filter { $0.isNumber }

                if digits.isEmpty {

                    model.compartments[index].litresText = ""

                    return

                }

                let typed = Int(digits) ?? 0

                let sfl = model.compartments[index].capacityLitres

                let clamped = min(typed, sfl)

                model.compartments[index].litresText = String(clamped)

                if clamped > 0 { model.compartments[index].isDegassed = false }

            }

        )

    }

}
