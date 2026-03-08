---

type: canonical-snapshot

snapshot_role: resources

project: DriverAssistant

version: v0.2.6

snapshot_id: 20260308-1530

date: 08-Mar-2026

timezone: Australia/Brisbane

paired_code_snapshot: Snapshot-v0.2.6

device_reference: iPad8,10 / iOS 26.2.1

  

copyrighted: © 2026 Cory Russell Olsen. All rights reserved.

This snapshot and its contents are proprietary and confidential.

---

  

# Snapshot Resources – Driver Assistant (CANONICAL SUPPORT FILE)

  

This file contains the **supporting material** for the Driver Assistant canonical snapshot.

  

It is paired with the executable code snapshot:

  

**Snapshot – Driver Assistant (CANONICAL CODE SNAPSHOT)**

  

Together the two files represent the **complete project state at the time of capture.**

  

• Snapshot (code) → executable source files  

• Snapshot Resources (this file) → architecture, registries, notes, and reference material  

  

If any discrepancy exists between documentation and code, **the code snapshot takes precedence.**

  

---

  

# 0. Resource Scope

  

Includes:

  

• PATCHLOG history  

• Architecture notes  

• Domain modelling notes  

• Registry seed definitions (terminals, suppliers, load accounts, products)  

• Future design notes  

• Reference diagrams or explanations  

• Development philosophy and guardrails  

  

Excludes:

  

• `.swift` runtime source files  

• Any code required for compilation  

• Build configuration  

• Derived data  

  

Executable code exists only in the **paired code snapshot**.

  

---

  

# 1. Canonical Rules

  

1. This file documents **why the code exists**, not the code itself.

  

2. Registry examples may appear here for documentation purposes, but the **authoritative runtime version exists in the code snapshot**.

  

3. This file may include:

   - partial code examples

   - pseudocode

   - architectural sketches

  

4. These examples are **non-authoritative** and must not be treated as executable truth.

  

---

  

# 2. Snapshot Context

  

Build status of paired snapshot:

  

Compiles: YES  

Runs on device: YES  

  

Test device reference:

  

iPad8,10 / iOS 26.2.1

  

---

  

# 3. Major Architecture Themes

  

Current development direction:

  

• Modular transport domain architecture  

• Separation of **core transport concepts** from **fuel-specific implementation**  

• Movement toward persistence-backed **Event Journal**

  

Strategic layers:

  

1. Live State Engine  

2. Asset Registry  

3. Event Journal  

  

Future strategic layer:

  

Command

  

• Journal  

• Truck  

• Numbers  

  

Navigation philosophy:

  

• Command accessible anytime  

• No automatic activity switching  

• Motion-aware logging  

• “Coach, not nanny” interaction model

  

---

  

# 4. AI / Codex Orientation (Repository Map)

  

Purpose:

  

This section provides **high-level orientation for AI coding agents and future maintainers**.

  

The Driver Assistant project follows these structural boundaries.

  

Core principles:

  

• ODO readings are **authoritative truth for distance**  

• GPS distance is **evidence used for correction modelling**  

• Fatigue calculations must never depend on GPS distance alone  

• Driver-entered data always overrides inferred telemetry

  

Primary runtime domains:

  

Core  

• fatigue engine  

• shift timeline  

• event journal  

• location services  

  

TransportDomain (future intermediary layer)  

• cargo units  

• stops  

• transactions  

• quantities  

  

FuelDomain (current specialization)  

• compartments  

• DG placarding  

• terminal loading  

• product SG calculations  

  

UI layers:

  

Views  

• Today  

• Load  

• Map  

• Sim  

• Debug Dashboard  

  

Data sources:

  

Asset registries provide static seed data for:

  

• terminals  

• suppliers  

• load accounts  

• products  

  

These registries will eventually migrate to **JSON-backed persistence**.

  

---

  

# 5. Resource Manifest

  

This snapshot contains the following resource files:

  

- RESOURCES/ArchitectureNotes.md

- RESOURCES/GPS Integration.md

- RESOURCES/GPS Philosophy.md

- RESOURCES/JSON SQLite Persistence Plan.md

- RESOURCES/Learnings.md

- RESOURCES/PATCHLOG.md

- RESOURCES/Persistence Plan.md

- RESOURCES/PricingTiers.md

- RESOURCES/SettingsBehaviourContract.md

- RESOURCES/Todo.md

  

---

  

# RESOURCES (Markdown Only)

  

---

  

## RESOURCES/ArchitectureNotes.md

  

```markdown

Architecture Notes – v0.3 (Persistence-Ready, Pre-Implementation)

  

This document captures architectural decisions informed by:

    •    real-world driving context

    •    regulatory constraints (NHVR, DG)

    •    iterative hands-on development

    •    preparation for future persistence

  

This is not a refactor plan.

This is a guardrail document to prevent accidental architectural drift.

  

⸻

  

What Changed Since v0.2 (Reality Check)

  

Despite earlier intent to delay structural work:

    •    AppModel extensions were split into an AppModels folder

    •    Views were explicitly separated into Screens / Partials / Components / Sheets

    •    Several large views were decomposed for cognitive load reasons

    •    Folder structure now mirrors conceptual ownership, not just file type

  

These changes were:

    •    deliberate

    •    contained

    •    pre-persistence safe

  

They do not introduce persistence, hidden coupling, or premature abstraction.

  

⸻

  

AppModel Structure (v0.3 → v0.1.303 milestone)

  

AppModel has been split for readability using extensions and grouped into an AppModels/ folder:

  

• AppModel.swift  

  = Core observable state + init + high-level orchestration  

  = Owns autosave controller hookup (crash insurance only)  

  = Remains the single source of runtime truth  

  

• AppModel+ShiftActions.swift  

  = Shift / drive / break lifecycle actions  

  = Segment transitions + activity state control  

  

• AppModel+RestLogic.swift  

  = Fatigue/rest calculations + planners  

  = NHVR legality engine (no UI interpretation logic)  

  

• AppModel+OdoCapture.swift  

  = Odo/suburb capture flow  

  = Gating logic for shift start / break qualification  

  

• AppModel+LoadPlan.swift  

  = Load plan helpers + totals  

  = Confirm logic + axle load calculations  

  = Transactional behaviour (pre-persistence, session-bound)  

  

• AppModel+TemplatesAndSimulation.swift  

  = Templates + simulation hooks  

  = Draft manipulation only (never authoritative history)  

  

• AppModel+DGPlacard.swift  

  = DG state mapping + placard decision  

  = Compartment-state driven (no fabricated history)  

  

• AppModel+Timeline.swift  

  = Timeline projection for UI  

  = Derives segments + events for display  

  = Does not persist independently  

  

• AppModel+Guard.swift  

  = High-level workflow guards  

  = Prevent illegal state transitions (e.g. conflicting activities)  

  

• AppModel+GuardHelpers.swift  

  = Small reusable guard utilities  

  = Shared validation logic used across shift/load flows  

  

• AppModel+Incident.swift  

  = Incident draft lifecycle + event logging  

  = Guidance only (pre-authoritative)  

  = Does not mutate driving/break state automatically  

  

• AppModel+GPS.swift  

  = GPS ingestion + motion-state inference  

  = Evidence-based interpretation (speed/location as signals only)  

  = No authority; no retroactive correction  

  

Persistence (current phase)

- Autosave snapshots provide crash insurance only.

- Resume flow restores in-memory shift state when available.

- No multi-day querying or authoritative history yet.

- AppModel remains persistence-agnostic beyond autosave injection.

  

This is still a single domain model object (one ObservableObject).

We have deliberately NOT split into multiple managers/services/repositories yet.

  

Reason:

Pre-authoritative persistence, we want:

- One obvious source of runtime truth

- Clear orchestration

- No cross-object race conditions

- Maximum debuggability

  

Splitting into repositories/services happens when SQLite becomes the authoritative truth store.

  

⸻

  

Accepted Third-Party & Self-Review Observations

  

    •    AppModel remains a single domain authority by design  

         Split by file, not by ownership. Still one source of domain truth.

  

    •    Magic numbers still exist  

         Acceptable temporarily, but now clearly isolated and discoverable.

  

    •    Fatigue logic must be fully deterministic from stored events  

         No rolling counters, no hidden state.  

         Determinism applies across restarts and imports.

  

    •    Constants must be centralised before persistence  

         Partial progress made; final extraction deferred intentionally.

  

    •    UI state must never leak into persisted state  

         This rule remains absolute.

  

⸻

  

Architectural Rationale — Base Truth vs Behaviour (v0.3 Addendum)

  

This section captures foundational reasoning behind modularisation, motion handling, and freight abstraction.

It exists to prevent accidental coupling of physics, rules, UI, or advisory logic as the app expands beyond fuel use cases.

  

---

  

1. Physics Is Universal; Freight Is Behavioural

  

Gravity, mass, and geometry apply identically regardless of freight type:

    •    liquid fuel

    •    solid freight

    •    DG

    •    livestock

    •    machinery

  

Differences between freight types do not alter gravity or axle mathematics.

They introduce constraints and behaviour, not new physics.

  

Therefore:

    •    Axles, chassis geometry, and mass distribution form a base, freight-agnostic layer

    •    Freight modules (fuel, DG, general freight, livestock) are clients of the mass engine

    •    Safe Fill Levels (SFL), slosh, restraint rules, segregation, and handling risks belong to storage or rules layers, not physics

  

This separation is non-negotiable.

  

---

  

2. Longitudinal Geometry Is the Dominant Axis (Australian Context)

  

Australian heavy vehicles operate within a largely fixed width envelope (~2.44–2.50 m).

Meaningful compliance, mass, and handling variation occurs along the length of the vehicle.

  

As a result:

    •    Side-profile (2D longitudinal) modelling is the correct abstraction, not a simplification

    •    Axles are treated as points along a longitudinal axis

    •    Freight storage is treated as segments along that axis

    •    Width and lateral CG are intentionally abstracted away until oversized or specialised modules exist

  

This mirrors real-world engineering practice and driver mental models.

  

---

  

3. Motion Telemetry Is Evidence, Not Authority

  

GPS speed, course, and location are treated as signals, not truth.

  

They are:

    •    noisy

    •    lossy

    •    environment-dependent (yards, terminals, urban canyons)

  

The system must degrade gracefully under uncertainty.

  

Therefore:

    •    Motion states (accelerating, decelerating, cruising, crawl, stopped, unsure) are descriptive only

    •    They do not directly drive decisions without context

    •    No module may assume motion telemetry is perfect or continuous

  

---

  

4. Context Dominance Over Telemetry

  

Human activity context dominates raw motion data.

  

In real freight operations:

    •    High speed → driving context

    •    Sustained low or zero speed → work or off-duty context

    •    Work context overwhelmingly implies loading, unloading, or task dwell — regardless of freight type

  

Accordingly:

    •    Two invisible overarching contexts exist:

         – Driving-dominant

         – Non-driving (work / off-duty) dominant

    •    When non-driving context is active:

         – Motion state precision is deprioritised

         – GPS noise is tolerated

         – Focus shifts to load/unload, dwell, and task duration

  

Downstream modules must consult context first, not raw motion state.

  

---

  

5. Modularity Justification (Why This Is Not Premature Abstraction)

  

Fuel is treated as the first customer, not the foundation.

  

This validates:

    •    storage behaviour modules (liquid vs solid)

    •    DG placarding logic

    •    segregation rules

    •    future freight types

  

The base system intentionally models:

    •    axles

    •    chassis

    •    mass

    •    time

    •    motion signals

  

Freight types:

    •    add constraints

    •    add advisory logic

    •    add compliance hints

    •    never alter base physics

  

This architecture enables:

    •    bolt-on freight modules

    •    data packs

    •    AI advisory layers

    •    future monetisation without undermining trust

  

---

  

6. Explicit Non-Goals (Reaffirmed)

  

The app does not attempt to:

    •    model full 3D vehicle dynamics

    •    simulate lateral roll or sway

    •    guarantee regulatory correctness

    •    replace driver responsibility

    •    silently enforce DG segregation rules without user confirmation

  

Advisory ≠ Authority.

  

Driver Assistant is evolving from operational tool

to single-operator transport system:

Execution + Asset + Financial oversight.

⸻

  

Current Structural Intent (v0.3)

  

AppModels

    •    AppModel.swift = state + orchestration

    •    AppModel+X.swift = domain-specific logic slices

    •    No authoritative persistence assumptions (yet)

    •    No UI concepts allowed

  

Logic

    •    Stateless or semi-stateless engines

    •    Calculations, rules, policy

    •    No SwiftUI imports

  

Models

    •    Plain data structures

    •    Codable readiness preferred but not enforced yet

  

Persistence (Phase 0 / pre-SQLite)

    •    autosave snapshots as crash insurance

    •    resumability on relaunch (restore-if-available + user prompt)

    •    debug tooling to inspect autosave files

    •    not authoritative history / multi-day rules yet

Services

    •    constants and location managers etc

  

Views

    •    Screens → top-level navigable views

    •    Partials → structural subviews owned by a Screen

    •    Components → reusable UI building blocks

    •    Sheets → modal / transient UI

  

Stable heading into authoritative persistence (SQLite truth store).

  

⸻

  

Deferred Refactors (Reaffirmed – Still Explicitly NOT Doing)

  

    •    Splitting AppModel into multiple manager objects

    •    Protocol-driven architecture / dependency injection

    •    Repository pattern

    •    Abstract fatigue engine interfaces

    •    Formal unit test suite

  

Reason remains unchanged:

These add cognitive and maintenance overhead before persistence exists.

  

⸻

  

Active Guardrails (Non-Negotiable)

  

    •    ❌ No new business logic in Views

    •    ❌ No persistence of derived values

    •    ❌ No mutation of fatigue state outside AppModel

    •    ❌ No refactors “for cleanliness”

    •    ❌ No hidden time-based logic

    •    ❌ No persistence writes from Views

    •    ✅ Append-only event thinking

    •    ✅ Deterministic recomputation

    •    ✅ Explicit ownership of logic

    •    ✅ Folder structure reflects responsibility

  

⸻

  

Persistence Preconditions (Updated)

  

Before introducing the SQLite “truth store”, the following MUST be true:

  

• Truth model is locked:

  - What counts as an authoritative fact (events, segments, odo captures, confirmed loads)

  - What is derived (fatigue totals, warnings, summaries) and never stored as authority

  - What is UI-only (focus state, sheet state, sim state) and never persisted

  

• Identity + IDs are stable:

  - Shift IDs and primary keys are stable and never reused

  - Evidence records have timestamps + provenance fields (created_at, source/import)

  

• Ordering & idempotency rules exist:

  - Events can be replayed deterministically (ordering contract)

  - Writes are idempotent (no accidental duplicates on resume/crash recovery)

  

• Minimal inspection tooling exists:

  - A “debug/export view” to list: latest shift, events, segments, odo captures, confirmed loads

  - A visible marker when debug mode/time offset is active (if you implement it)

  

NOT required before persistence (can be phased later):

• Full enumeration of NHVR vs company fatigue rules

• Final DG placard logic (as long as confirmed load snapshots are stored correctly)

• All regulatory constants extracted (only those needed for current UI/logic)

  

---

  

Architectural North Star

  

If the app crashes and reloads, every regulatory and fatigue-relevant decision must be reproducible from stored events alone.

  

If a feature violates that principle, it does not ship.

  

*************************

DATA PACKS!!

*************************

  

### Driver Assistant — Architecture Intent

### Persistence & Data Pack Strategy (v0.1.280 era)

  

Status:

- App version v0.1.303 is stable, usable, and intentionally beginning-persistence.

- No architectural changes are required at this stage.

- This document captures intent so future decisions remain aligned.

  

---

  

### Core Philosophy

  

- Infrastructure first, community first.

- Data is additive, opt-in, and reversible.

- Persistence must not block future mod / pack extensibility.

- Never persist raw strings where stable IDs will exist later.

  

---

  

### Post-Persistence Data Layers

  

### 1. Core Data (Shipped, Read-Only)

- Implemented as built-in “Core Packs”.

- Stored in the app bundle.

- Versioned and immutable at runtime.

  

Examples:

- Public terminals

- Regions (states + major hubs)

- Default truck packs

- Canonical product definitions

  

Core data behaves like a first-party mod pack.

  

---

  

### 2. User Data (Persistent, Editable)

Stored in the user database:

  

- Driver-created content:

  - My Places

  - My Trucks

  - Load templates

- User settings:

  - Enabled regions

  - Enabled packs

  - UI preferences

- Operational history:

  - Confirmed loads

  - Odometer captures

  - Shift records

  

User data references core / pack data by ID only.

User data never duplicates core data.

  

---

  

### 3. Data Packs (“Mods”)

Data-only bundles that add content.

  

Examples:

- Truck Packs

- Place Packs

- Load Template Packs

- (Later) Rest / Stop Packs, Knowledge Packs

  

Rules:

- Data only (no code).

- Additive only (no overrides).

- No silent updates.

- Enable / disable freely.

- Removal must not break historical records.

  

---

  

### Persistence Rule (Critical)

  

Packs and templates may populate reference tables or user templates, but never create or mutate authoritative history records.

  

All persisted records store:

- A stable ID reference.

- A display snapshot captured at the time of record creation.

  

Example:

- terminalClientId = "core.au.qld.whinstanes.united"

- displayAtTime = "ATOM Whinstanes · United"

  

If a pack is removed or renamed, history remains readable.

  

---

  

### ID Strategy

  

IDs must be:

- Stable

- Namespaced

- Never deleted (only deprecated or aliased)

  

Examples:

- core.au.qld.whinstanes

- core.au.qld.whinstanes.united

- pack.community.seq.truckstops.v1

- user.<uuid>

  

---

  

### Resolver Model

  

At runtime:

1. Load core pack(s).

2. Load enabled data packs.

3. Build an in-memory index.

4. Resolve IDs to objects.

5. Gracefully fall back when references are missing.

  

---

  

### Settings Interaction

  

Settings persist:

- Enabled regions

- Enabled packs

- Selected truck (by ID)

- User overrides (hidden items, nicknames, favourites)

  

Settings never duplicate pack data.

  

---

  

### Development Workflow (Debug Builds Only)

  

Core data is developed using the same pack system.

  

### Runtime Debug Tools (v0.1.303 – Implemented)

    •    Debug Dashboard (dev-only)

    •    State inspector

    •    Timeline viewer

    •    Confirmed load viewer

    •    Autosave inspection + file stats

    •    Manual autosave flush

    •    Clear autosaves

    •    In-memory shift wipe

    •    ODO deadlock trigger

    •    Resume recovery flow testing

  

### Pack / Sandbox Tools (Planned – Post-Persistence)

    •    Purge user data

    •    Import/export pack

    •    Promote sandbox

    •    Validate IDs

    •    Region reference checks

### Promotion Rules

- Only reference data is promotable (places, trucks, templates).

- History data is never promoted.

- Promotion generates a versioned pack file.

- Developer manually commits pack into app bundle.

  

---

  

### Monetisation Alignment

  

- Core infrastructure: free.

- Community sharing: free.

- Data packs: free to import and share.

- Paid features are reserved for:

  - Fleet control

  - Governance and locking

  - Advanced reporting

  - Liability-bearing features

  

---

  

### Explicit Non-Goals

  

- No self-modifying production app.

- No remote forced updates.

- No claims of regulatory authority.

- No silent behavioural changes from packs.

  

---

  

### Activation Point

  

    •    Layer 0 (Autosave + resumability) landed in v0.1.292.

    •    v0.1.303 = persistence phase active; Layer 1 (SQLite truth store) now underway.

    •    This document exists to preserve intent and guide future implementation.

  

# Transport Domain Layer — Architecture Notes

  

## Purpose

Introduce a TransportDomain layer between the App Core and industry modules (e.g. Fuel Delivery).  

This prevents the core engine from being tightly coupled to fuel terminology and allows future modules such as:

  

- livestock transport

- pallet freight

- refrigerated freight

- container haulage

- bulk commodities

  

The goal is to define a generic transport vocabulary that any industry module can translate into driver-facing language.

  

---

  

# Layer Architecture

  

App structure should evolve toward:

  

Core  

↓  

TransportDomain  

↓  

Industry Modules (Fuel, Livestock, Pallets, Containers, etc)

  

---

  

## Core Layer

Contains application infrastructure only.

  

Examples:

  

- GPS location services  

- fatigue engine  

- journal / event logging  

- persistence layer  

- vehicle geometry helpers  

- app lifecycle management  

- debugging tools  

  

The Core must not contain industry nouns such as:

  

- compartments  

- diesel  

- terminals  

- pallets  

- cattle  

  

Core handles mechanics and evidence streams only.

  

---

  

## TransportDomain Layer (new intermediary)

  

Defines generic transport concepts used by all freight industries.

  

These are the shared nouns and actions involved in moving cargo.

  

Primary domain entities:

  

- Vehicle  

- CargoModule  

- CargoUnit  

- Site  

- StorageUnit  

- Transaction  

- OperationEvidence  

- QuantityValue  

  

These must remain industry neutral.

  

---

  

# Core Domain Concepts

  

## Vehicle

A transport platform capable of carrying cargo.

  

Typical properties:

  

- axles  

- tare mass  

- geometry  

- attachment points  

- centre-of-gravity calculations  

  

Examples of vehicles:

  

- fuel tanker  

- livestock truck  

- refrigerated trailer  

- container chassis  

- flatbed  

  

Vehicle behaviour belongs in TransportDomain because it applies to all freight.

  

---

  

## CargoModule

A physical structure attached to a vehicle that holds cargo.

  

Examples by industry:

  

Fuel  

- tank barrel

  

Livestock  

- livestock body

  

Freight  

- curtainsider body  

- refrigerated box

  

Containers  

- container chassis + container

  

Modules may be:

  

- permanent  

- removable  

- swappable  

  

Example module behaviour types:

  

- Fixed  

- SwapOnly  

- UnloadWhileMounted  

- TransferCapable  

  

---

  

## CargoUnit

A subdivision inside a module where cargo resides.

  

Examples by industry:

  

Fuel  

- compartment

  

Livestock  

- deck / pen

  

Pallet freight  

- pallet slot / freight zone

  

Refrigerated freight  

- temperature zone / pallet area

  

Containers  

- container position  

- internal freight zones (if hand-unloading)

  

Internally, the system treats all cargo units as:

  

CargoUnit  

- capacity  

- quantity  

- mass  

- position  

  

Industry modules translate these into driver-facing terminology.

  

---

  

## Site

A geographic stop where an operation occurs.

  

Examples:

  

- terminal  

- depot  

- customer site  

- farm  

- port  

- warehouse  

- service station  

  

Sites remain generic.  

Industry modules determine how the site is interpreted.

  

---

  

## StorageUnit (optional)

Some sites contain structured storage elements.

  

Examples:

  

Fuel  

- underground tanks

  

Warehouses  

- loading docks

  

Ports  

- container stacks

  

Not every site requires structure.

  

Sites may be:

  

- unstructured  

- lightly structured  

- fully structured  

  

Structure should only be created where it improves driver workflow.

  

---

  

## Transaction

A cargo movement or operation occurring at a stop.

  

All transport industries reduce to a small set of operational actions.

  

Common transaction types include:

  

- Load / Pickup  

- Unload / Deliver  

- Transfer  

- Swap / Attach / Detach  

- Inspect / Observe  

  

Examples by industry:

  

Fuel  

- load from terminal  

- deliver to tank  

- transfer between compartments  

  

Livestock  

- load animals  

- unload animals  

- inspect head count  

  

Freight  

- pickup pallets  

- deliver pallets  

  

Containers  

- pickup container  

- drop container  

- unload contents  

  

---

  

## OperationEvidence

Driver observations captured during an operation.

  

Examples:

  

- tank dip before loading  

- container seal check  

- pallet count verification  

- livestock headcount  

  

Evidence belongs to an event, not to a continuous tracking system.

  

Typical structure:

  

beforeObservation  

movedQuantity  

expectedAfter  

  

This preserves driver evidence without turning the app into an inventory system.

  

---

  

# Industry Modules

  

Industry modules sit above TransportDomain and translate concepts into domain language.

  

Example mapping: TransportDomain → Fuel Module

  

CargoUnit → Compartment  

Site → Terminal / Customer  

StorageUnit → Tank  

QuantityValue → Litres  

CargoItem → Fuel Product  

  

Example mapping: TransportDomain → Livestock Module

  

CargoUnit → Deck / Pen  

QuantityValue → Head Count  

CargoItem → Animal Type  

  

Example mapping: TransportDomain → Pallet Freight

  

CargoUnit → Pallet Slot  

QuantityValue → Pallet Count  

CargoItem → Freight SKU  

  

Drivers never see TransportDomain terminology.  

They only see industry-specific language supplied by the module.

  

---

  

# Design Philosophy

  

1. Core contains mechanics, not industry vocabulary.

  

2. TransportDomain contains generic transport concepts.

  

3. Industry modules translate those concepts into driver language.

  

4. The architecture must allow additional freight types without rewriting the engine.

  

---

  

# Guiding Question

  

When designing new functionality ask:

  

“Would this concept exist in any transport industry, or only in fuel?”

  

If the answer is any industry, the concept belongs in TransportDomain.

  

If the answer is fuel only, the concept belongs in the Fuel module.

  

---

  

# Long-Term Vision

  

This structure allows Driver Assistant to evolve from a:

  

Fuel Driver App

  

into a modular system:

  

Transport Operations Platform

  

where different transport industries operate on the same core engine while presenting different terminology and workflows to the driver.

```

  

