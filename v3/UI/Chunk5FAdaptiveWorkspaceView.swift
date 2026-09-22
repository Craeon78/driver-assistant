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
    @State private var correctionEventID: UUID? = nil
    @State private var correctionCorrectedLitres = 0
    @State private var transactionActualLitres = 0
    @State private var transactionPostEmpty = false
    @State private var transactionVarianceNote = ""

    public init(store: Chunk5FPrototypeStore) {
        _store = StateObject(wrappedValue: store)
    }

    public init() {
        _store = StateObject(wrappedValue: Chunk5FPrototypeStore())
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch store.workspace {
                case .preShift: preShift
                case .active: active
                case .site: site
                case .load: load
                case .rest: active
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if store.workspace == .active || store.workspace == .rest {
                bottomBar
            }
            if !store.message.isEmpty && store.workspace != .preShift {
                Text(store.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
            }
        }
        .sheet(isPresented: $store.showGateReport) {
            if let report = store.lastGateReport {
                Chunk5GGateReportView(report: report) {
                    store.showGateReport = false
                }
            }
        }
    }

    private var topBar: some View {
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

                if store.hasArchivedGateReport {
                    Button("PREVIOUS GATE REPORT") {
                        store.presentArchivedGateReport()
                    }
                    .buttonStyle(.bordered)
                }

                if !store.message.isEmpty {
                    Text(store.message).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Chunk5FRunView(store: store).frame(maxWidth: .infinity)
        }
    }

    private var active: some View {
        HStack(alignment: .top, spacing: 14) {
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
    }

    private var bottomBar: some View {
        HStack {
            if store.simulatedDrivingRunning {
                Button("STOP SIMULATED DRIVING") { store.stopSimulatedDriving() }
                    .tint(.red)
            } else {
                Button("START SIMULATED DRIVING") { store.startSimulatedDriving() }
            }
            Button("OPEN NEXT SITE") { store.openNextIncompleteSite() }
                .disabled(store.prototypeSpeedKmh > 5)
            Button("TERMINAL / LOAD") { store.openLoad() }
                .disabled(store.prototypeSpeedKmh > 5)
            if store.isResting {
                Button("END REST") { store.endRest() }
            } else {
                Button("START REST") { store.beginRest() }
            }
            Button("RELAUNCH") { store.simulateRelaunch() }
            Button("END SHIFT") { store.endShift() }
                .buttonStyle(.borderedProminent)
        }
        .buttonStyle(.bordered)
        .padding()
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
                panel("CURRENT DROP") {
                    Text(store.currentFill?.name ?? "—").font(.title2)
                    Text("\(store.currentFill?.plannedLitres.formatted() ?? "0") L \(store.currentFill?.product ?? "") planned")
                    if let visit = store.currentVisit, visit.fills.count > 1 {
                        Divider()
                        Text("Drops at this site").font(.caption.bold())
                        ForEach(Array(visit.fills.enumerated()), id: \.element.id) { idx, f in
                            HStack {
                                Text(f.completed ? "✓" : (idx == store.selectedFill ? "→" : "○"))
                                Text("\(f.name)  \(f.plannedLitres.formatted()) L \(f.product)")
                                    .font(.caption)
                                Spacer()
                                if !f.completed && idx != store.selectedFill {
                                    Button("GO") { store.selectFill(at: idx) }
                                        .font(.caption2)
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                        if visit.fills.contains(where: { $0.completed }),
                           visit.fills.contains(where: { !$0.completed }) {
                            Button("CONTINUE TO NEXT DROP") { store.advanceToNextFillAtSite() }
                                .buttonStyle(.borderedProminent)
                                .font(.caption)
                        }
                    }
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

                    Text("Physical Check (driver observation)").font(.caption.bold())
                    HStack {
                        Picker("C", selection: $reconcileIndex) {
                            ForEach(0..<store.compartments.count, id: \.self) { Text("C\($0+1)").tag($0) }
                        }
                        TextField("Observed L", value: $reconcileObserved, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 90).keyboardType(.numberPad)
                        Button("CONFIRM PHYSICAL CHECK") {
                            store.commitPhysicalCheck(compartment: reconcileIndex, observedLitres: reconcileObserved, note: "Driver observation")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)

                    Text("Correction (input error)").font(.caption.bold())
                    Picker("Original event", selection: $correctionEventID) {
                        Text("Select Load / Delivery").tag(Optional<UUID>.none)
                        ForEach(store.correctableCargoEvents) { event in
                            Text("\(event.kind.rawValue.capitalized) — \(event.committedLitres ?? 0) L")
                                .tag(Optional(event.id))
                        }
                    }
                    HStack {
                        Picker("C", selection: $correctionIndex) {
                            ForEach(0..<store.compartments.count, id: \.self) { Text("C\($0+1)").tag($0) }
                        }
                        TextField("Correct total L", value: $correctionCorrectedLitres, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 110).keyboardType(.numberPad)
                        Button("CONFIRM CORRECTION") {
                            if let eventID = correctionEventID {
                                store.commitCorrection(eventID: eventID, correctedLitres: correctionCorrectedLitres, compartment: correctionIndex, note: "Driver correction")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(correctionEventID == nil || correctionCorrectedLitres <= 0)
                    }
                    .font(.caption)
                }.frame(width: 320)
            }
            panel("TRANSACTION VARIANCE (optional)") {
                HStack {
                    TextField("Actual total L", value: $transactionActualLitres, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 130).keyboardType(.numberPad)
                    Toggle("Truck empty after transaction", isOn: $transactionPostEmpty)
                    TextField("Variance note", text: $transactionVarianceNote)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Calculated and actual totals are both retained; variance never becomes cargo.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack {
                Button("UNDO") { store.undoDraft() }.buttonStyle(.bordered)
                Spacer()
                Button("CONFIRM \(store.deliveryMovement.formatted()) L DELIVERY") {
                    store.commitDelivery(
                        actualLitres: transactionActualLitres > 0 ? transactionActualLitres : nil,
                        postTransactionEmpty: transactionActualLitres > 0 ? transactionPostEmpty : nil,
                        varianceNote: transactionVarianceNote
                    )
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.deliveryDraftIsValid)
            }
        }
        .padding()
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
            Text("LOAD — draft only until Confirm").font(.headline)
            Chunk5FTruckCargoView(store: store, mode: .load)
            panel("TRANSACTION VARIANCE (optional)") {
                HStack {
                    TextField("Actual total L", value: $transactionActualLitres, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 130).keyboardType(.numberPad)
                    Toggle("Truck empty after transaction", isOn: $transactionPostEmpty)
                    TextField("Variance note", text: $transactionVarianceNote)
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Button("UNDO") { store.undoDraft() }.buttonStyle(.bordered)
                Spacer()
                Button("CONFIRM LOAD") {
                    store.commitLoad(
                        actualLitres: transactionActualLitres > 0 ? transactionActualLitres : nil,
                        postTransactionEmpty: transactionActualLitres > 0 ? transactionPostEmpty : nil,
                        varianceNote: transactionVarianceNote
                    )
                }.buttonStyle(.borderedProminent)
            }
            if !store.message.isEmpty {
                Text(store.message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}
