import SwiftUI

public struct Chunk5FAdaptiveWorkspaceView: View {
    @StateObject private var store: Chunk5FPrototypeStore

    public init(store: Chunk5FPrototypeStore = Chunk5FPrototypeStore()) {
        _store = StateObject(wrappedValue: store)
    }

    public var body: some View {
        VStack(spacing: 0) {
            instrumentBar
            Divider()
            Group {
                switch store.workspace {
                case .preShift: preShift
                case .active: active
                case .site: site
                case .load: load
                case .rest: rest
                }
            }
            .padding(12)
        }
    }

    private var instrumentBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
            VStack { Text("\(store.prototypeSpeedKmh)").font(.title2.bold()); Text("km/h").font(.caption2) }
            VStack(alignment: .leading) { Text("ODO 482,315"); Text("Cleveland").font(.caption) }
            Image(systemName: "location.north.circle").font(.title2)
            Spacer()
            VStack {
                Text(store.workspace == .rest ? "REST \(store.restMinutes) / 30m" : store.workspace == .preShift ? "READY TO START" : "NEXT REST 1h 42m")
                    .font(.headline)
                ProgressView(value: store.workspace == .rest ? Double(store.restMinutes) / 30.0 : 0.45)
            }.frame(maxWidth: 300)
            Spacer()
            VStack(alignment: .trailing) {
                Text(store.workspace == .rest ? "RESTING" : "NEXT: SEALINK")
                Text(store.workspace == .rest ? "Recovery first" : "Cleveland").font(.caption)
            }
            Image(systemName: "line.3.horizontal")
            Image(systemName: "gearshape")
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private var preShift: some View {
        HStack(alignment: .top, spacing: 14) {
            panel("DRIVER / TRUCK") {
                Text("DRIVER: MACOZZA").font(.title3.bold())
                Text("Truck 92 • selected")
                Divider()
                Text("Running tank: Full")
                Text("AdBlue: Full")
                Text("Planned cargo: 2,000 ULP • 38,500 DIE")
                Button("START SHIFT") { store.startShift() }.buttonStyle(.borderedProminent)
            }
            panel("TODAY") {
                Text("No current attention items")
                Spacer()
                Text("This month").font(.caption).foregroundStyle(.secondary)
                Text("Litres delivered  •  km driven")
            }
            Chunk5FRunView(store: store).frame(maxWidth: .infinity)
        }
    }

