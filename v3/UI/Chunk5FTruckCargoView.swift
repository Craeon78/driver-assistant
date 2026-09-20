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
                CompartmentColumn(
                    index: index,
                    compartment: compartment,
                    store: store,
                    mode: mode
                )
            }
        }
    }
}

// Separate view so each compartment can hold its own drag state without shaking neighbours.
private struct CompartmentColumn: View {
    let index: Int
    let compartment: Chunk5FCompartment
    @ObservedObject var store: Chunk5FPrototypeStore
    let mode: Chunk5FWorkspaceState

    // Local drag state prevents the whole HStack from re-rendering on every pixel of drag.
    @State private var isDragging = false
    @State private var latchedValue: Int? = nil

    var body: some View {
        VStack(spacing: 6) {
            Text("C\(compartment.id)").font(.headline)
            GeometryReader { proxy in
                let displayLitres = isDragging ? (latchedValue ?? store.draftLitres[index]) : store.draftLitres[index]
                let fraction = CGFloat(displayLitres) / CGFloat(max(1, compartment.capacityLitres))
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
                            isDragging = true
                            let rawFraction = 1 - min(max(value.location.y / max(1, proxy.size.height), 0), 1)
                            let stepped = Int((rawFraction * CGFloat(compartment.capacityLitres) / 50).rounded() * 50)
                            let proposed = mode == .site
                                ? store.snapDelivery(compartment: index, proposed: stepped)
                                : stepped
                            // Hysteresis: once latched near a snap target, stay latched until drag moves > 80 L away.
                            if let latched = latchedValue, mode == .site {
                                if abs(proposed - latched) < 80 {
                                    return // stay latched — prevents shake
                                }
                            }
                            latchedValue = proposed
                            store.setDraft(compartment: index, litres: proposed)
                        }
                        .onEnded { _ in
                            isDragging = false
                            if let final = latchedValue {
                                store.setDraft(compartment: index, litres: final)
                            }
                            latchedValue = nil
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