---

 
  ## RESOURCES/GPS Integration.md
  

```markdown

# GPS System Roadmap v0.3 (Pre-SQLite Phase)

  

This document defines system invariants for GPS estimation and correction learning.

Thresholds may be tuned.

Invariants must not be violated.

  

Scope:

Stabilise real-time GPS distance estimation, correction-factor learning,

and background gap detection.

  

No persistence-layer changes in this phase.

No history rewriting.

OdoCapture remains the single immutable truth anchor.

  

------------------------------------------------------------

1. Truth Hierarchy (Immutable Order)

------------------------------------------------------------

  

1. OdoCapture = absolute, immutable truth anchor.

2. GPS = estimator only (never authoritative).

3. Gap adjustments = advisory patches only (never used for learning).

4. Correction factor learns only from closed spans anchored by OdoCapture.

  

------------------------------------------------------------

2. Span Model

------------------------------------------------------------

  

Closed Span:

Distance between two consecutive confirmed OdoCapture anchors.

Immutable once closed. Never rewritten.

  

Open Span:

Distance accumulated since the last OdoCapture.

Mutable until next anchor.

Finalised only at span closure.

  

New OdoCapture event:

- Closes current open span.

- Opens new span from this anchor forward.

- Must not modify any prior closed spans.

  

------------------------------------------------------------

3. GPS Distance Accumulation Rules

------------------------------------------------------------

  

Single global LocationManager.

No restart during shift.

  

Raw accumulation:

Sum of delta distances between accepted location samples.

  

Sample acceptance criteria (controlled filters, tunable):

- horizontalAccuracy ≤ 30 m (adjustable via DebugDashboard)

- sample age ≤ 15 seconds

- reject extreme jump anomalies (e.g., unrealistic speed spike)

- crawl / slow movement must count

- gaps detected and recorded (never silently ignored)

  

Required telemetry (DebugDashboardView):

- acceptedSamples

- rejectedByAccuracy

- rejectedByJump

- gapCount

- maxGapSeconds

- gpsKmRaw

- gpsKmFiltered (if filtering enabled)

  

------------------------------------------------------------

4. Background Gap Handling (Advisory Only)

------------------------------------------------------------

  

Trigger:

App loses focus → capture start anchor (if quality acceptable).

App regains focus → capture end anchor.

  

Evaluation:

If time gap ≥ 45 s AND straight-line distance ≥ 800 m:

- Attempt road distance via MapKit routing (automobile, no alternates).

- If routing unavailable:

    Option A: fallback straight-line × 1.2 (log as low-confidence)

    Option B: prompt manual OdoCapture (preferred when offline)

- Calculate suggested odo delta (rounded visually to whole km).

  

UI Surface:

Far-left warning triangle turns amber.

  

Card shows:

⚠️ App paused for ~18 min

Estimated road distance: 12.4 km

Suggested odo: 1,059,042 (+12 km)

  

[ Accept ]  [ Edit… ]  [ Ignore ]

  

Rules:

- Never auto-apply.

- Gap adjustments do NOT feed correction factor.

- Large gaps (>50 km) flagged as manual review recommended.

- All outcomes logged.

  

------------------------------------------------------------

5. Raw vs Filtered Source Selection

------------------------------------------------------------

  

During open span track both:

- gpsKmRaw

- gpsKmFiltered (if enabled)

  

At span closure (new OdoCapture):

- Compute absolute error vs odoDelta for both sources.

- Choose source with lower absolute error.

- Log chosen source.

- Use chosen source consistently for:

    - Final span distance

    - Correction factor update

  

Rules:

- No mid-span switching.

- No blended or weighted source mixing.

- No silent switching.

  

------------------------------------------------------------

6. Correction Factor Learning

------------------------------------------------------------

  

Only at span closure:

  

odoDelta = newOdo - lastAnchorOdo

gpsWindow = chosenSourceDistance

windowFactor = odoDelta / gpsWindow

  

Update effectiveFactor via adaptive blending:

  

Embryonic → aggressive update

Stabilising → moderate update

Mature → light update

  

Rules:

- No mid-span updates.

- No updates from gap adjustments.

- Clamp factor within sanity bounds (initially 0.85–1.15).

- Log every update + maturity state.

  

------------------------------------------------------------

7. Maturity States (Session-Based)

------------------------------------------------------------

  

States:

Embryonic → Stabilising → Mature → Drifting

  

Determined by:

- Number of OdoCapture anchors

- Recent drift magnitude

- Factor variance over last N spans

  

Behaviour:

- Suggestion frequency decreases with maturity.

- Suggestions only when stationary/safe.

- Never block driving.

  

------------------------------------------------------------

8. Calibration (Future Tool – Epoch Reset Model)

------------------------------------------------------------

  

Calibration = controlled, high-confidence span.

  

If passes quality checks:

- Set effectiveFactor = calibrationFactor (hard reset).

- Begin new calibration epoch.

- Reset drift/variance metrics.

- Enter short verification phase.

  

Rules:

- Does not rewrite history.

- Not blended like normal spans unless calibration quality insufficient.

- Calibration suggestion suppressed until at least two normal anchors occur,

  unless drift exceeds hard threshold.

  

------------------------------------------------------------

9. Non-Negotiable Invariants

------------------------------------------------------------

  

- No silent corrections ever.

- No rewriting of closed spans.

- Correction factor updates only from OdoCapture-anchored closed spans.

- Gap adjustments never feed correction factor.

- No auto-apply of gap patches.

- No mid-span learning.

- No source switching mid-span.

- All source selections, factor updates, and gap outcomes logged.

  

------------------------------------------------------------

END OF v0.3 GPS ARCHITECTURE

------------------------------------------------------------
```

  

