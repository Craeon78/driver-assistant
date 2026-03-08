
import SwiftUI

  

//======================================

// MARK: - Other Activity Sheet (Phase 1)

//======================================

//

// Purpose (pre-persistence):

// - Fast, driver-friendly way to log “non-standard” activities

//   that don’t deserve a dedicated button (e.g. paperwork, delays).

// - Allow ad-hoc creation AND immediate use in a single flow.

// - Optional note captured at start time (not retroactive editing).

//

// Design decisions (intentional):

// - Activities are lightweight labels, not fully-managed entities.

// - Creation + usage are combined to minimise taps while on duty.

// - Activities live in-memory on AppModel until persistence exists.

//

// Planned evolution (post-persistence):

// - Activities become editable entities (rename, reorder, archive, delete).

// - Notes may become time-ranged or editable after the fact.

// - “Other activity” may merge with a general activity editor.

// - Fleet / driver defaults may seed common activities.

//

// This sheet is intentionally *not* a full CRUD editor yet.

// Speed and safety take priority over completeness in Phase 1.

//======================================

  

struct OtherActivitySheet: View {

    @EnvironmentObject var model: AppModel

    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""

    @State private var isWork: Bool = true

    @State private var optionalNote: String = ""

    private var optionalNoteClean: String? {

        let t = optionalNote.trimmingCharacters(in: .whitespacesAndNewlines)

        return t.isEmpty ? nil : t

    }

    var body: some View {

        NavigationStack {

            VStack(spacing: 3) {

                // TOP: fixed, non-scrolling inputs

                Form {

                    Section(header: Text("Optional note")) {

                        TextField("e.g. gate delay / paperwork / spill kit", text: $optionalNote)

                    }

                    Section(header: Text("Add new activity")) {

                        TextField("Label (e.g. \"Paperwork\")", text: $newName)

                        Toggle("Counts as work (on duty)", isOn: $isWork)

                        Button("Add and use") { addAndUseActivity() }

                            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    }

                }

                .scrollDisabled(true)          // KEY: stops the form stealing scroll

                .frame(height: 260)            // tweak if you want (240–300)

                Divider()

                    .padding(.top, 6)

                    .padding(.vertical, 8)

                // BOTTOM: the only scrolling region

                if model.otherActivities.isEmpty {

                    Text("No saved activities yet.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .padding()

                    Spacer()

                } else {

                    List {

                        ForEach(model.otherActivities) { activity in

                            Button {

                                model.startOtherActivity(activity, note: optionalNoteClean)

                                dismiss()

                            } label: {

                                HStack {

                                    Text(activity.name)

                                    Spacer()

                                    Text(activity.isWork ? "Work" : "Rest")

                                        .font(.caption)

                                        .foregroundColor(.secondary)

                                }

                            }

                        }

                    }

                    .listStyle(.plain)

                }

            }

            .navigationTitle("Other activity")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") { dismiss() }

                }

            }

        }

    }

    private func addAndUseActivity() {

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }

        if let existing = model.otherActivities.first(where: {

            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame && $0.isWork == isWork

        }) {

            model.startOtherActivity(existing, note: optionalNoteClean)

            dismiss()

            return

        }

        let activity = OtherActivity(id: UUID(), name: trimmed, isWork: isWork)

        model.otherActivities.append(activity)

        model.startOtherActivity(activity, note: optionalNoteClean)

        dismiss()

    }

    }
