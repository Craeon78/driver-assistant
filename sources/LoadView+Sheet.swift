
import SwiftUI

//======================================

// MARK: - Loadview+Sheet.swift

//======================================

//

//  Read-only, print-style summary of the current load or unload plan.

//

//  This view:

//  • Presents the authoritative snapshot of the *current draft* load plan

//  • Combines compartment truth, totals, axle loading and DG placarding

//  • Allows the driver to explicitly CONFIRM a load into immutable history

//

//  This view deliberately:

//  • Does NOT allow editing (all edits happen in the left panel)

//  • Does NOT enforce compliance (visual guidance only)

//  • Assumes it sits under EnvironmentObject(AppModel)

//

//  Think of this as the “paper sheet you’d hand to someone”,

//  rendered live from the model.

  

struct LoadSheetView: View {

    @EnvironmentObject var model: AppModel

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 12) {

                headerCard

                compartmentTable

                totalsAndAxlesWithPlacardRow

                confirmedLoadsSection

            }

            .padding()

            .frame(maxWidth: .infinity, alignment: .topLeading)

        }

        .background(Color(.systemBackground))

    }

    //======================================

    // MARK: - Header card (print-ish summary)

    //======================================

    private var headerCard: some View {

        VStack(alignment: .leading, spacing: 4) {

            HStack {

                Text("BFA") // Placeholder logo text (Phase 4: replace with image)

                    .font(.title2)

                    .fontWeight(.bold)

                Spacer()

                Text(model.isUnloadMode ? "Unload Planning (remaining on truck)" : "Load Plan")

                    .font(.headline)

            }

            Divider()

            HStack(alignment: .top) {

                VStack(alignment: .leading, spacing: 2) {

                    Text("Load code: \(model.loadCode)")

                    Text("Terminal: \(model.terminalNameDisplay)")

                    Text("Supplier: \(model.supplierNameDisplay)")

                    Text("Role: \(model.billingRoleDisplay)")

                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {

                    Text("Driver: \(model.settings.driverName)")

                    Text("Vehicle: \(model.vehicleId)")

                    Text("Date: \(formattedToday)")

                }

            }

            .font(.subheadline)

        }

        .padding()

        .background(Color.gray.opacity(0.08))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Compartment table

    //======================================

    private var compartmentTable: some View {

        VStack(alignment: .leading, spacing: 4) {

            Text("Compartments")

                .font(.headline)

            HStack {

                Text("Comp").frame(width: 50, alignment: .leading)

                Text("SFL").frame(width: 60, alignment: .trailing)

                Text("Prod").frame(width: 60, alignment: .leading)

                Text("SG").frame(width: 60, alignment: .trailing)

                Text("Qty L").frame(width: 70, alignment: .trailing)

                Text("Mass kg").frame(width: 80, alignment: .trailing)

            }

            .font(.caption.bold())

            Divider()

            ForEach(model.compartments) { comp in

                let litres = Double(comp.litresText) ?? 0

                let product = comp.selectedProduct

                let productCode = product?.shortName ?? ""

                let sgValue = product.map { model.sg(for: $0) }

                let mass = model.massKg(for: comp)

                HStack {

                    Text(comp.name)

                        .frame(width: 50, alignment: .leading)

                    Text("\(comp.capacityLitres)")

                        .frame(width: 60, alignment: .trailing)

                    Text(productCode)

                        .frame(width: 60, alignment: .leading)

                    if let sg = sgValue {

                        Text(String(format: "%.4f", sg))

                            .frame(width: 60, alignment: .trailing)

                    } else {

                        Text("—")

                            .foregroundColor(.secondary)

                            .frame(width: 60, alignment: .trailing)

                    }

                    if litres > 0 {

                        Text(String(format: "%.0f", litres))

                            .frame(width: 70, alignment: .trailing)

                    } else {

                        Text("—")

                            .foregroundColor(.secondary)

                            .frame(width: 70, alignment: .trailing)

                    }

                    if let mass = mass {

                        Text(String(format: "%.0f", mass))

                            .frame(width: 80, alignment: .trailing)

                    } else {

                        Text("—")

                            .foregroundColor(.secondary)

                            .frame(width: 80, alignment: .trailing)

                    }

                }

                .font(.caption)

            }

        }

        .padding()

        .background(Color.gray.opacity(0.03))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Totals

    //======================================

    private var totalsSection: some View {

        VStack(alignment: .leading, spacing: 4) {

            Text("Totals")

                .font(.headline)

            Text("Total litres: \(model.totalLitres)")

            Text(String(format: "Total mass: %.0f kg", model.totalMassKg))

        }

        .padding()

        .background(Color.gray.opacity(0.03))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Axles (demo colours)

    //======================================

    private var lazyAxleBinding: Binding<Bool> {

        Binding(

            get: { model.lazyAxleIsUp },

            set: { model.lazyAxleIsUp = $0 }

        )

    }

    private var axlesSection: some View {

        let cfg = model.truckConfig

        let steer = model.steerLoadedKg

        let drive = model.driveLoadedKg

        let gvm   = model.gvmLoadedKg

        // UI-only colour helper (not enforcement).

        func colour(for load: Double, limit: Double) -> Color {

            guard limit > 0 else { return .primary }

            let ratio = load / limit

            if ratio > 1.0 { return .red }

            if ratio > 0.9 { return .orange }

            return .primary

        }

        return VStack(alignment: .leading, spacing: 4) {

            if model.truckConfig.hasLazyAxle {

                Toggle("Lazy axle lifted", isOn: lazyAxleBinding)

                    .toggleStyle(.switch)

                    .font(.caption)

            }

            // Running tank slider (stepped; kg-only heuristic)

            // - Drives AppModel.fuelStepIndex (0..6)

            // - fuelFraction is computed from that index (read-only)

            VStack(alignment: .leading, spacing: 6) {

                let fullKg = cfg.runTankFullKg

                let runningKg = fullKg * model.fuelFraction

                let missingKg = fullKg * (1.0 - model.fuelFraction)

                HStack {

                    Text("Running tank:")

                        .font(.caption)

                        .foregroundStyle(.secondary)

                    Text("\(model.fuelStepLabel) (≈\(Int(runningKg.rounded())) kg)")

                        .font(.caption)

                        .bold()

                    Spacer()

                    Text("Tare −\(Int(missingKg.rounded())) kg")

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                }

                Slider(

                    value: Binding(

                        get: { Double(model.fuelStepIndex) },

                        set: { model.fuelStepIndex = Int($0.rounded()) }

                    ),

                    in: 0...6,

                    step: 1

                )

                HStack {

                    Text("0")

                    Spacer()

                    Text("1/4")

                    Spacer()

                    Text("1/3")

                    Spacer()

                    Text("1/2")

                    Spacer()

                    Text("2/3")

                    Spacer()

                    Text("3/4")

                    Spacer()

                    Text("FULL")

                }

                .font(.caption2)

                .foregroundStyle(.secondary)

            }

            .padding(.top, 6)

            Text("Axles (demo)")

                .font(.headline)

            HStack {

                Text("Steer").frame(width: 60, alignment: .leading)

                Text(String(format: "%.0f / %.0f kg", steer, cfg.maxSteerKg))

                    .foregroundColor(colour(for: steer, limit: cfg.maxSteerKg))

            }

            .font(.caption)

            HStack {

                Text("Drive").frame(width: 60, alignment: .leading)

                Text(String(format: "%.0f / %.0f kg", drive, cfg.maxDriveKg))

                    .foregroundColor(colour(for: drive, limit: cfg.maxDriveKg))

            }

            .font(.caption)

            HStack {

                Text("GVM").frame(width: 60, alignment: .leading)

                Text(String(format: "%.0f / %.0f kg", gvm, cfg.maxGvmKg))

                    .foregroundColor(colour(for: gvm, limit: cfg.maxGvmKg))

            }

            .font(.caption)

        }

        .padding()

        .background(Color.gray.opacity(0.03))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Totals + Axles + Placard row

    //======================================

    private var totalsAndAxlesWithPlacardRow: some View {

        HStack(alignment: .top, spacing: 16) {

            VStack(alignment: .leading, spacing: 12) {

                totalsSection

                axlesSection

            }

            Spacer()

            // Placard reads model.displayedDGPlacardDecision.

            // Assumes this view sits under the same EnvironmentObject(AppModel).

            DGPlacardView()

                .frame(width: 500) // Phase 4: make responsive for split view / smaller iPads

                .padding(.top, 4)

        }

    }

    //======================================

    // MARK: - Confirmed loads list

    //======================================

    private var confirmedLoadsSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            HStack {

                Text("Confirmed loads (today)")

                    .font(.headline)

                Spacer()

                // This is the ONE place the draft becomes "authoritative history".

                Button("Confirm this load") {

                    // Tier 3 Confirm Guard: ALWAYS verify segment before confirming

                    let expectedSegment = model.isUnloadMode ? ActivityType.workUnload : ActivityType.workLoad

                    if model.currentActivity != expectedSegment {

                        // Wrong segment — block and prompt

                        model.presentSegmentMismatchBlocker(expected: expectedSegment)

                    } else {

                        // Correct segment — allow confirm

                        model.confirmCurrentLoad()

                    }

                }

                .font(.subheadline)

                .buttonStyle(.borderedProminent)

                .disabled(!model.canConfirmCurrentLoad)

                .opacity(model.canConfirmCurrentLoad ? 1.0 : 0.35)

            }

            if !model.canConfirmCurrentLoad {

                Text("No changes since last confirmed load.")

                    .font(.caption2)

                    .foregroundColor(.secondary)

            }

            if model.confirmedLoads.isEmpty {

                Text("No loads confirmed yet.")

                    .font(.caption)

                    .foregroundColor(.secondary)

            } else {

                ForEach(model.confirmedLoads) { load in

                    DisclosureGroup {

                        // Expanded: per-compartment truth at that moment

                        VStack(alignment: .leading, spacing: 6) {

                            HStack {

                                Text("Comp").font(.caption.bold())

                                Spacer()

                                Text("Prod").font(.caption.bold())

                                Spacer()

                                Text("L").font(.caption.bold())

                                Spacer()

                                Text("kg").font(.caption.bold())

                            }

                            .foregroundColor(.secondary)

                            ForEach(load.compartments) { line in

                                HStack {

                                    Text(line.name)

                                        .font(.caption)

                                        .frame(width: 40, alignment: .leading)

                                    Spacer()

                                    Text(line.productShort)

                                        .font(.caption)

                                        .frame(width: 60, alignment: .leading)

                                    Spacer()

                                    Text(formatLitres(line.litres))

                                        .font(.caption)

                                        .frame(width: 60, alignment: .trailing)

                                    Spacer()

                                    Text(formatKg(line.massKg))

                                        .font(.caption)

                                        .frame(width: 80, alignment: .trailing)

                                }

                            }

                        }

                        .padding(.top, 6)

                    } label: {

                        // Collapsed summary

                        VStack(alignment: .leading, spacing: 2) {

                            HStack {

                                Text(loadHeader(load))

                                    .font(.caption.bold())

                                Spacer()

                                Text(load.mode.rawValue)

                                    .font(.caption2.bold())

                                    .padding(.horizontal, 8)

                                    .padding(.vertical, 3)

                                    .background(load.mode == .loadConfirmed

                                                ? Color.blue.opacity(0.15)

                                                : Color.orange.opacity(0.18))

                                    .cornerRadius(8)

                            }

                            Text(String(format: "Total: %d L, %.0f kg",

                                        load.totalLitres, load.totalMassKg))

                            .font(.caption)

                            Text(String(format: "Axles S/D/G: %.0f / %.0f / %.0f kg",

                                        load.steerKg, load.driveKg, load.gvmKg))

                            .font(.caption2)

                            .foregroundColor(.secondary)

                        }

                        .padding(.vertical, 4)

                    }

                    Divider()

                }

            }

        }

        .padding()

        .background(Color.gray.opacity(0.03))

        .cornerRadius(12)

    }

    //======================================

    // MARK: - Small helpers

    //======================================

    private func loadHeader(_ load: ConfirmedLoad) -> String {

        // Phase 4: hoist DateFormatter to static if this ever becomes hot.

        let df = DateFormatter()

        df.timeStyle = .short

        df.dateStyle = .none

        return "\(df.string(from: load.timestamp)) – \(load.terminalName) \(load.loadCode)"

    }

    private var formattedToday: String {

        // Phase 4: hoist DateFormatter to static if this ever becomes hot.

        let df = DateFormatter()

        df.dateStyle = .short

        df.timeStyle = .none

        return df.string(from: Date())

    }

}

  

private func formatLitres(_ litres: Double) -> String {

    String(format: "%.0f", litres)

}

  

private func formatKg(_ kg: Double) -> String {

    String(format: "%.0f", kg)

}
