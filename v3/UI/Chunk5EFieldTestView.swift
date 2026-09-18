import SwiftUI

public struct Chunk5EFieldTestView: View {
    @ObservedObject private var store: FieldTestStore

    public init(store: FieldTestStore) { self.store = store }

    public var body: some View {
        TabView {
            TodayFieldView(store: store)
                .tabItem { Label("Today", systemImage: "truck.box") }
            JournalFieldView(store: store)
                .tabItem { Label("Journal", systemImage: "list.bullet.rectangle") }
        }
    }
}

private struct TodayFieldView: View {
    @ObservedObject var store: FieldTestStore
    @State private var expected = "5000"
    @State private var destination: DeliveryDestinationKind = .storageTank
    @State private var dipAvailable = true
    @State private var selectedProductIndex = 0
    @State private var startingCargo = ["", "", "", "", ""]

    var body: some View {
        NavigationStack {
            List {
                Section("Five-compartment test tanker") {
                    ForEach(Array(store.compartmentIDs.enumerated()), id: \.offset) { index, id in
                        let reconciled = try? CargoStateReconciler.currentState(
                            ledger: store.snapshot.cargoLedger,
                            reconciliationLog: store.snapshot.reconciliationLog,
                            compartmentID: id
                        )
                        HStack {
                            Text("C\(index + 1)")
                            Spacer()
                            Text(reconciled?.quantity.map { "\(Int($0.units)) L" } ?? "Empty")
                        }
                    }
                }

                Section("Starting cargo") {
                    Picker("Product", selection: $selectedProductIndex) {
                        ForEach(Array(store.products.enumerated()), id: \.offset) { index, product in Text(product.name).tag(index) }
                    }
                    ForEach(0..<min(5, store.compartmentIDs.count), id: \.self) { index in
                        HStack {
                            TextField("C\(index + 1) litres", text: $startingCargo[index]).keyboardType(.decimalPad)
                            Button("Load") {
                                guard store.products.indices.contains(selectedProductIndex), let litres = Double(startingCargo[index]), litres > 0 else { return }
                                try? store.establishStartingCargo(product: store.products[selectedProductIndex], litres: litres, compartmentID: store.compartmentIDs[index])
                                startingCargo[index] = ""
                            }
                        }
                    }
                }

                Section("New delivery") {
                    TextField("Expected litres", text: $expected).keyboardType(.decimalPad)
                    Picker("Destination", selection: $destination) {
                        Text("Tank").tag(DeliveryDestinationKind.storageTank)
                        Text("Direct into equipment").tag(DeliveryDestinationKind.equipment)
                        Text("Other").tag(DeliveryDestinationKind.other)
                    }
                    if destination == .storageTank {
                        Toggle("Usable dipstick", isOn: $dipAvailable)
                    }
                    Button("Add delivery") {
                        guard store.products.indices.contains(selectedProductIndex) else { return }
                        let product = store.products[selectedProductIndex]
                        let method: LevelObservationMethod? =
                            destination == .storageTank && dipAvailable ? .dipstick : nil
                        store.addJob(
                            product: product,
                            expectedLitres: Double(expected),
                            context: DeliveryContext(
                                destinationKind: destination,
                                evidenceCapability: .init(levelObservationMethod: method)
                            )
                        )
                    }
                }

                ForEach(store.snapshot.jobs) { job in
                    NavigationLink {
                        DeliveryFieldView(store: store, jobID: job.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Delivery").font(.headline)
                            Text(job.state.rawValue.capitalized)
                        }
                    }
                }
            }
            .navigationTitle("Today")
        }
    }
}

private struct DeliveryFieldView: View {
    @ObservedObject var store: FieldTestStore
    let jobID: CanonicalID
    @State private var actual = ""
    @State private var opening = ""
    @State private var closing = ""
    @State private var allocation = ["", "", "", "", ""]
    @State private var message = ""

    private var job: ServiceJob? { store.snapshot.jobs.first { $0.id == jobID } }
    private var card: FuelDeliveryCard? { store.snapshot.cards.first { $0.serviceJobID == jobID } }
    private var context: DeliveryContext? { store.snapshot.contexts[jobID] }

