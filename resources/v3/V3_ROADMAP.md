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

## 3.5. NHVR regulatory interpretation + diary projections — PASS (2026-09-16)
Policy/regulatory interpretation layer over the passed Chunk 3 ledger. Chunk 3 Driver truth remains locked and unmodified.

Implemented Standard Hours foundation includes:
- sub-24-hour periods counted forward from rest-break ends with overlapping windows retained;
- 24h / 7d / 14d policy fixtures for major stationary rest, night rest, consecutive night rest and overlapping anchors;
- base-time-zone input and boundary/cross-midnight fixtures;
- explicit separation of rolling analytics from statutory counting periods;
- driver-facing compliance headline model with drill-down to active windows;
- forgotten/late/missing work-rest uncertainty, correction/provenance support and deterministic replay;
- one canonical exact-timestamp ledger projected separately as exact/EWD-style, WWD and local-area representations.

Gate: **PASS** — foundation harness plus 3.5a Long-period Standard Hours, 3.5b Diary interpretation, 3.5c Recovery/replay and 3.5d Driver surface all passed in Swift Playgrounds on iPad on 2026-09-16. See `v3/CHUNK3_5_CLOSEOUT.md`.

Scope note: Standard Hours is the first policy implementation. BFM/AFM/other schemes remain policy variants/deferred unless separately promoted; the architecture must not bake Standard Hours assumptions into Driver truth. Passing Chunk 3.5 is an engineering gate, not NHVR certification of an EWD.

## 4. Vehicle + Operations — UNBLOCKED
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
