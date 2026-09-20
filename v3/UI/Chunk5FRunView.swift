import SwiftUI

public struct Chunk5FRunView: View {
    @ObservedObject var store: Chunk5FPrototypeStore
    var subdued: Bool = false

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

            // ADD WORK controls (pre-shift or stationary remaining-plan)
            if store.canMutateRemainingPlan {
                HStack(spacing: 8) {
                    Button("ADD SITE") {
                        store.addSiteVisit(customer: "NEW CUSTOMER", site: "NEW SITE")
                    }
                    .buttonStyle(.bordered)
                    Button("ADD TERMINAL") {
                        store.addTerminalLoad()
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)
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
                                    Image(systemName: "trash")
                                        .font(.caption)
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
                                            Image(systemName: "minus.circle")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            if store.canMutateRemainingPlan && !visit.isComplete {
                                Button("ADD FILL") {
                                    store.addFill(toVisitIndex: index)
                                }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if store.workspace != .rest && store.canOpenOperationalWorkspace && !visit.isComplete && !visit.isTerminalLoad {
                            store.openSite(index)
                        } else if visit.isTerminalLoad && store.canOpenOperationalWorkspace {
                            store.openLoad()
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
