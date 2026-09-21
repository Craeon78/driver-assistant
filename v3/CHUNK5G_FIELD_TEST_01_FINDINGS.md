# Chunk 5G — Field Test 01 Findings and Repair Package

**Status:** FIELD GATE FAILED — DIAGNOSIS COMPLETE / REPAIR IN SCOPE  
**Authority:** merged `CHUNK5G_INTENT_TO_BUILD.md`, `CHUNK5G_REAL_SHIFT_GATE.md`, and first iPad 5G field simulation after PR #30  
**Purpose:** durable Costa/Niles diagnosis for the continuing 5G BUILD. This is not a new Intent-to-Build and does not authorise scope expansion.

## 1. Driver-observed sequence

The first 5G iPad run deliberately simulated a real morning rather than the old deterministic 5F scenario.

- START SHIFT was over-enlarged and moved above the three-column workspace. Intended placement remains the middle of the centre Today column: prominent, but not a full-width banner.
- Pre-shift lacked the required vehicle-assumption cargo verification/edit surface, so the driver used Load as a workaround to establish cargo already aboard.
- The manually entered load used real prior load-plan quantities including 5,358 L, 3,249 L and 7,239 L.
- Later workspaces reverted to old/default cargo instead of carrying confirmed state forward. Product liquid presentation also changed colour between workspaces.
- ADD SITE created generic NEW CUSTOMER / NEW SITE with a default 5,000 L fill and no edit step for customer/site/product/quantity.
- Entering work could trap the driver in Delivery with no neutral exit. With zero-delivery confirmation disabled, a false delivery became the practical escape.
- The driver entered 4,000 L for Minjerrabah during this simulation, not the 5,000 L later reported. Seabreeze likewise required an artificially large entry because wrong cargo was present, yet the Gate Report reported the old 9,000 L fixture.
- End Shift was pressed around 07:03. The report then stamped its demo events at report generation and invented a shift start eight hours earlier.
- The Gate Report reported old deterministic 5F scenario values rather than the driver-entered run.

These observations are field evidence. Exact real-world quantities outside the simulated inputs are not required to establish the failure.

## 2. Costa — provenance / truth red-team

**Disposition: FAIL. Synthetic test data can masquerade as live driver-established truth.**

### C1 — Fixture data crosses the live path — P0

Inspection of `Chunk5FPrototypeStore.init()` confirms live harness construction injects:

- opening cargo `[4000, 0, 4500, 3200, 7200]` into CargoLedger with note `chunk5f.fixture.opening`;
- Minjerrabah planned 5,000 L;
- Seabreeze planned 9,000 L;
- Everstin planned 6,500 L.

These are useful deterministic fixtures but currently initialise the store used by live 5G.

**Invariant:** fixtures may exist only behind an explicit simulation/test boundary. They must never silently initialise or substitute for live shift truth.

### C2 — Gate Report is explicitly synthetic — P0

`endShiftDemo()` calls `makeDemoGateReport()`. That builder hardcodes shift start as current time minus eight hours, ODO anchors, opening/closing cargo, 5,000/9,000 deliveries, 200 L transfer, C4 reconciliation, discrepancy count, and every PASS flag.

Its events default to `Date()`, so the synthetic chronology is timestamped at report generation.

Therefore Field Test 01's green PASS labels are not evidence of live 5G integrity.

### C3 — Confirm Load does not commit a Load — P0

`commitLoad()` calls `resetDraft()`, sets a message and returns Active. Because reset reads the unchanged ledger, the driver's proposed load is discarded and fixture state reappears.

### C4 — Confirm Delivery does not commit cargo movement — P0

`commitDelivery()` marks the fill complete but appends no unload transaction to CargoLedger. It then resets from the unchanged ledger.

### C5 — Transfer/Reconcile controls are messages only — P0

The Site controls only set prototype messages. No Transfer or Reconciliation operation is committed. The demo Gate Report nevertheless reports both.

### C6 — Relaunch/persistence PASS is synthetic — P0

`simulateRelaunch()` changes only a message. No persistence/replay occurs in this path, while the demo report sets `persistenceOK: true`.

### C7 — Add Work manufactures plan defaults — P1

`addSiteVisit` defaults to XLS / 5,000 L. ADD SITE supplies NEW CUSTOMER / NEW SITE and no edit step. Plan defaults must never become history.

## 3. Niles — architecture / state inventory

**Disposition: CargoLedger arithmetic is not yet implicated. First defects are failure to commit driver drafts plus fixture/demo state retaining authority. Do not rewrite CargoLedger maths unless post-repair tests fail.**

