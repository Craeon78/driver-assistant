# V3 Chunk 4 — Vehicle + Operations

Status: **PASS (2026-09-16)**
Owners: Vehicle + Operations
Consumes: Core identity/persistence/distance contracts; Driver truth only as independent coexistence evidence

## User-confirmed invariant
Changing the driver's **current** truck/combination must never rewrite which truck/combination was used by a **past** operation.

## Ownership
- Vehicle owns physical vehicle/combination identity and configuration truth.
- Operations owns Drive, Stop, Load, Unload, Transfer, Wait, Maintenance and Incident activity history.
- Driver remains the sole owner of work/rest truth.
- Chunk 2 remains owner of authoritative driver-entered ODO/distance evidence; Vehicle attributes that evidence to the powered vehicle and Operations may consume validated evidence without owning or rewriting it.
- Cargo/Fuel remains deferred to Chunk 5; operation kinds do not own transported-product quantities.

## Historical model
An Operation captures an immutable `VehicleCombinationSnapshot`. A later current-vehicle selection/configuration creates new present/future truth; it does not retroactively alter an earlier operation's snapshot.

Physical assets are independently identifiable where lifecycle/history matters: powered chassis, fitted body/container, towed asset and equipment. Physical compartment identity/capacity belongs Vehicle; transported product/quantity/DG/slosh remains Cargo/Fuel.

## Gate — PASS
1. Drive/Stop lifecycle exists independently of Driver work/rest — PASS.
2. An operation preserves the vehicle combination used at occurrence time — PASS.
3. A materially different second vehicle fixture attaches without Driver or Operations redesign — PASS.
4. Changing current vehicle leaves past operations unchanged — PASS.
5. Operations and captured Vehicle history survive Codable replay/relaunch — PASS.
6. Driver truth remains unchanged by Vehicle/Operations actions — PASS.
7. Rigid and quad-dog physical topology, axle groups/ratings, equipment and configuration-bound tare survive device gates — PASS.
8. Chunk 2 ↔ Chunk 4 ODO integration preserves driver-entered ODO authority, prevents cross-vehicle span contamination before distance-engine commit, and keeps evidence single-use and vehicle-matched — PASS.

## Closeout evidence
- Combination Topology Gate: PASS on Swift Playgrounds/iPad, 2026-09-16.
- Physical Truth Hardening Gate: PASS on Swift Playgrounds/iPad, 2026-09-16.
- Chunk 2 ↔ Chunk 4 ODO Integration Gate v2: PASS on Swift Playgrounds/iPad, 2026-09-16.
- PR #14 Codex review raised three substantive integration defects (pre-commit truck boundary, mutation-path validation, duplicate evidence consumption); all were addressed before the final device gate.

## Residuals / deliberately deferred
- Current transported fuel/product quantities, DG and slosh are Chunk 5 Cargo/Fuel truth.
- Richer running-fuel behaviour is deferred until a later consumer requires it; it is not required to satisfy the Chunk 4 gate.
- Regulatory/legal interpretation remains Policy, not Vehicle.
- Full production UI remains later scope.

## Closure
**CHUNK 4 — VEHICLE + OPERATIONS: PASS.**

The Chunk 5 Cargo/Fuel dependency gate is unblocked.
