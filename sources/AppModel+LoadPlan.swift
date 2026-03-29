//======================================
// MARK: - AppModel+LoadPlan
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+LoadPlan.swift
//
// Purpose:
// - Manages draft load/unload plan behaviour, confirmation workflow, and load-related calculations.
//
// Responsibilities:
// - Own SG, mass, litre, and axle/GVM helpers for the current draft load plan.
// - Control confirm gating and commit current load/unload state into confirmed session history.
// - Apply templates and unload/degas operations to the current compartment plan.
//
// Notes:
// - This file currently bridges draft UI state and confirmed session load history.
// - Confirmed loads are the authoritative in-session source for placarding, summaries, and last-known product state.
// - Transfer, variance, spill, and broader stock-ledger behaviour are not yet implemented here.
// - Pre-persistence logic currently relies on in-memory compartments and confirmedLoads.
//
// Phase: Pre-persistence
//======================================

import SwiftUI
extension AppModel {
    
    //======================================
    // MARK: - SG helpers
    //======================================
    
    func sg(for product: Product) -> Double {
        if let override = sgOverrides[product.id] {
            return override
        }
        return product.defaultSg
    }
    
    func setSg(_ value: Double, for product: Product) {
        let clamped = min(max(value, product.sgMin), product.sgMax)
        var copy = sgOverrides
        copy[product.id] = clamped
        sgOverrides = copy          // <- reassign triggers @Published properly
    }
    
    func massKg(for comp: CompartmentModel) -> Double? {
        guard let product = comp.selectedProduct,
              let litres = Double(comp.litresText),
              litres > 0 else {
            return nil
        }
        let sgValue = sg(for: product)
        return litres * sgValue
    }
    
    var totalMassKg: Double {
        compartments.compactMap { massKg(for: $0) }.reduce(0, +)
    }
    
    //======================================
    // MARK: - Confirm gating (Phase 1)
    //======================================
    //
    // Goal:
    // - Prevent accidental double-confirm of an identical draft.
    // - "Confirm this load" is enabled only if the current draft differs
    //   from the most recent confirmed load of the same mode (Load vs Unload).
    
    var canConfirmCurrentLoad: Bool {
        // If there is literally nothing to confirm, block it.
        let hasAnyLitres = compartments.contains { (Double($0.litresText) ?? 0) > 0 }
        let hasAnyProduct = compartments.contains { $0.selectedProduct != nil }
        
        // LOAD mode: must have litres
        // UNLOAD mode: allow “confirm to zero” as long as products are defined
        if isUnloadMode {
            guard hasAnyProduct else { return false }
        } else {
            guard hasAnyLitres else { return false }
        }
        
        // Compare only against last confirm of the SAME mode (load vs unload planning).
        let sameModeLoads = confirmedLoads.reversed().first { $0.mode == currentConfirmMode }
        guard let lastSameMode = sameModeLoads else { return true }
        
        return draftSignature() != confirmedSignature(for: lastSameMode)
    }
    
    private var currentConfirmMode: ConfirmedLoadMode {
        isUnloadMode ? .unloadSnapshot : .loadConfirmed
    }
    
    private func draftSignature() -> String {
        // Stable signature: mode + per-compartment (name|product|litres)
        // Normalise litres to whole litres (int) to avoid float noise.
        let lines = compartments.map { comp -> String in
            let litresInt = Int((Double(comp.litresText) ?? 0).rounded())
            let prod = comp.selectedProduct?.shortName ?? ""
            return "\(comp.name)|\(prod)|\(litresInt)"
        }
        
        return "\(currentConfirmMode.rawValue)#" + lines.joined(separator: ";")
    }
    
    private func confirmedSignature(for load: ConfirmedLoad) -> String {
        let lines = load.compartments.map { line -> String in
            let litresInt = Int(line.litres.rounded())
            return "\(line.name)|\(line.productShort)|\(litresInt)"
        }
        
        return "\(load.mode.rawValue)#" + lines.joined(separator: ";")
    }
    
    //======================================
    // MARK: - Confirm current load
    //======================================
    