    private var active: some View {
        HStack(alignment: .top, spacing: 12) {
            panel("NEXT SITE") {
                Text("SEALINK").font(.title2.bold())
                Text("Cleveland")
                Text("05:00 requested • ETA 04:55")
                Text("14,000 L DIE • 2 fills")
                Button("Contact") { store.message = "Contact details would expand here." }
            }.frame(width: 230)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(.quaternary)
                VStack {
                    Image(systemName: "map").font(.system(size: 72))
                    Text("MAP — current position → Cleveland")
                    Text("Driving state: status, not analysis").font(.caption).foregroundStyle(.secondary)
                }
            }
            Chunk5FRunView(store: store).frame(width: 280)
        }
        .overlay(alignment: .bottom) {
            HStack {
                Button(store.prototypeSpeedKmh > 5 ? "SIMULATE STOP" : "SIMULATE DRIVING") { store.setPrototypeMoving(store.prototypeSpeedKmh <= 5) }
                Button("OPEN NEXT SITE") { store.openSite(0) }.disabled(store.prototypeSpeedKmh > 5)
                Button("TERMINAL / LOAD") { store.openLoad() }.disabled(store.prototypeSpeedKmh > 5)
                Button("START REST") { store.beginRest() }
            }.buttonStyle(.bordered).padding(8).background(.thinMaterial, in: Capsule())
        }
    }

    private var site: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                panel("SITE") {
                    Text("Mini Map • Cleveland")
                    Text("Site context only — presence does not prove service.")
                }
                panel("CURRENT FILL") {
                    Text(store.currentVisit.map { "\($0.customer) — \($0.site)" } ?? "—").bold()
                    Text(store.currentFill?.name ?? "—").font(.title2)
                    Text("\(store.currentFill?.plannedLitres.formatted() ?? "0") L \(store.currentFill?.product ?? "") planned")
                    Button("Contact") { store.message = "Contact details would expand here." }
                }
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("TRUCK — proposed remaining quantities").font(.headline)
                    Chunk5FTruckCargoView(store: store, mode: .site)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.currentFill?.name.uppercased() ?? "RECEIVING").font(.headline)
                    RoundedRectangle(cornerRadius: 12).fill(.quaternary).frame(height: 150)
                        .overlay(Text("VISUAL FILL ONLY\nNOT LEVEL EVIDENCE").multilineTextAlignment(.center))
                    Text("+\(store.deliveryMovement.formatted()) L \(store.currentFill?.product ?? "")").font(.title2.bold())
                    Text("Planned \(store.plannedDelivery.formatted()) L")
                    if store.deliveryDifference != 0 {
                        Text("Difference \(store.deliveryDifference > 0 ? "+" : "")\(store.deliveryDifference) L")
                    }
                    Text("DRAG → CONTEXT SNAP → PRECISION → CONFIRM").font(.caption).foregroundStyle(.secondary)
                }.frame(width: 260)
            }
            HStack {
                Button("UNDO") { store.undoDraft() }.buttonStyle(.bordered)
                Spacer()
                Button("CONFIRM \(store.deliveryMovement.formatted()) L DELIVERY") { store.commitDelivery() }
                    .buttonStyle(.borderedProminent).disabled(store.deliveryMovement == 0)
            }
        }
    }

    private var load: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                panel("TERMINAL") { Text("Mini Map"); Text("Safe stopped capture outside terminal") }
                panel("DRIVER LOAD PLAN") {
                    Text("Mini physical-sheet representation")
                    Text("DA → driver → terminal process").font(.caption).foregroundStyle(.secondary)
                }
                panel("PAPERWORK") {
                    Text("BOL likeness • EIP status")
                    Text("DA representation — not official document").font(.caption)
                    Button("SHOW DETAILS") { store.message = "Structured BOL/EIP likeness expands here." }
                }
            }
            Text("PROPOSED TRUCK CARGO").font(.headline)
            Chunk5FTruckCargoView(store: store, mode: .load)
            if !store.message.isEmpty { Text(store.message).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("SCAN BOL (SIMULATED)") { store.simulateBOLScan() }.buttonStyle(.bordered)
                Button("UNDO") { store.undoDraft() }.buttonStyle(.bordered)
                Spacer()
                Text("SCAN + DRAG + TYPE = ONE LOAD DRAFT").font(.caption)
                Spacer()
                Button("CONFIRM LOAD") { store.commitLoad() }.buttonStyle(.borderedProminent)
            }
        }
    }

    private var rest: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 12) {
                panel("MINI MAP") { Text("Current location"); Text("Work context available on request").font(.caption) }
                panel("SHIFT SO FAR") {
                    Text("1 site • 2 deliveries")
                    Text("14,000 L delivered")
                    Text("Distance and terminal loads would project here.")
                }
            }.frame(maxWidth: .infinity)
            panel("FATIGUE") {
                Text("CURRENT REST").font(.headline)
                Text("\(store.restMinutes) / 30 min").font(.system(size: 42, weight: .bold))
                ProgressView(value: Double(store.restMinutes), total: 30)
                Text("\(max(0, 30 - store.restMinutes)) min remaining")
                Divider()
                Text("Started shift 03:42")
                Text("Work elapsed 3h 16m")
                Text("Estimated finish 13:10").foregroundStyle(.secondary)
                Button("END REST") { store.endRest() }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity)
            Chunk5FRunView(store: store, subdued: true).frame(maxWidth: .infinity)
        }
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
