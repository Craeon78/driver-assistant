# Chunk 5H — Cross-System Operational Integration Gate

**Status:** PREBUILD / DISCOVERY PACKAGE  
**Authority:** plan only — no implementation GO is granted by this document  
**Position:** follows Chunk 5G PASS; intended final gate before Chunk 5 close  
**Canonical repository:** `Craeon78/driver-assistant`

## 1. Purpose

Chunk 5H exists to prove that the already-passed Driver/Work-Rest/Fatigue, Vehicle/Operations, Cargo/Fuel, Run/Plan, ODO/time and persistence/recovery systems can coexist through one realistic tanker shift **without contradicting one another, corrupting truth, inventing history or promoting estimates into facts**.

5H is a cross-system integration gate. It is not a new predictive-intelligence feature.\n\n**Primary acceptance is a live real shift on the iPad.** A deterministic harness may be built only as preflight/regression support; harness success alone cannot pass 5H.

Canonical question:

> Can Driver Assistant carry one realistic shift while previously-passed systems interact, and still preserve one coherent, auditable account of what was planned, what actually happened, what was observed and what remains uncertain?

## 2. Why 5H belongs here

The V3 roadmap already defines Chunk 5 as **Cargo/Fuel + operational integration**. Chunks 6–8 are presently allocated to Journal/Data-Road Packs, Numbers/Simulation/Command, and Hardening/Release. None presently owns deliberate cross-system operational thrashing.

Therefore 5H is the minimum closure gate required to complete the integration claim already made by Chunk 5 rather than deferring a hidden architecture risk downstream.

## 3. Governing boundaries

5H MUST combine existing truths and rules.

5H MUST NOT pretend Driver Assistant already knows:
- route/travel duration with production confidence;
- site service duration;
- fuel flow rates;
- nozzle/bulk/gravity duration models;
- learned customer timing;
- predictive schedule feasibility;
- "rest before this delivery because it will take N minutes" intelligence.

Those are future intelligence inputs.

If 5H encounters missing duration/intelligence data, the correct state is **unknown / unavailable / not yet modelled**, not guessed.

## 4. Systems intentionally brought together

Minimum 5H interaction surface:

1. **Driver truth**
   - active shift
   - generic Work anchors
   - Rest start/end
   - fatigue/current rule projections already established by Chunk 3/3.5

2. **Run / Plan**
   - Site Visit / Fill Items
   - Terminal / Load
   - planned Rest
   - planned Other Work
   - editable remaining intent
   - committed execution anchored against destructive plan mutation

3. **Vehicle / Operations**
   - current vehicle/combination context
   - operational event vocabulary
   - ODO ownership/evidence boundaries

4. **Cargo / Fuel**
   - opening cargo baseline
   - Load
   - Delivery, including deliberate 0 L outcome
   - Transfer
   - transaction variance
   - Physical Check/reconciliation
   - append-only Correction

5. **Persistence / recovery**
   - save/relaunch/replay during an active shift
   - End Shift/archive/reset
   - immutable completed evidence

6. **Gate / reconstruction**
   - chronological event reconstruction
   - representation integrity
   - operational completeness kept distinct
   - persistence status evidence-based

## 5. Truth rules 5H must protect

- Plan remains intention until execution establishes history.
- Planned Rest is not Rest history.
- Planned Other Work is not Work history.
- Delivery/Load/Transfer/Physical Check/Correction remain separate evidence species.
- Actual operational work must remain Work for fatigue purposes; cargo work does not become Rest.
- Starting or ending Rest must not mutate cargo, Run history or prior operational events.
- Completing cargo work must not silently reset or manufacture Driver fatigue state.
- Reordering future Run items must never reorder committed history.
- GPS/context may enrich later but must not be required to establish valid capture in 5H.
- ODO remains driver truth; no cross-system projection may silently correct it.
- Internal consistency must not be promoted to real-world completeness.
- Estimates/projections are rebuildable and must never become source truth.

## 6. Evidence readiness for future intelligence

5H must audit whether today's event model preserves enough defensible evidence for later operational intelligence **without building that intelligence now**.

Check that later systems could, where evidence exists, recover or relate:
- event timestamps;
- shift/work/rest intervals;
- Run item / Site Visit / Fill identity;
- actual delivery/load quantities;
- cargo exception provenance;
- vehicle identity;
- ODO anchors;
- site/context identity where available;
- ordering and causality between plan, execution and correction.

Do not add synthetic pump-start/pump-finish timestamps merely to make future analytics easier.

Known future intelligence candidates such as delivery method (nozzle, auto-shut-off nozzle, 2-inch bulk, 3-inch bulk, 3-inch gravity, 4-inch gravity), observed flow behaviour, site overhead and travel duration are **future model inputs** unless an already-authoritative field exists today.

## 7. Live-shift acceptance model\n\n5H should be exercised primarily by Cory during a **real working shift**, using the normal DA workflow as events actually occur. The purpose is to let already-passed systems collide naturally rather than to script a synthetic day and call that integration proven.\n\nA deterministic integration harness is still useful before field use to catch obvious regressions and reproduce defects, but it is subordinate evidence. It must not replace the live-shift gate.\n\nThe live shift does not need to manufacture every exception below. Where a rare scenario does not occur naturally, a bounded harness/fixture may provide supplementary coverage without being confused with field evidence.\n\n## 8. Adversarial acceptance scenarios

Niles may refine the exact harness, but 5H should prove at least the following classes.