    /// Commits the current Load/Unload state into `confirmedLoads` (session history).
    /// - Load mode: records only compartments with product + litres (>0).
    /// - Unload mode: records a snapshot of remaining on-truck state (includes 0L lines if product is still selected).
    /// This is the ONLY place where totals, axle loads, and DG "last known family" history become authoritative.
    func confirmCurrentLoad() {
        
        // Capture ONE timestamp used for:
        // - segment switch (so timeline stays physically possible)
        // - confirmed load record
        // - event log
        let confirmTime = Date()
        
        if isUnloadMode {
            // Unload mode:
            // Allow confirming snapshots even when litres are 0,
            // as long as there is still product context selected (placarding/history),
            // OR the driver explicitly declared empty via Full Unload / Degas.
            let hasAnyProduct = compartments.contains { $0.selectedProduct != nil }
            guard totalLitres > 0 || hasAnyProduct || unloadFinalised else { return }
            
        } else {
            // Load mode:
            // Require at least one compartment with positive litres AND a product.
            let hasAnyProduct = compartments.contains { comp in
                (Double(comp.litresText) ?? 0) > 0 && comp.selectedProduct != nil
            }
            guard hasAnyProduct else { return }
        }
        
        // --- Segment reconciliation ---
        // Confirming LOAD/UNLOAD means the driver is doing WORK.
        // If they forgot to change segment (e.g., still on Break or Driving),
        // we fix the state at the moment of confirm.
        if isOnDuty {
            // Make UI flags match reality (always do this)
            isDriving = false
            isOnBreak = false
            
            let newType: ActivityType = isUnloadMode ? .workUnload : .workLoad
            
            // Only switch segment if not already in the right mode
            if currentActivity != newType {
                startActivity(newType, at: confirmTime)
            } else {
                // Optional: update timestamp on existing open segment if needed
                // currentSegmentStart = confirmTime  // rare case
            }
        }
        
        // If we are confirming a LOAD, any compartment with product+litres is definitely not degassed.
        for i in compartments.indices {
            let litres = Double(compartments[i].litresText) ?? 0
            if litres > 0, compartments[i].selectedProduct != nil {
                compartments[i].isDegassed = false
            }
        }
        
        // Build compartment snapshots
        var compSnapshots: [ConfirmedCompartment] = []
        
        for comp in compartments {
            let litres = Double(comp.litresText) ?? 0
            
            if isUnloadMode {
                // In unload mode, include compartments that still have a product selected
                // (placarding context), even if litres are 0.
                guard let product = comp.selectedProduct else { continue }
                
                let sgValue = sg(for: product)
                let mass = litres * sgValue
                
                let snap = ConfirmedCompartment(
                    name: comp.name,
                    sfl: comp.capacityLitres,
                    productShort: product.shortName,
                    sg: sgValue,
                    litres: litres,
                    massKg: mass
                )
                compSnapshots.append(snap)
                
            } else {
                // Load mode: only include compartments with positive litres + product.
                guard litres > 0, let product = comp.selectedProduct else { continue }
                
                let sgValue = sg(for: product)
                let mass = litres * sgValue
                
                let snap = ConfirmedCompartment(
                    name: comp.name,
                    sfl: comp.capacityLitres,
                    productShort: product.shortName,
                    sg: sgValue,
                    litres: litres,
                    massKg: mass
                )
                compSnapshots.append(snap)
            }
        }
        
        let load = ConfirmedLoad(
            timestamp: confirmTime,
            mode: isUnloadMode ? .unloadSnapshot : .loadConfirmed,
            terminalName: terminalNameDisplay,
            loadCode: loadCode,
            vehicleId: vehicleId,
            driverName: settings.driverName,
            compartments: compSnapshots,
            totalLitres: totalLitres,
            totalMassKg: totalMassKg,
            steerKg: steerLoadedKg,
            driveKg: driveLoadedKg,
            gvmKg: gvmLoadedKg
        )
        
        confirmedLoads.append(load)
        
        // ✅ Log the event ONCE per load (not per compartment)
        logEvent(isUnloadMode ? .unload : .load, at: confirmTime)
        
        // Reset empty-finalisation after we successfully confirm.
        // (If driver is unloading and then starts loading again, this prevents accidental "empty confirms".)
        unloadFinalised = false
        suppressPlacardUntilNextConfirm = false
        autosave?.requestAutosave(reason: "Confirmed load/unload", immediate: true)
    }

    // MARK: - Typical load templates (pre-persistence)
    
    // NOTE: Used by the "Apply typical load" UI.
    // Do not delete until `typicalLoadTemplates` and `applyTypicalLoad(_:)`
    // are migrated to the unified `LoadTemplate` system.
    struct TypicalLoadTemplate: Identifiable {
        let id = UUID()
        let name: String
        /// Keyed by compartment name, e.g. "C1" → ("DSL", 5000)
        let perCompartment: [String: (productShortName: String, litres: Int)]
    }
    
    //======================================
    // MARK: - Axle load helpers
    //======================================
    private var runningTankMissingKg: Double {
        let f = min(max(fuelFraction, 0), 1)
        return truckConfig.runTankFullKg * (1.0 - f)
    }
    
    private var tareSteerAdjustedKg: Double {
        max(truckConfig.tareSteerKg - runningTankMissingKg * 0.15, 0)
    }
    
    private var tareDriveAdjustedKg: Double {
        max(truckConfig.tareDriveKg - runningTankMissingKg * 0.85, 0)
    }
    
    var steerLoadedKg: Double {
        var total = tareSteerAdjustedKg
        for comp in compartments {
            guard let mass = massKg(for: comp),
                  let split = truckConfig.axleSplitByCompartment[comp.name] else { continue }
            total += mass * split.steerFraction
        }
        
        // Lazy axle up => shift some load off steer (heuristic)
        if truckConfig.hasLazyAxle, lazyAxleIsUp {
            total = max(total - truckConfig.lazyLiftTransferKg, 0)
        }
        
        return total
    }
    
