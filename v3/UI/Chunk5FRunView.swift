import SwiftUI

public struct Chunk5FRunView: View {
    @ObservedObject var store: Chunk5FPrototypeStore
    var subdued: Bool = false

    public init(store: Chunk5FPrototypeStore, subdued: Bool = false) {
        self.store = store; self.subdued = subdued
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S RUN").font(.headline)
            ForEach(Array(store.visits.enumerated()), id: \.element.id) { index, visit in
                Button {
                    if store.workspace != .rest { store.openSite(index) }
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
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(subdued ? 0.48 : 1)
    }
}
