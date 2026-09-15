# DriverAssistant V3 — Chunked Roadmap

Status: V3 implementation roadmap based on the supplied V3 roadmap and restart supplement.

## 1. Silent spine
Freeze V2 reference; establish V3 ownership/contracts and test target; canonical quantities/localisation; event spine/canonical IDs; persistence/replay/recovery.

Gate: V3 boots, saves and replays a fabricated shift correctly, including forced crash/relaunch.

## 2. Distance truth engine
Migrate proven V2 GPS measurement/filtering into canonical Core evidence; breadcrumb lifecycle/retention; Distance/ODO engine with field-derived regression fixtures.

Gate: road comparison matches or beats V2 accuracy without the catalogued distance regressions.

## 3. Driver truth — PASS (2026-09-16)
Persistent Driver Work/Rest ledger; daily fatigue; rolling/multi-day analytical views; explicit temporal separation of previous/current calendar day, driver-declared shift, continuous episode and rolling windows. A minimal Operations input may be borrowed early without building Operations wholesale.

Gate: **PASS** — real shift, relaunch, overnight-open and cross-midnight temporal tests preserve fatigue truth. Chunk 3 establishes canonical Driver temporal truth; it does not claim complete NHVR regulatory interpretation.

## 3.5. NHVR regulatory interpretation + diary projections
Insert a Policy/regulatory interpretation layer over the passed Chunk 3 ledger before Vehicle + Operations. Do not reopen or mutate Chunk 3 truth to satisfy regulatory presentation.

Implement current applicable NHVR Standard Hours counting-period semantics, including:
- sub-24-hour periods counted forward from relevant rest-break ends, with all simultaneously applicable/overlapping counting windows retained;
- 24h / 7d / 14d periods anchored according to the applicable NHVR major-rest/counting rules rather than treating `now - duration` rolling analytics as statutory truth;
- qualifying stationary rest, short-rest blocks, night rest, consecutive night rest and boundary/overlap cases;
- base-time-zone handling and exact-boundary/adversarial fixtures;
- explicit separation of rolling analytics from statutory counting periods;
- driver-facing current compliance state for each applicable period, with drill-down to all active/relevant counting windows and clear distinction between compliant-as-of-now, approaching constraint, breach and uncertain history;
- forgotten/late/missing work-rest input, corrections, provenance and deterministic replay; missing history must never silently produce a more favourable compliance state;
- one canonical exact-timestamp ledger capable of supporting both electronic-work-diary-style computation and written-work-diary/logbook projection without changing underlying fatigue truth. WWD rounding/representation and EWD-style exact-time interpretation are projections, not competing ledgers;
- preserve the V2 logbook visual concept as a calendar/WWD projection where appropriate.

Gate: Given one canonical work/rest history, Driver Assistant can simultaneously reconcile calendar/logbook representation, continuous episodes, shift truth, rolling analytics and every applicable NHVR counting period. Adversarial fixtures prove overlapping anchors and boundary cases. Driver forgetfulness/correction cannot silently create compliance. The driver can inspect current sub-24h counting-window status and the underlying applicable windows.

Scope note: Standard Hours is the first policy implementation. BFM/AFM/other schemes remain policy variants/deferred unless separately promoted; the architecture must not bake Standard Hours assumptions into Driver truth.

## 4. Vehicle + Operations
Vehicle model with current rigid and truck/quad-dog fixtures; independent Driver/Vehicle/Operations state.

Gate: simultaneous truths coexist. The second vehicle fixture must not require Core/Driver/Operations redesign.

## 5. Cargo/Fuel + modularity proof
Journal replay harness; Site Library; Runs/What's Next shell; Fuel migration to new contracts; Vehicle Mass and Fuel Cargo integration.

Gate A: complete real fuel-delivery shift on V3.

Gate B: a deliberately thin second Cargo stub conforms to the same Cargo contract and attaches without changes to Core, Driver, Vehicle or Operations. If it cannot, modularity has failed regardless of Fuel functionality.

## 6. Journal + Data/Road Packs
Full Journal surface; Data Packs; Road Events/advisory filtering.

Gate: use V3 for a full working week and accurately reconstruct each day.

## 7. Numbers, Simulation, Command
Validate Numbers against known real totals. Give Simulation and Command dedicated design/build phases; do not freeze V2 shells merely because they exist.

## 8. Hardening/release
Privacy/retention/export; justified localisation/commercial-region work; legal/privacy/commercial review. Revalidate the regulatory Policy implementation against then-current authoritative requirements before release; passing Chunk 3.5 is not legal certification of an EWD.

Gate: audit retention, export and fitness for wider use.

## Slice contract
Every semantic implementation slice states its owning domain, allowed dependencies, prohibited ownership, inputs/outputs, invariants, relevant regressions, acceptance tests, non-goals and V2 behaviour to preserve/discard.

Each chunk closes as PASS, PASS WITH RESIDUALS or FAIL. The next chunk remains blocked until its dependency gate permits it.