    var driveLoadedKg: Double {
        var total = tareDriveAdjustedKg
        for comp in compartments {
            guard let mass = massKg(for: comp),
                  let split = truckConfig.axleSplitByCompartment[comp.name] else { continue }
            total += mass * split.driveFraction
        }
        
        // Lazy axle up => shift that load onto drives (heuristic)
        if truckConfig.hasLazyAxle, lazyAxleIsUp {
            total += truckConfig.lazyLiftTransferKg
        }
        
        return total
    }
    
    var gvmLoadedKg: Double {
        steerLoadedKg + driveLoadedKg
    }
    
    //======================================
    // MARK: - Load plan helpers
    //======================================
    
    var totalLitres: Int {
        compartments.compactMap { Int($0.litresText) }.reduce(0, +)
    }
    
    var loadPlanProducts: [Product] {
        var result: [Product] = []
        for comp in compartments {
            if let product = comp.selectedProduct,
               let litres = Int(comp.litresText),
               litres > 0 {
                result.append(product)
            }
        }
        return result
    }
    
    // PHASE 1 STUB (kept intentionally).
    // Not used by DG placarding (placarding is compartment-state driven).
    // Retained as a reference point for future multi-product Hazchem logic post-persistence.
    var combinedHazchemForLoad: String {
        let products = loadPlanProducts
        guard !products.isEmpty else { return "—" }
        let hasE = products.contains { $0.hazchem.uppercased().contains("E") }
        let eChar = hasE ? "E" : ""
        return "3Y" + eChar // PHASE1_STUB: real multi-load Hazchem logic deferred until DG history exists
    }
    
    var copyToPaperSummaryLines: [String] {
        compartments.compactMap { comp in
            guard let product = comp.selectedProduct,
                  let litres = Int(comp.litresText),
                  litres > 0 else {
                return nil
            }
            return "\(comp.name): \(product.shortName)  \(litres) L"
        }
    }
    
    /// Applies a load template as a DRAFT ONLY.
    /// - Does not append to `confirmedLoads`.
    /// - DG placard in Load Plan mode should continue showing last confirmed state until `confirmCurrentLoad()`.
    func applyTemplateToLoadPlan(_ template: LoadTemplate) {
        
        // 1) Clear first: blank the plan (NOT "0")
        for i in compartments.indices {
            compartments[i].litresText = ""
            compartments[i].selectedProduct = nil
            compartments[i].isDegassed = false
        }
        
        // 2) Apply each item
        for item in template.items {
            guard let idx = compartments.firstIndex(where: { $0.name == item.compartmentName }) else { continue }
            
            // Product is optional: only set if it matches
            if let prod = product(shortName: item.productShortName) {
                compartments[idx].selectedProduct = prod
                
                // litres: show blank if 0, otherwise the number
                let litres = max(item.litres, 0)
                compartments[idx].litresText = litres == 0 ? "" : "\(litres)"
                
                // SG override: store per product if provided
                if let sg = item.sgOverride {
                    setSg(sg, for: prod)
                }
            } else {
                // If product shortName doesn't match, leave blank
                compartments[idx].selectedProduct = nil
                compartments[idx].litresText = ""
            }
        }
    }
    
    // MARK: - Unload helpers
    
    /// Applies a delivery in UNLOAD mode.
    /// Subtracts delivered litres from the current "remaining" litres (clamped at 0).
    /// Intended to be called by DeliverySheetView to avoid manual maths in the main grid.
    func applyDelivery(compName: String, litresDelivered: Int) {
        guard litresDelivered > 0 else { return }
        guard let idx = compartments.firstIndex(where: { $0.name == compName }) else { return }
        
        let currentRemaining = Int(compartments[idx].litresText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let newRemaining = max(currentRemaining - litresDelivered, 0)
        
        compartments[idx].litresText = String(newRemaining)
        
        // If anything remains, it definitely isn't degassed.
        if newRemaining > 0 {
            compartments[idx].isDegassed = false
        }
        
        // A delivery implies the truck is not in "final empty" state.
        // (Driver can still press Full Unload to explicitly declare empty.)
        unloadFinalised = false
    }
    
    /// Clear litres only — keep product type for placarding.
    func fullUnload() {
        for i in compartments.indices {
            compartments[i].litresText = "0"
        }
        // Driver has explicitly declared: truck is empty (on board inventory)
        unloadFinalised = true
    }
    
    /// Degassed — clear litres AND product types.
    func degasTruck() {
        for i in compartments.indices {
            compartments[i].isDegassed = true
            compartments[i].litresText = "0"
            compartments[i].selectedProduct = nil
        }
        suppressPlacardUntilNextConfirm = true
    }
    
}
