
import SwiftUI

  

//======================================

// MARK: - INCIDENT SHEET (PRE-PERSISTENCE)

//======================================

//

// Purpose:

// - Calm triage UI + computed action plan.

// - Uses IncidentAdviceEngine (pure logic) + DriverSettings.

//

// Phase 1 scope:

// - No persistence.

// - “Save” logs a simple timeline event for now.

//

//======================================

  

struct IncidentSheet: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        NavigationStack {

            Group {

                if model.incidentDraft == nil {

                    emptyState

                } else {

                    content

                }

            }

            .navigationTitle("Incident")

            .toolbar {

                ToolbarItem(placement: .topBarLeading) {

                    Button("Close") { close() }

                }

                ToolbarItem(placement: .topBarTrailing) {

                    Button("Save") { saveAndClose() }

                        .disabled(model.incidentDraft == nil)

                }

            }

        }

        .onAppear {

            if model.incidentDraft == nil {

                model.beginIncidentDraft()

            }

            model.recomputeIncidentAdvice()

        }

        .onChange(of: model.incidentDraft?.id) { _, _ in

            model.recomputeIncidentAdvice()

        }

        .onDisappear {

            DebugLog.ui("DISAPPEAR: clearing draft/plan")

            model.incidentDraft = nil

            model.lastIncidentAdvicePlan = nil

        }

    }

    private var emptyState: some View {

        ContentUnavailableView("Preparing incident…", systemImage: "exclamationmark.triangle")

    }

    private var content: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 14) {

                // Context snapshot

                contextCard

                // Triage

                triageCard

                // Evidence

                evidenceCard

                // Action plan (computed)

                planCard

                Spacer(minLength: 18)

            }

            .padding()

        }

    }

    private var contextCard: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Context").font(.headline)

            if let r = model.incidentDraft {

                HStack {

                    Text("Time")

                    Spacer()

                    Text(r.timestamp.formatted(date: .abbreviated, time: .shortened))

                        .foregroundStyle(.secondary)

                }

                HStack {

                    Text("Suburb")

                    Spacer()

                    Text((r.suburb?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? r.suburb! : "—")

                        .foregroundStyle(.secondary)

                }

                HStack {

                    Text("GPS")

                    Spacer()

                    if let lat = r.latitude, let lon = r.longitude {

                        Text("\(lat, specifier: "%.5f"), \(lon, specifier: "%.5f")")

                            .foregroundStyle(.secondary)

                    } else {

                        Text("—").foregroundStyle(.secondary)

                    }

                }

            }

        }

        .padding()

        .background(Color(.secondarySystemGroupedBackground))

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private var triageCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Triage").font(.headline)

            if model.incidentDraft != nil {

                let r = Binding<IncidentReport>(

                    get: { model.incidentDraft! },

                    set: { model.incidentDraft = $0 }

                )

                Picker("Type", selection: r.type) {

                    ForEach(IncidentType.allCases, id: \.self) { t in

                        Text(t.rawValue.capitalized).tag(t)

                    }

                }

                Picker("Severity", selection: r.severity) {

                    Text("Info only").tag(IncidentSeverity.informationOnly)

                    Text("Minor").tag(IncidentSeverity.minor)

                    Text("Serious").tag(IncidentSeverity.serious)

                    Text("Emergency").tag(IncidentSeverity.emergency)

                }

                ternaryPicker("Safe stopped?", selection: r.isSafeStopped)

                ternaryPicker("Injuries?", selection: r.injuriesPresent)

                ternaryPicker("Fire or spill?", selection: r.fireOrSpill)

                // Only show hit & run when it makes sense

                if r.wrappedValue.type == .accident || r.wrappedValue.type == .nearMiss {

                    ternaryPicker("Hit & run?", selection: r.hitAndRun)

                }

            }

        }

        .padding()

        .background(Color(.secondarySystemGroupedBackground))

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private var evidenceCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Evidence").font(.headline)

            if model.incidentDraft != nil {

                let r = Binding<IncidentReport>(

                    get: { model.incidentDraft! },

                    set: { model.incidentDraft = $0 }

                )

                Stepper("Photos taken: \(r.wrappedValue.photosTakenCount)",

                        value: r.photosTakenCount,

                        in: 0...20)

                TextField("1 sentence note (optional)", text: Binding(

                    get: { r.wrappedValue.shortNote ?? "" },

                    set: { r.shortNote.wrappedValue = $0.isEmpty ? nil : $0 }

                ))

                .textFieldStyle(.roundedBorder)

                if model.settings.hasVehicleCamera {

                    Text("Dashcam: if safe, preserve footage / note the time.")

                        .font(.footnote)

                        .foregroundStyle(.secondary)

                }

            }

        }

        .padding()

        .background(Color(.secondarySystemGroupedBackground))

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private var planCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Action plan").font(.headline)

            if let plan = model.lastIncidentAdvicePlan {

                Text(plan.headline)

                    .foregroundStyle(.secondary)

                ForEach(plan.actions) { action in

                    HStack(alignment: .top, spacing: 10) {

                        Image(systemName: icon(for: action))

                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {

                            Text(title(for: action))

                                .font(.body)

                            if let sub = subtitle(for: action) {

                                Text(sub)

                                    .font(.footnote)

                                    .foregroundStyle(.secondary)

                            }

                        }

                        Spacer()

                    }

                    .padding(.vertical, 4)

                }

            } else {

                Text("No plan yet.")

                    .foregroundStyle(.secondary)

            }

        }

        .padding()

        .background(Color(.secondarySystemGroupedBackground))

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private func ternaryPicker(_ label: String, selection: Binding<TernaryAnswer>) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(label).font(.subheadline)

            Picker(label, selection: selection) {

                Text("Unknown").tag(TernaryAnswer.unknown)

                Text("Yes").tag(TernaryAnswer.yes)

                Text("No").tag(TernaryAnswer.no)

            }

            .pickerStyle(.segmented)

        }

    }

    private func close() {

        dismiss()

        model.isShowingIncidentSheet = false

        DispatchQueue.main.async {

            model.incidentDraft = nil

            model.lastIncidentAdvicePlan = nil

        }

    }

    private func saveAndClose() {

        DebugLog.persistence("SAVE: commit start, draft nil? \(model.incidentDraft == nil)")

        model.commitIncidentDraft()

        DebugLog.persistence("SAVE: commit done, closing sheet")

        model.isShowingIncidentSheet = false

    }

    private func icon(for action: IncidentAdviceAction) -> String {

        switch action {

        case .call000: return "phone.fill"

        case .callSpecialistAdvice: return "cross.case.fill"

        case .callSupervisor: return "person.crop.circle.badge.exclamationmark"

        case .callMechanic: return "wrench.and.screwdriver.fill"

        case .reportToPolicelink: return "building.columns.fill"

        case .takePhotos: return "camera.fill"

        case .writeShortNote: return "square.and.pencil"

        case .hydrateAndRest: return "cup.and.saucer.fill"

        }

    }

    private func title(for action: IncidentAdviceAction) -> String {

        switch action {

        case .call000:

            return "Call 000 (Emergency)"

        case .callSpecialistAdvice(_):

            return "Call specialist advice"

        case .callSupervisor(_):

            return "Call supervisor"

        case .callMechanic(_):

            return "Call mechanic"

        case .reportToPolicelink:

            return "Report via Policelink (non-urgent)"

        case .takePhotos(let count):

            return "Take \(count) photos"

        case .writeShortNote:

            return "Write 1 sentence note"

        case .hydrateAndRest:

            return "Drink water and take a breath"

        }

    }

    private func subtitle(for action: IncidentAdviceAction) -> String? {

        switch action {

        case .callSpecialistAdvice(let phone):

            return phone.isEmpty ? "Add number in Settings" : phone

        case .callSupervisor(let phone):

            return phone.isEmpty ? "Add number in Settings" : phone

        case .callMechanic(let phone):

            return phone.isEmpty ? "Add number in Settings" : phone

        case .reportToPolicelink:

            return model.settings.policelinkPhone

        default:

            return nil

        }

    }

}
