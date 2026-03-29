//======================================
// MARK: - AppModel+DGPlacard
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+DGPlacard.swift
//
// Purpose:
// - Derives compartment DG states and the placard decision to display from current app state.
//
// Responsibilities:
// - Translate load/unload compartment state into DG compartment states
// - Decide whether placard display should use draft, confirmed, or on-truck state
// - Bridge AppModel session data into DGPlacardLogic
//
// Notes:
// - This is domain/workflow logic, not pure UI logic
// - DGPlacardLogic remains the pure decision engine; this file prepares the inputs
// - Current behaviour is pre-persistence and relies on session confirmedLoads history
//
// Phase: Pre-persistence
//======================================

import SwiftUI
extension CompartmentModel {
    
    /// Draft-only DG state derived from the current picker + litres text.
    /// - Note: Degassing is tracked separately via `isDegassed`.
    /// - Important (pre-persistence): Selecting a product with 0L does NOT imply residue/placarding.
    ///   Until litres exist (or persistence is implemented), treat 0L as `.unknown`.
    var dgStateForNow: DGCompartmentState {
        guard let product = selectedProduct else { return .unknown }
        
        let litres = Int(litresText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let family: DGProductFamily = (product.unNumber == 1203) ? .ulp : .diesel
        
        if litres > 0 {
            return .loaded(family: family, litres: litres)
        } else {
            return .unknown
        }
    }
}

extension AppModel {
    
    /// DG placard decision the UI should display.
    /// - Load plan mode: show LAST CONFIRMED state only (do not change while drafting).
    /// - Unload planning mode: show CURRENT ON-TRUCK state (changes as remaining litres change).
    var displayedDGPlacardDecision: DGPlacardDecision {
        isUnloadMode ? onTruckDGPlacardDecision : confirmedOnlyDGPlacardDecision
    }
    
    /// Placard based ONLY on the last confirmed load (ignores current picker/litres edits).
    private var confirmedOnlyDGPlacardDecision: DGPlacardDecision {
        // After a degas, keep placard blank while drafting the next load (until Confirm).
        if suppressPlacardUntilNextConfirm {
            return .blankTopHalf
        }
        
        // If everything is degassed, force blank top.
        if !compartments.isEmpty, compartments.allSatisfy({ $0.isDegassed }) {
            return .blankTopHalf
        }
        
        guard !confirmedLoads.isEmpty else {
            return .blankTopHalf
        }
        
        // Build states in current compartment order.
        let states: [DGCompartmentState] = compartments.map { comp in
            if comp.isDegassed { return .degassedEmpty }
            
            guard let fam = lastKnownFamilyForCompartment(compName: comp.name) else {
                return .unknown
            }
            
            // In “confirmed-only”, if we knew it was last in there, treat as residue/vapour.
            return .residueOrVapour(family: fam)
        }
        
        return DGPlacardLogic.decide(.init(compartments: states))
    }
    
    private var onTruckDGPlacardDecision: DGPlacardDecision {
        // UNLOAD MODE ONLY:
        // Placard represents what is currently on the truck, using remaining litres plus
        // confirmed history for product family (never the picker).
        let states = dgCompartmentsOnTruck
        return DGPlacardLogic.decide(.init(compartments: states))
    }
    
    private var dgCompartmentsOnTruck: [DGCompartmentState] {
        
        // 0) If EVERY compartment is degassed => true blank top.
        if !compartments.isEmpty, compartments.allSatisfy({ $0.isDegassed }) {
            return Array(repeating: .degassedEmpty, count: compartments.count)
        }
        
        // 1) No confirmed history yet => unknown everywhere (start-of-shift reality pre-persistence)
        guard !confirmedLoads.isEmpty else {
            return compartments.map { comp in
                comp.isDegassed ? .degassedEmpty : .unknown
            }
        }
        
        // 2) We have confirmed history this session: use LAST KNOWN FAMILY as the truth source.
        return compartments.map { comp in
            let litres = Int(comp.litresText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            
            // Degassed overrides everything
            if comp.isDegassed {
                return .degassedEmpty
            }
            
            let lastFam = lastKnownFamilyForCompartment(compName: comp.name)
            
            if litres > 0 {
                // When unloading, litres>0 means “product remains”.
                // Family must come from confirmed history (not the dropdown).
                if let fam = lastFam {
                    return .loaded(family: fam, litres: litres)
                }
                return .unknown
            }
            
            // litres == 0: if we have last known family => residue/vapour applies
            if let fam = lastFam {
                return .residueOrVapour(family: fam)
            }
            
            return .unknown
        }
    }
    
    private func lastKnownFamilyForCompartment(compName: String) -> DGProductFamily? {
        // Walk backwards through confirmed loads (session) to find the last known DG family
        // for this compartment. This is the single source of truth for unload placarding.
        for load in confirmedLoads.reversed() {
            if let fam = load.lastFamilyForCompartmentNamed(compName) {
                return fam
            }
        }
        return nil
    }
}
