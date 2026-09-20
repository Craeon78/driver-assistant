# Chunk 5G — Bob Intent-to-Build: Real-Shift Harness

**Status:** PREBUILD — AWAITING GO  
**Target:** iPad / Swift Playgrounds V3 test harness  
**Base authority:** `v3/CHUNK5G_REAL_SHIFT_GATE.md` plus existing V3 contracts  
**Implementation rule:** This document authorises planning only. No 5G Swift implementation begins until Cory gives an explicit **GO** after review.

## 1. Intent

Bob intends to turn the proven 5F adaptive-workspace harness into the smallest truthful **real-shift harness** capable of accompanying one complete tanker shift from Start Shift to End Shift.

The build is not a production-V3 feature sweep. It exists to make the next field experiment possible.

The implementation target is:

> **A driver can enter or alter the intended Run, start a real shift, record real loads/deliveries/transfers/reconciliations as they occur, survive deviations and app relaunch, end the shift, and receive a DA-generated Gate Report that reconstructs the day before any external company report is consulted.**

Once that target is achieved, development stops and the harness goes to the iPad for real-shift testing.

## 2. Owning domains and boundaries

5G will use the established ownership model rather than creating a parallel prototype truth system.

- **Core:** lifecycle, persistence/replay/recovery and event spine.
- **Driver:** shift and Work/Rest anchors.
- **Vehicle:** selected vehicle and ODO anchors.
- **Sites/Runs:** Plan Run, Today's Run and remaining-plan mutation.
- **Cargo:** authoritative quantity transactions and balances derived from them.
- **Fuel:** product/residual-vapour semantics over Cargo.
- **Operations:** Load, Unload/Delivery, Transfer and Reconciliation operational events.
- **Journal/Developer projection:** chronological reconstruction and 5G Gate Report.

Prohibited shortcuts:
- no independent 5G cargo balance as competing truth;
- no Run-plan mutation masquerading as completed history;
- no GPS-derived physical pump events;
- no destructive correction of committed history;
- no use of the external BFA/FC shift-end report to construct DA's own Gate Report.

## 3. Build strategy

Bob will extend the existing 5F harness rather than restart the UI.

The work is split into **seven bounded slices**. Each slice must compile on the target and preserve the contracts of earlier slices.

### Slice A — blocking 5F field repairs

Implement only the repairs needed for real field use:

1. move/enlarge START SHIFT into the central Today area;
2. stabilise Delivery compartment drag geometry;
3. add contextual-snap hysteresis/latching without moving drag geometry;
4. change multi-fill progression from immediate next-fill activation to **next expected fill context**;
5. settle confirmed work into actual Run order while keeping remaining work editable;
6. replace prototype diesel-as-`DIE` semantics with correct `XLS` product semantics;
7. add practical product selection while respecting liquid product and residual/vapour state;
8. keep Rest substantially unchanged.

EIP / SHOW PAPERWORK may remain a truthful simplified harness surface. It must not claim unverified compliance behaviour.

### Slice B — minimum Plan Run + live remaining-plan editing

Add a deliberately small Plan Run workspace capable of representing a real operational sequence.

Required item structure:
- Terminal / Load;
- Customer Site Visit;
- Fill Items nested under a Site Visit;
- requested/fixed time when supplied;
- product;
- planned litres.

Required actions before shift:
- add;
- edit;
- remove;
- reorder.

Required actions during shift on **remaining future intent**:
- ADD WORK / ADD STOP;
- edit;
- remove where no committed history exists;
- reorder while stationary/crawl.

Run invariant:

> **Completed = actual history. Current = present context. Remaining = editable future intent.**

A same-site extra receiving destination is ADD FILL. A different physical site is a new Site Visit.

The harness may trial swipe-to-remove for an untouched future item, but 5G does not freeze swipe as production UX.

Completed items are not destructively removable.

Removing an untouched future item removes it from the **current remaining-plan projection**. It must not require destructive erasure of evidence that the item previously existed in an earlier plan state. 5G does not require a full plan-versioning subsystem, but its implementation must not close the door on plan/revision provenance.

### Slice C — real cargo operations

Remove dependence on simulated scenarios for actual field capture.

**Load**
- manual product selection;
- arbitrary compartment quantities;
- returned product preserved;
- multiple loads/reloads;
- drag + numeric entry on one Load Draft;
- Undo before Confirm;
- Confirm Load commits through Cargo truth.

**Delivery**
- planned and actual quantities may differ;
- driver may choose different physical source compartments;
- extra fill supported;
- no negative physical cargo silently manufactured;
- Confirm Delivery commits actual movement.

**Transfer**
- source compartment;
- destination compartment;
- product;
- quantity;
- Confirm Transfer.

**Reconciliation/correction escape path**
- explicit calculated-versus-observed variance;
- physical empty may reconcile a calculated residual;
- no silent zeroing;
- minimum correction path for erroneous harness input;
- an erroneous committed value is corrected by an explicit provenance-preserving correction event/record, not by overwriting the original committed event;
- provenance retained.

