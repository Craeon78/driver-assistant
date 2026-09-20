# Chunk 5F — Bob Intent-to-Build

**State:** INTENT READY  
**Destination gate:** iPad Swift Playgrounds UX/interaction field gate  
**Build authority:** NOT YET GRANTED — requires Cory's explicit GO.

## 1. Outcome

Build a deterministic SwiftUI **Adaptive Workspace UX Harness** that makes the five paper-prototype states touch-testable on Cory's iPad:

1. Pre-shift
2. Active / Driving
3. Site / Delivery
4. Load
5. Rest / Break

The harness exists to test interaction grammar and state transitions. It is not the production V3 UI and not an exhaustive V3 feature implementation.

## 2. Current-state basis

The build will rely on:
- `V3_REFACTOR_CONTRACT.md` for ownership/invariants;
- merged Chunk 5E field-gate code under `v3/UI/`;
- existing Cargo ledger/reconciliation contracts under `v3/Cargo/`;
- existing Operations contracts under `v3/Operations/`;
- existing Driver work/rest/fatigue contracts under `v3/Driver/`;
- existing Fuel delivery coordination where it remains appropriate.

Chunk 5E's domain result is retained; its field UI is reference/fixture material, not the UX to polish.

## 3. Prebuild findings incorporated

### Niles
- UI may own ephemeral drafts, never parallel business truth.
- Confirm is the draft -> event boundary.
- Reuse existing V3 contracts rather than rebuilding cargo truth for convenience.
- Do not reproduce false pump start/finish semantics.
- Site Visit -> Fill Item is the driver-facing run ontology.
- Truck 92/five compartments are fixture data only.
- Scan/drag/type manipulate one Load Draft.
- Existing returned cargo is preserved.
- Rest uses deterministic harness data, not new compliance logic.
- Journal remains outside 5F.
- 5F absence does not retire V2 features; later migration audit remains required.

### Costa
- Keep plan/projection/observation/draft/event terminology distinct.
- Simulate OCR output only; no image retention system.
- Whole-screen BOL verification by driver; no confidence bureaucracy.
- DA paperwork likenesses are not official documents.
- No unverified EIP/ERG/DG rules.
- Receiving fill animation must not claim tank level evidence.
- Location/context cannot manufacture operational events.
- Keep 5F durable truth in this repository rather than duplicating it into CozzaHQ.

## 4. Architecture / ownership

### Prototype workspace state

Add a small 5F-specific observable store/model responsible only for:
- current workspace state;
- deterministic fixture data;
- current run/site/fill selection;
- draft compartment quantities;
- simulated scan result;
- demo rest/fatigue presentation state.

It will not become a general AppModel.

### Confirmed cargo

Where a 5F interaction crosses Confirm, use/adapt the existing Cargo/Fuel coordination path so the harness demonstrates the existing truth boundary rather than directly mutating “confirmed” quantities.

### Draft cargo

Draft quantities are separate from confirmed cargo. Dragging, snapping, typing and simulated scanning update draft/projection only.

### Run fixture

Introduce a harness-only physical hierarchy sufficient to represent:

`Run -> Site Visit -> Fill Item`

including SeaLink Cleveland with Minjerrabah and Seabreeze as two fills inside one visit.

Do not remodel production Runs/Sites in this chunk.

## 5. Expected files/components

Exact filenames may change only for ordinary implementation hygiene; material ownership changes return to PREBUILD.

### ADD
- `v3/UI/Chunk5FAdaptiveWorkspaceView.swift` — five-state SwiftUI workspace and state-specific layouts.
- `v3/UI/Chunk5FPrototypeStore.swift` — deterministic harness state, drafts and fixture transitions.
- `v3/UI/Chunk5FTruckCargoView.swift` — reusable interactive truck/compartment surface for Delivery and Load.
- `v3/UI/Chunk5FRunView.swift` — physical site-visit/fill run presentation and prototype reorder behaviour.
- `v3/Tests/Chunk5FAdaptiveWorkspaceTests.swift` — deterministic non-touch/state tests.
- `v3/Chunk5FAdaptiveWorkspaceHarnessView.swift` — simple Playgrounds entry harness.
- `v3/CHUNK5F_PREBUILD.md` — consolidated approved prebuild/interaction contract.
- device-side change report/handoff documentation required by the repository workflow.

### REUSE / MAY MODIFY IF REQUIRED
- `v3/UI/FieldTestStore.swift`
- `v3/Fuel/` delivery coordination
- `v3/Cargo/` existing ledger/reconciliation contracts
- `v3/Operations/` existing operation/context contracts

Any material domain-contract change discovered during build is a stop-and-return-to-PREBUILD condition rather than an automatic 5F expansion.

### DELETE
- None planned.

## 6. Implementation sequence