---

  


## RESOURCES/GPS Philosophy.md

  

```markdown

### GPS Philosophy — Driver Assistant

  

This app prioritises **truth over apparent accuracy**.

  

GPS data is treated as *fallible evidence*, not authority. The system must never invent movement, distance, or certainty that was not observed.

  

### Core Principles

  

- Truth beats cosmetic accuracy

- Uncertainty is information, not failure

- Sensors are witnesses, not judges

- State and physics outweigh single samples

- Human confirmation is authoritative when uncertainty matters

  

### Speed Display States

  

Speed is a **verdict**, not raw telemetry.

  

- `N km/h`  

  Confident movement

  

- `0 km/h`  

  Confident stop  

  (Derived from physics: dwell + static position, even if GPS speed is stale or invalid)

  

- `—`  

  Movement unknown  

  (GPS unavailable or severely degraded, and movement cannot be confidently inferred)

  

### Key Rule

  

> If the app can confidently say “stopped”, it should show **0 km/h**, even if GPS data is delayed or degraded.

  

`—` must be used sparingly and intentionally. It should not appear during ordinary stops such as traffic lights where physics clearly indicates the vehicle is stationary.

  

### GPS Degradation

  

GPS degradation is normal in:

- tunnels

- terminals

- loading racks

- urban structures and canopies

  

GPS degradation:

- is not an error

- is not actionable by the driver in most cases

- may be annotated for records, but should not alarm the driver

  

### Separation of Concerns

  

- UI may summarise or derive states for driver clarity

- Persistent records must not fabricate or backfill missing data

- Distance and fatigue calculations must remain conservative during uncertainty

  

This document exists to prevent future “polish” from eroding epistemic honesty.

```

  

---

  

## RESOURCES/JSON SQLite Persistence Plan.md

  

```markdown

### Persistence Architecture (Driver Assistant) — JSON + SQLite (Joint Storage)

  

> **Implementation Architecture:**  

> This document describes *how* persistence is implemented (SQLite truth, JSON assets).  

> It MUST conform to the rules and guarantees defined in **persistence_plan.md**.

  

### Core philosophy

- **Files are for humans; timestamps are for truth.**

- Calendar **day files** are storage buckets (like paper logbook pages). They are not “shifts”.

- **Shifts are derived** by replaying activity/events; midnight is not semantically special.

- **Authority is split on purpose:**

  - **SQLite = authoritative logbook truth + querying**

  - **JSON = portable, shareable, human-auditable assets + imports/exports**

- **Evidence must be replayable**: no “derived totals” are authoritative.

  

### Deterministic replay (why replay still matters)

- Multi-day fatigue rules are best treated as **windowed replay**:

  1) Query a bounded window (last 7/14/28 days),

  2) Sort by timestamp,

  3) Run rule simulation deterministically,

  4) Derive compliance state on demand.

- SQLite helps with:

  - fast window queries (“give me all activity between X and Y”)

  - integrity constraints (no impossible state transitions)

  - audit trails / edits / versioning of events

- **Derived state** (fatigue totals, warnings, summaries) remains non-authoritative.

  

### Cross-midnight shifts

- Late shifts can span two calendar days — correct and expected.

- **DB stores timestamps as epoch milliseconds (UTC) for ordering + precision.**

- **Exports store ISO-8601 timestamps with timezone** (e.g. `2026-01-08T23:00:00+10:00`) for human audit.

- Never infer timestamps from filenames.

  

---

  

### The split: what is authoritative?

  

### SQLite = authority for “what happened” + “what was carried”

SQLite is the *single source of truth* for:

- Activity segments (work/rest/driving)

- Events (shift start/end, break start/end, incidents, notes)

- Odo/location captures (and which context they belong to)

- Confirmed loads/unloads + compartment transactions

- Pins (stable IDs, edits, categories) **once post-persistence begins**

- Audit metadata (createdAt, editedAt, editedBy, reason/comments)

  

### JSON = authority for portable assets + pack ecosystem

JSON is authoritative for:

- Templates / Packs (read-only sources)

- Vehicle/Driver identity bundles (portable config)

- Settings/preferences (UX behaviour)

- Exports / evidence bundles (generated from DB truth)

  

**Key rule:** JSON may be used to *import* evidence, but SQLite holds the authoritative copy once imported.

  

---

  

### Folder responsibilities (one folder = one responsibility)

  

Documents/

└── Persistence/

    ├── DB/                         # Authoritative store

    │   ├── driver_assistant.sqlite

    │   ├── driver_assistant.sqlite-wal

    │   └── driver_assistant.sqlite-shm

    │

    ├── JSON/

    │   ├── Vehicle/                # Portable config (can be pack-sourced)

    │   │   └── vehicle.json

    │   ├── Driver/

    │   │   └── driver.json

    │   ├── Pins/                   # Pre-persistence only OR export bundle (post-persistence truth is DB)

    │   │   └── pins.json

    │   ├── Templates/              # User-created helpers (non-evidence)

    │   │   ├── Loads/

    │   │   └── Runs/

    │   ├── Packs/                  # Read-only sources (bundle or Documents mirror)

    │   │   └── {packId}/...

    │   ├── Settings/

    │   │   └── settings.json

    │   ├── Exports/                # Evidence bundles generated from DB truth

    │   │   ├── shift_2026-01-12.json

    │   │   ├── last_14_days.json

    │   │   └── inspector_bundle_2026-01-12.zip (optional)

    │   └── Cache/                  # Derived snapshots (safe to delete/rebuild)

    │       └── fatigue_snapshot.json

    │

    ├── GPS/                        # High-volume telemetry (separate from DB)

    │   ├── 2026-01-08/00.jsonl

    │   └── 2026-01-09/00.jsonl

    │

    └── Autosave/                   # Crash recovery only (never official)

        ├── current.json

        └── previous.json

  

---

  

### What goes where (quick rules)

  

### DB (SQLite)

- Timeline truth:

  - shift start/end events

  - break start/end events

  - incident events + structured answers

  - notes/comments (and later breach reasons)

- Activity truth:

  - segmentsToday becomes ActivitySegment rows with start/end

- Odo/location truth:

  - all odo captures with context `.shiftStart/.legalBreakEnd/.shiftEnd/.odoUpdate`

- Load truth:

  - confirmed loads + unload snapshots + compartment transactions

- Pins truth:

  - stable IDs + edits + categories (post-persistence)

  

### JSON

- Templates & Packs:

  - run templates, load templates, presets

- Vehicle/Driver:

  - portable identity/config bundles

- Settings:

  - preferences, toggles, UI behaviour

- Exports:

  - “prove this” bundles produced from DB (not written as authority)

  

### GPS

- Breadcrumbs/trail; stored separately due to volume + pruning.

- Can be referenced by time window but does not define activity truth.

  

---

  

### Modding / “Packs” concept (read-only)

- Packs are **read-only** reference/template sources.

- Packs should never write directly into DB truth tables.

- User can copy pack assets into Templates (user-owned JSON).

- Prefer metadata fields: `schemaVersion`, `packVersion`, `author`, `createdAt`.

  

Bundle/

└── Packs/

    ├── au-standard/

    └── qld-fuel-tanker/

  

---

  

### Authority test (litmus)

Ask: “If an inspector asked ‘prove this’, what do I point to?”

- **Primary**: SQLite export (generated evidence bundle) derived from DB truth.

- **Supporting**: JSON exports / printable summaries / audit bundles.

- **Never**: Templates / Packs / Cache / Autosave.

  

---

  

### Naming contract (JSON assets)

- Date key: YYYY-MM-DD (e.g., 2026-01-08)

- Hour key: HH 00–23 (e.g., 23)

- Template slug: lowercase snake_case (e.g., brisbane_loop)

- Pack id: lowercase kebab-case (e.g., qld-fuel-tanker)

  

---

  

### Sync & migration rules (critical)

  

### Single-writer rule

- During live operation: **write truth only to SQLite**.

- JSON is:

  - read-only sources (packs),

  - user assets (templates),

  - exports (generated from DB),

  - imports (explicit ingestion).

  

### Import pipeline (JSON → DB)

- Accept evidence imports only through an explicit “Import evidence” action.

- On import:

  - validate schemaVersion

  - map into DB tables

  - generate/retain stable IDs

  - record provenance in `import_log`

  

### Template install pipeline (JSON → JSON)

- Templates/Packs do **not** import into truth tables.

- Pack assets are copied into user Templates (optional), still non-evidence.

  

### Export pipeline (DB → JSON)

- Exports are generated on demand:

  - “This shift”

  - “Last 7/14/28 days”

  - “Inspector bundle”

- Exports include:

  - ordered events

  - segments

  - odo captures

  - loads/unloads

  - minimal metadata (schemaVersion, exportedAt, timezone)

  

### Crash recovery

- Autosave remains JSON and is **never** considered official history.

- On recovery:

  - offer: “restore draft state” (user choice)

  - never silently merge into DB truth

  

---

---

  

  

### SQLite Persistence (Authoritative History) — Schema Notes

  

### Timestamp contract

- Store timestamps as INTEGER milliseconds since epoch (UTC).

- Fatigue logic rounds/aggregates at minute granularity, but storage stays ms for ordering.

  

### Schema (v1 draft)

-- ============================================================

-- TRUTH TABLES (authoritative, never deleted)

-- ============================================================

  

-- Shifts (driver-declared work periods)

CREATE TABLE shifts (

    id TEXT PRIMARY KEY,

    started_at INTEGER NOT NULL,        -- When driver pressed "Start Shift"

    ended_at INTEGER,                   -- When driver pressed "End Shift"

    created_at INTEGER NOT NULL,

    import_batch_id TEXT,               -- If imported

    FOREIGN KEY (import_batch_id) REFERENCES import_log(id)

);

  

-- Activity segments (derived from events, but stored for query performance)

CREATE TABLE activity_segments (

    id TEXT PRIMARY KEY,

    shift_id TEXT NOT NULL,

    segment_type TEXT NOT NULL,         -- 'driving', 'workGeneral', 'restBreak', etc

    start_occurred_at INTEGER NOT NULL,

    end_occurred_at INTEGER,

    -- Audit trail

    created_at INTEGER NOT NULL,

    updated_at INTEGER NOT NULL,

    modified_by_source TEXT NOT NULL,   -- 'driver_manual', 'system_auto', 'import'

    -- Edit chain

    supersedes TEXT,

    superseded_by TEXT,

    reason_code INTEGER,

    edit_reason TEXT,

    -- Location corroboration

    start_lat REAL,

    start_lon REAL,

    start_location_accuracy REAL,

    end_lat REAL,

    end_lon REAL,

    end_location_accuracy REAL,

    import_batch_id TEXT,

    FOREIGN KEY (shift_id) REFERENCES shifts(id),

    FOREIGN KEY (import_batch_id) REFERENCES import_log(id)

);

  

-- Events (timeline markers)

CREATE TABLE events (

    id TEXT PRIMARY KEY,

    shift_id TEXT NOT NULL,

    occurred_at INTEGER NOT NULL,

    event_kind TEXT NOT NULL,           -- 'shiftStart', 'driveStart', 'breakStart', etc

    note TEXT,

    created_at INTEGER NOT NULL,

    import_batch_id TEXT,

    FOREIGN KEY (shift_id) REFERENCES shifts(id),

    FOREIGN KEY (import_batch_id) REFERENCES import_log(id)

);

  

-- Odo captures (logbook evidence)

CREATE TABLE odo_captures (

    id TEXT PRIMARY KEY,

    shift_id TEXT NOT NULL,

    captured_at INTEGER NOT NULL,

    context TEXT NOT NULL,              -- 'shiftStart', 'legalBreakEnd', 'shiftEnd', 'odoUpdate'

    odo_text TEXT NOT NULL,             -- Keep as text (allows commas, validation later)

    suburb TEXT NOT NULL,

    -- Location corroboration

    lat REAL,

    lon REAL,

    location_accuracy REAL,

    location_source TEXT,               -- 'gps', 'manual', 'wifi'

    created_at INTEGER NOT NULL,

    import_batch_id TEXT,

    FOREIGN KEY (shift_id) REFERENCES shifts(id),

    FOREIGN KEY (import_batch_id) REFERENCES import_log(id)

);

  

-- Confirmed loads (mass/DG truth)

CREATE TABLE confirmed_loads (

    id TEXT PRIMARY KEY,

    shift_id TEXT NOT NULL,

    confirmed_at INTEGER NOT NULL,

    mode TEXT NOT NULL,                 -- 'loadConfirmed', 'unloadSnapshot'

    terminal_name TEXT NOT NULL,

    load_code TEXT NOT NULL,

    total_litres INTEGER NOT NULL,

    total_mass_kg REAL NOT NULL,

    steer_kg REAL NOT NULL,

    drive_kg REAL NOT NULL,

    gvm_kg REAL NOT NULL,

    created_at INTEGER NOT NULL,

    import_batch_id TEXT,

    FOREIGN KEY (shift_id) REFERENCES shifts(id),

    FOREIGN KEY (import_batch_id) REFERENCES import_log(id)

);

  

-- Confirmed compartments (per-load detail)

CREATE TABLE confirmed_compartments (

    id TEXT PRIMARY KEY,

    load_id TEXT NOT NULL,

    compartment_name TEXT NOT NULL,

    sfl INTEGER NOT NULL,

    product_short TEXT NOT NULL,

    sg REAL,

    litres REAL NOT NULL,

    mass_kg REAL NOT NULL,

    FOREIGN KEY (load_id) REFERENCES confirmed_loads(id)

);

  

-- Pins (post-persistence)

CREATE TABLE pins (

    id TEXT PRIMARY KEY,                -- Stable ID (never changes)

    name TEXT NOT NULL,

    category TEXT NOT NULL,             -- 'terminal', 'customer', 'breakSpot', 'other'

    lat REAL NOT NULL,

    lon REAL NOT NULL,

    created_at INTEGER NOT NULL,

    updated_at INTEGER NOT NULL,

    import_batch_id TEXT,

    FOREIGN KEY (import_batch_id) REFERENCES import_log(id)

);

  

-- ============================================================

-- METADATA TABLES

-- ============================================================

  

-- Import log (provenance tracking)

CREATE TABLE import_log (

    id TEXT PRIMARY KEY,

    imported_at INTEGER NOT NULL,

    source_type TEXT NOT NULL,          -- 'template', 'pack', 'backup', 'manual'

    source_identifier TEXT,             -- Pack ID, template name, etc

    source_version TEXT,

    import_method TEXT NOT NULL,        -- 'user_action', 'sync', 'recovery'

    records_created INTEGER,

    validation_warnings TEXT            -- JSON array

);

  

-- Schema migrations (GRDB handles this, but explicit for clarity)

CREATE TABLE schema_migrations (

    version INTEGER PRIMARY KEY,

    applied_at INTEGER NOT NULL

);

  

-- ============================================================

-- INDEXES (query performance)

-- ============================================================

  

CREATE INDEX idx_segments_shift ON activity_segments(shift_id);

CREATE INDEX idx_segments_occurred ON activity_segments(start_occurred_at, end_occurred_at);

CREATE INDEX idx_events_shift ON events(shift_id);

CREATE INDEX idx_events_occurred ON events(occurred_at);

CREATE INDEX idx_odo_shift ON odo_captures(shift_id);

CREATE INDEX idx_loads_shift ON confirmed_loads(shift_id);

CREATE INDEX idx_pins_category ON pins(category);

  

### Migrations

- GRDB migrations manage schema evolution.

- Maintain schema_migrations table and versioned migration files.

  

### Sync/Export bridge (future)

- “Export shift/day/run” writes JSON bundles derived from SQLite truth.

- “Import evidence bundle” ingests JSON evidence into SQLite truth.

  

### foundation work sqlite phase 2.1

[ ] Install GRDB.swift

[ ] Create schema (shifts, events, segments, odo, loads)

[ ] Write migration v1

[ ] Durably write to SQLite on every event (WAL)

[ ] Test crash recovery (kill app mid-shift, verify restore)

  

### asset management phase 2.2

[ ] Load vehicle.json on launch

[ ] Load driver.json on launch

[ ] Persist settings.json (UI preferences)

[ ] Implement template save/load (loads, runs)

  

### import export phase 2.3

[ ]  "Install template" (Pack/JSON → JSON/Templates)

[ ] "Import evidence bundle" (JSON Export/Backup → SQLite)

[ ] "Export shift" (SQLite → JSON)

[ ] "Export last 14 days" (SQLite → JSON bundle)

[ ] Import provenance tracking

  

### gps breadcrumbs phase 2.4

[ ] Write breadcrumbs to JSONL files (1-hour buckets)

[ ] Implement pruning (delete files older than 28 days)

[ ] Read breadcrumbs for replay/visualization

  

### mod pack system phase 2.5

[ ] Define pack manifest schema

[ ] Implement pack loader (read-only)

[ ] UI to enable/disable packs

[ ] Import pack assets into user templates

```

  