    var body: some View {
        Form {
            if let job, let card {
                Section("State") {
                    LabeledContent("Job", value: job.state.rawValue.capitalized)
                    if let suggested = card.expectedDeliveryLitres.suggestedValue {
                        LabeledContent("Expected (suggested)", value: "\(Int(suggested)) L")
                    }
                }

                if context?.evidenceCapability.canObserveReceivingLevel == true {
                    Section("Physical level evidence") {
                        TextField("Opening level L", text: $opening).keyboardType(.decimalPad)
                        Button("Record opening observation") { recordLevel(opening, opening: true) }
                        TextField("Closing level L", text: $closing).keyboardType(.decimalPad)
                        Button("Record closing observation") { recordLevel(closing, opening: false) }
                    }
                }

                Section("Driver actions") {
                    if job.state == .planned {
                        Button("Confirm arrived") { store.mutateJob(jobID) { _ = $0.confirmArrival(at: Date()) } }
                    }
                    if job.state == .arrived {
                        Button("Begin service") { store.mutateJob(jobID) { _ = $0.begin(at: Date()) } }
                    }
                    if job.state == .active && card.pumpStartedAt == nil {
                        Button("Start pump") { store.mutateCard(for: jobID) { _ = $0.startPump(at: Date()) } }
                    }
                    if job.state == .active && card.pumpStartedAt != nil && card.pumpFinishedAt == nil {
                        Button("Finish pump") { store.mutateCard(for: jobID) { _ = $0.finishPump(at: Date()) } }
                    }
                }

                if job.state == .active && card.pumpFinishedAt != nil {
                    Section("Confirm what moved") {
                        TextField("Actual delivered litres", text: $actual).keyboardType(.decimalPad)
                        Button("Confirm delivered quantity") {
                            guard let value = Double(actual), value > 0 else { return }
                            store.mutateCard(for: jobID) {
                                $0.recordDeliveredLitres(.init(
                                    value: value, unitName: "L", status: .confirmed, occurredAt: Date()
                                ))
                            }
                        }
                        ForEach(0..<min(5, store.compartmentIDs.count), id: \.self) { index in
                            TextField("C\(index + 1) litres", text: $allocation[index]).keyboardType(.decimalPad)
                        }
                        Button("Commit delivery & complete service") {
                            let pairs = store.compartmentIDs.enumerated().compactMap { index, id -> (CanonicalID, Double)? in
                                guard index < allocation.count,
                                      let value = Double(allocation[index]), value > 0 else { return nil }
                                return (id, value)
                            }
                            do {
                                try store.commitDelivery(jobID: jobID, allocations: pairs)
                                message = "Delivery committed."
                            } catch {
                                message = "Not committed: \(error)"
                            }
                        }
                    }
                }

                if job.state == .completed && job.actualDeparture == nil {
                    Section {
                        Button("Depart") { store.mutateJob(jobID) { _ = $0.depart(at: Date()) } }
                    }
                }

                if !message.isEmpty {
                    Section("Result") { Text(message) }
                }
            }
        }
        .navigationTitle("Delivery")
    }

    private func recordLevel(_ text: String, opening: Bool) {
        guard let value = Double(text), let capability = context?.evidenceCapability else { return }
        let evidence = OperationalQuantityEvidence(
            value: value,
            unitName: "L",
            status: .observed,
            occurredAt: Date(),
            resolution: capability.approximateResolutionLitres,
            sourceDescription: capability.levelObservationMethod?.rawValue
        )
        store.mutateCard(for: jobID) {
            if opening { $0.recordOpeningLevel(evidence) }
            else { $0.recordClosingLevel(evidence) }
        }
    }
}

private struct JournalFieldView: View {
    @ObservedObject var store: FieldTestStore

    var body: some View {
        NavigationStack {
            List(store.snapshot.jobs) { job in
                let card = store.snapshot.cards.first { $0.serviceJobID == job.id }
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.state.rawValue.capitalized).font(.headline)
                    if let value = job.actualArrival { Text("Arrived \(value.formatted(date: .omitted, time: .standard))") }
                    if let value = job.actualStart { Text("Started \(value.formatted(date: .omitted, time: .standard))") }
                    if let value = card?.pumpStartedAt { Text("Pump start \(value.formatted(date: .omitted, time: .standard))") }
                    if let value = card?.pumpFinishedAt { Text("Pump finish \(value.formatted(date: .omitted, time: .standard))") }
                    if let value = card?.actualDeliveredLitres { Text("Confirmed delivery \(Int(value)) L") }
                    if let value = job.actualCompletion { Text("Completed \(value.formatted(date: .omitted, time: .standard))") }
                    if let value = job.actualDeparture { Text("Departed \(value.formatted(date: .omitted, time: .standard))") }
                }
            }
            .navigationTitle("Journal")
        }
    }
}
