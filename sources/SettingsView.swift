
import SwiftUI

  

//======================================

// MARK: - Settings (Phase 1)

//======================================

//

// Purpose (v0.2):

// - Single place to edit driver identity + truck label used on Today/Load.

// - Capture NHVR “base” info (name/address + radius) used by the Map tab.

// - Provide an About/Patch Log entry point.

//

// Notes:

// - Settings are currently bound directly to `model.settings`.

//   Pre-persistence this is fine; post-persistence we’ll likely:

//   - load/save `DriverSettings` to disk (SwiftData/CoreData/UserDefaults)

//   - possibly add “Apply/Cancel” behaviour if we want to avoid live edits.

//

// Safety/Scope:

// - The NHVR base radius is an informational planning aid (100 km zone context),

//   not an enforcement/policing feature. Any future warnings should be framed

//   as reminders / situational awareness, not legal adjudication.

//

// Future (post-persistence):

// - Default week definition (Mon–Sun vs Sun–Sat) and day-boundary settings

// - Rule set selector (Standard / BFM / AFM / Two-up) + company policy toggles

// - Saved terminals/customers/break spots + pin persistence

// - Theme selection (navy / grey / leather + logbook yellow sheets)

//======================================

  

struct SettingsView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    @Environment(\.dismiss) private var dismiss

    @State private var showingAbout = false

    @State private var showingDebugDashboard = false

    var body: some View {

        NavigationStack {

            Form {

                //==================================

                // MARK: Driver

                //==================================

                Section(header: Text("Driver")) {

                    TextField("Driver name", text: $model.driverProfile.driverName)

                    DisclosureGroup("Licence & hours") {

                        Picker("Licence", selection: $model.driverProfile.licenceType) {

                            ForEach(DriverProfilePayloadV1.LicenceType.allCases, id: \.self) { t in

                                Text(t.rawValue).tag(t)

                            }

                        }

                        Picker("Hours mode", selection: $model.driverProfile.licenceHoursMode) {

                            ForEach(DriverProfilePayloadV1.LicenceHoursMode.allCases, id: \.self) { m in

                                Text(m.rawValue).tag(m)

                            }

                        }

                        Picker("Crew", selection: $model.driverProfile.crewMode) {

                            ForEach(DriverProfilePayloadV1.CrewMode.allCases, id: \.self) { c in

                                Text(c.rawValue).tag(c)

                            }

                        }

                        Toggle("Owner-driver", isOn: $model.driverProfile.isOwnerDriver)

                    }

                }

                // Mark:- Truck (phase 1)

                Section(header: Text("Truck")) {

                    TextField("Selected truck (temporary)", text: $model.selectedTruckLabel)

                        .textInputAutocapitalization(.characters)

                    Text("Later this becomes a Truck Profile picker (linked by ID).")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

                //==================================

                // MARK: NHVR base (100 km rule)

                //==================================

                Section(header: Text("NHVR base (100 km rule)")) {

                    TextField("Base name (e.g. BP 6750 depot)",

                              text: $model.settingsProfile.nhvrBaseName)

                    TextField("Base address or description",

                              text: $model.settingsProfile.nhvrBaseAddress)

                    HStack {

                        Text("Radius (km)")

                        Spacer()

                        TextField("100",

                                  value: $model.settingsProfile.nhvrRadiusKm,

                                  format: .number)

                        .keyboardType(.numberPad)

                        .multilineTextAlignment(.trailing)

                        Text("km")

                            .foregroundColor(.secondary)

                    }

                    Text("Later on, this radius will help warn when you're leaving the 100 km zone and should be running a logbook.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .fixedSize(horizontal: false, vertical: true)

                }

                //==================================

                // MARK: Future (placeholder)

                //==================================

                Section(header: Text("Coming later")) {

                    Text("• Saved terminals, customers and break spots\n• Preference for fatigue rule set (Standard / BFM / AFM / Two-up)\n• Theme (navy / grey / leather)")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .fixedSize(horizontal: false, vertical: true)

                }

                //==================================

                // MARK: Debug Dashboard (dev only)

                //==================================

                if DebugFlags.debugMenu {

                    Section(header: Text("🔧 Developer Tools")) {

                        Button {

                            showingDebugDashboard = true

                        } label: {

                            HStack {

                                Label("Debug Dashboard", systemImage: "hammer.fill")

                                Spacer()

                                Image(systemName: "chevron.right")

                                    .foregroundColor(.secondary)

                                    .font(.caption)

                            }

                        }

                        Text("Comprehensive state inspector, edge case triggers, and diagnostic tools.")

                            .font(.caption)

                            .foregroundColor(.secondary)

                            .fixedSize(horizontal: false, vertical: true)

                    }

                }

                //==================================

                // MARK: About / Patch log

                //==================================

                Section {

                    Button {

                        showingAbout = true

                    } label: {

                        HStack {

                            Text("About")

                            Spacer()

                            Text("v\(AppBuildInfo.shared.version) • \(AppBuildInfo.shared.buildDatePretty)")

                                .foregroundColor(.secondary)

                        }

                        .font(.footnote)

                    }

                }

            }

            .navigationTitle("Settings")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") { dismiss() }

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Save") { 

                        model.saveProfilesToJSON()

                        dismiss()}

                }

            }

            .sheet(isPresented: $showingAbout) {

                AboutView()

            }

            .sheet(isPresented: $showingDebugDashboard) {

                DebugDashboardView()

                    .environmentObject(model)

                    .environmentObject(locationManager)

            }

        }

    }

}
