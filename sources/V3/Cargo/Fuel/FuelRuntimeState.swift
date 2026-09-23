import Foundation

/// Fuel-module runtime state extracted from the application shell.
/// Fuel owns fuel-cargo workflow state; it does not own Driver, Vehicle, GPS or fatigue truth.
struct FuelRuntimeState {
    var compartments: [CompartmentModel] = []
    var confirmedLoads: [ConfirmedLoad] = []
    var isUnloadMode = false
    var unloadFinalised = false
    var suppressPlacardUntilNextConfirm = false
    var sgOverrides: [UUID: Double] = [:]

    var terminalName = "BP"
    var loadCode = "6750"
    var selectedSupplierID: UUID?
    var resolvedSupplierName = ""
    var resolvedTerminalName = ""

    var loadAccountCandidates: [LoadAccount] = []
    var loadAccountResolveHint: String?
    var resolvedTerminalID: UUID?
    var resolvedLoadAccountID: UUID?
    var typedLoadNumber = ""
    var loadAccountResolveError: String?
    var loadAccountAmbiguousMatches: [LoadAccount] = []

    var savedTemplates: [LoadTemplate] = []
    var draftTemplate = LoadTemplate(
        name: "New template",
        items: [
            .init(compartmentName: "C1", productShortName: "DSL", litres: 0),
            .init(compartmentName: "C2", productShortName: "P91", litres: 0),
            .init(compartmentName: "C3", productShortName: "DSL", litres: 0),
            .init(compartmentName: "C4", productShortName: "DSL", litres: 0),
            .init(compartmentName: "C5", productShortName: "DSL", litres: 0)
        ]
    )

    var loadCodeCanonical: String {
        loadCode.replacingOccurrences(of: " ", with: "")
    }
}
