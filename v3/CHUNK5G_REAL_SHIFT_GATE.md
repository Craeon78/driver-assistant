# Chunk 5G — Real-Shift Harness Gate Contract

**Status:** PREBUILD GATE CONTRACT  
**Scope:** One to two real tanker shifts on the iPad using V3 as a field harness. This is not a production-release gate.

## 1. Purpose

Chunk 5G exists to answer one question:

> **Can Driver Assistant accompany a real tanker shift from Start Shift to End Shift, ask the driver only for information it genuinely needs, survive deviations from the plan, preserve operational truth, and reconstruct the day accurately afterwards?**

5G deliberately moves beyond simulated Load/Delivery scenarios without pretending the rest of V3 is production-complete.

A successful 5G test requires at least one complete real shift. Two materially different real shifts are preferred before drawing strong conclusions.

## 2. Authority and inherited invariants

5G inherits the V3 architecture and truth rules from:
- `V3_REFACTOR_CONTRACT.md`;
- `resources/v3/V3_ROADMAP.md`;
- the Cargo/Fuel contracts;
- `v3/CHUNK5F_IPAD_FIELD_TEST_FINDINGS.md`.

5G does not redefine those contracts.

In particular:
- append-only truth remains authoritative;
- projections are rebuildable and are not evidence;
- ODO remains the driver truth anchor for distance;
- GPS/location is evidence/context and never gates valid capture;
- driver confirmation establishes facts only the driver can establish;
- no invented history and no silent correction;
- Fuel liquid state and residual/vapour state remain distinct;
- Confirm remains the normal draft/projection-to-truth boundary;
- planning assists work but never becomes historical truth merely because it was planned.

## 3. Experimental separation: plan, DA record and external comparison

The real-shift experiment deliberately keeps three artefacts separate:

1. **Trip report / supplied work** — intended work before the shift.
2. **Driver Assistant shift record** — what DA independently captured and reconstructed during the real shift.
3. **External BFA/FC shift-end report** — independently generated company record used after the shift for comparison.

The external shift-end report must **not** be used to repair, complete or influence DA's Real-Shift Gate Report before DA's internal gate result is produced.

The post-shift comparison may also use the driver's recollection/notes to explain genuine operational differences.

Disagreement is evidence. A mismatch must not be silently massaged away merely to make DA agree with the external report.

## 4. Required 5F repairs carried into 5G

5G includes only the 5F repairs required to make a real shift usable:

- make START SHIFT a large central primary action;
- stabilise delivery drag geometry;
- add contextual-snap hysteresis/latching so snap cannot shake the compartment UI;
- after a confirmed fill, expose another fill as expected context rather than falsely implying pumping has started;
- allow confirmed execution to progressively reconcile Today's Run order;
- correct the prototype DIE/XLS error: XLS is diesel; DIE is Direct Into Equipment and is not a fuel product;
- provide practical compartment product selection without bypassing liquid/residual Fuel truth;
- retain scan + drag + type as one Load Draft concept;
- retain the Rest workspace substantially as already field-tested.

EIP / SHOW PAPERWORK may remain simplified for this gate and must not make unverified legal claims.

## 5. Minimum Plan Run capability

5G requires a deliberately small Plan Run editor. It is an operational sequence editor, not a customer-only list and not an optimisation engine.

It must allow a real day to be represented using at least:
- Terminal / Load items;
- Customer Site Visits;
- multiple Fill Items beneath one physical Site Visit;
- requested/fixed times where applicable;
- product;
- planned litres;
- manual reordering;
- add, edit and remove of future plan items.

Example structure:

`START → Terminal/Load → Site Visit (multiple fills) → Site Visit → Reload → Site Visit → END`

Planning remains optional. A missing or incorrect plan must never prevent the driver recording what physically happened.

## 6. Today's Run: mutable future, immutable execution

Today's Run begins as a plan and progressively becomes a record of actual execution.

Canonical mutability boundary:

> **Completed = actual history. Current = present operational context. Remaining = editable future intent.**

For remaining/unexecuted work, Today's Run must permit:
- **ADD WORK / ADD STOP** during the shift;
- edit;
- reorder while stationary/crawl under the existing movement restraint;
- remove when no committed execution/history exists.

Add is not restricted to the pre-shift Plan Run workspace. Unexpected work is normal operational reality and must be addable during the shift.

