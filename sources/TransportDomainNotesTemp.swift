
// ============================================================

// TransportDomainNotes.swift

// Temporary architectural placeholder

// Purpose: describe the emerging transport layer that will sit

// between core app systems and specific freight modules.

// ============================================================

  

  

// ------------------------------------------------------------

// WHY THIS FILE EXISTS

// ------------------------------------------------------------

//

// The app originally grew around a fuel delivery workflow.

// Many domain nouns (compartment, product, terminal, etc)

// were therefore baked directly into the core app structure.

//

// As the architecture evolves, the system must support

// multiple transport types:

//

// • Fuel tankers

// • Livestock carriers

// • Palletised freight

// • Refrigerated freight

// • Container haulage

//

// To achieve this, a generic TRANSPORT layer will sit between:

//

// Core App Systems

// ↓

// Transport Domain

// ↓

// Specific Modules (Fuel, Livestock, etc)

//

// This file marks the conceptual boundary for that layer.

  

  

// ------------------------------------------------------------

// CORE APP RESPONSIBILITIES (Remain outside Transport)

// ------------------------------------------------------------

//

// Core contains systems that are NOT transport-specific:

//

// • AppModel lifecycle

// • persistence

// • timeline / journal

// • fatigue engine

// • GPS telemetry

// • distance reconciliation

// • UI navigation

// • debugging / telemetry policy

//

// These systems should never contain fuel-specific logic.

  

  

// ------------------------------------------------------------

// TRANSPORT LAYER RESPONSIBILITIES

// ------------------------------------------------------------

//

// The transport layer introduces neutral transport concepts

// that can apply to many types of freight.

//

// Examples:

//

// CargoUnit

// A physical location on a vehicle that can hold cargo.

//

// TransportOrder

// A movement of goods from one place to another.

//

// SiteAsset

// A storage unit or infrastructure element at a site.

//

// CargoMath

// Shared calculations involving:

//

// • quantity

// • mass

// • fill percentage

// • capacity

//

// These concepts allow modules to translate their own

// vocabulary into shared transport behaviour.

  

  

// ------------------------------------------------------------

// EXAMPLE VOCABULARY MAPPING

// ------------------------------------------------------------

//

// Transport concept → Fuel module translation

//

// CargoUnit       → Compartment

// SiteAsset       → Tank

// TransportOrder  → Delivery / Load / Transfer

//

// Other modules will translate differently:

//

// CargoUnit       → Pallet Slot

// CargoUnit       → Livestock Pen

// CargoUnit       → Container Position

  

  

// ------------------------------------------------------------

// DESIGN PRINCIPLE

// ------------------------------------------------------------

//

// Core must never "know about fuel".

//

// Instead:

//

// Core

//   ↕

// Transport concepts

//   ↕

// Module vocabulary

  

  

// ------------------------------------------------------------

// CURRENT STATUS

// ------------------------------------------------------------

//

// The current codebase still contains fuel-specific models

// in the main Models area.

//

// This is expected during transition.

//

// Over time:

//

// • generic concepts move into Transport

// • fuel-specific models move into Modules/Fuel

  

  

// ------------------------------------------------------------

// FUTURE TRANSPORT MODELS (PLACEHOLDERS)

// ------------------------------------------------------------

//

// CargoUnit.swift

// TransportOrder.swift

// SiteAsset.swift

//

// These may start as simple structs or protocols and grow

// as additional transport modules appear.

  

  

// ------------------------------------------------------------

// FUTURE TRANSPORT LOGIC (PLACEHOLDERS)

// ------------------------------------------------------------

//

// CargoMath.swift

// TransportWorkflow.swift

//

// These hold shared behaviours independent of cargo type.

  

  

// ------------------------------------------------------------

// IMPORTANT NOTE

// ------------------------------------------------------------

//

// This file is temporary and exists only to document

// architectural intent while the system transitions.

//

// Once the Transport layer stabilises this file may be:

//

// • moved to Resources

// • replaced with formal documentation

// • or removed entirely.

  

  

// ============================================================

// END OF FILE

// ============================================================
