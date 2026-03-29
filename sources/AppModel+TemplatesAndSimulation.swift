//======================================
// MARK: - AppModel+TemplatesAndSimulation
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+TemplatesAndSimulation.swift
//
// Purpose:
// - Provides template lookup, draft template application, and mass simulation helpers.
//
// Responsibilities:
// - Resolve products from short codes for template-driven workflows.
// - Apply built-in and saved templates to the current draft load plan.
// - Expose draft mass simulation results for SimulationView.
// - Save the current draft as a reusable template entry.
//
// Notes:
// - This file bridges template-driven draft state and simulation output.
// - `savedTemplates` are in-memory only until persistence is implemented.
// - Built-in “typical loads” are transitional helpers and may later merge into the unified LoadTemplate system.
// - Simulation here is draft-only and must not mutate authoritative load history.
//
// Phase: Pre-persistence
//======================================

import SwiftUI

extension AppModel {
    
    //======================================
    // MARK: - Product lookup + template application
    //======================================
    
    /// Finds a product by short name (case-insensitive), e.g. "DSL", "P91", "P95".
    /// Single source of truth for mapping template strings → Product models.
    func product(shortName: String) -> Product? {
        products.first { $0.shortName.uppercased() == shortName.uppercased() }
    }
    
    /// Computed draft simulation result for the current `draftTemplate`.
    /// Pure calculation: should NOT mutate model state.
    var draftSimulationResult: MassSimulationResult {
        MassSimulationLogic.simulate(template: draftTemplate, products: products, truck: truckConfig)
    }
    
    /// Applies a built-in "Typical load" pattern as a DRAFT ONLY.
    /// - Compartments mentioned in the template: set product + litres.
    /// - Compartments not mentioned: clear litres (leave product picker untouched).
    /// Note: Placarding should not change in Load Plan mode until `confirmCurrentLoad()`.
    func applyTypicalLoad(_ template: TypicalLoadTemplate) {
        for index in compartments.indices {
            let name = compartments[index].name
            if let config = template.perCompartment[name],
               let prod = product(shortName: config.productShortName) {
                compartments[index].selectedProduct = prod
                compartments[index].litresText = "\(config.litres)"
            } else {
                // Not in this template: clear litres only.
                // Leaving the product picker alone avoids accidental type changes when comparing templates.
                compartments[index].litresText = ""
            }
        }
    }
    
    /// Forces SwiftUI to refresh views that depend on `draftSimulationResult`.
    /// Used when the draft template mutates in a way that doesn't naturally trigger an @Published change.
    func recalcDraftSimulation() {
        objectWillChange.send()
    }
    
    /// Saves the current `draftTemplate` as a NEW `LoadTemplate` entry.
    /// - Creates a new UUID + createdAt timestamp.
    /// - Copies items/notes as-is (no validation here).
    /// Phase 1: stored in-memory only until persistence is implemented.
    func saveDraftAsNewTemplate() {
        let newTemplate = LoadTemplate(
            id: UUID(),
            name: draftTemplate.name,
            createdAt: Date(),
            items: draftTemplate.items,
            notes: draftTemplate.notes
        )
        savedTemplates.append(newTemplate)
    }
}
