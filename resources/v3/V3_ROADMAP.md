# DriverAssistant V3 — Chunked Roadmap

**Status:** Living V3 implementation roadmap  
**Updated:** 20 September 2026  
**Current position:** Chunk 5F target-runtime field findings captured; targeted refinement and Plan Run design remain before Chunk 5 closes.

This roadmap is directional, not a substitute for each chunk's contract, gate evidence or field-test record. Completed chunks remain locked unless a later integration defect requires an explicit repair.

## 1. Silent spine — PASS

Freeze V2 reference; establish V3 ownership/contracts and test target; canonical quantities/localisation; event spine/canonical IDs; persistence/replay/recovery.

Gate: V3 boots, saves and replays a fabricated shift correctly, including forced crash/relaunch.

## 2. Distance truth engine — PASS

Migrate proven V2 GPS measurement/filtering into canonical Core evidence; breadcrumb lifecycle/retention; Distance/ODO engine with field-derived regression fixtures.

Locked principle: **ODO is driver truth; GPS is evidence/estimate.** GPS may enrich context but must not silently correct ODO or manufacture history.

Gate: road comparison matches or beats V2 accuracy without the catalogued distance regressions.

## 3. Driver truth — PASS (2026-09-16)

Persistent Driver Work/Rest ledger; daily fatigue; rolling/multi-day analytical views; explicit temporal separation of previous/current calendar day, driver-declared shift, continuous episode and rolling windows.

Gate: **PASS** — real shift, relaunch, overnight-open and cross-midnight temporal tests preserve fatigue truth. Chunk 3 establishes canonical Driver temporal truth; it does not claim complete NHVR regulatory interpretation.

## 3.5. NHVR regulatory interpretation + diary projections — PASS (2026-09-16)

Policy/regulatory interpretation layer over passed Chunk 3 truth. Chunk 3 Driver truth remains locked and unmodified.

Implemented Standard Hours foundation includes overlapping statutory counting windows, long-period fixtures, base-time-zone handling, exact/EWD-style/WWD/local-area projections, uncertainty/correction provenance and deterministic replay.

Gate: **PASS** on Swift Playgrounds/iPad. See `v3/CHUNK3_5_CLOSEOUT.md`.

Scope note: this is an engineering/policy gate, **not NHVR approval or EWD certification**. BFM/AFM/other schemes remain policy variants unless separately promoted.

---

# Post-3.5 implementation record

## 4. Vehicle + Operations — PASS (2026-09-16)

Vehicle and Operations were separated from Driver truth.

Established:
- physical vehicle/combination identity and immutable historical combination snapshots;
- rigid and truck/quad-dog topology fixtures;
- axle groups/ratings, equipment and configuration-bound tare;
- Drive/Stop/Load/Unload/Transfer/Wait/Maintenance/Incident operation vocabulary;
- Chunk 2 ODO evidence attributed to the powered vehicle without transferring ODO authority to Vehicle/Operations;
- cross-vehicle ODO spans rejected before distance-engine commit;
- past operations remain attached to the vehicle/combination actually used.

Gate: **PASS**. See `v3/CHUNK4_VEHICLE_OPERATIONS.md`.

## 5. Cargo/Fuel + operational integration — IN PROGRESS

Chunk 5 is no longer one undifferentiated Fuel migration. It has established a generic Cargo socket first, then Fuel, mass and field-workflow integration on top.

### 5A. Generic Cargo foundation — PASS

Generic Cargo owns reusable cargo identity, quantities, compartment limits, transactions and append-only ledger semantics.

Key rule: **Cargo is the socket; Fuel is a client of it.** A thin non-fuel implementation must remain possible without teaching Core, Driver, Vehicle or Operations about Fuel.

Planning/drafts do not mutate authoritative cargo truth. Confirmed cargo changes are attributable through the Cargo transaction spine.

### 5B. Fuel/Cargo handshake — PASS WITH CONTRACT RESIDUALS CARRIED FORWARD

Fuel specialises generic Cargo rather than creating a second inventory ledger.

Established:
- litres as Fuel inventory quantity;
- fuel product identity/catalogue behind the Fuel boundary;
- load, unload/delivery, transfer and correction through generic Cargo transactions;
- Fuel-specific residue/vapour and Degas semantics;
- running-tank delivery remains a cargo unload/customer delivery, not unexplained consumption;
- derived mass does not become competing inventory truth.

