# Chunk 5F — Niles Prebuild Review

**State:** PREBUILD REVIEW  
**Scope:** Adaptive Workspace UX Harness  
**Basis:** V3 refactor contract, merged Chunk 5E field gate, Chunk 5E field findings, and Cory's five paper prototype states.

## Review conclusion

**PROCEED TO BOB INTENT WITH CONSTRAINTS.**

5F is correctly scoped as a UX/interaction harness, not a production V3 implementation. The proposed five states — Pre-shift, Active/Driving, Site/Delivery, Load, Rest — can test the adaptive-workspace hypothesis without requiring persistence, production OCR, production fatigue/compliance logic, or a full V3 feature inventory.

## Architecture findings

1. **Do not create a second business-truth model in UI.** The harness may own ephemeral workspace/draft state, but confirmed cargo operations must continue to respect the existing V3 ownership split: Cargo owns transported cargo truth; Operations owns operational events/context; Driver owns work/rest/fatigue; Vehicle owns vehicle truth.
2. **Draft and confirmed state must be separate types/state paths.** Finger movement, simulated OCR, typing and snap suggestions may alter only a draft/projection. Confirm is the boundary that produces a prototype event/recalculated confirmed state.
3. **Reuse the 5E cargo contracts where practical.** 5F should not replace CargoLedger, reconciliation semantics or the Fuel delivery coordination merely to make the prototype easier. A thin harness adapter is preferable to mutation of production contracts.
4. **Do not preserve 5E's false pump-timing UI.** 5F must use truthful interaction timestamps/labels and must not imply that tapping the iPad proves physical pump start/finish.
5. **Run ontology must be physical.** The harness needs a prototype Site Visit -> Fill Item model. External FC jobs may be retained as references later, but must not dictate the driver-facing hierarchy.
6. **Truck 92 is fixture data, not architecture.** Five compartments and current quantities are acceptable deterministic test fixtures; no universal five-compartment assumption belongs in shared contracts.
7. **Load input is one draft with three manipulators.** Simulated scan, drag and direct numeric entry must converge on the same Load Draft. Do not create OCR/manual/visual modes with divergent state.
8. **Returned product must be additive/projection-aware.** Simulated BOL input must not blindly replace existing cargo.
9. **Rest must reuse Driver-domain concepts without becoming a production fatigue engine.** Fake deterministic fatigue values are acceptable. The harness must not encode new legal interpretations.
10. **The persistent shell is a presentation contract, not a new truth owner.** Top-bar content may adapt by workspace state while reading existing/fake domain state.
11. **Journal is not a 5F redesign target.** V2 Journal remains provisional KEEP. 5F should not spend scope reworking it.
12. **5F is not the V3 feature specification.** Absence of V2 features such as lazy-axle status, running-tank status or other proven capabilities means only “not required for this harness”. A later V2 -> V3 migration audit remains mandatory before production feature freeze.

## Suggested implementation boundary

Keep 5F additions concentrated under `v3/UI/` plus dedicated 5F tests/harness documentation. Only change existing domain files if a genuine missing contract is exposed and the change remains inside the approved intent. If the prototype requires material domain redesign, stop and return to PREBUILD.

A small prototype state store may contain:
- workspace state;
- deterministic run/site/fill fixtures;
- draft cargo state;
- plan/projection values;
- simulated scan result;
- fake fatigue/rest values.

It must not become the future AppModel.

## Required acceptance evidence

The iPad gate must demonstrate:
- coherent state transitions across all five states;
- physical Site Visit containing multiple Fill Items;
- C4 3200 -> 0 and C5 7200 -> 5400 deriving a 5000 L Minjerrabah delivery;
- useful, overridable empty/planned-remainder snapping;
- exact numeric correction and Undo;
- no confirmed cargo mutation before Confirm;
- multi-fill advancement without returning to Active between fills;
- one Load Draft manipulated by simulated scan + drag + type;
- returned cargo preserved;
- Rest makes fatigue dominant and Run subdued but available.

## Niles disposition

No architectural blocker to Bob writing the 5F Intent-to-Build, provided the above constraints are incorporated.
