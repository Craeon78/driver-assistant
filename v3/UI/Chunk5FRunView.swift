import SwiftUI

public struct Chunk5FRunView: View {
    @ObservedObject var store: Chunk5FPrototypeStore
    var subdued: Bool = false

    @State private var draftCustomer = ""
    @State private var draftSite = ""
    @State private var draftFillName = "Fill 1"
    @State private var draftProduct = "XLS"
    @State private var draftPlanned = 0
    @State private var showAddEditor = false

    @State private var addFillVisitIndex: Int? = nil
    @State private var extraFillName = "Fill 2"
    @State private var extraFillProduct = "XLS"
    @State private var extraFillPlanned = 0

    /// Edit an existing untouched visit (remaining plan only).
    @State private var editVisitIndex: Int? = nil
    @State private var editCustomer = ""
    @State private var editSite = ""

    /// Edit an existing uncompleted fill.
    @State private var editFillVisitIndex: Int? = nil
    @State private var editFillIndex: Int? = nil
    @State private var editFillName = ""
    @State private var editFillProduct = "XLS"
    @State private var editFillPlanned = 0
    @State private var editRunItemIndex: Int? = nil
    @State private var editRunItemTitle = ""

    public init(store: Chunk5FPrototypeStore, subdued: Bool = false) {
        self.store = store; self.subdued = subdued
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S RUN").font(.headline)
                Spacer()
                if store.canMutateRemainingPlan {
                    Text("EDITABLE REMAINING").font(.caption2).foregroundStyle(.secondary)
                } else if store.workspace == .active {
                    Text(store.canReorderRun ? "HOLD + DRAG TO REORDER" : "VIEW ONLY WHILE MOVING")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if store.canMutateRemainingPlan {
                HStack(spacing: 8) {
                    Button("ADD SITE") {
                        showAddEditor = true
                        editVisitIndex = nil
                        addFillVisitIndex = nil
                        editFillVisitIndex = nil
                    }
                    .buttonStyle(.bordered)
                    Button("ADD TERMINAL") { store.addTerminalLoad() }
                        .buttonStyle(.bordered)
                    Button("ADD REST") { store.addPlannedRest() }.buttonStyle(.bordered)
                    Button("ADD OTHER WORK") { store.addPlannedOtherWork() }.buttonStyle(.bordered)
                }
                .font(.caption)

                if showAddEditor { addSiteEditor }
                if let fi = addFillVisitIndex, store.visits.indices.contains(fi) { addFillEditor(visitIndex: fi) }
                if let vi = editVisitIndex, store.visits.indices.contains(vi) { editVisitEditor(visitIndex: vi) }
                if let vi = editFillVisitIndex, let fi = editFillIndex,
                   store.visits.indices.contains(vi),
                   store.visits[vi].fills.indices.contains(fi) {
                    editFillEditor(visitIndex: vi, fillIndex: fi)
                }
                if let index = editRunItemIndex, store.runItems.indices.contains(index) {
                    HStack {
                        TextField("Run item", text: $editRunItemTitle).textFieldStyle(.roundedBorder)
                        Button("SAVE") { store.updateRunItem(at: index, title: editRunItemTitle); editRunItemIndex = nil }.buttonStyle(.borderedProminent)
                        Button("CANCEL") { editRunItemIndex = nil }
                    }.font(.caption)
                }
            }

            List {
                ForEach(Array(store.runItems.enumerated()), id: \.element.id) { runIndex, item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.isSatisfied ? "✓" : (item.hasCommittedExecution ? "→" : icon(for: item.kind)))
                            Text(item.title).bold()
                            Spacer()
                            Text(item.requestedTime ?? "—")
                            if store.canMutateRemainingPlan && !item.hasCommittedExecution {
                                if item.kind != .siteVisit { Button { editRunItemIndex = runIndex; editRunItemTitle = item.title } label: { Image(systemName: "pencil").font(.caption) }.buttonStyle(.plain) }
                                Button(role: .destructive) { store.removeRunItem(at: runIndex) } label: { Image(systemName: "trash").font(.caption) }.buttonStyle(.plain)
                            }
                        }
                        if let visitIndex = store.visitIndex(for: item), store.visits.indices.contains(visitIndex) {
                            let visit = store.visits[visitIndex]
                            HStack {
                                Text("\(visit.plannedLitres.formatted()) L • \(visit.fills.count) fill\(visit.fills.count == 1 ? "" : "s")").font(.caption)
                                if store.canMutateRemainingPlan && !visit.fills.contains(where: { $0.completed }) {
                                    Button { editVisitIndex = visitIndex; editCustomer = visit.customer; editSite = visit.site; showAddEditor = false } label: { Image(systemName: "pencil").font(.caption) }.buttonStyle(.plain)
                                }
                            }
                            ForEach(Array(visit.fills.enumerated()), id: \.element.id) { fillIndex, fill in
                                HStack {
                                    Text("  \(fill.completed ? "✓" : "•") \(fill.name)  \(fill.plannedLitres.formatted()) L \(fill.product)").font(.caption2)
                                    if store.canMutateRemainingPlan && !visit.fills.contains(where: { $0.completed }) {
                                        Button { editFillVisitIndex = visitIndex; editFillIndex = fillIndex; editFillName = fill.name; editFillProduct = fill.product; editFillPlanned = fill.plannedLitres; showAddEditor = false } label: { Image(systemName: "pencil").font(.caption2) }.buttonStyle(.plain)
                                        if visit.fills.count > 1 { Button(role: .destructive) { store.removeFill(visitIndex: visitIndex, fillIndex: fillIndex) } label: { Image(systemName: "minus.circle").font(.caption2) }.buttonStyle(.plain) }
                                    }
                                }
                            }
                            if store.canMutateRemainingPlan && !visit.fills.contains(where: { $0.completed }) {
                                Button("ADD FILL") { addFillVisitIndex = visitIndex; showAddEditor = false }.font(.caption2).buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard store.workspace == .active,
                              store.canOpenOperationalWorkspace,
                              !item.isSatisfied else { return }
                        store.openRunItem(at: runIndex)
                    }
                }
                .onMove { source, destination in
                    store.moveRunItem(from: source, to: destination)
                }
                .moveDisabled(!store.canReorderRun || store.workspace == .rest)
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(store.canReorderRun && (store.workspace == .active || store.workspace == .preShift) ? .active : .inactive))
        }
        .opacity(subdued ? 0.48 : 1)
    }

    private func icon(for kind: Chunk5FRunItemKind) -> String {
        switch kind { case .siteVisit: return "○"; case .terminalLoad: return "T"; case .plannedRest: return "R"; case .plannedOtherWork: return "W" }
    }

    // MARK: - Editors

    private var addSiteEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New site (edit before insert)").font(.caption.bold())
            TextField("Customer", text: $draftCustomer).textFieldStyle(.roundedBorder)
            TextField("Site", text: $draftSite).textFieldStyle(.roundedBorder)
            TextField("Fill name", text: $draftFillName).textFieldStyle(.roundedBorder)
            HStack {
                Picker("Product", selection: $draftProduct) {
                    ForEach(Chunk5FPrototypeStore.availableProducts, id: \.self) { Text($0).tag($0) }
                }
                TextField("Planned L", value: $draftPlanned, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
            }
            HStack {
                Button("CANCEL") { showAddEditor = false }
                Spacer()
                Button("INSERT INTO RUN") {
                    store.addSiteVisit(
                        customer: draftCustomer.trimmingCharacters(in: .whitespacesAndNewlines),
                        site: draftSite.trimmingCharacters(in: .whitespacesAndNewlines),
                        fillName: draftFillName.isEmpty ? "Fill 1" : draftFillName,
                        product: draftProduct,
                        plannedLitres: max(0, draftPlanned)
                    )
                    draftCustomer = ""; draftSite = ""; draftFillName = "Fill 1"
                    draftProduct = "XLS"; draftPlanned = 0
                    showAddEditor = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftCustomer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || draftSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func addFillEditor(visitIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add fill to \(store.visits[visitIndex].customer) — \(store.visits[visitIndex].site)")
                .font(.caption.bold())
            TextField("Fill name", text: $extraFillName).textFieldStyle(.roundedBorder)
            HStack {
                Picker("Product", selection: $extraFillProduct) {
                    ForEach(Chunk5FPrototypeStore.availableProducts, id: \.self) { Text($0).tag($0) }
                }
                TextField("Planned L", value: $extraFillPlanned, format: .number)
                    .textFieldStyle(.roundedBorder).keyboardType(.numberPad).frame(width: 100)
            }
            HStack {
                Button("CANCEL") { addFillVisitIndex = nil }
                Spacer()
                Button("INSERT FILL") {
                    store.addFill(
                        toVisitIndex: visitIndex,
                        name: extraFillName.isEmpty ? "Extra Fill" : extraFillName,
                        product: extraFillProduct,
                        plannedLitres: max(0, extraFillPlanned)
                    )
                    extraFillName = "Fill 2"; extraFillProduct = "XLS"; extraFillPlanned = 0
                    addFillVisitIndex = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func editVisitEditor(visitIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Edit planned site (remaining only)").font(.caption.bold())
            TextField("Customer", text: $editCustomer).textFieldStyle(.roundedBorder)
            TextField("Site", text: $editSite).textFieldStyle(.roundedBorder)
            HStack {
                Button("CANCEL") { editVisitIndex = nil }
                Spacer()
                Button("SAVE SITE") {
                    store.updateVisit(
                        at: visitIndex,
                        customer: editCustomer.trimmingCharacters(in: .whitespacesAndNewlines),
                        site: editSite.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    editVisitIndex = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(editCustomer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || editSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func editFillEditor(visitIndex: Int, fillIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Edit planned fill (uncompleted only)").font(.caption.bold())
            TextField("Fill name", text: $editFillName).textFieldStyle(.roundedBorder)
            HStack {
                Picker("Product", selection: $editFillProduct) {
                    ForEach(Chunk5FPrototypeStore.availableProducts, id: \.self) { Text($0).tag($0) }
                }
                TextField("Planned L", value: $editFillPlanned, format: .number)
                    .textFieldStyle(.roundedBorder).keyboardType(.numberPad).frame(width: 100)
            }
            HStack {
                Button("CANCEL") { editFillVisitIndex = nil; editFillIndex = nil }
                Spacer()
                Button("SAVE FILL") {
                    store.updateFill(
                        visitIndex: visitIndex,
                        fillIndex: fillIndex,
                        name: editFillName.isEmpty ? "Fill" : editFillName,
                        product: editFillProduct,
                        plannedLitres: max(0, editFillPlanned)
                    )
                    editFillVisitIndex = nil
                    editFillIndex = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}
