
import SwiftUI

  

//======================================

// MARK: - Odometer + Location Capture Sheet

//======================================

//

// Purpose:

// - Single unified sheet for odometer + suburb/location capture

// - Replaces legacy BreakOdometerSheet (deleted)

//

// Contexts (driven by model.odoPromptContext):

// - .shiftStart: mandatory odo + suburb

// - .legalBreakEnd: mandatory odo + suburb

// - .shiftEnd: mandatory odo + suburb

// - .odoUpdate: mandatory odo, suburb optional

//

// Features:

// - GPS suburb suggestion (via SuburbSuggestionManager)

// - Tap suggested suburb to apply

// - Manual refresh button

// - Numeric-only odo validation

// - Auto-focus odo field on appear

// - Next/Done keyboard toolbar (numberPad safe)

// - Auto-jump to suburb after odo entered (1.4s delay)

//

//======================================

  

struct OdoLocationSheet: View {

    @EnvironmentObject var model: AppModel

    @StateObject private var suburbSuggester = SuburbSuggestionManager()

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case odo, suburb }

    private var ctx: OdoPromptContext? { model.odoPromptContext }

    private var isLocationRequired: Bool { ctx != .odoUpdate }

    @State private var odoJumpTask: Task<Void, Never>?

    private var title: String {

        switch ctx {

        case .shiftStart:     return "Start shift – Odo & Suburb"

        case .legalBreakEnd:  return "Break end – Odo & Suburb"

        case .shiftEnd:       return "End shift – Odo & Suburb"

        case .odoUpdate:      return "Update odo – Odo & Location"

        case nil:             return "Odo & Suburb"

        }

    }

    private var odoTrimmed: String {

        model.odoPromptOdoText.trimmingCharacters(in: .whitespacesAndNewlines)

    }

    private var odoIsNumeric: Bool {

        !odoTrimmed.isEmpty && odoTrimmed.allSatisfy { $0.isNumber }

    }

    private var suburbTrimmed: String {

        model.odoPromptSuburbText.trimmingCharacters(in: .whitespacesAndNewlines)

    }

    private var canSave: Bool {

        guard odoIsNumeric else { return false }

        return isLocationRequired ? !suburbTrimmed.isEmpty : true

    }

    private var locationHeaderText: String {

        isLocationRequired ? "Location" : "Location (optional)"

    }

    private var locationPlaceholder: String {

        isLocationRequired ? "Suburb" : "Suburb (optional)"

    }

    var body: some View {

        NavigationView {

            Form {

                Section(header: Text("Odometer")) {

                    TextField("Odo (km)", text: $model.odoPromptOdoText)

                        .keyboardType(.numberPad)

                        .textInputAutocapitalization(.never)

                        .autocorrectionDisabled()

                        .focused($focusedField, equals: .odo)

                        .foregroundStyle((!odoTrimmed.isEmpty && !odoIsNumeric) ? .red : .primary)

                    if let suggested = model.suggestedOdoFromGps {

                        let entered = Int(odoTrimmed)

                        let diff: Int? = entered.map { $0 - suggested }

                        HStack {

                            Text("Suggested:")

                                .foregroundStyle(.secondary)

                            Text("\(suggested)")

                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {

                                model.odoPromptOdoText = "\(suggested)"

                                focusedField = isLocationRequired ? .suburb : nil

                            } label: {

                                Label("Apply", systemImage: "arrow.down.circle")

                                    .labelStyle(.titleAndIcon)

                                    .foregroundStyle(.secondary)

                            }

                            .buttonStyle(.borderless)

                        }

                        if let diff {

                            Text("Difference: \(diff >= 0 ? "+" : "")\(diff) km")

                                .font(.caption2)

                                .foregroundStyle(.secondary)

                        }

                    }

                    if !odoTrimmed.isEmpty && !odoIsNumeric {

                        Text("Odometer must be numbers only.")

                            .font(.caption)

                            .foregroundStyle(.red)

                    }

                }

                Section(header: Text(locationHeaderText)) {

                    // Suggested suburb (grey), tap-to-apply

                    if let suggestion = suburbSuggester.suggestedSuburb, !suggestion.isEmpty {

                        HStack {

                            Text("Suggested:")

                                .foregroundStyle(.secondary)

                            Text(suggestion)

                                .foregroundStyle(.secondary)

                            Spacer()

                            Image(systemName: "arrow.down.circle")

                                .foregroundStyle(.secondary)

                        }

                        .contentShape(Rectangle())

                        .onTapGesture {

                            model.odoPromptSuburbText = suggestion

                            focusedField = nil

                        }

                    } else if suburbSuggester.isFetching {

                        HStack {

                            ProgressView()

                            Text("Finding suburb…")

                                .foregroundStyle(.secondary)

                        }

                    } else if isLocationRequired {

                        Text("No GPS suburb suggestion available.")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                    TextField(locationPlaceholder, text: $model.odoPromptSuburbText)

                        .textInputAutocapitalization(.words)

                        .autocorrectionDisabled()

                        .focused($focusedField, equals: .suburb)

                    Button {

                        suburbSuggester.refresh()

                    } label: {

                        Label("Refresh GPS suggestion", systemImage: "location.circle")

                            .foregroundStyle(.secondary)

                    }

                    .buttonStyle(.borderless)

                }

            }

            .navigationTitle(title)

            .toolbar {

                ToolbarItem(placement: .confirmationAction) {

                    Button("Save") { model.commitOdoCapture() }

                        .disabled(!canSave)

                }

                // ✅ Keyboard accessory: works even with .numberPad (no Return key)

                ToolbarItemGroup(placement: .keyboard) {

                    Spacer()

                    if focusedField == .odo {

                        Button("Next") {

                            focusedField = isLocationRequired ? .suburb : nil

                        }

                        .disabled(!odoIsNumeric)

                    } else {

                        Button("Done") {

                            focusedField = nil

                        }

                    }

                }

            }

        }

        .presentationDetents([.medium])

        .presentationDragIndicator(.visible)

        .interactiveDismissDisabled(true)

        .scrollDismissesKeyboard(.interactively)

        .onAppear {

            // ✅ reliable focus after sheet animation

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {

                focusedField = .odo

            }

            suburbSuggester.refresh()

        }

        .onChange(of: model.odoPromptOdoText) { _, _ in

            guard isLocationRequired else { return }

            guard odoIsNumeric else { return }

            guard focusedField == .odo else { return }

            odoJumpTask?.cancel()

            odoJumpTask = Task {

                try? await Task.sleep(nanoseconds: 1_400_000_000) // 1.4s pause

                if !Task.isCancelled {

                    focusedField = .suburb

                }

            }

        }

    }

}