### A. Planned Rest vs actual Rest
- Rest exists in Run plan.
- Driver performs work before the planned Rest.
- Rest starts earlier or later than the planned slot.
- Actual Rest creates Rest truth only when started.
- Remaining Run intent stays coherent.

### B. Planned Other Work vs actual Work
- Other Work exists in plan.
- Opening/ending actual Other Work creates generic Work truth.
- Plan item cannot manufacture a historical Work interval by itself.

### C. Delivery + Work/Rest coexistence
- Driver completes one or more deliveries while in Work state.
- Delivery does not count as Rest.
- Starting Rest after a delivery leaves delivery/cargo history unchanged.
- Ending Rest returns to Work without duplicating prior cargo events.

### D. Zero-delivery + fatigue/run interaction
- Planned fill resolves to 0 L actual.
- Fill advances correctly.
- No cargo movement or compensating Physical Check is created.
- Driver Work/Rest chronology remains independent and valid.

### E. Exception during same shift
Exercise at least one explicit cargo exception (transaction variance OR Physical Check OR Correction) during a shift that also contains Rest and Run-plan changes.
Expected: exception provenance remains intact and Driver truth is unaffected except for real elapsed Work/Rest state.

### F. Unplanned / reordered work
- Insert or reorder future work after some execution is committed.
- Historical items remain anchored.
- Future intent remains editable where allowed.
- No history is rewritten.

### G. Mid-shift relaunch
- Persist/relaunch after a mixture of Work/Rest and cargo/run events.
- Recover one coherent current state.
- No duplicate Rest, Delivery, Load or plan-change events.
- Current Run and cargo projections rebuild from durable truth.

### H. End Shift reconstruction
- End with coherent ODO anchors, Driver history, Run execution and cargo state.
- Gate can reconstruct event order.
- Representation integrity can PASS while operational completeness remains NOT ESTABLISHED unless external completeness evidence exists.

## 9. Deliberate non-goals

5H does not build:
- learned route times;
- map routing/traffic;
- site ETA;
- delivery-duration prediction;
- flow-rate modelling;
- truck pump performance modelling;
- nozzle/bulk/gravity timing intelligence;
- fatigue-based schedule optimisation;
- proactive "take rest before this job" recommendations;
- Journal redesign;
- Data/Road Packs;
- Numbers/Simulation/Command redesign;
- release hardening;
- new NHVR/EWD claims;
- broader V3 visual redesign.

A finding that genuinely requires one of these is captured as a later roadmap dependency, not silently absorbed into 5H.

## 10. Role-specific prebuild duties

### Jarvis — orchestration
- treat this file as the cold-start handoff;
- verify current `main`, roadmap and 5G closeout evidence;
- keep 5H bounded to integration;
- move routine PREBUILD -> build/review loops without using Cory as NEXT middleware;
- stop only for material scope/authority change or required human target-runtime evidence.

### Niles — architecture/adjudication
- confirm dependency directions between Driver, Operations, Run, Cargo/Fuel and persistence;
- identify any cross-system coupling that would violate existing ownership;
- specify minimum test harness and acceptance evidence;
- distinguish integration defect from future-intelligence feature request;
- final adjudication is 5H PASS / PASS WITH RESIDUALS / FAIL.

### Bob — implementation
- prefer harness/integration glue and tests over new domain architecture;
- reuse passed contracts;
- do not create parallel fatigue, cargo, Run or persistence truth;
- make only repairs required by demonstrated integration defects.

### Costa — provenance/evidence
- audit plan vs projection vs event vs observation vs reconciliation/correction distinctions;
- ensure future-intelligence evidence readiness does not create false precision;
- ensure no external BFA/FC report or remembered timing is promoted into DA source truth.

### Quinn — field/UX interpretation
- help turn target-runtime behaviour and driver reactions into explicit findings;
- separate awkward UX from truth-model failure;
- red-team whether a "smart" behaviour is actually supported by available evidence.

## 11. Lifecycle handoff for Work

Expected sequence:

`PREBUILD discovery -> Niles boundary review -> bounded Intent-to-Build -> Cory GO -> Bob build -> Niles review -> Codex review -> findings loop -> merge-for-test decision -> iPad/Swift Playgrounds validation -> Niles adjudication`

Do not declare PASS from merge, static tests or review alone.

A Work session should be able to begin with:

> Jarvis: resume Driver Assistant Chunk 5H from `v3/CHUNK5H_CROSS_SYSTEM_INTEGRATION_PREBUILD.md`. Niles first. Verify current main and 5G PASS evidence, then take the bounded cross-system integration gate through the CozzaHQ lifecycle. Do not expand into predictive scheduling, route/site duration, flow-rate intelligence, Journal, Numbers/Simulation/Command or release hardening.

## 12. Completion criterion

5H passes only when **live-shift target-runtime evidence**, supported by regression/harness evidence where needed, demonstrates that the already-passed systems can interact through a representative real shift without:
- inventing or rewriting history;
- corrupting cargo or Driver truth;
- collapsing plan into execution;
- silently promoting projections/estimates into evidence;
- losing state through relaunch;
- falsely claiming operational completeness.

If 5H passes, **Chunk 5 may be adjudicated complete** subject to Niles confirming no unresolved Chunk 5 contractual residual remains.

## 13. Current disposition

- Chunk 5G: PASS. Durable closeout evidence: `v3/CHUNK5G_CLOSEOUT.md`.
- Chunk 5H: PREBUILD / not yet authorised for implementation.
- Chunk 5: OPEN pending 5H and final Niles closeout.
