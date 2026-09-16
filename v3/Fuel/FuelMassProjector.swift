import Foundation

public struct FuelMassCompartmentProjection: Codable, Sendable, Equatable {
    public let compartmentID: CanonicalID
    public let litres: Double
    public let massKg: Double

    public var kilogramsPerLitre: Double? {
        litres > 0 ? massKg / litres : nil
    }
}

public enum FuelMassProjectionError: Error, Equatable {
    case missingLoadEvidence(transactionID: CanonicalID)
    case duplicateLoadEvidence(transactionID: CanonicalID)
    case invalidLoadEvidence(transactionID: CanonicalID)
    case insufficientMass(compartmentID: CanonicalID)
}

/// Derived Fuel mass projection. Litres remain inventory truth in CargoLedger; mass is
/// replayed from committed load-density evidence. Loads add evidenced mass, unloads remove
/// the source compartment's current proportional mass, and transfers conserve that mass.
public enum FuelMassProjector {
    private struct WorkingState {
        var litres: Double = 0
        var massKg: Double = 0
    }

    public static func project(_ state: FuelCommittedState) throws -> [FuelMassCompartmentProjection] {
        var evidenceByTransaction: [CanonicalID: FuelLoadEvidence] = [:]
        for record in state.loadEvidence {
            guard evidenceByTransaction[record.cargoTransactionID] == nil else {
                throw FuelMassProjectionError.duplicateLoadEvidence(transactionID: record.cargoTransactionID)
            }
            evidenceByTransaction[record.cargoTransactionID] = record.evidence
        }

        var working: [CanonicalID: WorkingState] = [:]
        let ordered = state.ledger.transactions.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }
            return $0.id.raw.uuidString < $1.id.raw.uuidString
        }

        func remove(_ litres: Double, from compartmentID: CanonicalID) throws -> Double {
            var source = working[compartmentID] ?? WorkingState()
            guard source.litres >= litres, source.litres > 0 else {
                throw FuelMassProjectionError.insufficientMass(compartmentID: compartmentID)
            }
            let massRemoved = source.massKg * (litres / source.litres)
            source.litres -= litres
            source.massKg -= massRemoved
            if abs(source.litres) < 0.000_001 { source = WorkingState() }
            working[compartmentID] = source
            return massRemoved
        }

        for transaction in ordered {
            // Fuel mass owns only fuel.* cargo. Thin non-fuel Cargo remains outside this projector.
            guard transaction.cargo.kind.hasPrefix("fuel.") else { continue }
            switch transaction.kind {
            case .load:
                guard let destination = transaction.destinationCompartmentID else { continue }
                guard let evidence = evidenceByTransaction[transaction.id] else {
                    throw FuelMassProjectionError.missingLoadEvidence(transactionID: transaction.id)
                }
                guard evidence.kilogramsPerLitre > 0 else {
                    throw FuelMassProjectionError.invalidLoadEvidence(transactionID: transaction.id)
                }
                var destinationState = working[destination] ?? WorkingState()
                destinationState.litres += transaction.units
                destinationState.massKg += evidence.massKg(forLitres: transaction.units)
                working[destination] = destinationState

            case .unload:
                guard let source = transaction.sourceCompartmentID else { continue }
                _ = try remove(transaction.units, from: source)

            case .transfer:
                guard let source = transaction.sourceCompartmentID, let destination = transaction.destinationCompartmentID else { continue }
                let movedMass = try remove(transaction.units, from: source)
                var destinationState = working[destination] ?? WorkingState()
                destinationState.litres += transaction.units
                destinationState.massKg += movedMass
                working[destination] = destinationState

            case .correction:
                // Cargo correction semantics are authoritative for quantity. Exact mass reversal
                // of an arbitrary historical transaction requires replaying the corrected fact as
                // absent, rather than inventing density. Build an effective transaction stream.
                continue
            }
        }

        // Corrections require a second replay with corrected targets removed. This keeps mass
        // evidence attached to the original load while respecting append-only correction truth.
        let correctedIDs = Set(state.ledger.transactions.compactMap { $0.kind == .correction ? $0.correctsTransactionID : nil })
        if !correctedIDs.isEmpty {
            let effectiveTransactions = state.ledger.transactions.filter { $0.kind != .correction && !correctedIDs.contains($0.id) }
            var effectiveLedger = try CargoLedger(limits: state.ledger.limits)
            for transaction in effectiveTransactions.sorted(by: { $0.occurredAt < $1.occurredAt }) {
                try effectiveLedger.append(transaction)
            }
            return try project(FuelCommittedState(ledger: effectiveLedger, fuelEvents: state.fuelEvents, loadEvidence: state.loadEvidence))
        }

        return working.map { FuelMassCompartmentProjection(compartmentID: $0.key, litres: $0.value.litres, massKg: $0.value.massKg) }
            .sorted { $0.compartmentID.raw.uuidString < $1.compartmentID.raw.uuidString }
    }

    public static func totalMassKg(_ state: FuelCommittedState) throws -> Double {
        try project(state).reduce(0) { $0 + $1.massKg }
    }
}
