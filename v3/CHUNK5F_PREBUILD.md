# Chunk 5F — Adaptive Workspace Prebuild Contract

**State:** BUILD AUTHORISED  
**Authorisation:** Cory — “GO!”  
**Purpose:** Touch-test the five-state adaptive workspace on iPad without promoting prototype interaction state into production truth.

## Five workspace states

1. Pre-shift
2. Active / Driving
3. Site / Delivery
4. Load
5. Rest / Break

## Interaction contract

- The persistent shell remains visible across states.
- Active/Driving is map-dominant and interaction-poor.
- Run is organised by physical Site Visit, with Fill Items inside the visit.
- Delivery manipulates a draft cargo projection first. Confirm is the only commit boundary.
- Load has one Load Draft. Simulated scan, drag and numeric entry all modify that same draft.
- Receiving-vessel graphics communicate destination/movement only; they are not level evidence.
- Rest makes fatigue/current-rest state dominant while keeping the Run available but subdued.
- No interaction timestamp is presented as proof of physical pump start/finish or physical loading time.

## Deterministic field fixtures

SeaLink Cleveland is one site visit with:
- Minjerrabah — planned 5,000 L DIE
- Seabreeze — planned 9,000 L DIE

Delivery touch case:
- C4 3,200 L -> 0
- C5 7,200 L -> 5,400 L
- derived movement = 5,000 L

The harness should expose EMPTY and planned-remainder snap targets but never force them.

## Truth boundary

Finger movement, direct typing, simulated OCR and snap suggestions are draft/projection state. They must not silently alter confirmed cargo. Undo discards the proposal. Confirm crosses the prototype truth boundary using existing Cargo/Fuel contracts where practical.

## Load contract

The simulated scan represents extracted BOL data only. There is no image retention. The driver checks the whole DA representation against the physical BOL, then may rescan, drag or type corrections before Confirm Load.

Existing/returned cargo is additive to the proposed load where the fixture semantics say the BOL describes newly loaded quantity.

## Explicit exclusions

No real OCR/camera, GRDB, production fatigue/compliance engine, DG/EIP/ERG legal rules, production MapKit routing/geofence, Journal redesign, Settings suite, production mass model or V2 feature migration.

5F does not retire any V2 feature by omission.

## Stop condition

If implementing the harness requires material changes to existing domain ownership/contracts, stop and return to PREBUILD rather than expanding 5F.
