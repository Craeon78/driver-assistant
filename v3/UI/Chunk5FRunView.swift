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
                if store.workspace == .active {
                    Text(store.canReorderRun ? "HOLD + DRAG TO REORDER" : "VIEW ONLY WHILE MOVING")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            List {
                ForEach(Array(store.visits.enumerated()), id: \.element.id) { index, visit in
                    Button {
                        if store.workspace != .rest && store.canOpenOperationalWorkspace && !visit.isComplete {
                            store.openSite(index)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(visit.isComplete ? "✓" : "○")
                                Text("\(visit.customer) — \(visit.site)").bold()
                                Spacer()
                                Text(visit.requestedTime ?? visit.projectedTime)
                            }
                            Text("\(visit.plannedLitres.formatted()) L • \(visit.fills.count) fill\(visit.fills.count == 1 ? "" : "s")")
                                .font(.caption)
                            ForEach(visit.fills) { fill in
                                Text("  \(fill.completed ? "✓" : "•") \(fill.name)  \(fill.plannedLitres.formatted()) L \(fill.product)")
                                    .font(.caption2)
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.workspace == .rest || !store.canOpenOperationalWorkspace || visit.isComplete)
                }
                .onMove { source, destination in
                    store.moveVisit(from: source, to: destination)
                }
                .moveDisabled(!store.canReorderRun || store.workspace == .rest)
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(store.canReorderRun && store.workspace == .active ? .active : .inactive))
        }
        .opacity(subdued ? 0.48 : 1)
    }
}