A new Fill Item at the same physical Site Visit is conceptually **ADD FILL**. Work at another physical site is a new Site Visit/Run item.

A purely planned item with no committed execution may be removed from the remaining Run. A lightweight swipe-to-remove interaction is a candidate for the harness.

Once an item has committed operational history, destructive Run removal is prohibited. Plan-editing controls must never erase confirmed execution.

The exact production gesture is not frozen by 5G; the gate tests the mutability rule rather than declaring swipe to be permanent UI.

## 7. Future high-detail history refinement — preserve the doorway, do not build it in 5G

A later interaction-resolution design may make the secondary action on completed work useful to high-detail drivers.

Its purpose is not merely to add labels. It may allow the driver to append facts that DA could not defensibly infer from sensors.

Example:

DA evidence:
`05:11–05:34 — GPS stationary at site`

Later driver-established refinement could include:
- waited here;
- pump started at a driver-declared time;
- pump stopped at a driver-declared time;
- repositioned;
- paperwork;
- waiting/demurrage;
- other work;
- operational note.

The original evidence remains untouched. Retrospective driver detail is appended with provenance indicating that it was declared later and refers to the earlier operational period.

This is a promising mechanism for higher interaction resolution without covering the primary workspace in permanent buttons.

**It is explicitly not a 5G implementation requirement.** 5G preserves the architectural doorway and uses the real-shift findings to inform later design.

## 8. Historical enrichment is not correction

Three concepts must remain distinct:

1. **Historical enrichment** — additional driver-known operational detail appended to existing history.
2. **Correction of erroneous driver entry** — e.g. a fat-finger quantity/time entry.
3. **Physical reconciliation/variance** — observation disproves calculated physical state.

These may eventually share an entry gesture or secondary menu, but they are not the same domain operation.

5G requires only the minimum functional correction/reconciliation escape paths needed to prevent a real shift becoming stranded. The full correction UX, including treatment of erroneous committed events, is deferred for later deliberate design.

Corrections must preserve provenance rather than destructively rewriting history.

## 9. Real Load capture

Real OCR is not a prerequisite for 5G.

The harness must allow the driver to use the physical BOL/paperwork as the reference and manually reproduce the actual load using the existing multimodal Load Draft concepts.

It must support:
- real product selection;
- arbitrary compartment quantities;
- returned product already aboard;
- multiple loads/reloads in one shift;
- drag and numeric entry;
- Undo before confirmation;
- Confirm Load as the commit boundary;
- a functional post-confirm correction/reconciliation escape path.

A simulated BOL control may remain in the harness but is not used as evidence for the real-shift gate.

## 10. Real Delivery, Transfer and reconciliation

The harness must survive ordinary real-world variance, including:
- actual delivery quantity differs from plan;
- different source compartments from the planned/expected allocation;
- calculated residual but compartment physically empty;
- customer takes more or less than expected;
- extra fill;
- mistaken iPad entry;
- compartment-to-compartment transfer.

Delivery, Transfer and Reconciliation remain distinct domain events.

A minimal Transfer path must permit:
`source compartment → destination compartment → product → quantity → CONFIRM TRANSFER`.

A minimal Reconciliation path must permit an explicit physical observation to correct calculated state without silent zeroing or history rewrite.

## 11. Work/rest resolution for 5G

5G does not require the final high-detail operational taxonomy.

The minimum useful real-shift representation may remain approximately:

`START SHIFT → WORK → REST → WORK → … → END SHIFT`

Automatic evidence may be retained around those anchors. The real shifts are intended to reveal where richer driver classifications are actually worth the interaction cost.

Stationary GPS evidence must never silently become REST.

## 12. Start Shift, End Shift and persistence

A real shift must have complete lifecycle boundaries.

Start Shift requires the existing opening ODO/location checkpoint concept.

End Shift must at minimum capture:
- closing ODO;
- current vehicle;
- outstanding/unresolved cargo discrepancy state;
- explicit End Shift confirmation.

The shift must survive app termination/relaunch during the day. Relaunch must not destroy the evidence required for the field test.

Final production persistence architecture is not required to be redesigned solely for 5G, but durable save/replay/recovery is a blocker for a valid real-shift gate.

## 13. Minimal Journal / chronological reconstruction

5G does not require the final V3 Journal UI.

