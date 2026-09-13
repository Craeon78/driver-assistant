# DriverAssistant V3 — Chunked Roadmap

Status: V3 implementation roadmap based on the supplied V3 roadmap and restart supplement.

## 1. Silent spine
Freeze V2 reference; establish V3 ownership/contracts and test target; canonical quantities/localisation; event spine/canonical IDs; persistence/replay/recovery.

Gate: V3 boots, saves and replays a fabricated shift correctly, including forced crash/relaunch.

## 2. Distance truth engine
Migrate proven V2 GPS measurement/filtering into canonical Core evidence; breadcrumb lifecycle/retention; Distance/ODO engine with field-derived regression fixtures.

Gate: road comparison matches or beats V2 accuracy without the catalogued distance regressions.

## 3. Driver truth
Persistent Driver Work/Rest ledger; migrate/prove daily fatigue; add rolling/multi-day rules. A minimal Operations input may be borrowed early without building Operations wholesale.

Gate: real shifts plus relaunch and overnight-open-shift tests preserve fatigue truth.

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
Privacy/retention/export; justified localisation/commercial-region work; legal/privacy/commercial review.

Gate: audit retention, export and fitness for wider use.

## Slice contract
Every semantic implementation slice states its owning domain, allowed dependencies, prohibited ownership, inputs/outputs, invariants, relevant regressions, acceptance tests, non-goals and V2 behaviour to preserve/discard.

Each chunk closes as PASS, PASS WITH RESIDUALS or FAIL. The next chunk remains blocked until its dependency gate permits it.
