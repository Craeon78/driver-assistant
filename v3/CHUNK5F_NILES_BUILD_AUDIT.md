# Chunk 5F — Niles Build Audit

**State:** REPAIR REQUIRED  
**Audited branch:** `chunk5f-adaptive-workspace`

## What is correct

- Build is isolated to new 5F harness/test/document files; no existing V3 domain contract was modified.
- Five adaptive workspace states are represented.
- Site Visit -> Fill Item is represented in the fixture.
- Delivery has draft quantities, Undo, Confirm and receiving visual marked non-evidentiary.
- Load scan is explicitly simulated structured extraction and additive to returned cargo.
- Rest keeps Run visible but subdued.
- Deterministic gate covers the core C4/C5 5,000 L case and draft-before-confirm invariant.

## Blocking finding

**N5F-01 — Confirm boundary currently commits by directly overwriting `Chunk5FCompartment.confirmedLitres`.**

The Intent explicitly requires Confirm to use/adapt the existing Cargo/Fuel coordination path where practical, and the V3 contract says transported cargo truth belongs to Cargo. The prototype store currently has its own confirmed cargo array and therefore demonstrates a parallel confirmation mechanism.

This is acceptable for draft rendering, but not acceptable as the acceptance proof for “Confirm is the only boundary that commits the prototype cargo event”.

### Required repair

Either:
1. back the deterministic delivery/load fixture with the existing `CargoLedger`/Fuel coordination contracts and derive displayed confirmed quantities from it; or
2. if the existing coordinator cannot represent the 5F interaction without material domain redesign, stop and document that as a PREBUILD blocker.

Do not widen the build beyond this repair.

## Non-blocking observations for iPad gate

- Drag snapping currently uses a fixed 120 L tolerance; treat this as reversible harness tuning, not a domain rule.
- Active-state movement suppression is represented conceptually but not yet sensor-driven; acceptable for 5F because production GPS is explicitly excluded.
- Reordering is not yet touch-implemented. It is an acceptance target from the Intent and should be added before iPad handoff if it can remain harness-only.

## Niles disposition

**REPAIR REQUIRED — N5F-01.**