---

  

## RESOURCES/Learnings.md

  

```markdown

### Learnings.md

© 2026 Cory Russell Olsen. All rights reserved.

  

Purpose:

- Capture lessons learned during development and field testing.

- Record insights that should influence future design and coding decisions.

- Avoid repeating PATCHLOG entries; focus on interpretation, patterns, and pitfalls.

  

---

  

### 0. Release Platform Constraints

  

Before public release the project will require a Mac environment to manage:

  

• App Store versioning

• TestFlight distribution

• subscription / payment tier configuration

  

Current development on iPad via Swift Playgrounds is effective for early development but will not cover the full release pipeline.

  

### 1. Swift Playgrounds / iPad Development

  

#### 1.1 Compile state can lie

Swift Playgrounds can enter a stale compile state where:

- obvious syntax errors are not reported immediately

- console prints stop appearing

- app launch behaviour becomes misleading

  

A hard quit of:

- the running app

- Swift Playgrounds

- sometimes the iPad session itself

  

can reset this stale state.

  

**Lesson:** when behaviour makes no sense, suspect tooling state before assuming architecture is broken.

  

---

  

#### 1.2 Giant SwiftUI views create misleading errors

Large SwiftUI bodies often produce:

- “unable to type-check in reasonable time”

- unrelated-looking generic inference errors

- errors pointing at innocent lines instead of the real culprit

  

Breaking views into:

- smaller subviews

- computed sections

- isolated bindings

  

dramatically improves compile reliability.

  

**Lesson:** if SwiftUI starts hallucinating, reduce body complexity before chasing phantom syntax bugs.

  

---

  

#### 1.3 Stable IDs matter more than they seem

Computed registries that regenerate UUIDs on each access break:

- selection state

- resolver lookups

- display derivation

- Picker behaviour

  

This was a major source of confusion in load account resolution.

  

**Lesson:** anything used as lookup truth must have deterministic IDs.

  

---

  

### 2. GPS / ODO / Distance Truth

  

#### 2.1 GPS is evidence, not truth

Real-world testing reinforced that:

- GPS distance can drift

- GPS can undercount during unsure motion periods

- GPS can overcount depending on motion noise and accumulation behaviour

  

Driver-entered odometer remains the most trustworthy distance anchor.

  

**Lesson:** GPS should support truth, not replace it.

  

---

  

#### 2.2 ODO capture is not just a number entry — it is an audit event

ODO capture has architectural significance:

- it anchors distance truth

- it compares live telemetry against reality

- it provides a learning moment for correction logic

- it should occur only in safe, stable motion states

  

**Lesson:** treat ODO capture like a transactional boundary, not a casual text field.

  

---

  

#### 2.3 ODO capture while driving is both unsafe and noisy

Real-world thinking confirmed:

- the driver cannot safely verify numbers while moving

- capture during motion makes comparison less meaningful

- stable stop / crawl windows are better moments for truth entry

  

**Lesson:** ODO capture should be encouraged or gated toward non-driving states.

  

---

  

#### 2.4 “Km this shift” must reflect declared truth, not just corrected telemetry

Testing showed that a shift total based on corrected GPS can diverge from what the driver knows to be true from odometer readings.

  

Example pattern:

- live GPS looked plausible

- corrected segment total looked internally consistent

- but driver expectation was based on actual ODO delta

  

**Lesson:** user-facing “Km this shift” should represent the chosen truth model explicitly, not a hidden compromise.

  

---

  

#### 2.5 Live estimates and truth snapshots are different jobs

There are really three distance views:

  

1. driver-entered ODO truth

2. live GPS-derived estimate

3. corrected estimate using learned factor

  

Only the first is authoritative.

The other two are useful while driving, but they should be clearly presented as estimates.

  

**Lesson:** do not label live estimates in ways that imply they are real odometer truth.

  

---

  

#### 2.6 We need instrumentation for “unsure”

The current “strikes to unsure” threshold is still being tuned.

Without counters, tuning is guesswork.

  

Useful future metrics:

- unsure episodes per segment

- unsure episodes per shift

- unsure time since last ODO

- unsure time per shift

  

**Lesson:** uncertain motion needs measurement before it can be tuned well.

  

---

  

### 3. Architecture / Modularity

  

#### 3.1 Fuel-specific nouns are already too close to the core

The current codebase still uses fuel-shaped terminology in places where future modules will need generic language.

  

Examples:

- compartment

- terminal

- product

- load code

  

These make sense for the first module but not for the platform.

  

**Lesson:** introduce a TransportDomain layer between Core and Fuel before modular growth gets harder.

  

---

  

#### 3.2 “CargoUnit” is the right underlying generic concept

Across transport types, the same internal concept appears repeatedly:

- tanker compartment

- livestock deck / pen

- pallet slot

- fridge zone

- container position

  

Internally these are all loadable sub-units with:

- capacity

- quantity

- mass

- position

  

**Lesson:** CargoUnit should be the generic engine term, with modules skinning it into domain language.

  

---

  

#### 3.3 The driver should never see generic engine words

Words like:

- CargoUnit

- CargoModule

- TransactionType

  

are useful internally but should not leak into the UI.

  

The module should translate them into:

- Compartment

- Deck

- Slot

- Terminal

- Customer

- etc.

  

**Lesson:** generic underneath, domain-specific on the surface.

  

---

  

#### 3.4 Site structure should only exist when it helps the driver

Not every site needs a detailed internal model.

  

Useful rule:

- if the structure changes driver decisions, model it

- if not, don’t

  

Examples:

- servo / depot tanks: useful

- one-off onsite refuelling with scattered equipment: probably not

- SmartFill-style continuous site inventory: definitely out of scope

  

**Lesson:** draw the line at driver usefulness, not technical possibility.

  

---

  

#### 3.5 Event evidence is in scope; inventory management is not

A useful pattern emerged for tanks and site storage:

  

Capture:

- before dip / observation

- moved quantity

- expected after

  

But do not attempt:

- live inventory management

- replacing SmartFill

- ongoing site tank state

  

**Lesson:** event evidence fits the app; continuous operational telemetry does not.

  

---

  

### 4. UI / Interaction Learnings

  

#### 4.1 The truck itself should become the interface

The long-term vision remains sound:

- truck graphic as primary interaction surface

- compartment/freight state embedded visually

- wheels showing axle mass

- paperwork / placard as pull-out panel

- mode controls around the vehicle, not separate forms

  

The current panel-heavy UI is useful for truth-building, but it is not the end state.

  

**Lesson:** current forms are scaffolding; future UI should be spatial and vehicle-led.

  

---

  

#### 4.2 More dense can still mean more clear

A denser interface is not automatically worse if:

- the truck geometry does most of the communication

- numbers are embedded in the physical model

- colour encodes product / cargo type

- clutter is controlled with side panels and popups

  

**Lesson:** spatial truth beats table truth once the underlying model is stable.

  

---

  

#### 4.3 Context labels should match the mode

The same card should not always be called “Terminal”.

  

Better future pattern:

- Load mode → Terminal

- Unload mode → Customer

- Transfer mode → Compartment Configuration

  

**Lesson:** mode context should shape labels, not just data.

  

---

  

### 5. Working with AI

  

#### 5.1 This project is not “vibe coding”

The work is closer to:

- domain-driven design

- architecture-led development

- iterative field validation

- AI-assisted implementation

  

The project succeeds when:

- truth is carefully defined

- changes are tested against real operational behaviour

- architecture is intentionally shaped

  

**Lesson:** use AI as collaborator and repo mechanic, not as an unquestioned code fountain.

  

---

  

#### 5.2 Chat and Codex have different jobs

Best split so far:

  

Chat is good for:

- architecture

- naming

- tradeoffs

- philosophy

- interpreting field tests

  

Codex-style tooling is better for:

- repo-wide edits

- multi-file refactors

- tracing state flow

- batch code changes

  

**Lesson:** thinking bench and workshop are different tools.

  

---

  

#### 5.3 Snapshot quality matters

A useful snapshot is not:

- every file that ever existed

- every conversation copied verbatim

  

A useful snapshot is:

- current canonical code

- patchlog

- architecture notes

- current issues

- learnings

  

**Lesson:** curated truth beats exhaustive clutter.

  

---

  

### 6. Process / Project Discipline

  

#### 6.1 PATCHLOG and Learnings should do different jobs

PATCHLOG should record:

- what changed

- when

- where

  

Learnings should record:

- what surprised us

- what patterns emerged

- what should influence future decisions

  

**Lesson:** if both files say the same thing, one of them is failing.

  

---

  

#### 6.2 The glamorous UI should wait until truth and persistence are stable

The truck-cockpit vision is still the right destination, but:

- truth models

- persistence

- event journal

- reliable state recovery

  

must come first.

  

Otherwise the visual layer will need to be rebuilt repeatedly.

  

**Lesson:** build the engine room before the bridge.

  

---

  

#### 6.3 Real-world testing changes priorities faster than theory

Several issues only became obvious once the app was used in an actual shift:

- GPS vs ODO disagreement

- useless ODO delta presentation

- need for unsure instrumentation

- importance of safe ODO capture timing

  

**Lesson:** field testing reveals the real hierarchy of problems.

  

---

  

### Future Additions

  

This file should continue to collect:

- patterns worth repeating

- mistakes worth avoiding

- architecture decisions that emerged from testing

- toolchain traps

- domain insights that affect multiple modules

```

  

---

  

## RESOURCES/PATCHLOG.md

  