The complete production correction UX is not part of 5G.

### Slice D — shift lifecycle + ODO

Wire a complete real lifecycle:

`PRE-SHIFT → START SHIFT → opening checkpoint → ACTIVE/operations → END SHIFT → closing checkpoint → GATE REPORT`

Opening checkpoint:
- selected vehicle;
- opening driver-entered ODO;
- location/context where available without making it mandatory truth.

Closing checkpoint:
- closing driver-entered ODO;
- selected/current vehicle;
- unresolved cargo discrepancy warning/state;
- explicit End Shift confirmation.

ODO remains the authoritative distance anchor.

### Slice E — durable real-shift persistence and replay

The harness must survive deliberate app termination/relaunch during a shift.

Required:
- committed events persist;
- current shift identity persists;
- confirmed cargo reconstructs from authoritative transactions;
- remaining Run plan persists;
- completed execution persists;
- Work/Rest anchors persist;
- ODO anchors persist;
- unresolved discrepancies persist;
- drafts are either safely restored as drafts or explicitly discarded according to existing crash-insurance semantics; a draft must never silently become committed truth.

After relaunch, the same committed history must reconstruct the same authoritative result.

No new giant AppModel or second persistence truth store is permitted.

5G persistence must reuse or extend the existing V3 authoritative event/persistence spine. Serialising a mutable 5G screen/workspace model may be used only for draft/UI crash recovery where consistent with existing autosave semantics; such a blob must never become the authoritative shift ledger or cargo truth.

### Slice F — minimal chronological reconstruction

Add a deliberately plain chronological field-test view sufficient to inspect:

- Start Shift;
- terminal/load activity;
- Loads;
- Site Visits / Deliveries;
- Transfers;
- Reconciliations/corrections;
- Work/Rest anchors;
- End Shift.

This is not the final Journal redesign.

The purpose is to answer:

> **Did V3 remember the day truthfully?**

### Slice G — End Shift Real-Shift Gate Report

After End Shift commits, produce a test-instrumentation report from DA's own records.

Report sections should include, where available:
- shift start/end/elapsed;
- opening/closing ODO and derived km;
- Work/Rest timeline/totals;
- intended Run versus actual execution;
- terminal/load visits;
- Loads by product/compartment/litres;
- Site Visits and Fill/Delivery events in actual order;
- Transfers;
- Reconciliations/corrections;
- cargo opening → movements → closing reconstruction;
- unplanned work / changed quantities;
- unresolved discrepancies;
- relevant evidence/uncertainty;
- persistence/recovery observations.

Internal checks:
- cargo arithmetic reconciles: PASS/FAIL;
- ODO anchors complete: PASS/FAIL;
- Work/Rest timeline sufficiently complete for 5G: PASS/FAIL;
- all confirmed Loads represented: PASS/FAIL;
- all confirmed Deliveries represented: PASS/FAIL;
- unresolved discrepancy count;
- persistence/replay reproduces committed result: PASS/FAIL.

Gate integrity and real-world uncertainty are separate. A truthful unresolved discrepancy does **not** automatically fail DA's internal integrity gate. For example, cargo transaction/replay integrity may PASS while `unresolved physical discrepancies: 1`. Losing, hiding or silently resolving that discrepancy is the failure.

Before post-mortem comparison it must state:

**EXTERNAL REPORT COMPARISON: NOT YET CHECKED**

The external BFA/FC report is not imported to make this report pass.

## 4. Interaction-resolution boundary for 5G

5G preserves but does not implement the proposed richer completed-history interaction.

Future high-detail behaviour may allow a driver to append driver-known facts to existing history, including:
- waiting;
- retrospectively declared pump start/stop;
- repositioning;
- paperwork;
- demurrage/other work;
- notes.

Original GPS/time evidence remains unchanged and the later declaration retains provenance.

This is **not** part of the 5G build.

Likewise, do not conflate:
- historical enrichment;
- correction of erroneous entry;
- physical reconciliation.

Only the minimum correction/reconciliation escape path required to finish a real shift belongs in 5G.

## 5. Movement restraint

Existing 5F restraint remains:

- while moving, information remains visible;
- Run manipulation and other nonessential planning interaction is unavailable;
- a control already under direct manipulation must not be ripped away mid-gesture;
- necessary safety/Work-Rest controls remain available as appropriate.

5G does not attempt to finish production driving-lock policy.

## 6. Explicit non-goals

Do not spend 5G time on:
- production Maps;
- real routing/traffic/ETA;
- site polygon editor;
- geofence tuning;
- entry/exit pins;
- real OCR;
- final EIP/ERG/DG rules;
- final product colour palette;
- final mass UI;
- production top-row wiring/polish;
- final Journal UX;
- final detailed-driver history refinement;
- comprehensive correction UX;
- onboarding;
- phone/Android;
- cloud sync;
- visual polish unrelated to field usability.

