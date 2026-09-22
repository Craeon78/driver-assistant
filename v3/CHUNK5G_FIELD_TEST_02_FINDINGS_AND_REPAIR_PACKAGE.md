# Chunk 5G — Field Test 02 Findings and Repair Package

**Status:** PREBUILD evidence package  
**Baseline:** `main` after merge of PR #36 (`09be73191c16954129c2ca66d336bea337e582ce`)  
**Purpose:** preserve the field-established defects and bounded repair requirements needed for the next Chunk 5G repair cycle.

This document is evidence and scope for the next build lifecycle. It is not an implementation, merge approval, or PASS declaration.

## Governing boundary

The latest field run demonstrated that the ordinary 5G cargo spine is now coherent enough that it should **not be reopened as part of this repair unless implementation evidence proves one of the bounded repairs genuinely requires it**.

Observed working behaviour included:
- driver-established opening cargo baseline flowing into subsequent transactions;
- ordinary load/delivery chaining;
- cargo continuity across navigation;
- planned quantities remaining distinct from committed actual quantities;
- run progression;
- opening/closing ODO anchors within the harness;
- End Shift/archive/reset behaviour observed in-process;
- Gate reconstruction from committed records, subject to the completeness defect below.

The next repair therefore targets the **exception layer and explicit state transitions**, not a general cargo redesign.

## Evidence minimisation

The external BFA Trip Report and Shift End Report are **not** DA source data and are not to be imported or reconstructed as a DA shift.

Only facts from those reports that materially support a required procedure/setting change are retained below:
- the externally established TGE delivery quantity of **16,192 L** supports the transaction-variance requirement against DA's **15,997 L** calculated quantity;
- the externally established United quantity of **19,504 L** supports classification of the DA **19,604 L** entry as a driver-input correction case;
- multiple discrete breaks support the requirement that Rest has a repeatable start/end lifecycle.

All other report content is outside this package unless independently required by a later approved scope.

---

# Required repairs

## 1. Transaction variance

### Field finding

DA calculated/committed quantity available for the TGE delivery was **15,997 L**. External metered/dip-established evidence recorded the actual delivery as **16,192 L**.

Derived variance:

`16,192 - 15,997 = +195 L`

The truck was physically empty after delivery.

The existing workflow could not faithfully represent this outcome.

### Required invariant

> A confirmed physical/metered transaction must be recordable when its externally established actual total differs from Driver Assistant's calculated transaction total. DA must preserve the difference explicitly without rejecting the real quantity, inventing compartment cargo, creating negative physical cargo, or requiring the driver to falsify pre-transaction cargo.

### Driver interaction

Variance is an **exception attached to the derived transaction total**, not a standalone normal operation.

For a delivery, the normal compartment interaction continues to derive the DA calculated total. The derived total must provide an exception path that can capture:
- DA calculated quantity;
- externally observed/metered actual quantity;
- signed derived variance;
- post-transaction physical-state evidence where supplied;
- optional note/reason;
- evidence/provenance.

Equivalent behaviour should be available to a load where the same evidence pattern applies.

### Acceptance fixture

- calculated delivery: 15,997 L
- actual/metered delivery: 16,192 L
- variance: +195 L
- observed truck post-state: empty
- expected: actual quantity is preserved; calculated quantity is preserved; +195 variance is explicit; no invented +195 compartment; no negative physical cargo.

---

## 2. Physical Check

### Field finding

The driver may physically observe that a compartment contains a different quantity from DA's calculated state. This is a physical-world observation, not itself an accounting instruction.

### Required invariant

> Driver-facing capture records the physical observation. Reconciliation is the accounting consequence applied by DA.

Use **Physical Check** (or an equivalently plain driver-facing term) rather than exposing generic `Reconcile` as the primary driver concept.

Capture sufficient provenance to retain:
- calculated-before quantity;
- observed quantity;
- derived difference;
- observation/evidence context;
- resulting reconciled current-state projection.

Both positive and negative differences must be valid where physically possible.

### Acceptance fixtures

A. DA C3 = 0 L; driver observes C3 = 100 L.  
Expected: Physical Check records observed 100 L and explicit +100 L difference; current projection reconciles accordingly.

B. DA C3 = 100 L; driver observes C3 = 0 L.  
Expected: Physical Check records empty observation and explicit -100 L difference; no silent zeroing.

---

## 3. Append-only Correction

### Field finding

During the run, **19,604 L** was entered where the intended/externally supported quantity was **19,504 L**. This is an input error, not unexplained cargo variance and not a Physical Check.

### Required invariant

> A committed driver-entered fact that was entered incorrectly is corrected by an append-only correction referring to the original event. The original event is not silently edited or deleted.

The correction must preserve:
- original event identity/value;
- corrected value;
- signed delta;
- correction timestamp/provenance;
- recalculated projections derived through the original event plus correction.

Canonical fixture:

`19,604 L → 19,504 L; delta -100 L`

The user must not need to falsify another cargo state or use Transfer/Physical Check to compensate for an entry error.

---

## 4. Transfer remains distinct

Transfer is a real physical movement:

`source compartment → destination compartment`

It must remain semantically and operationally separate from:
- transaction variance;
- Physical Check/reconciliation;
- Correction.

No repair in this package should collapse these exception species into one generic `Reconcile` operation.

---

## 5. Rest lifecycle

### Field finding

The field harness allowed **Start Rest** but provided no normal usable **End Rest** transition. The driver had to use simulated-driving controls as a workaround.

