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
                    Button("ADD SITE") { showAddEditor = true }
                        .buttonStyle(.bordered)
                    Button("ADD TERMINAL") { store.addTerminalLoad() }
                        .buttonStyle(.bordered)
                }
                .font(.caption)

                if showAddEditor {
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
            }

            List {
                ForEach(Array(store.visits.enumerated()), id: \.element.id) { index, visit in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(visit.isComplete ? "✓" : (visit.isTerminalLoad ? "T" : "○"))
                            Text(visit.isTerminalLoad ? "TERMINAL / LOAD" : "\(visit.customer) — \(visit.site)")
                                .bold()
                            Spacer()
                            Text(visit.requestedTime ?? visit.projectedTime)
                            if store.canMutateRemainingPlan && !visit.isComplete && !visit.fills.contains(where: { $0.completed }) {
                                Button(role: .destructive) {
                                    store.removeVisit(at: index)
                                } label: {
                                    Image(systemName: "trash").font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !visit.isTerminalLoad {
                            Text("\(visit.plannedLitres.formatted()) L • \(visit.fills.count) fill\(visit.fills.count == 1 ? "" : "s")")
                                .font(.caption)
                            ForEach(Array(visit.fills.enumerated()), id: \.element.id) { fillIndex, fill in
                                HStack {
                                    Text("  \(fill.completed ? "✓" : "•") \(fill.name)  \(fill.plannedLitres.formatted()) L \(fill.product)")
                                        .font(.caption2)
                                    Spacer()
                                    if store.canMutateRemainingPlan && !fill.completed && visit.fills.count > 1 {
                                        Button(role: .destructive) {
                                            store.removeFill(visitIndex: index, fillIndex: fillIndex)
                                        } label: {
                                            Image(systemName: "minus.circle").font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Only open operational workspace from Active when stationary — not from pre-shift planning.
                        guard store.workspace == .active,
                              store.canOpenOperationalWorkspace,
                              !visit.isComplete else { return }
                        if visit.isTerminalLoad {
                            store.openLoad()
                        } else {
                            store.openSite(index)
                        }
                    }
                }
                .onMove { source, destination in
                    store.moveVisit(from: source, to: destination)
                }
                .moveDisabled(!store.canReorderRun || store.workspace == .rest)
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(store.canReorderRun && (store.workspace == .active || store.workspace == .preShift) ? .active : .inactive))
        }
        .opacity(subdued ? 0.48 : 1)
    }
}