Fuel compartment projection retains **two product-related states** where applicable:
1. liquid product + litres;
2. residual/vapour state.

Therefore **0 L is not equivalent to chemically clear**. Product history/residue persists until a valid explicit state transition such as Degas clears it.

Load-specific density/SG and any cross-density blending semantics must remain explicit; do not silently average, relabel or turn density into product identity without a proved rule.

See `v3/CHUNK5B_FUEL_CARGO_CONTRACT.md`.

### 5C. Vehicle mass integration — PASS

Vehicle consumes generic cargo mass without learning Fuel semantics.

Established:
- tare remains Vehicle evidence;
- gross mass is derived from applicable tare + transported mass;
- axle distribution requires explicit geometry and configuration-matched tare evidence;
- missing/ambiguous geometry returns unavailable rather than guessed axle splits;
- Truck 92 evidence remains a fixture, not a universal formula;
- weighbridge/supplier discrepancies remain independent evidence rather than being massaged to reconcile.

No empirical Truck 92 axle rule is promoted to generic architecture.

### 5D–5E. Operational workflow / field-model integration — MODEL DIRECTION ESTABLISHED

Field modelling established the distinction between:
- **Plan** — intended future;
- **Projection** — calculated consequence if the plan executes;
- **Event log** — committed/recorded facts;
- **Current cargo** — derived from authoritative committed transactions;
- **Observation/evidence** — physical-world signal or driver observation;
- **Reconciliation** — explicit correction/variance when observation disproves calculated state.

Delivery, reconciliation and transfer are distinct events. A site visit may contain multiple fills/deliveries plus transfer/reconciliation activity.

Confirmed interaction timestamps must not be falsely labelled as physical pump start/finish times.

5E field result: **MODEL PASS / UX FAIL**. The domain model survived; the old field UI was not to be polished and instead led to the 5F adaptive-workspace exercise.

### 5F. Adaptive workspace UX harness — TARGET RUNTIME PASS / UX CONCEPT PASS WITH REFINEMENT

Five touch-testable iPad states were built:
1. Pre-shift
2. Active / Driving
3. Site / Delivery
4. Load
5. Rest / Break

The harness compiles/runs on the actual Swift Playgrounds/iPad target after target-runtime actor-initialisation repairs.

#### Passed or validated
- stationary/crawl Run reordering;
- moving-state restraint: information remains visible while plan/site manipulation is suppressed;
- truck-as-input delivery concept;
- direct numeric quantity entry;
- Confirm as draft/projection → committed truth boundary;
- one Load Draft manipulated by simulated scan + drag + type;
- Rest workspace hierarchy;
- post-load return to Active;
- physical Run ontology centred on **Run → Site Visit → Fill Item**, rather than inheriting external FC job granularity.

#### Refinement required
- make START SHIFT a large central primary action;
- stabilise delivery drag geometry and use snap hysteresis/latching so the planned-quantity snap cannot shake the compartment UI;
- after one fill at a multi-fill site, expose the next fill as **expected context**, not as if pumping has started;
- allow confirmed execution to progressively reconcile displayed Run order while leaving remaining work editable;
- replace permanent Load paperwork expansion with an **EIP-first panel + SHOW PAPERWORK modal**;
- correct prototype terminology: **XLS = diesel; DIE = Direct Into Equipment and is not a fuel product**;
- add easy product selection/differentiation without bypassing confirmed liquid or residual/vapour truth;
- keep product identity and proposed/confirmed state as separate visual dimensions;
- do not infer physical pump/load timing from iPad interactions.

See `v3/CHUNK5F_IPAD_FIELD_TEST_FINDINGS.md`.

### Interaction-resolution architecture — REQUIRED BEFORE PRODUCTION UI FREEZE

5F field testing established that Driver Assistant needs **one truth/evidence plumbing with configurable interaction resolution**, not separate basic/detailed logging systems.

Four conceptual layers:
1. **Core anchors** — facts DA requires to remain truthful/useful.
2. **Automatic evidence** — timestamps, GPS/movement/stationary/site proximity and other captured signals.
3. **Derived projections** — calculated cargo/run/etc. views; useful outputs, never independent evidence/source truth.
4. **Optional operational refinement** — driver-established detail such as waiting/demurrage, repositioning, prep, paperwork and richer other-work classification.