```markdown

  

## [0.2.6] – Load code resolver hardening + selection ID migration – 20260305

  

### [WHAT]

- Load code autofill now resolves across:

  - 4-digit load numbers (e.g. Whinstanes)

  - 6-digit load numbers (e.g. Chevron) once registry + normalization paths align

- Normalization tightened: typed load codes are compared canonically (spaces ignored).

- UI now correctly flips between:

  - “No matching load account”

  - resolved Supplier / Terminal / Role when match found.

  

### [WHY]

- Drivers type what the docket shows (sometimes spaced, sometimes not).

- Resolver must be deterministic and tolerant, or the UI feels “randomly broken”.

- Needed a clean migration path away from legacy selection vars without nuking working UI.

  

### [WHERE]

- Core/Assets:

  - `LoadAccountRegistry` seed accounts list

- AppModel:

  - `resolveLoadNumber(_:)` (legacy path)

  - `resolveLoadCodeAutofill()` (new resolver path)

  - `selectedLoadAccount` computed helper

- Resolver:

  - `LoadAccountResolver.normalize(_:)`

  - `LoadAccountResolver.resolve(terminalID:typed:accounts:)`

  

### [HOW]

- Canonical compare strips spaces from both typed input and registry loadNumber.

- Resolver behaviour:

  - Unique match → sets `resolvedLoadAccountID` (+ bridges terminal fields)

  - No match → leaves previous selection intact, shows hint

  - Ambiguous → populates candidates list and hint (“choose one”)

- Deterministic default:

  - If multiple matches exist, prefer `.nominal` over `.cartage`.

  

### [MIGRATION NOTES]

- Legacy state to phase out:

  - `selectedTerminalID`

  - `selectedLoadAccountID`

- Replacement “truth” moving forward:

  - `resolvedLoadAccountID` (primary)

  - `loadAccountCandidates` (when ambiguous)

  - `loadAccountResolveHint` (UI messaging)

  

### [VALIDATED]

- Typed load codes now resolve correctly in live UI for known accounts:

  - Whinstanes nominal/cartage codes resolve and populate Supplier/Terminal/Role.

  - Chevron 6-digit load code resolves and populates correctly (confirmed by UI screenshot).

- Non-matching codes show “No matching load account” without overwriting existing selections.

  

### [KNOWN ISSUES]

- If `selectedTerminalID` is removed before all call sites migrate, compilation errors will appear where resolver expects an optional terminal hint.

- Mixed “selected*” and “resolved*” variables can temporarily cause UI desync if both are being set.

  

### [NEXT]

- Remove `selectedTerminalID` and `selectedLoadAccountID` after migrating all references to:

  - `resolvedLoadAccountID` / `resolvedLoadAccount` computed property

  - `resolvedTerminalID` (or derive terminal via resolved account)

- Add explicit “Pick from candidates” UI when ambiguous.

  

## [0.2.5] – Background gap advisory pipeline + banner diagnostics – 20260304

  

### [WHAT]

- Added Background Gap Advisory pipeline (Coordinator + Estimator wiring).

- Added “good-fix” GPS publishing (`lastGoodLocation`) from LocationManager.

- Added banner diagnostics layers for GPS vs BG advisory vs ODO evidence.

- Added Debug Dashboard BG inspection + actions.

  

### [WHY]

- Recover *lost distance awareness* when app suspends (iPad focus loss / backgrounding)

  without corrupting:

  - GPS segment accumulation

  - correction-factor learning

  - fatigue/compliance calculations

- [DECISION] We intentionally reject “auto-merge BG estimate into totals” because it is hypothesis, not evidence.

  

### [WHERE]

- AppModel: lifecycle hooks + Combine wiring

  - `onAppBackgrounded()` records BG anchor (timestamp + coordinate)

  - `onAppBecameActive()` sets `backgroundGapResumePending`

  - observes `lm.$lastGoodLocation` to complete estimate when fresh fix arrives

- LocationManager:

  - added `@Published var lastGoodLocation: CLLocation?`

- UI:

  - BannerShellView “future area” diagnostics (3 layers)

  - DebugDashboardView BG panel (resume pending, last estimate, history count, actions)

  

### [HOW]

- Introduced `BackgroundGapCoordinator` as glue around `BackgroundGapEstimator`:

  - Stores BG anchor when app backgrounds

  - On foreground return waits for fresh validated fix

  - Produces optional `BackgroundGapEstimate` (route/straight-line + confidence)

- Good-fix publishing:

  - Only publish to `lastGoodLocation` when accuracy/freshness gates pass

  - Allows UI/lifecycle logic to react to *validated* samples only

- Advisory-only separation:

  - BG estimate never writes into authoritative GPS shift meters

  - never affects odometer reconciliation/correction-factor learning

  

### [IMPACT]

- Distance evidence now exists in 3 intentionally separate layers:

  1) Driver Odometer (highest authority)

  2) GPS Segment Accumulation (operational truth during shift)

  3) Background Gap Advisory (temporary hypothesis on resume)

- Banner and Debug tools now *surface discrepancies* without mutating calculations.

  

### [VALIDATED]

- Off-duty / stationary correctly shows placeholders (—) rather than fake numbers.

- No regression in:

  - GPS shift accumulation

  - odometer correction window

  - fatigue engine behaviour

  - simulation harness

- BG estimator confirmed isolated from correction-factor learning.

  

### [KNOWN ISSUES]

- BG estimate quality depends on availability of a fresh “good” fix on resume.

- [RISK] Route-based estimates can be wrong (detours, tunnels, outages) → stays advisory by design.

  

### [NEXT]

- [TODO] Add user-facing coaching text during ODO capture referencing BG advisory (“possible missing distance since background”).

- [TODO] Consider saving BG advisory history into Journal layer post-persistence (still advisory).

  

  

## [0.2.4] – Multi-day fatigue forecasting + Sim harness stabilisation – 20260301

  

### [WHAT]

- Implemented true rolling 14-day driver summary in Simulation.

- Removed “growing from sim start” behaviour and removed artificial 15-day clamp.

- Stabilised long-horizon simulation testing (> Day 100).

- AppConfig persistence corrected and separated cleanly from DebugDashboard.

  

### [WHY]

- Fatigue correctness needs *rolling windows* anchored to “engine now” for realistic forecasting.

- Simulation must allow long runs for stress-testing multi-day math.

  

### [WHERE]

- SimulationView (windowing + horizon)

- Fatigue aggregation (rolling windows)

- DebugDashboardView / AppConfig separation

- SaveStore JSON assets for AppConfig persistence

  

### [HOW]

- Rolling 14-day window:

  - window anchors to simulated `engineNow`

  - slides forward/back as sim time changes

  - segments clipped across calendar boundaries

  - in-progress segments (`end == nil`) resolve using `engineNow`

- Removed 15-day clamp and confirmed rendering remains stable.

  

### [IMPACT]

- Simulation becomes a real multi-day test harness (not a short demo).

- Fatigue views now explicitly operate on bounded rolling windows.

  

### [VALIDATED]

- Stable beyond 100+ simulated days.

- No regression in:

  - night rest streak detection

  - rolling window maths

  - countdown flashing

  - engine segment bridging

  - JSON save/load pipeline

- Confirmed removal of 15-day ceiling does not affect evaluation integrity.

  

### [KNOWN ISSUES]

- Simulation remains sandbox-only (no persistence by design pre-Journal).

  

### [NEXT]

- [TODO] Post-persistence: compare Sim results against Journal replay outputs for parity.

  

  

## [0.2.3] – Profile assets + GPS integrity refinement – 20260226

  

### [WHAT]

- Added JSON-backed profile assets:

  - `DriverProfilePayloadV1`

  - `SettingsPayloadV1`

- SaveStore reads/writes `driver.json` and `settings.json`.

- Refined shift km accumulation via segment-based aggregation.

  

### [WHY]

- Begin “Assets phase” (stable config/profiles) before Journal truth store.

- Keep driver identity separate from general app settings and future truck profiles.

  

### [WHERE]

- Core/Assets (payload structs)

- SaveStore (read/write)

- Settings UI (advanced driver fields)

- GPS/distance aggregation path

  

### [HOW]

- Split identity:

  - DriverProfile = identity + licensing modes (future)

  - Settings = NHVR base etc

- GPS accumulation:

  - confirmed operational distance remains stable through lifecycle inactive events

  

### [IMPACT]

- Profiles are now externalised, versionable, and ready for future schema upgrades.

  

### [VALIDATED]

- No regression in autosave rotation.

- No sheet routing conflicts.

- No banner layout regressions.

- Live test: km tracking stable.

  

### [KNOWN ISSUES]

- Truck selection still Phase 1 hard-coded (future TruckProfile ID linkage).

  

### [NEXT]

- [TODO] Add schema version migration helpers when PayloadV2 arrives.

  

  

## [0.2.2] – UI layout overhaul + Command Centre – 20260225

  

### [WHAT]

- Added Cmd tab: module launcher (Journal / Truck / Numbers).

- Full-screen command modules (no nested modal pile-ups).

- Centralised sheet routing at ContentView level.

- Introduced global 5-zone BannerShellView:

  1) Integrity

  2) Now (live telemetry)

  3) Navigation (tabs incl Cmd)

  4) Future (projection lane)

  5) Settings

  

### [WHY]

- Establish stable “command shell” before Journal spine.

- Reduce sheet conflicts and navigation fragility.

- Keep banner persistent across modules.

  

### [WHERE]

- AppModel: `CommandSheet` enum + `activeCommandSheet`

- ContentView: sheet routing centralisation

- BannerShellView: new persistent UI container

- Now telemetry visuals + heading marker fixes

  

### [HOW]

- Routing:

  - command modules presented from single source of truth (`activeCommandSheet`)

- Banner:

  - layout priorities tuned so NAV doesn’t wrap under tighter widths

  - reserved integrity slot maintained even when empty to prevent layout jump

  

### [IMPACT]

- UI becomes modular and stable for future expansion (Journal/Truck/Numbers).

- Global navigation and telemetry become consistent.

  

### [VALIDATED]

- No regressions in:

  - mandatory ODO capture coexistence with command routing

  - StatusCard km tracking

  - lifecycle inactive handling

  - autosave pipeline

  

### [KNOWN ISSUES]

- Integrity triangle logic remains placeholder (dev-only dot) until later.

  

### [NEXT]

- [TODO] Hook integrity issue count to real validations once Journal truth exists.

  

  

## [0.2.0] – Distance Integrity + Lifecycle Hardening – 20260220

  

### [WHAT]

- Added `.inactive` handling to scenePhase (iPad split/focus loss reliability).

- Resolved StatusCard km stalling mid-segment.

- Tightened distance accumulation thresholds in LocationManager.

- Hardened AppModel GPS subscription guard against “connected but pipes dead”.

- Added ODO reconciliation audit notes into timeline.

  

### [WHY]

- iPad focus loss behaves like a “soft background” and was causing missed gap logic.

- Under-count lag required better delta thresholding without letting bounce noise in.

- ODO reconciliation needed visibility for debugging without SQLite yet.

  

### [WHERE]

- App lifecycle scenePhase handler

- LocationManager delta thresholds

- AppModel.connect(locationManager:) subscription guards

- reconcileDistanceIfPossible(…) timeline notes

  

### [HOW]

- `.inactive` treated as lifecycle event relevant for distance integrity.

- minDeltaMetersToCount reduced 6.0 → 4.0 with consistent maxDelta constant.

- Subscription guard ensures Combine pipes are re-established when needed.

- Reconciliation logs odoΔ / gpsWindowKm / factor / finalised estimate.

  

### [IMPACT]

- Distance tracking more resilient under real-world iPad behaviour.

- Debuggability improved without full persistence.

  

### [VALIDATED]

- Real-world drive test (~46km segment) confirmed:

  - km increments during drive

  - no freeze during focus loss

  - gap popup behaviour under inactive state

  

### [KNOWN ISSUES]

- Mandatory ODO capture interactive dismiss still identified (hard lock pending).

  

### [NEXT]

- [TODO] Formalise mandatory ODO sheet lock behaviour post workflow hardening.

  

  

## [0.1.307] – Debug dashboard clarity + strategic layer direction – 20260218

  

### [WHAT]

- Formalised 3-layer modular direction:

  1) Live State Engine

  2) Asset Registry (JSON-backed profiles)

  3) Event Journal (append-only truth)

- Planned strategic Command layer as access shell.

- Improved debug dashboard UI and motion state pill colours.

  

### [WHY]

- Prevent architecture drift and “prototype spaghetti”.

- Provide a clear phase sequence:

  Assets → Command shell → Journal spine.

  

### [WHERE]

- Architecture notes + patchlog decision record

- Debug dashboard UI + motion pill presentation

  

### [HOW]

- Documented separation of concerns; no runtime changes beyond debug/UI tweaks.

  

### [IMPACT]

- Sets the project’s long-term shape and protects correctness during refactors.

  

### [VALIDATED]

- N/A (architecture direction + minor UI fixes)

  

### [NEXT]

- [TODO] Keep enforcing “no hidden auto-switching” philosophy until Journal exists.

  

  

## [0.1.303] – Bug fixes + Debug Tools – 20260215

  

### [WHAT]

- Fixed SwiftUI ForEach overload ambiguity:

  - “Cannot convert value of type '[ConfirmedCompartment]' to expected argument type 'Binding<C>'”

- Cleared stale Playgrounds compile state behaviour (phantom non-firing prints).

- Introduced Debug Dashboard internal tooling (Developer Tools).

  

### [WHY]

- Playgrounds type inference can choose binding-based ForEach overload unexpectedly.

- Needed observability before moving into persistence work.

  

### [WHERE]

- Load sheet confirmed-load display ForEach

- Playgrounds runtime behaviour

- DebugDashboardView toolset

  

### [HOW]

- Forced value-based iteration: `ForEach(load.compartments, id: \.id)`

- Hard-quit resets stale compilation state in Playgrounds environment.

- Debug dashboard provides state inspector, workflow gates, GPS & motion, timeline/events, autosave mgmt, edge triggers, destructive actions.

  

### [IMPACT]

- App becomes testable without blind guessing.

- Debug tooling provides confidence for later Journal/persistence.

  

### [VALIDATED]

- Confirmed stable:

  - Load/Unload workflow gating

  - segment lifecycle

  - autosave write timing

  - shift start/end transitions

- Autosave growth + reduction verified.

  

### [KNOWN ISSUES]

- Some preview/canvas quirks remain but are non-fatal.

  

### [NEXT]

- [TODO] Expand debug panels as new evidence layers appear (ODO vs GPS vs BG etc).

  

  

## [0.1.292] – Persistence Begins (Autosave Infrastructure) – 20260212

  

### [WHAT]

- Introduced rotating JSON autosave safety net:

  - `autosave_current.json`

  - `autosave_previous.json`

- Added AutoSaveController (debounced writes + forced saves on key events).

- Added SaveStore abstraction for deterministic file IO and rotation.

  

### [WHY]

- Crash resilience required before real-world testing.

- Pre-SQLite: autosave preserves session state without claiming “historical truth”.

  

### [WHERE]

- AutoSaveController

- SaveStore file IO and folder layout

- Restore-on-launch logic

  

### [HOW]

- Debounced saves to avoid high-frequency disk writes.

- Forced saves on high-value transitions:

  - confirm load

  - activity switch

  - ODO capture

  - shift transitions

- Restore respects workflow gates (doesn’t bypass ODO locks).

  

### [IMPACT]

- App is now crash-resilient within same-day session.

- Enables confident in-truck testing.

  

### [VALIDATED]

- Restore works across relaunch.

- State restoration does not bypass safety gates.

  

### [KNOWN ISSUES]

- No multi-day history.

- No corruption detection checksum (future).

- JSON grows with session complexity (acceptable in Phase 1).

  

### [NEXT]

- [TODO] Post-assets: add checksum + schema versioning when writing JSON payloads.

  

  

## [0.1.280] – LocationManager Stabilisation – 20260212

  

### [WHAT]

- Resolved crash loop related to background location config in Playgrounds.

- Removed `allowsBackgroundLocationUpdates` and `showsBackgroundLocationIndicator` from pre-permission setup.

- Stabilised delegate assignment timing.

- Reduced motion debug noise behind DebugFlags.

  

### [WHY]

- Playgrounds instability around permission/config ordering.

- Needed deterministic start sequence.

  

### [WHERE]

- LocationManager setup and permission flow.

  

### [HOW]

- Delay/guard background location flags until safe.

- Ensure delegate set timing is stable.

  

### [IMPACT]

- Location services become reliable enough for field testing.

  

### [VALIDATED]

- Walk testing confirmed stable startup and ingestion.

  

### [NEXT]

- [TODO] Reintroduce background location features carefully post-persistence where needed.

  

  

## [0.1.165] – GPS movement pill + Preview stabilisation – 20260208

  

### [WHAT]

- Added GPS Movement State Pill (accel/decel/cruising/crawl/stopped/unsure).

- Added preview/playgrounds guards to stop runaway render loops.

  

### [WHY]

- Driver-facing motion confidence needed.

- SwiftUI preview was unusable due to rapid re-renders from live publishers.

  

### [WHERE]

- TodayView pill UI

- AppModel ingestion: `ingestSpeedSample`, `ingestGpsDeltaMeters`, `tickMotionState`

- ContentView/LocationManager preview guards

  

### [HOW]

- Pill driven by evidence-based inference (not authority).

- Preview disables real GPS/timer publishers; forces splash skip.

  

### [IMPACT]

- UI iteration becomes possible in Playgrounds again.

- Motion awareness becomes visible.

  

### [VALIDATED]

- Preview now stable enough for layout editing.

- Real device run required for live motion.

  

### [KNOWN ISSUES]

- Pill is intentionally dormant in preview.

  

### [NEXT]

- [TODO] Expand motion debug history into Command/Numbers post-Journal.

  

  

## [0.1.117] – Incident workflow + mass calibration groundwork – 20260129

  

### [WHAT]

- Added Incident domain models + IncidentAdviceEngine (pure logic).

- Added Incident Sheet UI with calm triage flow and dynamic action plan.

- Added timeline event logging for incident save (pre-persistence placeholder).

- Expanded Driver settings scaffolding for incident contacts.

  

### [WHY]

- Driver needs structured guidance during high-stress events.

- Must remain advisory (not authority) pre-persistence.

  

### [WHERE]

- Incident models + advice engine

- Incident sheet routing via ContentView

- AppModel+Incident draft lifecycle

  

### [HOW]

- Advice plan derived from answers + DriverSettings.

- Save → dismiss → deferred clearing to prevent binding invalidation crash.

  

### [IMPACT]

- Incident capture becomes stable and calm.

- Adds foundational domain for later Journal truth.

  

### [VALIDATED]

- Fixed crash on incident save.

- Confirmed stable under: premature close, save+dismiss, reopen.

  

### [KNOWN ISSUES]

- Phone/deep-link actions not fully wired.

- Advice text still generic in places.

  

### [NEXT]

- [TODO] Improve advice ordering and conditional specificity.

- [TODO] Post-persistence: store incident evidence references (photos/notes) in Journal.

  

  

## [0.1.103] – Mobility prompts + speed + policy simplification – 20260120

  

### [WHAT]

- Added mobility prompts:

  - “Are you driving?” when movement detected but segment state disagrees.

- Added loadview prompts while stopped (context-based coaching).

- Added lazy axle toggle switch in load view for mass adjustments.

- Clarified shift boundaries in timeline.

  

### [WHY]

- Reduce driver button pushing.

- Keep workflow truthful without hidden auto-switching.

  

### [WHERE]

- AppModel guard/coaching logic

- Load view UI controls

- Timeline boundary events

  

### [KNOWN ISSUES]

- Earlier load event duplication per compartment resolved subsequently.

  

### [NEXT]

- [TODO] Expand coaching prompts into structured “nudge” system with snooze semantics.

  

  

## [Unreleased] – Fatigue UI trust + interpretation fixes (record of decisions)

  

### [WHAT]

- Introduced “rest-in-progress limbo” concept:

  - While break < 15m, UI should avoid breach messaging.

- Deferred 30m/60m limbo approach.

  

### [WHY]

- Prevent false “app is broken” perception while driver is actively taking a qualifying break.

- [DECISION] Keep NHVR counting logic unchanged; only UI trust layer changes.

  

### [WHERE]

- TodayView fatigue presentation

- AppModel helper introspection (no engine math change)

  

### [HOW]

- UI shows neutral/grey while break is still maturing toward ≥15m legal rest.

  

### [IMPACT]

- Trust and readability improve without affecting legality math.

  

### [NEXT]

- [TODO] Replace “limbo” beyond 15m with remaining-shortfall coaching post-Journal.

  

  

## [0.1.98] – Mobility prompts + constants extraction – 20260113

  

### [WHAT]

- Added mobility prompts (soft prompt when movement detected without driving state).

- Extracted magic numbers into canonical Constants files (fatigue/DG/load/countdown/sim).

- Speed shown in Today status card and Map view.

- Removed “Company Policy” row from fatigue UI (Phase 1).

  

### [WHY]

- Constants extraction prevents drift and prepares for rule expansion.

- Policy overlays require historical truth; deferred until after Journal.

  

### [WHERE]

- Constants files

- Today/Map UI

- Fatigue UI rows + Simulation repositioning

  

### [IMPACT]

- NHVR remains only legality engine in early versions.

  

### [NEXT]

- [TODO] Reintroduce policy overlays post-persistence as optional lens only.

  

  

## [0.1.93] – Today view streamlining – 20260110

  

### [WHAT]

- Added suburb alongside odometer in Status card.

- Moved timeline to right panel and added expandable rows.

- Clarified Simulation as pre-persistence placeholder.

  

### [WHY]

- Improve operational scanning and reduce cognitive load.

  

### [NEXT]

- [TODO] Redesign Simulation once historical data spans multiple days (Journal).

  

  

## [0.1.71] – Map: GPS blue dot + permission plumbing – 20260105

  

### [WHAT]

- Enabled live GPS “blue dot” (UserAnnotation).

- Added location permission plumbing.

- MapScreen shows session pin list with delete + jump-to-pin.

  

### [WHY]

- Establish baseline map capability before persistence.

  

### [KNOWN ISSUES]

- Follow-me UX deferred; pins are session-only until persistence.

  

### [NEXT]

- [TODO] Post-persistence: saved pins library + categories + stability tooling.

  

  

## [0.1.66] – Comment clarity + delivery sheet – 20260103

  

### [WHAT]

- Added Delivery Sheet workflow for recording delivered litres per compartment.

- Fatigue spacing UI changed from always-green to neutral until first ≥15m legal rest.

- Large comment/structure pass across ~44 files.

  

### [WHY]

- Delivery workflow is a real-world need; fatigue UI trust needed.

  

### [NEXT]

- [TODO] Post-persistence: full delivery history and editing/replay.

  

  

## [0.1.42] – Structural refactor + load/DG correctness – 20251231

  

### [WHAT]

- Integrated live DG placard view into Load screen.

- DG placarding responds correctly to product + litres changes (incl. zero-litre edge cases).

- Simulation supports saved load templates and applying them into Load planning.

- Introduced `AppModels/` folder grouping extensions.

- Major view decomposition into Partials/Components/Sheets for compile sanity.

  

### [WHY]

- Correctness + maintainability before scaling features.

- Prevent large-file compile failure cycles.

  

### [WHERE]

- Load screen + DG logic

- Simulation templates

- Folder structure + refactor

  

### [IMPACT]

- App is structurally navigable for ongoing development.

  

### [NEXT]

- [TODO] Persistence (Journal) + more rigorous in-truck testing pass.

  

  

## [0.1.15] – UX flow + compliance groundwork – 20251217

  

### [WHAT]

- Added “Confirmed loads (today)” + “Confirm this load” snapshot action.

- Settings About row shows version/build date from AppBuildInfo.

- Early map pin dropper prototype.

- Added Simulation screen for fatigue validation.

- Shift start gated behind mandatory ODO + suburb capture.

  

### [WHY]

- Establish compliance-aligned flow early.

- Confirmed-load snapshot becomes early “mini-truth” before Journal.

  

### [NEXT]

- [TODO] Weekly report export (post-persistence likely).

  

  

## [0.1.0] – Initial Patch Bundle – 20251211

  

### [WHAT]

- Unified fatigue engine using ActivitySegments.

- Countdown logic shared TodayView ↔ Simulator.

- 5h15 NHVR compliance row.

- Other Activity system.

- 2×3 action grid (Drive/Break/Load/Unload/Breakdown/Other).

- SG override storage per product.

- Background-safe tick logic using delta time.

  

### [NEXT]

- [TODO] Persistence, export, fatigue UI polish.

  

<!-- PATCHLOG DOCUMENTATION FOOTER -->

<!-- Do not place new version entries below this line -->

  

# PATCHLOG.md

© 2026 Cory Russell Olsen. All rights reserved.

  

Purpose:

- Human-readable change log for Driver Assistant.

- Optimised for “6–12 months later Cory” searching for:

  - WHY did we do this?

  - WHERE was it implemented?

  - HOW does it work?

  - WHAT changed / what broke?

  

Search system (new headers / tags):

- Use Cmd+F for: WHAT / WHY / WHERE / HOW / IMPACT / VALIDATED / KNOWN / NEXT

- Optional quick tags inside bullets:

  - [DECISION] [BOUNDARY] [RISK] [LESSON] [MIGRATION] [TEST] [TODO]

  

Conventions:

- This log describes intent + architecture + evidence, not every single diff.

- “Authoritative” = feeds shift truth / fatigue / legal calculations.

- “Advisory” = visible guidance only; does not alter authoritative totals.

```

  

