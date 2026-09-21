import SwiftUI

@MainActor
public struct Chunk5FAdaptiveWorkspaceView: View {
    @StateObject private var store: Chunk5FPrototypeStore
    @State private var transferFrom = 0
    @State private var transferTo = 2
    @State private var transferLitres = 0
    @State private var reconcileIndex = 3
    @State private var reconcileObserved = 0
    @State private var correctionIndex = 0
    @State private var correctionDelta = 0

    public init(store: Chunk5FPrototypeStore) {
        _store = StateObject(wrappedValue: store)
    }

    public init() {
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
            Spacer()
            VStack {
                Text(store.workspace == .rest ? "REST \(store.restMinutes) / 30m" : store.workspace == .preShift ? "READY TO START" : "IN SHIFT")
                    .font(.headline)
            }.frame(maxWidth: 300)
            Spacer()
            VStack(alignment: .trailing) {
                if let next = store.nextIncompleteVisit {
                    Text("NEXT: \(next.customer)")
                    Text(next.site).font(.caption)
                } else {
                    Text(store.visits.isEmpty ? "NO RUN YET" : "RUN COMPLETE")
                    Text(store.openingBaselineAccepted ? "Baseline OK" : "Baseline required").font(.caption)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private var preShift: some View {
        HStack(alignment: .top, spacing: 14) {
            panel("DRIVER / TRUCK") {
                Text("DRIVER: MACOZZA").font(.title3.bold())
                Text("Truck 92 • selected")
                Divider()
                Text("Opening ODO (driver-entered)").font(.headline)
                TextField("Opening ODO", value: $store.draftOpeningODO, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .disabled(store.openingBaselineAccepted)
                Divider()
                Text("Opening cargo (vehicle assumption)").font(.headline)
                Text("Confirm what is already aboard. This is not a Load.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(store.compartments.enumerated()), id: \.element.id) { index, c in
                    HStack {
                        Text("C\(c.id)")
                        if !store.openingBaselineAccepted {
                            Picker("", selection: Binding(
                                get: { store.compartments[index].product },
                                set: { store.setProduct(compartment: index, product: $0) }
                            )) {
                                ForEach(Chunk5FPrototypeStore.availableProducts, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 80)
                        } else {
                            Text(c.product)
                        }
                        Spacer()
                        TextField("L", value: Binding(
                            get: { store.draftLitres[index] },
                            set: { store.setOpeningDraft(compartment: index, litres: $0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .keyboardType(.numberPad)
                        .disabled(store.openingBaselineAccepted)
                    }
                    .font(.caption)
                }
                if store.openingBaselineAccepted {
                    Text("Baseline accepted: \(store.cargoOpeningSnapshot.map(String.init).joined(separator: ", "))")
                        .font(.caption2).foregroundStyle(.green)
                    Text("Opening ODO \(store.openingODO.map(String.init) ?? "—")")
                        .font(.caption2)
                } else {
                    Button("CONFIRM OPENING BASELINE") {
                        store.acceptOpeningBaseline()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            panel("TODAY") {
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
                    Text("\(next.plannedLitres.formatted()) L")
                } else {
                    Text(store.visits.isEmpty ? "NO SITES PLANNED" : "RUN COMPLETE").font(.title2.bold())
                }
                Text("Cargo: \(store.confirmedLitres.map(String.init).joined(separator: ", "))")
                    .font(.caption2).foregroundStyle(.secondary)
                Divider()
                Text("Closing ODO").font(.caption.bold())
                TextField("Closing ODO", value: $store.draftClosingODO, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }.frame(width: 230)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(.quaternary)
                VStack {
                    Image(systemName: "map").font(.system(size: 72))
                    Text("MAP — status, not analysis").font(.caption)
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
                    Text(store.currentVisit.map { "\($0.customer) — \($0.site)" } ?? "—").bold()
                    Text("Presence does not prove service.").font(.caption)
                }
                panel("CURRENT FILL") {
                    Text(store.currentFill?.name ?? "—").font(.title2)
                    Text("\(store.currentFill?.plannedLitres.formatted() ?? "0") L \(store.currentFill?.product ?? "") planned")
                }
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("TRUCK — proposed remaining quantities").font(.headline)
                    Chunk5FTruckCargoView(store: store, mode: .site)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("+\(store.deliveryMovement.formatted()) L").font(.title2.bold())
                    Text("Planned \(store.plannedDelivery.formatted()) L")

                    Text("Transfer (editable)").font(.caption.bold())
                    HStack {
                        Picker("From", selection: $transferFrom) {
                            ForEach(0..<store.compartments.count, id: \.self) { Text("C\($0+1)").tag($0) }
                        }
                        Picker("To", selection: $transferTo) {
                            ForEach(0..<store.compartments.count, id: \.self) { Text("C\($0+1)").tag($0) }
                        }
                        TextField("L", value: $transferLitres, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 70).keyboardType(.numberPad)
                        Button("CONFIRM TRANSFER") {
                            store.commitTransfer(from: transferFrom, to: transferTo, litres: transferLitres)
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)

                    Text("Reconcile (physical)").font(.caption.bold())
                    HStack {
                        Picker("C", selection: $reconcileIndex) {
                            ForEach(0..<store.compartments.count, id: \.self) { Text("C\($0+1)").tag($0) }
                        }
                        TextField("Observed L", value: $reconcileObserved, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 90).keyboardType(.numberPad)
                        Button("CONFIRM RECONCILE") {
                            store.commitReconciliation(compartment: reconcileIndex, observedLitres: reconcileObserved, note: "Physical observation")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)

                    Text("Correction (input error)").font(.caption.bold())
                    HStack {
                        Picker("C", selection: $correctionIndex) {
                            ForEach(0..<store.compartments.count, id: \.self) { Text("C\($0+1)").tag($0) }
                        }
                        TextField("Delta L", value: $correctionDelta, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 90).keyboardType(.numbersAndPunctuation)
                        Button("CONFIRM CORRECTION") {
                            store.commitCorrection(compartment: correctionIndex, deltaLitres: correctionDelta, note: "Driver correction")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)
                }.frame(width: 320)
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
            Text("PROPOSED TRUCK CARGO").font(.headline)
            Chunk5FTruckCargoView(store: store, mode: .load)
            if !store.message.isEmpty { Text(store.message).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("SCAN BOL (SIMULATED)") { store.simulateBOLScan() }.buttonStyle(.bordered)
                Button("UNDO") { store.undoDraft() }.buttonStyle(.bordered)
                Spacer()
                Button("CONFIRM LOAD") { store.commitLoad() }.buttonStyle(.borderedProminent)
            }
        }
    }

    private var rest: some View {
        HStack(alignment: .top, spacing: 14) {
            panel("SHIFT SO FAR") {
                Text("\(store.eventLog.filter { $0.kind == .delivery }.count) deliveries")
                Text("Events: \(store.eventLog.count)")
            }.frame(maxWidth: .infinity)
            panel("FATIGUE") {
                Text("\(store.restMinutes) / 30 min").font(.system(size: 42, weight: .bold))
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
