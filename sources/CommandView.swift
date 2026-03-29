//======================================
// MARK: - CommandView
//======================================
//
// Path:
// - Views/Screens/CommandView.swift
//
// Purpose:
// - Lightweight in-app command surface for accessing secondary modules.
//
// Responsibilities:
// - Present a simple menu of available tools/modules.
// - Handle local navigation between command sections:
//   - menu
//   - journal
//   - truck
//   - numbers
// - Host each module as a full-frame replacement within the same view
//   (no navigation stack required).
//
// Notes:
// - This is an isolated utility surface, not part of the primary driver flow.
// - Navigation is intentionally local and state-driven (enum-based),
//   avoiding global routing complexity.
// - Modules presented here are expected to manage their own internal state
//   and lifecycle.
//
// Future direction:
// - May evolve into a more structured command palette or tool hub.
// - Could adopt a unified routing mechanism if cross-module navigation grows.
//======================================

import SwiftUI

enum CommandSection: String, Identifiable {
    case menu, journal, truck, numbers
    var id: String { rawValue }
}

struct CommandView: View {
    @State private var section: CommandSection = .menu
    
    var body: some View {
        ZStack {
            switch section {
            case .menu:
                menu
            case .journal:
                JournalSheet(onClose: { section = .menu })
            case .truck:
                TruckProfile2DSheet(onClose: { section = .menu })
            case .numbers:
                NumbersSheet(onClose: { section = .menu })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var menu: some View {
        VStack(spacing: 16) {
            Text("Command").font(.largeTitle.bold())
            Text("Pick a module.").foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                Button("Journal") { section = .journal }
                Button("Truck")   { section = .truck }
                Button("Numbers") { section = .numbers }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
}