Two boundaries must be deliberately designed:
- **Minimum useful interaction floor:** below this, DA becomes too weak/misleading to perform its core job.
- **Maximum practical interaction ceiling:** above this, extra prompts/buttons/classifications create attention fatigue, forgotten/late inputs or false precision.

Canonical rule:

> **Capture the strongest defensible evidence once. Preserve the same major anchors. Allow the driver to refine the operational record only to a useful, chosen resolution.**

Driver settings may change operational resolution but cannot disable questions necessary for cargo truth, fatigue/work-rest integrity or other core functions.

### Plan Run — NEW REQUIRED DESIGN STATE

5F field testing exposed a missing pre-planning workspace. The pre-shift screen can show Today's Run, but V3 still needs a place to construct it.

Plan Run must support an operational sequence rather than a customer-only list, including:
- terminal/load stops;
- customer Site Visits and Fill Items;
- reloads;
- fixed/requested times;
- current and required cargo;
- travel/geography;
- fatigue constraints;
- driver judgement/manual reorder.

Planning is optional and must never block valid unplanned work. DA may project/suggest; the driver chooses the operational plan. Do not add fake scheduling intelligence to the 5F fixture merely to imitate this future engine.

### Chunk 5 remaining gate

Before Chunk 5 can close:
1. apply/review the targeted 5F UX refinements;
2. design/test the interaction-resolution floor and ceiling;
3. design Plan Run as its own UX state;
4. preserve explicit reconciliation/variance paths;
5. complete any remaining production integration needed to run a representative real fuel-delivery shift without bypassing Cargo/Fuel truth;
6. retain the thin non-fuel Cargo modularity proof.

**Chunk 5 is not closed merely because the 5F harness runs.**

---

## 6. Journal + Data/Road Packs — PLANNED

Journal remains the truth-history projection: **TodayView = decision display; Journal = truth history.**

Full Journal surface; Data Packs; Road Events/advisory filtering; site pins/boundaries and useful geospatial evidence without turning GPS into operational truth.

The existing V2 Journal design is provisionally retained unless later testing gives a reason to replace it.

Gate: use V3 for a full working week and accurately reconstruct each day.

## 7. Numbers, Simulation, Command — PLANNED

Validate Numbers against known real totals. Give Simulation and Command dedicated design/build phases; do not freeze V2 shells merely because they exist.

Mass and cargo calculations must retain their evidence/projection boundaries; simulations must not create historical truth.

## 8. Hardening / release — PLANNED

Privacy/retention/export; justified localisation/commercial-region work; legal/privacy/commercial review; accessibility and production polish.

Revalidate regulatory Policy against then-current authoritative requirements before release. Passing Chunk 3.5 is not legal certification of an EWD.

Gate: audit retention, export and fitness for wider use.

---

## Cross-cutting V3 rules now established

- **Append-only truth; projections are rebuildable.**
- **ODO is driver truth; GPS is evidence/estimate.**
- **Sensors establish evidence; context establishes likely state; driver actions establish facts only the driver can confirm.**
- **GPS/geofence enriches but never gates valid capture.**
- **No invented history and no silent corrections.**
- **Confirm is the normal draft/projection → truth boundary.**
- **TodayView is a decision display; Journal is truth history.**
- **While moving: status, not analysis.**
- **While resting: recovery first; work remains available on request.**
- **Run begins as plan and progressively becomes a record of actual execution.**
- **External business-system job granularity does not dictate physical driver workflow.**
- **Automation removes work; it does not remove driver control.**
- **Calculated/derived state is not evidence and must not be fed back as source truth.**
- **Fuel liquid state and residual/vapour state remain distinct.**
- **Truck 92 and five-compartment assumptions are fixtures, not architecture.**
- **No V2 feature is retired merely because a prototype omits it.**

## Mandatory V2 → V3 preservation audit

Before production feature freeze, every user-facing V2 capability must be classified:

**KEEP / ADAPT / REPLACE / RETIRE**

Known items that must not disappear accidentally include Journal behaviour, lazy-axle status, running-tank status, vehicle/shift/driver information and other useful V2 surfaces not exercised by 5F.

## Slice contract

Every semantic implementation slice states its owning domain, allowed dependencies, prohibited ownership, inputs/outputs, invariants, relevant regressions, acceptance tests, non-goals and V2 behaviour to preserve/discard.

Each chunk closes as **PASS, PASS WITH RESIDUALS or FAIL**. A later chunk may expose an integration defect, but must repair it explicitly rather than silently rewriting a previously locked truth model.