### Required state transition

`working → start rest → resting → end rest → working`

Rest must be repeatable within one shift. A completed rest remains historical truth and subsequent work must not mutate/delete it.

External shift evidence is relevant only insofar as it confirms that multiple discrete rest periods in one shift are ordinary operational reality; exact external break times are not acceptance fixtures for DA.

### Acceptance fixture

Within one active shift:
1. Start Rest.
2. End Rest.
3. Resume work.
4. Start a second Rest.
5. End Rest.
6. Verify chronological history contains both distinct rest intervals without simulation events being required.

---

## 6. Simulated-driving lifecycle and indication

### Field finding

Once simulated driving was started, the UI did not make the active state or exit sufficiently explicit. Reusing the same control appeared to toggle it, but the driver could not confidently determine the current simulation state.

### Required invariant

Simulation has an explicit state:

`stopped ↔ running`

When running, the UI must make the state unmistakable and expose an explicit stop action (for example **STOP SIMULATED DRIVING**).

Simulation is test infrastructure. It must not manufacture or masquerade as live operational truth.

---

## 7. Gate Report: internal integrity versus operational completeness

### Field finding

The latest Gate Report could report **0 unresolved discrepancies** even though the +195 L TGE discrepancy existed in the physical/external record, because DA had no supported mechanism capable of representing that discrepancy.

Therefore:

> Failure to record a discrepancy is not evidence that no discrepancy existed.

### Required distinction

Gate reporting must distinguish at least:

1. **Representation / internal integrity** — whether DA's committed records and projections are internally coherent.
2. **Operational completeness** — whether the available DA workflow successfully captured the material realities encountered by the acceptance run/test.

A Gate Report may therefore be internally coherent while operational completeness is **FAIL** or **NOT ESTABLISHED**.

Do not derive a claim of real-world completeness solely from zero recorded unresolved discrepancies.

Persistence/relaunch status remains evidence-based and must use **PASS / FAIL / NOT TESTED** (or equivalent), never infer PASS because no failure was recorded.

---

# Canonical exception taxonomy

These are separate concepts and should remain separate in UI, event semantics and durable knowledge:

| Concept | Driver-established meaning |
| --- | --- |
| Transaction variance | External actual transaction total differs from DA-derived total |
| Physical Check | Observed physical compartment state differs from calculated state |
| Correction | A previously entered fact was wrong |
| Transfer | Cargo physically moved from one compartment to another |

Internal reconciliation may implement the accounting consequence of a Physical Check. That does not make all four concepts `Reconcile`.

## Evidence/projection levels

Preserve distinctions between:
- planned;
- estimated;
- calculated;
- observed / externally established;
- corrected.

One level must not silently overwrite or promote itself into another.

---

# Acceptance package

The next implementation must include bounded regression/acceptance coverage for:

1. **Positive transaction variance:** 15,997 calculated → 16,192 actual → +195; truck empty; no negative/invented cargo.
2. **Correction:** 19,604 committed input → append correction to 19,504 → -100; original remains auditable.
3. **Positive Physical Check:** calculated 0 → observed 100.
4. **Negative Physical Check:** calculated 100 → observed 0.
5. **Transfer:** remains an actual compartment-to-compartment movement and is not used as a substitute for cases 1–4.
6. **Rest:** two complete start/end rest cycles in one active shift.
7. **Simulation:** running state visibly explicit; explicit stop; no false live-truth semantics.
8. **Gate:** internally coherent records cannot by themselves claim operational completeness; persistence remains PASS/FAIL/NOT TESTED from evidence.

Where a repair changes projections, Gate output or persistence, existing 5G regression cases from the merged PR #36 baseline must remain valid unless the approved Intent-to-Build explicitly changes an expectation.

---

# Explicitly out of scope

This package does **not** authorise:
- reopening ordinary cargo architecture without evidence that a required repair cannot be implemented within it;
- Journal/V3 redesign;
- day-card/right-rail navigation redesign;
- diary/logbook splash-screen work;
- map redesign;
- truck/rig mass-model redesign;
- general delivery-screen redesign beyond the bounded exception entry required here;
- BFA/FC import or replication;
- reconstruction of the complete external shift;
- EWD/NHVR approval claims;
- unrelated refactoring.

New design discoveries should be captured separately and must not expand this repair package.

---

# Lifecycle handoff

This document is intended to be sufficient evidence for a cold CozzaHQ/Work session to resume without access to the originating chat.

CozzaHQ remains authoritative for how the work is run. Driver Assistant remains authoritative for implementation state.

Expected next lifecycle:

`PREBUILD → bounded Intent-to-Build → Cory GO → BUILD → Niles/Bob repair loop → Niles CLEAR → PR/external review → findings disposed → merge-for-test decision → verified Playgrounds handoff → Cory runtime/field validation → PASS only from required evidence`

The likely next PR number after merged PR #36 is #37, but **the package does not reserve or require that number**. GitHub assigns the PR number when the implementation PR is created.

After GO, Jarvis owns routine in-scope transitions. Cory should not be used as the NEXT/message bus. Human re-entry remains for genuine scope/authority decisions, required review invocation where the platform requires it, merge/test authority, and real runtime/field evidence.

## Field-gate disposition entering this package

**Chunk 5G core shift spine: PASS evidence observed for the bounded ordinary-flow behaviours above.**  
**Chunk 5G exception handling: NOT CLEARED.**

No later build/review result may promote the exception package to PASS without the required executable/real-world validation evidence.