| Surface | Current behaviour | Classification | Required treatment |
|---|---|---|---|
| opening `[4000,0,4500,3200,7200]` | imported into CargoLedger in store init | KEEP FIXTURE / REMOVE LIVE AUTHORITY | explicit deterministic-fixture construction only |
| SeaLink 5000/9000 + Everstin 6500 | constructor Run fixture | KEEP FIXTURE / REMOVE LIVE AUTHORITY | explicit fixture only |
| `draftLitres` | workspace draft | KEEP | drafts may be local |
| `confirmedLitres` | reads CargoLedger only | REWIRE P0 | project current cargo through `CargoStateReconciler.currentState` so committed ledger movements **and** reconciliation events are reflected |
| `commitLoad()` | discards draft | REWIRE P0 | append confirmed Load movements |
| `commitDelivery()` | completes plan fill only | REWIRE P0 | append confirmed unload movements |
| Transfer/Reconcile buttons | message only | REWIRE P0 | commit real bounded operations |
| `makeDemoGateReport()` | hardcoded scenario | QUARANTINE P0 | explicit preview/test only; live report from records |
| `endShiftDemo()` | always demo report | REWIRE P0 | commit End Shift + live reconstruction |
| `simulateRelaunch()` | message only | REWIRE P0 | real save/reload/replay |
| Gate PASS booleans | supplied true | REMOVE LIVE AUTHORITY P0 | derive from live records |
| Event timestamps | generated at report creation | REMOVE LIVE AUTHORITY P0 | capture at commit |
| START SHIFT | full-width banner | REPAIR UX | centre Today column, prominent but bounded |
| opening cargo UI | absent | ADD REQUIRED | compact truck/list + Confirm/Edit |
| pre-shift Run editing | available | KEEP | off-shift planning valid |
| stationary active Run editing | available | KEEP | retain safe access |
| ADD SITE | hardcoded default item | REWIRE P1 | editable future-intent draft |
| Run row tap | opens Site | REPAIR NAVIGATION | planning must not imply service |
| Site/Load | no neutral exit | ADD P0 | leaving draft creates no event |
| liquid colour | workspace-mode colour | PRESENTATION FIX | shared product representation, colour secondary |
| residual/vapour state | absent from harness | INCOMPLETE | preserve separate state per 5G authority |

Current effective path:

`fixture ledger → workspace draft → Confirm → draft discarded / plan marked complete → fixture ledger remains → demo report ignores live state`.

Required path:

`accepted opening/takeover baseline → authoritative cargo event streams → CargoStateReconciler current-state projection → workspace draft → Confirm → committed operation/reconciliation event → reconciled projection recalculated → every workspace reads it → persistence/replay → Gate Report from committed records`.

**Reconciliation projection invariant:** `CargoLedger.state` alone is not authoritative current cargo after a reconciliation. Reconciliations remain a separate provenance-preserving stream in `CargoReconciliationLog`; all live current-cargo projections and the Gate Report must use `CargoStateReconciler.currentState` (or the equivalent shared reconciled projection) so a physical correction cannot later be resurrected as stale ledger cargo.

Do not repair by passing values directly View-to-View.

### Harness / evidence-source boundary

Harness behaviour and evidence source are separate concerns.

All V3 harnesses should exercise the same shared Driver Assistant domain/event/cargo/persistence spine. A harness may select an explicit source of scenario/evidence, but the harness itself must not own or silently substitute operational truth.

Conceptual source classes:

- **Fixture** — deterministic manufactured scenario for repeatable tests and regression.
- **Live** — current driver-established inputs/evidence for a field run.
- **Replay** — persisted evidence/events from a previous real shift, for future regression/reconstruction.

**5G scope:** implement the separation needed for Fixture versus Live now. Do **not** build a historical Replay feature merely because this architecture anticipates it. However, 5G persistence and event storage must not be designed in a way that prevents a future Replay source.

5F fixtures remain valuable and should not be deleted simply to make 5G safe. They should be quarantined behind an explicit Fixture source. The 5G field harness must use a Live source. Both feed the same authoritative V3 truth machinery; do not create separate CargoLedger/event implementations per harness.

The governing invariant is:

> **The selected source establishes the evidence. The harness exercises the app. The harness never silently substitutes evidence.**

## 4. Repair package for Bob

This remains inside approved 5G scope:

1. **Separate harness behaviour from scenario/evidence source.** Quarantine existing 5F deterministic values behind an explicit Fixture source; 5G field operation uses a Live source. Both feed the same authoritative V3 domain/event/cargo/persistence spine. Do not create duplicate cargo/event implementations for separate harnesses. Preserve an architectural seam for future Replay without implementing Replay in 5G.
2. Implement vehicle-assumption cargo baseline UI: compact pre-shift compartment/product/quantity state plus Confirm/Edit. Acceptance establishes baseline with provenance; it is not a Load. Preserve the same boundary for later vehicle takeover.
3. Make Confirm Load append real driver-confirmed movements to the authoritative cargo/event spine, with displayed current cargo projected through the shared reconciler.
4. Make Confirm Delivery append actual per-compartment unload movements, with subsequent fills/sites reading the resulting projection.
5. Wire Transfer and Reconciliation to real committed operations. Preserve reconciliation as its provenance-bearing stream and derive subsequent current cargo through `CargoStateReconciler.currentState`; do not treat raw `CargoLedger.state` as complete after reconciliation.
6. Build live Gate Report solely from committed records. Capture timestamps at event commit. No plan/default/fixture substitution.
7. Implement actual 5G save/relaunch/replay; a message is not persistence and cannot PASS.
8. Add neutral Back/Close/Return to Active from draft operational workspaces. Navigation commits nothing.
9. Make Add Work editable before insertion: customer, site, fill name(s), product, planned litres, optional applicable time. Planning remains available pre-shift and stationary during shift.
10. Restore START SHIFT to the centre of the middle Today column, larger than 5F but not full-width.
11. Unify product presentation and retain the separate residual/vapour-state boundary.
12. Only then test CargoLedger arithmetic. Change ledger maths only if distinctive-value regression proves it wrong.

## 5. Mandatory distinctive-value regression

Do not use 5F fixture numbers.

1. Accept opening cargo with distinctive values, e.g. C1 **3,917 L XLS**, C3 **4,271 L XLS**.
2. Navigate away/back: identical.
3. Confirm a real Load with an odd quantity: every subsequent workspace reflects the same authoritative result.
4. Confirm exactly **4,123 L** Delivery via explicit compartment movement. History/report must contain exactly 4,123 L.
5. Enter a Delivery draft then leave neutrally: event count and cargo unchanged.
6. Add unexpected work with editable customer/site/fill/product/planned litres. Plan does not become a Delivery.
7. Confirm another odd delivery.
8. Commit an odd Transfer.
9. Commit a Reconciliation/correction.
10. At an operationally safe point, force-close/relaunch using real recovery. Cargo, Run and committed history reproduce exactly.
11. End Shift: Gate Report reconstructs the same operations with original commit timestamps and derives checks from those records.
12. Search live state/report for old fixture values **5,000 / 9,000 / [4000,0,4500,3200,7200]**. Any unexplained appearance fails fixture isolation.

## 6. Gate disposition

Field Test 01 is a **useful 5G FAIL**.

It does not demonstrate a CargoLedger arithmetic defect. It demonstrates that PR #30 left deterministic 5F fixture/demo scaffolding on the live 5G execution path and that several confirm/relaunch/report controls are prototypes rather than committed operations.

Bob should repair the authority path, not cosmetically patch observed numbers.

## 7. CozzaHQ process finding

> When a BUILD graduates from deterministic simulation/harness testing to human-entered or live-field testing, PREBUILD must explicitly inventory and quarantine synthetic fixtures before implementation.

This belongs in CozzaHQ's lifecycle after the DA repair handoff. It is not a reason to restart 5G PREBUILD.


## 8. Field Test 02 — reconciled cargo transaction boundary

**Status:** BOB REPAIR AUTHORISED — Cory GO.

The second live 5G simulation after PR #35 materially improved fixture isolation and live reconstruction: distinctive opening cargo and ODO survived, real interaction timestamps were retained, neutral Back committed nothing, and the old 5F demo deliveries were not manufactured in the Gate Report.

The remaining P0 is now isolated. A driver-entered opening/takeover baseline establishes physical current cargo through `CargoReconciliationLog`, and `confirmedLitres` correctly projects it through `CargoStateReconciler.currentState`. Subsequent cargo-consuming operations still append/validate against raw `CargoLedger`, which has no ledger stock for a reconciliation-only opening baseline. A real 4,000 L delivery therefore failed with `insufficientQuantity`.

**Repair invariant:** any operation validated against authoritative reconciled current cargo must also be committable and replayable against that same chronological cargo truth. A reconciliation must neither strand cargo outside the transaction path nor allow later transactions to resurrect pre-reconciliation state.

Bob is authorised to repair this boundary across Delivery, Transfer, Correction and Load-after-reconciliation. Preserve reconciliation provenance; do not fabricate a Load, overwrite history, pass quantities view-to-view, or rewrite CargoLedger arithmetic merely to satisfy the harness.

Also in this bounded repair:
- derive Gate Report operation-representation checks from committed records rather than hard-coded `true`;
- distinguish persistence/replay **NOT TESTED** from genuine **FAIL**;
- retain Fixture/Live isolation and the existing shared truth spine.

Run the distinctive-value regression after implementation, including a transaction **after** a physical reconciliation and save/relaunch reconstruction.

**Branch/PR instruction:** all implementation commits for this repair must land on `chunk5g-reconciled-cargo-repair` and remain in its single repair PR. Do not create a second repair PR. Codex review, then Niles architecture/integration and Costa truth/provenance review, occur on that PR. Cory retains merge authority.