1. Create feature branch from current `main`.
2. Add deterministic 5F fixture/store and state transitions.
3. Build persistent shell and Pre-shift/Active states.
4. Add physical Run -> Site Visit -> Fill Item fixture/presentation.
5. Add shared interactive truck surface.
6. Implement Delivery draft flow: drag, empty snap, planned-remainder snap, precision entry, Undo, Confirm.
7. Implement multi-fill progression at SeaLink Cleveland.
8. Implement Load draft flow with simulated scan + drag + direct type on the same draft, including returned-product fixture.
9. Implement Rest presentation with fatigue dominant and Run subdued but available.
10. Add deterministic state/domain-boundary tests.
11. Produce iPad handoff harness and field-test checklist.
12. Niles audit -> repair loop before PR.

## 7. Invariants

- Driver-entered ODO remains authoritative; 5F does not change distance truth.
- GPS/context remains evidence; it does not create delivery/load/rest facts.
- Draft/projection never silently becomes confirmed state.
- Confirmed corrections preserve provenance; no silent cargo rewrite.
- Driver can record valid work without OCR/GPS/geofence/run-plan dependency.
- No production legal/compliance claim is introduced.
- No customer receiving level is fabricated from movement animation.
- No exact physical pump/load timestamp is inferred from iPad interaction.
- External job granularity does not define physical Site Visits.
- Five compartments/Truck 92 remain fixtures, not universal contracts.
- No V2 capability is retired by omission from 5F.

## 8. Acceptance cases

The candidate must support the following before target-runtime testing:

- Pre-shift -> Active -> Site -> Active -> Load -> Active -> Rest -> Active transitions.
- Moving Active state is information-rich but interaction-poor.
- SeaLink Cleveland is one Site Visit with Minjerrabah + Seabreeze Fill Items.
- Delivery fixture: C4 3200 -> 0 and C5 7200 -> 5400 derives 5000 L to Minjerrabah.
- EMPTY snap and planned-remainder snap are overridable.
- Exact numeric correction works.
- Undo restores the unconfirmed draft.
- Confirm is the only boundary that commits the prototype cargo event.
- Confirming Minjerrabah advances to Seabreeze; final fill returns to Active.
- One Load Draft can be altered by simulated scan, drag and type without mode reset.
- Driver is prompted to check DA's representation against the physical BOL.
- Existing/returned cargo is preserved when simulated new load is applied.
- Rest makes fatigue dominant; Run remains visible/available but subdued.

## 9. Validation plan

### Static/deterministic
- state-transition tests;
- draft vs confirmed-state tests;
- delivery arithmetic;
- returned-product arithmetic;
- multi-fill progression;
- Undo;
- snap-target calculations;
- simulated scan modifies only Load Draft.

### Review
- Niles audit against this Intent and V3 ownership;
- Bob repairs until Niles ALL CLEAR;
- PR/external review according to CozzaHQ build-system governance.

### Target runtime
Cory imports/runs the reviewed candidate in Swift Playgrounds on iPad and physically tests touch behaviour. Required evidence is UX PASS / PARTIAL PASS / UX FAIL plus specific observations for drag feel, snap behaviour, precision entry, density, transitions and Rest emphasis.

Merge is not PASS.

## 10. Not touching

5F will not build:
- real OCR/camera capture;
- image/document retention;
- GRDB/SQLite migration;
- production EventLog persistence;
- production fatigue/legal engine;
- NHVR EWD functionality;
- DG/EIP/ERG compliance rules;
- terminal integration;
- production BOL formats;
- production GPS/geofence/routing/traffic;
- final mass-distribution modelling;
- final styling/accessibility;
- Android/phone UI;
- cloud sync;
- onboarding;
- qualifications/maintenance/HR document storage;
- production statistics/Numbers;
- Journal redesign;
- Transfer/reconciliation exception UX beyond what is necessary to preserve existing truth contracts;
- full Settings/splash/menu suite;
- V2 feature migration itself.

## 11. V2 preservation gate

5F is not the shipped-product checklist. Before V3 feature freeze, a separate V2 -> V3 migration audit must account for every user-facing V2 capability as **KEEP / ADAPT / REPLACE / RETIRE**.

Known examples that must not be lost merely because they are absent from 5F include lazy-axle status, running-tank status and the provisionally retained V2 Journal design.

## 12. Known uncertainties intentionally left to the harness

The harness may experimentally choose reversible defaults for:
- drag geometry;
- snap tolerance/haptics;
- precision-entry presentation;
- +/- controls;
- Run expansion/reordering details;
- prototype movement threshold;
- Rest top-bar content;
- Shift So Far metrics;
- document-likeness expansion;
- animation duration.

If testing reveals a material domain/architecture change rather than a UI tuning decision, stop and return to PREBUILD.

## 13. Done when

5F is done only when:
1. the reviewed harness reaches the iPad;
2. Cory runs the required touch/interaction gate;
3. the acceptance cases are exercised;
4. the result is explicitly classified **UX PASS / PARTIAL PASS / UX FAIL**;
5. findings are captured for the next design/build decision.

A pretty screenshot, successful compile, PR approval or merge does not complete 5F.