---

  

## RESOURCES/Persistence_plan.md

  

```markdown

v0.2 Groundwork – State, Compliance & Trust Model

  

> **Design Contract:**  

> This document defines *what must persist, what must never persist, and why*.  

> It is storage-agnostic and is implemented by the **JSON + SQLite Persistence Architecture**.

The intent is correctness, auditability, and driver trust.

  

⸻

  

1. Core Principles

    •    The app must never invent history.

    •    All compliance-relevant data must be reproducible from stored facts.

    •    Derived values (fatigue status, breach flags) are recalculated, never stored.

    •    Manual driver input always overrides inferred or calculated data.

    •    If data is missing or uncertain, that uncertainty must be explicit.

    •    Persistence must support auditability before convenience.

  

⸻

  

2. State Boundaries

  

Ephemeral (does not persist)

    •    UI focus state (keyboard focus, selected fields)

    •    Temporary text entry not yet confirmed

    •    Sheet presentation state

    •    Simulator state

    •    Visual countdown animations

    •    Cosmetic UI flags

  

Persistent (must persist)

- Shifts (start → end)  [DB truth]

- Timeline events (append-only)  [DB truth]

- Activity segments (start/end, work/rest classification)  [DB truth]

- Confirmed loads + unload snapshots  [DB truth]

- Odometer + location captures  [DB truth]

- Driver-defined “Other” activity presets  [JSON settings / assets]

- Settings that affect calculations (policy lens, fatigue mode, etc.)  [JSON settings]

NOTE:

- “Legal rest blocks” are DERIVED from stored segments/events (not stored as authority).

  

⸻

  

3. Shift Lifecycle

  

A Shift is the highest-level persisted unit.

  

Each shift consists of:

    •    Start timestamp

    •    Optional declared earlier start offset

    •    Ordered timeline of activity events

    •    Zero or more confirmed loads

    •    End timestamp

  

Rules:

    •    Shifts cannot overlap.

    •    A shift must be explicitly ended.

    •    Ending a shift freezes its data.

    •    Editing historical shifts requires an explicit amend flow (future phase).

    •    A new shift cannot begin until the previous shift is closed or discarded.

  

⸻

  

4. Timeline Events (Append-Only)

  

Each timeline event stores:

    •    UUID

    •    Timestamp

    •    Event type (Drive / Break / Load / Unload / Incident / Other)

    •    Optional note

    •    Work/rest classification

    •    Source (manual vs inferred)

  

Rules:

    •    Timeline events are append-only.

    •    Events are never silently mutated.

    •    Future edits create revisions, not overwrites.

    •    Deletion (future phase) creates a tombstone entry, not removal.

  

⸻

  

5. Fatigue Engine Persistence Rules

    •     Fatigue calculations are derived, never stored.

    •     Stored data consists only of factual inputs:

    •     Timeline events (markers + notes)

    •     Activity segments (work/rest/driving with timestamps)

    •     Shift boundaries

  

Derived:

    •     Rest blocks and “legal break totals” are derived from segments/events.

    •     Breach states must be reproducible from stored data alone.

    •     Countdown logic must remain deterministic across restarts.

    •     Simulator and TodayView must use the same underlying data model.

  

⸻

  

6. Load Planning & Confirmation

  

Unconfirmed load plans

    •    Exist only in memory.

    •    Do not persist across app restarts.

    •    Are safe to discard without warning.

  

OPTIONAL NOTE:

    •    Post-persistence you MAY add a “Draft Load” autosave for convenience, but drafts are never evidence and never mutate confirmed loads.

  

  

Confirmed loads

  

Each confirmed load persists:

    •    Timestamp

    •    Load code

    •    Terminal (as known at confirmation time)

    •    Total litres (and litres per compartment)

    •    Total mass (and mass per compartment)

    •    Type of product per compartment

    •    Axle estimates (steer / drive / GVM)

    •    Associated shift ID

  

Rules:

    •    Confirmation is explicit.

    •    Confirmed loads are immutable.

    •    Confirmation snapshots the state as-loaded, not recalculated later.

  

⸻

  

7. Odometer & Location Capture

  

Each odometer capture persists:

    •    Timestamp

    •    Odometer value

    •    Mandatory capture context (shift start / legal break(s) / shift end)

    •    Suburb (manual or GPS-derived)

    •    Confidence flag (manual vs inferred)

  

Rules:

    •    Odometer captures are never overwritten.

    •    Missing suburb or odo values must be explicitly marked as unknown.

    •    Compliance logic must tolerate missing values but surface them clearly.

  

⸻

  

8. Undo Model (Future-Aware)

  

Undo is contextual and time-limited.

  

Rules:

    •    Undo applies only to the most recent confirmed action.

    •    Undo expires when:

    •    Another timeline event occurs

    •    A shift ends

    •    The app restarts (initial implementation)

    •    Undo availability must be visible but non-intrusive.

    •    Undo never silently alters historical data.

  

⸻

  

9. Settings Persistence Rules

  

Persisted settings include:

    •    Driver name

    •    Truck identifier

    •    Truck configuration data

    •    Saved “Other” activities

    •    App version / build metadata (read-only)

  

Rules:

    •    Settings changes apply prospectively.

    •    Historical data retains the values active at the time.

  

⸻

  

10. Migration & Versioning Notes

    •    Version 0.2 introduces persistence.

    •    Earlier snapshots may lack:

    •    Location data

    •    Odometer context

    •    Missing fields must default to explicit “unknown”.

    •    PATCHLOG is the single source of truth for versioning.

  

⸻

  

11. Non-Goals (Explicitly Out of Scope for v0.2)

    •    Cloud sync

    •    Cross-device merge

    •    Automatic legal submissions

    •    Editable historical compliance records

    •    Silent data correction

  

  

RetentionPolicy

  

v0.2 Groundwork – Data Retention, Thinning & Archival Strategy

  

This document defines how long data is retained, at what fidelity, and why.

It supports compliance-adjacent use, driver trust, auditability, and long-term sustainability.

  

It deliberately avoids implementation details (JSON / CoreData / SwiftData / etc).

  

⸻

  

1. Core Principles

    •    Retain only what is defensible and useful.

    •    Compliance-grade detail is time-limited.

    •    Long-term history favors summaries over raw telemetry.

    •    No silent data loss: thinning and expiry must be deterministic.

    •    Retention rules must support:

    •    NHVR-style rolling fatigue checks

    •    payslip / admin disputes

    •    driver self-review

    •    Storage must scale linearly, not exponentially.

  

⸻

  

2. Autosave & Crash Recovery (Ephemeral Safety Net)

  

#### Autosave & Crash Recovery now operational and validated under forced termination testing.

    •    Provides in-session continuity only.

    •    Not a substitute for authoritative persistence.

  

Purpose: protect against app crashes, power loss, OS kills, or accidental restarts.

  

Autosave Snapshot

    •    A single rolling snapshot of current in-progress state.

    •    Overwritten on each save (no history chain).

  

Triggers

    •    Immediately after any committed event:

    •    timeline event

    •    shift start / end

    •    load confirmation

    •    odometer capture

    •    Periodic timer-based save during long inactivity (e.g. long driving stints).

  

Rules

    •    Commit-triggered autosaves override timer-based saves.

    •    Autosave exists only to restore the latest known truth.

    •    Autosave is not part of historical reporting.

    •    Autosave remains a draft safety net even post-persistence:

        - SQLite stores committed truth immediately (WAL).

        - Autosave stores ONLY in-progress UI/draft state not yet committed

          (e.g., partially filled forms, draft load plan, sheet inputs).

        - Autosave is never treated as historical reporting/evidence.

  

2.1. Asset Registry (Soft Persistence Layer)

- JSON-backed

- Low write frequency

- Versioned profiles

- No impact on live state engine

  

Asset Registry must be implemented before Journal schema is finalised.

  

2.2. Event Journal (Hard Persistence Layer)

- Append-only event log

- Source of truth for replay + analytics

- Feeds Command layer projections

⸻

  

3. Compliance-Grade Detail (Short-Term, High Fidelity)

  

Retention Window

  

28 days (rolling)

  

This window supports:

    •    14-day rolling fatigue calculations

    •    NHVR-equivalent logbook inspection

    •    recent route and activity verification

  

Data Retained at Full Fidelity

    •    Shift boundaries

    •    Timeline activity events (append-only)

    •    Legal rest blocks

    •    Confirmed loads

    •    Odometer + suburb captures

    •    Detailed breadcrumb routes (thinned but continuous)

  

Rules

    •    This is the highest-fidelity data tier.

    •    All fatigue rules must be fully reproducible from this data alone.

    •    When data ages beyond 28 days, it is thinned or summarised, never silently deleted.

  

⸻

  

4. Medium-Term History (Operational & Admin Use)

  

Retention Window

  

12 months (rolling)

  

Supports:

    •    payslip disputes

    •    admin queries (“how many hours did I work last month?”)

    •    high-level operational review

  

Data Retained

  

Per shift:

    •    date

    •    start / end timestamps

    •    total work time

    •    total driving time

    •    total rest time

    •    legal break totals (≥15 / ≥30 / ≥60)

    •    start suburb / end suburb (if known)

    •    notes + edit flags (future phase)

  

Per load:

    •    timestamp

    •    load code

    •    terminal (as known at confirmation)

    •    total litres

    •    total mass

    •    axle estimates

  

Per day:

    •    shift count

    •    aggregate hours

  

Explicitly Not Retained

    •    minute-by-minute telemetry

    •    detailed breadcrumb tracks

    •    UI-level event granularity

  

⸻

  

5. Long-Term Archive (“Vault”)

  

Retention Window

  

3 years (rolling)

  

Purpose:

    •    long-term record keeping

    •    personal or business audits

    •    historical reference

  

Data Retained

    •    shift summaries only

    •    optional monthly rollups:

    •    total work hours

    •    total rest hours

    •    total driving hours

    •    shift counts

  

Rules

    •    Vault data is read-only.

    •    No telemetry, no route detail.

    •    Vault data must be compact, stable, and durable.

  

⸻

  

6. Breadcrumb & Location Data Thinning

  

Breadcrumbs exist to show where the driver went, not to replay every metre.

  

High Detail (≤ 28 days)

    •    Points captured at:

    •    fixed time intervals (xxxx seconds)

    •    significant heading change (xxxx degrees)

    •    speed transitions (stopped ↔ moving)

    •    geofence entry / exit

    •    key driver events (load, unload, breakdown, break)

    •    Always retain points at:

    •    terminals

    •    delivery locations

    •    depots / workshops

  

Thinned Detail (28 days – 12 months)

    •    Convert routes into:

    •    named stops

    •    arrival / departure times

    •    dwell duration

    •    Discard continuous movement paths.

  

Archive (> 12 months)

    •    Retain stops only.

    •    No route geometry.

  

⸻

  

7. Fatigue Data Specific Rules

    •    Fatigue calculations are never stored.

    •    Only factual inputs persist:

    •    activity events

    •    rest blocks

    •    shift boundaries

    •    Rolling fatigue windows (e.g. 14 days) are always derived from:

    •    the 28-day compliance dataset

    •    No separate “fatigue store” exists.

  

⸻

  

8. Load & Event Linking (Background Association)

    •    Confirmed loads may be linked to the nearest logical timeline event:

    •    load ↔ unload ↔ drive transitions

    •    Linking is:

    •    automatic

    •    non-destructive

    •    optional

    •    Unlinked records remain valid (though unlikely)

  

Purpose:

    •    reporting clarity

    •    audit trail strength

    •    zero additional driver burden

  

⸻

  

9. Expiry & Deletion Rules

    •    Expiry is deterministic and scheduled, not reactive.

    •    Data transitions between tiers are:

    •    logged

    •    reversible only within retention window

    •    No silent deletions.

    •    User-initiated export (future phase) must occur before expiry.

  

⸻

  

10. Non-Goals (Explicitly Out of Scope)

    •    Cloud sync

    •    Multi-device reconciliation

    •    Regulator-certified archival

    •    Legal evidence guarantees

    •    Infinite retention

  

⸻

  

Summary

  

This retention model balances:

    •    legal-adjacent usefulness

    •    driver trust

    •    storage realism

    •    future scalability

  

It ensures the app remains assistive, not invasive, and informative, not punitive — exactly in line with the project’s intent.

  

### Persistence Strategy (Design Contract)

  

Persistence in Driver Assistant is layered intentionally.

Each layer solves a different driver problem and must be built in order.

Higher layers must never undermine guarantees made by lower layers.

  

---

  

### Layer 0 — Safety Net (Autosave / Crash Recovery)

  

**Goal:**  

> “I cannot lose today’s work.”

  

This layer exists purely to prevent data loss during:

- app crashes

- force quits

- OS kills

- accidental restarts

  

#### Behaviour

- Automatically snapshot *all critical live state*:

  - current shift status

  - active activity segment

  - timeline events

  - confirmed loads / unloads

  - odometer capture state

  - current fatigue counters

  - map session state (pins, camera position, breadcrumbs if enabled)

- Snapshot frequency:

  - every N minutes (e.g. 5 min)

  - on key events (start/end shift, break, drive, load/unload, odo capture)

  - when app moves to background

- On app launch:

  - If a recent snapshot exists, prompt:

    - **Resume previous session**

    - **Discard and start fresh**

  

#### Constraints

- Snapshots overwrite previous autosave (not a history log)

- No editing, no auditing, no interpretation

- This layer must work before any other persistence is considered

  

---

  

### Layer 1 — "Committed truth survives relaunch” (SQLite)"

  

**Goal:**  

> “My data survives days, weeks, and relaunches.”

  

This layer stores structured app data so the driver can:

- resume where they left off

- view prior shifts

- retain settings and maps

  

#### Data Covered

- Driver settings & behaviour dials

- Confirmed loads / unloads

- Shift summaries

- Activity segments (work/rest)

- Odometer/location records

- Pins (customers, terminals, break spots)

- Templates and configuration data

  

#### Behaviour

- App restores last known persisted state on launch

- History views become possible

- Data may still be *correctable* later

  

#### Constraints

- Persistence does NOT imply legal authority

- No requirement for immutability

- Data can still be edited or corrected by the driver

  

---

  

### Layer 2 — "Truth is explainable + amendable via revisions” (schema supports edit chains)

  

**Goal:**  

> “I can prove what I did, when, and why.”

  

This layer introduces **event truth**, not just stored state.

  

#### Behaviour

- All meaningful actions become append-only events:

  - activity start/stop

  - corrections (time, rest/work classification, odometer)

  - load/unload confirmations

  - delivery applications

  - pin edits

- Events may include:

  - driver-entered reasons / comments

  - system-inferred context (movement, timing, thresholds)

- System can reconstruct state at any point in time

  

#### Outcomes

- Defensible timelines

- Management / compliance review support

- Foundation for future legal-grade exports

  

#### Constraints

- No silent mutation of past events

- Corrections add new events — they do not erase history

  

---

  

### Optional Layer 3 — Export & Portability

  

**Goal:**  

> “I can move, back up, or hand this data to someone else.”

  

#### Behaviour

- Export structured data (e.g. JSON / ZIP):

  - settings

  - shifts & events

  - loads / deliveries

  - pins & maps

  - diagnostics

- Import for restore, migration, or analysis

  

#### Notes

- Not required for core persistence

- Valuable for:

  - device migration

  - third-party review

  - succession / handover scenarios

  

---

  

### Build Order (Non-Negotiable)

  

1. Safety Net (Autosave / Crash Recovery)

2. Persistence (Save My Data)

3. Auditability (Explainable History)

4. Export & Portability (Optional)

  

- SQLite can deliver Layer 1 + the foundations of Layer 2 immediately,

  even if UI for amendments comes later.

  

Skipping earlier layers invalidates guarantees of later ones.

  

#### Export Formats (Product Tier Gate)

Exports may be tier-gated (see PricingTiers.md), but the persistence layers below

must not depend on exports to be useful.

  

- Free tier may include: on-device history viewing (logbook-style)

- Paid tiers may include: CSV export, PDF report export, scheduled exports

  

  

*****************

### Persistence Principle — Distance & Odometer

  

- GPS-derived distance is approximate and conservative

- Distance accumulation pauses or is down-weighted during degraded GPS

- Degraded segments are annotated, not filled or smoothed

- GPS km represents a lower bound, not an estimate

  

Odometer:

- Driver-confirmed odometer values are authoritative

- App may suggest values when uncertainty exists

- Driver edits are treated as learning signals, not errors

  

The system must prefer honest undercount to fabricated precision.
```

  