It does require enough chronological history to reconstruct the shift, including:
- Start Shift;
- loads;
- deliveries;
- transfers;
- reconciliations/corrections;
- required work/rest anchors;
- End Shift.

The central test is:

> **Did V3 remember the day truthfully?**

## 14. End Shift Real-Shift Gate Report

End Shift in the 5G harness is test instrumentation, not the final production End Shift design.

Flow:

`END SHIFT → closing checkpoint → commit shift → REAL-SHIFT GATE REPORT`

The Gate Report must be derived from DA's own authoritative records and projections. It must not be populated from the later BFA/FC report.

It should expose enough information to compare the day against the independent external shift-end report, including where available:
- shift start/end and elapsed time;
- opening/closing ODO and calculated kilometres;
- work/rest periods and totals;
- planned versus actual Run execution;
- terminal/load visits;
- loads by product/compartment/litres;
- physical Site Visits in actual sequence;
- deliveries by site/fill/product/litres;
- transfers;
- reconciliations/corrections;
- opening → movement → closing cargo reconstruction;
- unplanned work and changed quantities;
- unresolved discrepancies;
- relevant evidence/uncertainty;
- persistence/recovery events relevant to the test.

The internal gate should explicitly report checks such as:
- cargo arithmetic internally reconciles: PASS/FAIL;
- ODO/distance anchors complete: PASS/FAIL;
- work/rest timeline sufficiently complete for the harness: PASS/FAIL;
- every confirmed Load represented: PASS/FAIL;
- every confirmed Delivery represented: PASS/FAIL;
- unresolved discrepancies: count;
- persistence/replay reproduces the same committed result: PASS/FAIL.

Before the external report is supplied, the Gate Report should clearly state:

**EXTERNAL REPORT COMPARISON: NOT YET CHECKED**

## 15. Post-shift comparison

Only after the DA Gate Report has been produced should 5G compare:
- intended trip report;
- DA internal reconstruction;
- external BFA/FC shift-end report;
- driver recollection/notes where needed.

Differences should be classified rather than simply called failures. Useful categories include:
- DA failed to capture required truth;
- missing driver input;
- projection/calculation defect;
- persistence/replay defect;
- external system models the work differently;
- plan changed during execution;
- genuine operational distinction;
- unresolved/insufficient evidence.

The comparison is a test artefact. The BFA/FC report is not imported into DA as source truth.

## 16. Explicit non-goals

The following may remain fake, simplified or deferred for 5G unless a real-shift blocker is discovered:
- production top-row controls;
- real speed integration in the harness;
- compass;
- attention centre;
- polished suburb/location presentation;
- hamburger/settings implementation;
- production Maps presentation;
- site polygons;
- fill-point proximity circles;
- entry/exit pins;
- route optimisation;
- traffic;
- production ETA engine;
- geofence inference;
- real OCR;
- final EIP/ERG/DG compliance implementation;
- final mass visualisation;
- final product colour system;
- polished statistics;
- final Journal design;
- final high-detail historical-enrichment UX;
- complete correction UX;
- production visual polish/animation.

No deferred capability may be faked in a way that creates false operational history.

## 17. 5G build-entry checklist

Before the real shift, the harness must have:

1. blocking 5F repairs required for field use;
2. minimum Plan Run editor;
3. add/edit/reorder/remove of remaining work during the shift;
4. real manual Load capture;
5. real Delivery capture with planned-versus-actual quantity;
6. Transfer and reconciliation/correction escape paths;
7. Start Shift and End Shift with ODO anchors;
8. durable save/relaunch/recovery;
9. minimal chronological reconstruction;
10. End Shift Real-Shift Gate Report;
11. no workflow that requires GPS, Maps, geofence, OCR or a pre-existing plan to record something that physically happened.

Once these are present, stop expanding scope and field-test.

## 18. Gate disposition

5G passes only when a complete real shift can be carried from Start Shift through End Shift without losing authoritative truth or becoming trapped by an incorrect/missing plan, and the resulting DA record can be reconstructed independently for post-shift comparison.

The preferred confidence target is two materially different real shifts.

The real-shift gate question remains:

> **Can I carry this iPad for an entire real tanker shift, tell DA only what it genuinely needs to know, record reality when the day deviates from the plan, and reconstruct the day accurately afterwards?**
