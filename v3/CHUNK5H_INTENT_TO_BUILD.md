# Chunk 5H — Bounded Intent-to-Build

**Authority:** Cory GO 5H in Work, after review of the live-shift-first intent.
**Baseline:** `main` at `bf23ef7`, 5G PASS in `v3/CHUNK5G_CLOSEOUT.md`.
**State:** BUILD candidate; review and iPad live-shift gate still required.

## Outcome and ownership

Prove that already-passed Driver, Operations/Vehicle, Run, Cargo/Fuel, ODO and persistence contracts coexist through Cory's real working shift on iPad. Driver owns Work/Rest; Run owns planned intent and execution linkage; Cargo owns transactions and physical reconciliation; Vehicle/ODO retains driver-entered anchors; Core persistence restores committed records. Gate output is a reconstruction, not a second truth source.

## Construction limit

Build one deterministic cross-system preflight/regression fixture and its Playgrounds runner. Reuse the existing live `Chunk5FAdaptiveWorkspaceView` for the field shift. Repair only demonstrated integration defects within this boundary, through the normal review/PR loop. No fixture event is field evidence.

## Checks

- Planning Rest and Other Work creates only plan context; actual actions create Work/Rest anchors.
- Load, positive Delivery and 0 L outcome coexist while cargo activity remains Work; 0 L has no cargo movement.
- Committed Run items remain anchored when future intent changes.
- Transfer and Physical Check retain their distinct provenance.
- Mid-shift relaunch preserves event identities, Run order and cargo without duplication.
- End Shift archives ODO and chronological history; internal representation and operational completeness remain separate.

The preflight may exercise an exception even when the field shift does not naturally contain one. A preflight PASS cannot pass 5H.

## Primary acceptance

Cory carries DA through a real working shift on iPad, using the normal live workflow as events actually happen, including real Rest/Work, Run changes and cargo actions that arise. Relaunch mid-shift after committed mixed activity if safe to do so, then complete End Shift and preserve the Gate output and observed differences. Do not manufacture a rare delivery/exception to satisfy a checklist. Niles compares the independent field observations with DA's reconstruction and explicitly adjudicates PASS, PASS WITH RESIDUALS or FAIL. Chunk 5 closure requires a separate residual check.

## Non-goals

No predictive scheduling, route or site duration, flow-rate intelligence, map/traffic, Journal, Data/Road Packs, Numbers/Simulation/Command, release hardening, new NHVR/EWD claim or broader visual redesign. Missing evidence is unknown rather than inferred.

## Validation and handoff

Niles internal review → Codex PR review and findings loop → merge for target-runtime test → exact Playgrounds ADD/REPLACE/DELETE report → preflight on iPad → real working shift → Niles adjudication. The target-runtime handoff is `v3/CHUNK5H_PLAYGROUNDS_HANDOFF.md` and must be refreshed against merged `main` before Cory imports files.