---

  

## RESOURCES/PricingTiers.md

  

```markdown

### Pricing & Tier Strategy (Design Contract)

  

Guiding Principle:

A driver must never pay to be legal.

NHVR legality, fatigue compliance, and logbook truth are always available.

Pricing unlocks foresight, leverage, and insight — not safety.

  

> Behaviour definitions referenced here are defined in  

> **SettingsBehaviourContract.md**  

> This file controls access, not behaviour semantics.

  

---

  

### Tier Overview (Stable, Intentional)

  

| Tier | Name | Access Model |

|-----|------|--------------|

| Tier 0 | Core Driver | Free |

| Tier 1 | Early Bird Driver (Founding Era) | Subscription + Limited Lifetime |

| Tier 2 | Pro Driver (v3) | Subscription + Final Lifetime Era |

| Tier 3 | Business / Fleet | Subscription only (future) |

  

---

  

### Tier 0 — Core Driver (Free)

  

**Audience**

- All drivers

- Contractors

- Sceptics

- Roadside-inspection scenarios

  

**Philosophy**

> “If the app is open, it won’t lie to you.”

  

**Includes**

- NHVR-compliant fatigue tracking  

  - Single-day (pre-persistence)  

  - Multi-day rolling windows (post-persistence)

- Paper logbook-style timeline (work / rest / driving)

- Explicit shift start / end

- Odometer capture with audit visibility

- Legal vs non-legal rest distinction

- Confirmed load / unload logging

- DG placarding based on confirmed load history

- Map view:

  - Live GPS blue dot

  - Session-based pins (pre-persistence)

  - Persisted pins (post-persistence)

- NHVR legality indicators (always visible)

- End-of-shift summaries

- **28-day rolling logbook memory (view-only)**

  

**Explicitly NOT included**

- Forward planning

- Optimisation

- What-if scenarios

- Exports

- Long-term history access

- Automation

  

This tier must stand alone in audits and roadside inspections.

  

---

  

### Tier 1 — Early Bird Driver (Founding Era)

  

**Audience**

- Drivers who believe early

- Builders, testers, collaborators

- Owner-drivers who want foresight

  

#### Subscription

- **Founding price:** $6.99 / month  

- Founding subscribers **retain this price while subscribed**

- If cancelled, re-subscription occurs at the current price

  

#### Lifetime Licence (Founding Reward)

  

- **$99**

- Available only during **Founding seasonal windows**:

  - Launch

  - EOFY

  - Black Friday

  - Boxing Day

- Lifetime holders automatically receive **Pro Driver (v3)** when it launches

  

> Early Bird lifetime = permanent Pro Driver access  

> No upgrades. No fees. No tricks.

  

---

  

#### Unlocks

  

**Planning & Foresight**

- Earliest next legal start (with explanation)

- “If you do X now, you unlock Y later”

- Break timing trade-offs

- Early finish / late start comparisons

  

**History**

- Multi-day fatigue views

- Rolling 24h / 7-day timelines

- Pattern awareness (tight days, late finishes)

  

**Maps**

- Persisted pins

- Breadcrumb trails

- Resume last session

  

**Exports**

- **PDF logbook pages (driver-level)**

- Shift summaries (PDF)

  

Tone:

- Advisory

- Calm

- Never blocking

- Never punitive

  

---

  

### Tier 2 — Pro Driver v3 (Insight, Scenarios & Owner-Driver Tools)

  

**Audience**

- Owner-drivers

- Highly experienced drivers

- Drivers who want the app to *think with them*, not for them

  

**Philosophy**

> “Show me the consequences — I’ll decide what to do.”

  

This tier deepens foresight, pattern awareness, and financial clarity  

without removing agency or enforcing behaviour.

  

---

  

#### Access Model

  

**Subscription**

- Standard price: **$10.99 / month**

- Price may increase in future major versions

- Existing subscribers retain their price while subscribed

  

**Lifetime (Seasonal, Limited)**

- **$129 one-time**

- Available during defined seasonal windows only:

  - Launch

  - EOFY

  - Black Friday

  - Boxing Day

- Lifetime applies to **Pro Driver v3 capabilities only**

- No guarantee of lifetime access to future tiers

  

---

  

### Unlocks (on top of Pro Driver v2)

  

#### Advanced Planning & Scenario Modelling

  

- Multi-day forward simulations

- Branching “what-if” scenarios

- Fatigue buffer visualisation

- Start / finish trade-off comparisons

- “If I do X now, this becomes possible later” explanations

  

⚠️ Advisory only  

⚠️ Never blocks actions  

⚠️ Never uses illegal or coercive language

  

---

  

#### Owner-Driver Costings & Job Insight

  

- Cost-per-hour and cost-per-day views

- Scenario-based job costing

- load vs fatigue vs time trade-offs

- Run comparisons (“this job vs that job”)

- Sensitivity awareness (tight margins, long days)

  

> The app shows *numbers and consequences* —  

> what the driver does with that information is their choice.

  

No enforcement. No optimisation pressure.  

Just clearer thinking tools.

  

---

  

#### Maintenance Awareness (Opt-In, Driver-Controlled)

  

Maintenance features are **disabled by default**.

  

When explicitly enabled in settings, the app may:

  

- Track service intervals based on:

  - odometer

  - dates

  - driver-defined thresholds

- Display:

  - “Service approaching”

  - “Service due”

  - “Service overdue”

  

**Rules**

- Intervals are defined by the driver

- Language is informational, not authoritative

- No automatic scheduling

- No blocking of app functions

- No implication of legality or roadworthiness

  

> Responsibility remains with the driver —  

> the app reduces forgetting, not judgement.

  

---

  

#### Deeper Insight & Pattern Recognition

  

- Longer-range fatigue patterns

- Recurring tight days

- End-of-shift tendencies

- Consistency vs drift awareness

- Visual overlays (not alerts)

  

This tier adds **depth**, not noise.

  

---

  

#### Automation (Explainable, Overrideable)

  

- Stronger prompts with reasoning

- Optional comment capture on overrides

- Behaviour learning over time (post-persistence)

- Suggestions may adapt if the driver repeatedly overrides them

  

The app *learns the driver* —  

the driver never learns to obey the app.

  

---

  

### Explicit Non-Features (Still)

  

- No fleet dashboards

- No payroll

- No compliance exports

- No automated scheduling

- No authority over the driver

  

Those belong to future tiers.

  

---

  

### Design Contract Reminder (v3)

  

- No one pays to be legal

- NHVR illegal states are always visible

- Paid tiers change **how deeply** the app explains — never **what is true**

- All automation is optional, explainable, and overrideable

- Early adopters are treated fairly

- No user is trapped

  

### Lifetime Licence Rules (Non-Negotiable)

  

- Lifetime licences grant access to **all features of the tier they promise**

- Features are **never removed**

- Lifetime licences do **not** apply to Fleet / Business tiers

  

#### Early Bird Guarantee

  

- Early Bird lifetime holders:

  - Automatically receive Pro Driver (v3)

  - Never pay upgrade fees

  - Are permanently protected

  

No ladders.  

No “pay the difference”.  

No regret tax.

  

---

  

### Tier 3 — Business / Fleet (Future)

  

**Design Intent**

- Multiple drivers

- Shared vehicles

- Compliance dashboards

- Org-level exports

- Payroll & reporting

- Permissions and governance

  

**Rules**

- Subscription only

- No lifetime licences

- Separate audience from solo drivers

  

---

  

### Import & Export Rules

  

Free for all:

- Templates

- Community packs

- Non-authoritative planning assets

  

Paid tiers:

- Historical truth reuse

- Logbook PDFs

- Evidence exports

  

Fleet only:

- Bulk exports

- Compliance reporting

- Org-wide datasets

  

**Principle**

- Ideas are free  

- Truth is protected  

- Evidence has value

  

---

  

### Non-Negotiables

  

- No one pays to be legal

- NHVR illegality always visible

- No safety behind paywalls

- No downgrade of free features

- No upgrade prompts during stress or illegality

  

---

  

### Design Contract Reminder

  

Paid tiers change **how deeply** the app speaks — never **what is true**.

  

Early believers are rewarded.  

Late adopters are treated fairly.  

No one is trapped.

```

  