If one of these proves to be a genuine blocker during the real shift, record the finding rather than automatically expanding scope.

## 7. Test fixtures before live use

Before handing the harness to the real shift, Bob will run deterministic fixtures covering at minimum:

1. **Plan deviation:** planned A→B; execute B→A; completed order settles to actual without rewriting remaining intent.
2. **Live add/remove:** add an unexpected future stop; remove an untouched planned stop; completed history remains protected.
3. **Multi-fill:** Fill 1 confirms; Fill 2 becomes expected context, not falsely started.
4. **Load with returned product:** opening cargo + new Load yields correct post-load projection/commit.
5. **Delivery variance:** actual differs from planned quantity.
6. **Physical-empty reconciliation:** calculated residual explicitly reconciled to empty.
7. **Transfer:** compartment-to-compartment movement preserves total cargo.
8. **Fat-finger correction escape:** erroneous committed harness input can be corrected without destructive rewrite.
9. **Crash/relaunch:** terminate during an active shift; committed history and remaining plan reconstruct.
10. **End Shift:** closing ODO commits and Gate Report reconstructs the same day.

## 8. iPad pre-live gate

Before using 5G on a working shift:

- build succeeds in Swift Playgrounds on the actual iPad;
- Start Shift works;
- a representative Run can be entered;
- live remaining-plan add/edit/remove/reorder works;
- Load, Delivery, Transfer and Reconciliation work;
- Work/Rest minimum anchors work;
- force-close/relaunch preserves the shift;
- End Shift works;
- Gate Report renders and agrees with the harness's own committed event history.

No external report is required for this pre-live gate.

## 9. Real-shift procedure

During the live test:

1. use DA as a companion, not as a replacement for required company/legal systems;
2. enter/adjust the operational Run as needed;
3. record real Load/Delivery/Transfer/Reconciliation facts;
4. allow reality to diverge from the plan;
5. use minimum Work/Rest anchors;
6. if DA cannot represent a real event truthfully, do not invent a workaround that falsifies history—record the blocker externally for the post-mortem;
7. deliberately perform at least one app close/relaunch **only when operationally safe and practical** to exercise recovery. Do not perform this test while driving, actively loading/unloading, handling hoses or dangerous goods, or during another task that requires the driver's attention;
8. End Shift and generate the DA Gate Report **before** supplying the external company shift-end report for comparison.

## 10. Post-mortem inputs

After DA has produced its independent Gate Report, the post-mortem may compare:
- original trip report/intended work;
- DA Gate Report and chronological reconstruction;
- external BFA/FC shift-end report;
- driver recollection/notes;
- any screenshots or field-test observations.

Mismatch classification follows the 5G gate contract. Differences are investigated, not massaged away.

## 11. Acceptance

### Build acceptance

5G is ready to leave development when:
- all seven slices are present at minimum useful resolution;
- deterministic fixtures pass;
- actual iPad pre-live gate passes;
- no known workflow requires fake GPS/Maps/geofence/OCR or a perfect pre-existing plan to record a physical event.

### Field acceptance

5G receives a real-shift **PASS** only when:
- Start→End lifecycle completes;
- real deviations can be represented without corrupting history;
- committed truth survives relaunch;
- cargo operations reconstruct coherently;
- the Gate Report is independently generated;
- the day can be reconstructed sufficiently for comparison/post-mortem.

A second materially different real shift is the preferred confidence check before deciding the next architecture/UX priorities.

## 12. Stop rule

> **Once the minimum 5G real-shift capability is working and the iPad pre-live gate passes, stop building and run the real shift.**

Do not convert 5G into production V3 before collecting the field evidence it exists to obtain.

## 13. Bob build commitment after GO

After explicit GO, Bob will:
1. implement the slices in the order above unless a dependency requires a small reorder;
2. keep commits reviewable and bounded;
3. run available tests after each semantic slice;
4. avoid unrelated refactors;
5. preserve target-runtime Swift Playgrounds compatibility;
6. surface genuine domain ambiguity rather than guessing;
7. prepare the implementation PR for Codex/Niles review;
8. not merge that implementation PR until the asynchronous review cycle is actually complete and Cory chooses to merge.

**No implementation has been authorised by this prebuild document.**


## 14. Niles / Costa prebuild review disposition

The existing Intent-to-Build was reviewed without restarting PREBUILD.

**Niles — architecture/integration: PASS WITH CLARIFICATIONS incorporated here.** Future-plan removal must not require erasing plan provenance, and Slice E must use the V3 authoritative event/persistence spine rather than promote a mutable workspace snapshot to truth.

**Costa — safety/data-integrity red-team: PASS WITH GUARDRAILS incorporated here.** Recovery testing is subordinate to safe operations; committed-entry correction preserves provenance; and a truthful unresolved physical discrepancy is distinct from an internal integrity failure.

These are guardrails on the existing seven-slice build, not additional 5G scope.
