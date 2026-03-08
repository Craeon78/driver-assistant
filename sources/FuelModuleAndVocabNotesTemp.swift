
// ============================================================

// FuelModuleNotes.swift

// Temporary architectural placeholder

// Purpose: describe the Fuel transport module and how it

// maps generic transport concepts into fuel delivery logic.

// ============================================================

  

  

// ------------------------------------------------------------

// WHY THIS FILE EXISTS

// ------------------------------------------------------------

//

// The current application began as a fuel delivery assistant.

// Many systems therefore assume fuel-specific terminology.

//

// As the architecture evolves, fuel becomes only ONE module

// within a larger transport platform.

//

// This file records the vocabulary mapping and design intent

// for the fuel module.

  

  

// ------------------------------------------------------------

// ROLE OF THE FUEL MODULE

// ------------------------------------------------------------

//

// The Fuel module provides:

//

// • fuel product definitions

// • terminal registries

// • supplier registries

// • load accounts

// • compartment-based truck loading

// • DG placarding logic

//

// These features sit on top of generic transport behaviour.

  

  

// ------------------------------------------------------------

// VOCABULARY TRANSLATION

// ------------------------------------------------------------

//

// Transport Layer Term → Fuel Term

//

// CargoUnit            → Compartment

// SiteAsset            → Underground Tank

// TransportOrder       → Delivery / Load / Transfer

//

// This translation allows the same transport engine to

// support other freight types later.

  

  

// ------------------------------------------------------------

// EXAMPLE OF MODULE SKINNING

// ------------------------------------------------------------

//

// Transport concept:

//

// CargoUnit

//

// Fuel module interpretation:

//

// Compartment

// A tank compartment within a fuel tanker.

//

// Properties may include:

//

// • capacity

// • product type

// • fill level

// • weight contribution

// • axle mass effect

  

  

// ------------------------------------------------------------

// FUEL-SPECIFIC DOMAIN OBJECTS

// ------------------------------------------------------------

//

// Examples currently implemented:

//

// Product

// ProductRegistry

// Supplier

// SupplierRegistry

// Terminal

// TerminalRegistry

// LoadAccount

// LoadAccountRegistry

//

// These objects will eventually live fully inside the

// Fuel module rather than inside the generic Models folder.

  

  

// ------------------------------------------------------------

// DELIVERY SITE STRUCTURE

// ------------------------------------------------------------

//

// A delivery site may contain multiple tanks.

//

// Current company workflow:

//

// • dip tanks before delivery

// • deliver fuel to selected tanks

// • record volumes in external company system

//

// The Driver Assistant app does NOT attempt to replicate

// full inventory management systems like SmartFill.

//

// Instead the app focuses on:

//

// • planning

// • verification

// • driver assistance

// • mass simulation

// • operational awareness

  

  

// ------------------------------------------------------------

// IMPORTANT DESIGN LIMIT

// ------------------------------------------------------------

//

// The app intentionally avoids becoming a full fuel

// inventory management platform.

//

// Systems such as SmartFill already perform that role.

//

// The driver assistant only captures data that directly

// assists the driver during a shift.

  

  

// ------------------------------------------------------------

// FUTURE MODULE STRUCTURE

// ------------------------------------------------------------

//

// Modules

//   └ Fuel

//       ├ Models

//       ├ Logic

//       ├ Assets

//       └ UI

//

// Fuel-specific code should migrate here over time.

  

  

// ------------------------------------------------------------

// POSSIBLE FUTURE TRANSPORT MODULES

// ------------------------------------------------------------

//

// Livestock

// Refrigerated Freight

// Palletised Freight

// Container Transport

//

// Each module will translate transport concepts into its

// own domain vocabulary.

  

  

// ------------------------------------------------------------

// CURRENT STATUS

// ------------------------------------------------------------

//

// The system is mid-transition.

//

// Fuel logic still exists in multiple areas of the codebase:

//

// • Models

// • AppModel extensions

// • UI layers

//

// These will gradually consolidate into the Fuel module

// once the Transport layer stabilises.

  

  

// ------------------------------------------------------------

// TEMPORARY FILE NOTICE

// ------------------------------------------------------------

//

// This file exists only to guide architecture during

// refactoring.

//

// Once the module structure is fully implemented this file

// can be:

//

// • moved to Resources

// • replaced with formal documentation

// • or removed.

  

  

// ============================================================

// END OF FILE

// ============================================================