---

  

## RESOURCES/SettingsBehaviourContract.md

  

```markdown

### Company Policy + NHVR Severity Levels (Design Contract)

  

> Access to behaviour calibration is governed by  

> **PricingTiers.md**  

> This file defines behaviour, not monetisation.

  

Goal:

- NHVR legality must remain visually distinct from company policy.

- Company policy should guide behaviour without crying wolf.

  

#### Severity Lenses

- NHVR lens: legal / breach (authoritative once persistence + rolling windows exist)

- Company policy lens: workplace constraints (may be stricter than NHVR)

- Payroll lens: paid/unpaid, max paid hours, etc (future)

  

### Company Policy Strictness Levels

#### 1) Informational

- Show company policy bars, but never use "illegal" styling.

- No prompts, no blocking. Pure awareness.

- Recommended UI: neutral colours only.

- post persistence only after consultation. pre persistence it is removed.

  

#### 2) Advisory

- Show warnings when approaching / exceeding company targets.

- Soft prompts allowed (e.g., "Company prefers 30m break — convert 2×15m?").

- Never block actions.

- Recommended UI: amber/orange warnings (not red).

  

#### 3) Hard Limit

- Treat company limits as “do not proceed without reason”.

- Requires driver acknowledgement + optional reason/comment capture.

- Still must not reuse NHVR illegal styling.

- Recommended UI: strong warning styling (e.g., striped / bold) + confirm dialog.

  

### Visual Rules

- Red / flashing is reserved for NHVR illegal states only.

- Company policy must use a different visual vocabulary (e.g., amber + stripes).

  

### App Behaviour Dials (Design Contract)

  

These settings control HOW the app behaves, not WHAT is legal.

  

They are orthogonal and may be combined freely.

  

### Helpfulness

  

Controls how often the app initiates interaction.

  

#### Quiet

- App reacts only to explicit driver actions.

- No inferred prompts.

- Suitable for experienced drivers who dislike interruptions.

  

#### Helpful

- Contextual prompts when ambiguity is detected.

- Examples:

  - Movement detected without driving state → "Are you driving?"

  - Waiting >15m → "Convert to break?"

- Prompts are single-shot, not repetitive.

  

#### Proactive

- App anticipates opportunities and risks.

- Examples:

  - "A 15m break now unlocks a 10h rule."

  - "Delaying unload will push company hours over target."

- Requires clear visual distinction from legal warnings.

  

### Nerdiness

  

Controls information density and explanation depth.

  

- Driver: summaries only (bars, ticks, simple labels)

- Advanced: show breakdowns and active rules

- Nerd: show calculations, timestamps, and rule rationale

  

### Planning Assist

  

Controls forward-looking guidance.

  

- Off: report current state only

- Basic: earliest start / latest finish hints

- Strategic: what-if guidance and optimisation suggestions

```

  

---

  

## RESOURCES/Todo.md

  

```markdown

// =====================================================

// DRIVER ASSISTANT – DEVELOPMENT TODO (Reordered for Persistence Phase)

// =====================================================

//

// Guiding principle:

// - Pre-persistence = coaching, visibility, questions

// - Post-persistence = authority, correction, history

//

// We are now officially in PERSISTENCE PHASE (v1.x in progress)

//

// =====================================================

  

  

/////////////////////////////////////////////////////////

// COMPLETED (Historical – Pre-Persistence Wins)

/////////////////////////////////////////////////////////

  

[-] Show legal rest (≥15m blocks) explicitly under total rest on Status card

[-] Require odometer entry when ending a legal break (odo optional for non-legal breaks)

[-] Display both Legal rest (≥15m) and Short rest (<15m counts as work for NHVR)

[-] Guard against duplicate or near-duplicate timeline events

[-] Populate dropped pins in MapView left panel (live session only)

[-] Display live GPS position (blue dot)

[-] Add optional “Follow Me” button

[-] Follow Me behaviour polish (visual state)

[-] Add soft prompt when movement detected without active driving state

[-] Differentiate Company Policy severity from NHVR legality

[-] Clarify Company Policy behaviour for 2×15m vs preferred 30m

[-] Improve Company Policy wording (avoid false red stress)

[-] Clamp unload maths defensively (no negative litres)

[-] Remove Tomorrow Planner from TodayView

[-] Investigate occasional missing final Unload event

[-] Ensure End Shift finalises active activity before summary

[-] Add Debug Layer (clock jump simulator + badge)

[-] Verify stability across background/foreground/tab switching

[-] Replace Breakdown button with Incident

[-] Add Incident selection sheet

[-] SimView: Add Tomorrow Planner (sandbox)

[-] Auto-close driving when inactivity detected

[-] Auto-close break when movement detected

[-] Persist & reconcile last active event on resume

[-] Implement “Have you stopped driving?” prompt

  

  

/////////////////////////////////////////////////////////

// PERSISTENCE PHASE (v1.x) — IN PROGRESS

/////////////////////////////////////////////////////////

  

// Scope:

// - Multi-day truth

// - Rolling NHVR windows

// - Authoritative fatigue interpretation

// - Retroactive correction tools

// - SQLite as indexed truth store

// - Append-only event model

  

  

/////////////////////////////////////////////////////////

// PERSISTENCE CORE (Authoritative Truth Layer)

/////////////////////////////////////////////////////////

  

[ ] Finalise persistence split: JSON + SQLite

    - JSON: templates/mods/shareable packs

    - SQLite: authoritative history + indexed queries

    - Define migration rules early

  

[ ] Design authoritative schema:

    - shifts

    - segments (start/end/activity/isLegalRest/source)

    - events (load confirm, odo capture, incident, recovery)

    - confirmedLoads (snapshot)

    - pins (stable IDs)

  

[ ] Implement lightweight event commit ordering

    - Ensure Drive/Break/Load transitions are durable & replayable

  

[ ] Introduce debounced / idempotent event actions

    - Multiple taps resolve to single authoritative event

  

[ ] Enable safe retroactive correction of missing/incomplete events

  

[ ] Implement rolling 24h NHVR fatigue rules (authoritative)

  

[ ] Implement multi-day rolling fatigue rules (7/14 day windows)

  

[ ] History tab

    - NHVR physical logbook-style graph

    - Multi-day navigation

    - Indexed queries (not replay hacks)

  

[ ] Enable per-event editing

    - Timestamp correction

    - Rest vs work classification

    - Odometer correction

  

[ ] Enable retroactive correction of missed driving/break events

  

[ ] Unify fatigue summaries across:

    - NHVR lens

    - Company overlay lens

    - Payroll lens

  

  

/////////////////////////////////////////////////////////

// INCIDENT SYSTEM (Authoritative Post-Persistence)

/////////////////////////////////////////////////////////

  

[ ] Implement guided checklist per Incident type

  

[ ] Accident incident flow (injury, safety, leak, notify, notes)

  

[ ] Breakdown incident flow (movable, safe, DG risk, contacted)

  

[ ] Spill / DG incident flow (guidance only pre-escalation)

  

[ ] Ensure Incident events:

    - Do NOT auto-change Drive/Break state

    - Clearly visible in timeline

    - Coexist with active state

  

[ ] Language review: calm, procedural, non-alarmist

  

  

/////////////////////////////////////////////////////////

// LOAD / FUEL MODEL EVOLUTION

/////////////////////////////////////////////////////////

  

[ ] Implement partial load / additive fuel transactions

  

[ ] Treat Load/Unload/Transfer as parent activities with child transactions

  

[ ] Strengthen fuel transaction validation

    - Remaining litres logic

    - Additive logic

    - Historical corrections

  

[ ] Timeline row summaries (collapsed + expanded logic)

  

  

/////////////////////////////////////////////////////////

// MAP & PIN PERSISTENCE

/////////////////////////////////////////////////////////

  

[ ] Persist pins with stable IDs

  

[ ] Prompt for pin name on first edit (not on drop)

  

[ ] Allow rename / delete / category change

  

[ ] Use pin names in saved runs & stop ordering

  

[ ] Formalise map interaction state machine

    - Follow mode

    - Manual pan

    - Resume rules

  

  

/////////////////////////////////////////////////////////

// MAP INTELLIGENCE (Not Navigation)

/////////////////////////////////////////////////////////

  

[ ] Introduce Map Constraints Layer:

    - Bridge heights

    - Road mass limits

    - B-Double gazetted routes

    - DG restrictions

    - Sensitive zones

  

[ ] Constraint awareness tied to truck profile:

    - Height

    - Mass

    - DG status

    - Configuration

  

[ ] Soft warnings only (no rerouting)

  

[ ] Pre-emptive awareness logic (heading + proximity)

  

[ ] Driver knowledge capture (advisory metadata)

  

  

/////////////////////////////////////////////////////////

// ROUTE PLANNER (Mass-Sensitive Order Engine)

/////////////////////////////////////////////////////////

  

[ ] Store delivery jobs as structured stops

  

[ ] Add Road Mass-Sensitivity concept (Low/Med/High)

  

[ ] Capture driver knowledge quickly (minimal taps)

  

[ ] Build Planner scoring model

    - Mass-first logic

    - Geography secondary

    - Avoid backtracking

  

[ ] Generate Suggested Order + Explain Why

  

[ ] Learn from real runs (feedback loop)

  

[ ] Add load-aware constraints (steep/hinterland multiplier)

  

[ ] Add saved milk-runs / templates

  

[ ] Export planned vs actual runs (paid tier later)

  

  

/////////////////////////////////////////////////////////

// SIMVIEW (Sandbox – Snapshot Model)

/////////////////////////////////////////////////////////

  

[ ] Implement SimSession snapshot pattern

    - Base snapshot

    - Working copy

    - Reset to base

    - Visible SIMULATION badge

  

[-] Add Quick Experiment buttons (+15m rest, +1h work, reset)

  

[ ] Build simple multi-step mass experiment engine

  

[ ] Add guardrails preventing accidental real load edits

  

  

/////////////////////////////////////////////////////////

// SPEED & TELEMETRY (Post-Persistence Authority)

/////////////////////////////////////////////////////////

  

[-] Introduce filtered speed pipeline

    - Outlier rejection

    - Rolling smoothing

    - Single source of truth

  

[ ] Speed UI severity cues (advisory only)

  

[-] Sustained overspeed detection (max flitered only)

  

[ ] Overspeed advisory event capture (non-alarmist)

  

[ ] Overspeed classification logic (advisory only unless policy)

  

[-] Introduce Telemetry Quality state

    - good / degraded / unavailable

  

[-] Persist GPS confidence metadata

  

[-] Implement stationary override logic

  

[ ] Gate “Are you stopped?” prompts by:

    - dwell

    - user intent

    - proximity to known pin

  

[-] Prolonged GPS loss handling

    - Optional odometer confirmation

  

  

/////////////////////////////////////////////////////////

// SPILL DETECTION ENGINE (Authoritative)

/////////////////////////////////////////////////////////

  

[ ] Implement spill detection logic

    - Compare delivered vs SFL / Absolute Max

    - Classify severity

    - Trigger guidance flows

    - Log classification

  

  

/////////////////////////////////////////////////////////

// POLICY OVERLAYS (V2/V4)

/////////////////////////////////////////////////////////

  

[ ] Add Self-Imposed Rule overlay (Pro tier)

  

[ ] Add Company Policy Profile (Fleet tier)

    - Governance

    - Versioning

    - Audit overrides

  

  

/////////////////////////////////////////////////////////

// UI REWORK (Structural – When Persistence Stable)

/////////////////////////////////////////////////////////

  

[-] Rework top banner:

    - GPS coords

    - Suburb

    - Current activity

    - Settings

    - Tabs (Today / Load / Map / Sim / History)

  

  

/////////////////////////////////////////////////////////

// FUTURE COACHING (Post-15m Limbo Enhancement)

/////////////////////////////////////////////////////////

  

[ ] Optional 30m / 60m shortfall coaching

    - Presentation layer only

    - No rule engine modification

  

  

/////////////////////////////////////////////////////////

// ACCEPTANCE PRINCIPLES

/////////////////////////////////////////////////////////

  

// TodayView = operational live truth

// LoadView = paperwork + confirmed snapshots

// SimView = sandbox only

// MapView = execution + awareness

// Red UI = NHVR illegal only

// Company policy must visually differ from legality

// Short breaks count as work for NHVR windows

// No silent corrections ever

```

  

---

  

All source code contained in this snapshot is the intellectual property of [Cory Russell Olsen].

Unauthorized reproduction or distribution is prohibited.

  

# END OF SNAPSHOT
