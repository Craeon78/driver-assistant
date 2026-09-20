import SwiftUI

public struct Chunk5FTruckCargoView: View {
    @ObservedObject var store: Chunk5FPrototypeStore
    let mode: Chunk5FWorkspaceState

    public init(store: Chunk5FPrototypeStore, mode: Chunk5FWorkspaceState) {
        self.store = store; self.mode = mode
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(store.compartments.enumerated()), id: \.element.id) { index, compartment in
                VStack(spacing: 6) {
                    Text("C\(compartment.id)").font(.headline)
                    GeometryReader { proxy in
                        let fraction = CGFloat(store.draftLitres[index]) / CGFloat(max(1, compartment.capacityLitres))
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(mode == .load ? Color.orange.opacity(0.55) : Color.blue.opacity(0.45))
                                .frame(height: proxy.size.height * fraction)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let rawFraction = 1 - min(max(value.location.y / max(1, proxy.size.height), 0), 1)
                                    let raw = Int((rawFraction * CGFloat(compartment.capacityLitres) / 50).rounded() * 50)
                                    let value = mode == .site ? store.snapDelivery(compartment: index, proposed: raw) : raw
                                    store.setDraft(compartment: index, litres: value)
                                }
                        )
                    }
                    .frame(height: 155)
                    Text(compartment.product).font(.caption)
                    TextField("L", value: Binding(
                        get: { store.draftLitres[index] },
                        set: { store.setDraft(compartment: index, litres: $0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    Text("of \(compartment.capacityLitres) L").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
