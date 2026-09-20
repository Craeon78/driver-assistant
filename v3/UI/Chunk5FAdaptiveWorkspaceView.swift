import SwiftUI

@MainActor
public struct Chunk5FAdaptiveWorkspaceView: View {
    @StateObject private var store: Chunk5FPrototypeStore

    public init(store: Chunk5FPrototypeStore) {
        _store = StateObject(wrappedValue: store)
    }

    public init() {
        // Live evidence source — no fixture authority on the field path.
        _store = StateObject(wrappedValue: Chunk5FPrototypeStore(evidenceSource: .live))
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
        .sheet(isPresented: $store.showGateReport) {
            if let report = store.lastGateReport {
                Chunk5GGateReportView(report: report) {
                    store.showGateReport = false
                }
            }
        }
    }

    private var instrumentBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
            VStack { Text("\(store.prototypeSpeedKmh)").font(.title2.bold()); Text("km/h").font(.caption2) }
            VStack(alignment: .leading) {
                Text("ODO \(store.openingODO.map { "\($0)" } ?? "—")")
                Text(store.evidenceSource == .live ? "LIVE" : "FIXTURE").font(.caption)
            }
            Image(systemName: "location.north.circle").font(.title2)
            Spacer()
            VStack {
                Text(store.workspace == .rest ? "REST \(store.restMinutes) / 30m" : store.workspace == .preShift ? "READY TO START" : "NEXT REST 1h 42m")
                    .font(.headline)
                ProgressView(value: store.workspace == .rest ? Double(store.restMinutes) / 30.0 : 0.45)
            }.frame(maxWidth: 300)
            Spacer()
            VStack(alignment: .trailing) {
                if store.workspace == .rest {
                    Text("RESTING")
                    Text("Recovery first").font(.caption)
                } else if let next = store.nextIncompleteVisit {
                    Text("NEXT: \(next.customer)")
                    Text(next.site).font(.caption)
                } else {
                    Text(store.visits.isEmpty ? "NO RUN YET" : "RUN COMPLETE")
                    Text(store.openingBaselineAccepted ? "Baseline OK" : "Baseline required").font(.caption)
                }
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
                Text("Opening cargo (vehicle assumption)").font(.headline)
                Text("Confirm what is already aboard. This is not a Load.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(store.compartments.enumerated()), id: \.element.id) { index, c in
                    HStack {
                        Text("C\(c.id) \(c.product)")
                        Spacer()
                        TextField("L", value: Binding(
                            get: { store.draftLitres[index] },
                            set: { store.setOpeningDraft(compartment: index, litres: $0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .keyboardType(.numberPad)
                    }
                    .font(.caption)
                }
                if store.openingBaselineAccepted {
                    Text("Baseline accepted: \(store.cargoOpeningSnapshot.map(String.init).joined(separator: ", "))")
                        .font(.caption2).foregroundStyle(.green)
                } else {
                    Button("CONFIRM OPENING BASELINE") {
                        store.acceptOpeningBaseline()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            panel("TODAY") {
                // START SHIFT — centre of middle column, prominent but not full-width banner
                Button {
                    store.startShift()
                } label: {
                    Text("START SHIFT")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .frame(maxWidth: 280)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!store.openingBaselineAccepted)
                .frame(maxWidth: .infinity)

                if !store.message.isEmpty {
                    Text(store.message).font(.caption).foregroundStyle(.secondary)
                }
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
                if let next = store.nextIncompleteVisit {
                    Text(next.customer).font(.title2.bold())
                    Text(next.site)
                    if let requested = next.requestedTime {
                        Text("\(requested) requested • ETA \(next.projectedTime)")
                    } else {
                        Text("ETA \(next.projectedTime)")
                    }
                    Text("\(next.plannedLitres.formatted()) L • \(next.fills.count) fill\(next.fills.count == 1 ? "" : "s")")
                } else {
                    Text(store.visits.isEmpty ? "NO SITES PLANNED" : "RUN COMPLETE").font(.title2.bold())
                    Text("Add work from the Run panel when stationary.")
                }
                Text("Cargo: \(store.confirmedLitres.map(String.init).joined(separator: ", "))")
                    .font(.caption2).foregroundStyle(.secondary)
            }.frame(width: 230)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(.quaternary)
                VStack {
                    Image(systemName: "map").font(.system(size: 72))
                    Text(store.nextIncompleteVisit.map { "MAP — current position → \($0.site)" } ?? "MAP — no next site")
                    Text("Driving state: status, not analysis").font(.caption).foregroundStyle(.secondary)
                }
            }
            Chunk5FRunView(store: store).frame(width: 280)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                if !store.message.isEmpty {
                    Text(store.message).font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button(store.prototypeSpeedKmh > 5 ? "SIMULATE STOP" : "SIMULATE DRIVING") {
                        store.setPrototypeMoving(store.prototypeSpeedKmh <= 5)
                    }
                    Button("OPEN NEXT SITE") { store.openNextIncompleteSite() }
                        .disabled(store.prototypeSpeedKmh > 5)
                    Button("TERMINAL / LOAD") { store.openLoad() }
                        .disabled(store.prototypeSpeedKmh > 5)
                    Button("START REST") { store.beginRest() }
                    Button("RELAUNCH") { store.simulateRelaunch() }
                    Button("END SHIFT") { store.endShift() }
                        .buttonStyle(.borderedProminent)
                }
                .buttonStyle(.bordered)
                .padding(8)
                .background(.thinMaterial, in: Capsule())
            }
        }
    }

    private var site: some View {
        VStack(spacing: 12) {
            HStack {
                Button("BACK TO ACTIVE") { store.returnToActive() }
                    .buttonStyle(.bordered)
                Spacer()
                Text("Leaving discards draft — no event committed")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                panel("SITE") {
                    Text("Mini Map • Cleveland")
                    Text("Site context only — presence does not prove service.")
                }
                panel("CURRENT FILL") {
                    Text(store.currentVisit.map { "\($0.customer) — \($0.site)" } ?? "—").bold()
                    Text(store.currentFill?.name ?? "—").font(.title2)
                    Text("\(store.currentFill?.plannedLitres.formatted() ?? "0") L \(store.currentFill?.product ?? "") planned")
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
                    HStack {
                        Button("TRANSFER 200 C1→C3") {
                            store.commitTransfer(from: 0, to: 2, litres: 200)
                        }
                        .buttonStyle(.bordered)
                        Button("RECONCILE C4 EMPTY") {
                            store.commitReconciliation(compartment: 3, observedLitres: 0, note: "Physical empty")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)
                }.frame(width: 260)
            }
            HStack {
                Button("UNDO") { store.undoDraft() }.buttonStyle(.bordered)
                Spacer()
                Button("CONFIRM \(store.deliveryMovement.formatted()) L DELIVERY") { store.commitDelivery() }
                    .buttonStyle(.borderedProminent).disabled(!store.deliveryDraftIsValid)
            }
        }
    }

    private var load: some View {
        VStack(spacing: 12) {
            HStack {
                Button("BACK TO ACTIVE") { store.returnToActive() }
                    .buttonStyle(.bordered)
                Spacer()
                Text("Leaving discards draft — no event committed")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                panel("TERMINAL") { Text("Mini Map"); Text("Safe stopped capture outside terminal") }
                panel("DRIVER LOAD PLAN") {
                    Text("Mini physical-sheet representation")
                    Text("DA → driver → terminal process").font(.caption).foregroundStyle(.secondary)
                }
                panel("PAPERWORK") {
                    Text("BOL likeness • EIP status")
                    Text("DA representation — not official document").font(.caption)
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
                    Text("\(store.eventLog.filter { $0.kind == .delivery }.count) deliveries logged")
                    Text("Events: \(store.eventLog.count)")
                }
            }.frame(maxWidth: .infinity)
            panel("FATIGUE") {
                Text("CURRENT REST").font(.headline)
                Text("\(store.restMinutes) / 30 min").font(.system(size: 42, weight: .bold))
                ProgressView(value: Double(store.restMinutes), total: 30)
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
