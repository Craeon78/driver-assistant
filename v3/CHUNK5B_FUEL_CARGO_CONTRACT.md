# Chunk 5B — Fuel / Cargo Contract

Status: REVIEWED CONTRACT — BUILD BASIS
Date: 2026-09-17

## Purpose

Fuel/Cargo owns transported-product truth. It answers what product is physically represented in each vehicle compartment, how many litres are present, the product density/SG used for derived mass, the compartment's residual/vapour state, and the immutable cargo transactions that produced the current projection.

This contract consolidates the 5B fuel questionnaire and subsequent fuel/cargo deep dive. It deliberately excludes route optimisation, ETA, fatigue strategy and site-dwell prediction.

## Ownership boundaries

- Vehicle owns compartment identity, physical capacity, Safe Fill and geometry.
- Fuel/Cargo owns product identity, litres, density/SG, residual/vapour state and cargo transactions.
- Mass consumes Fuel/Cargo litres × density/SG and Vehicle geometry; Fuel/Cargo does not own empirical axle-distribution rules.
- Operations records Load / Unload / Transfer events.
- Site supplies customer/site context and site policy facts.
- Policy interprets DG, slosh, placard, compatibility and site restrictions. Fuel/Cargo must not invent regulatory policy.
- Run/TodayView may plan/propose cargo states but planning remains prospective until Confirm commits actual truth.
- Journal reconstructs actual cargo history from committed events; corrections do not rewrite history.

## Supported product catalogue

Initial fuel products:

- Diesel
- Ultimate Diesel
- ULP 91
- PULP 95
- S-PULP 98
- E10

Product catalogue data is configuration, not hard-coded operational policy.

## Truth model

### Litres

Litres are the primary inventory truth. Mass is derived, not independently edited cargo truth.

Derived product mass = observed litres × applicable density/SG.

A load uses one density/SG value per product for that load across compartments unless a later evidence-backed requirement explicitly establishes otherwise.

### Compartment state

A compartment projection must distinguish at least:

1. liquid product identity, if litres > 0;
2. liquid litres;
3. residual/vapour state;
4. whether an explicit degas has cleared the residual state.

Zero litres does NOT mean chemically blank/degassed.

Initial/new compartment state may be treated as effectively degassed only as an explicit initialisation condition; once product history exists, emptying liquid does not silently clear residue/vapour.

Product entry establishes the corresponding residual family/state. Diesel residue and petrol-family vapour/residue remain meaningful after liquid reaches zero. Explicit Degas is the state transition that clears residual/vapour state.

## Cargo transactions

Cargo truth is event-derived. Required transaction semantics include:

- Load — product enters transported cargo from an external source.
- Unload / Delivery — product leaves transported cargo to a customer/destination.
- Transfer — product moves between represented cargo locations without pretending it was newly loaded or disappeared.
- Degas — explicit operational state transition clearing applicable residual/vapour state; it is not equivalent to unloading to zero.
- Correction — append-only provenance correcting a recorded fact without erasing the original record.

Multiple loads and reloads during one shift/run are supported. A later load must not overwrite earlier load/delivery history.

### Running tank

Vehicle running fuel is distinct from transported cargo state. However, where company accounting treats the truck running tank as a customer, product delivered from transported cargo into the running tank is recorded as an Unload/Delivery transaction to a destination/customer type such as Vehicle / Running Tank. This reduces transported cargo litres normally and preserves the commercial/accounting meaning of the delivery.

Do not misclassify such a delivery as an internal cargo transfer merely because source and destination are on the same vehicle.

## Plan → actual → Confirm

Planning may propose compartment/product/litre states without mutating authoritative cargo truth.

Required flow:

Plan → capture actual → reconcile → Confirm → append committed cargo event(s) → project current state.

Original demand, proposed plan, chosen plan and confirmed actual are distinct facts. A changed customer quantity must not rewrite the original requested quantity.

Example test case: customer demand may begin at 20,000 L, driver/customer agreement may later confirm 17,000 L, and the actual load/delivery may differ again. All relevant stages remain reconstructable.

## Correction / incident / prevention semantics

These are not synonyms:

- Correct — the record is wrong; append a correction with provenance.
- Incident / shandy — the physical event itself was wrong or contamination/mixing actually occurred; preserve it as an incident, not as a tidy correction.
- Prevention — a proposed unsafe/invalid state is challenged before it becomes physical truth.

Consequential actions must be deliberate and easy to find. No silent correction of cargo history.

## Compatibility and policy

Fuel/Cargo may represent compatible additive loading when the physical/product model permits it, but terminal, site, DG, placard, switch-loading and other restrictions belong to Policy/Site rather than being guessed by Fuel/Cargo.

Switch-loading and degassing must be explicit state transitions where applicable. Configured site restrictions must not be inferred merely from GPS position.

Policy severity remains distinguishable as:

1. hard invariant;
2. verified regulatory intervention;
3. operational warning;
4. empirical advisory.

Unverified regulatory numbers or empirical Truck 92 behaviour must not become universal executable policy.

## Restricted-site behaviour

A site policy may require pre-printed paperwork, device-off, device-in-cab or similar operating constraints. Those constraints alter presentation/workflow availability, not Fuel/Cargo truth semantics.

## V2 behaviour explicitly retained

5B must preserve the useful V2 concepts rather than accidentally deleting them during refactor:

- residue/vapour awareness;
- Empty Load behaviour;
- placard-related projection inputs;
- degassing behaviour;
- running fuel distinguished from transported fuel;
- multiple/reload loads;
- relevant fuel widgets/projections, rebuilt against the new truth model rather than copied as authority.

## Non-goals for 5B

5B does not own:

- route optimisation or stop ordering;
- ETA/traffic prediction;
- fatigue strategy;
- customer/site dwell baselines;
- GPS breadcrumb logic;
- empirical axle mass-distribution formulae;
- terminal or site policy authoring;
- an all-purpose AppModel.

These systems may consume Fuel/Cargo projections through explicit interfaces.

## Invariants

1. No negative cargo litres.
2. Confirmed litres cannot exceed Vehicle-defined compartment capacity/Safe Fill constraints without an explicit policy/error result; Fuel/Cargo does not silently clamp the value.
3. A zero-litre compartment retains its residual/vapour state until an explicit state-changing event clears it.
4. Derived mass never becomes an independent competing inventory truth.
5. Corrections append provenance; original committed events remain reconstructable.
6. Planning/proposed state cannot silently mutate actual cargo truth.
7. Every committed cargo change has an attributable event/transaction.
8. No invented history and no silent balancing adjustment to make totals reconcile.

## Implementation intent — Bob

Build 5B as a small domain module, not a new monolithic application model.

The implementation should introduce domain types for Product, ResidualState, CompartmentCargoProjection and CargoTransaction/Event payloads; pure projection/reconciliation logic that derives current cargo state from authoritative compartment definitions plus committed cargo events; and tests/fixtures for load, unload, reload, zero-litres-with-residue, degas, correction provenance and running-tank-as-customer delivery.

UI integration follows the domain spine. Existing V2 widgets may be re-expressed as projections but must not become sources of truth.

Before code is marked PASS, verification must demonstrate the invariants above and show that 5B has not absorbed Run Planning or Mass ownership.

## Acceptance cases

Minimum verification scenarios:

1. Fresh/initial compartment → load diesel → unload to zero → diesel residual remains → Degas → residual clears.
2. Petrol-family load → unload to zero → vapour/residual remains.
3. Multiple compartments carrying the same product use the load's applicable product density/SG for derived mass.
4. Reload during the same run appends new truth and does not overwrite the first load.
5. 300 L XLS delivered from transported cargo to Vehicle / Running Tank reduces transported XLS by 300 L and is represented as a customer delivery, not unexplained consumption.
6. Requested 20,000 L → later customer-confirmed 17,000 L preserves both demand and confirmation; actual remains separately confirmable.
7. Incorrect recorded quantity is corrected append-only; the original record remains reconstructable.
8. Actual contamination/shandy is represented as an incident rather than disguised as a correction.
9. Proposed incompatible/invalid state can be prevented without creating a false physical event.
10. Route ETA, peak-hour traffic, site manoeuvring and dwell explanations do not enter the Fuel/Cargo domain model.

## Gate

Niles review: ownership/provenance boundaries incorporated.
Costa review: policy/safety boundary incorporated; no unverified rule promoted to hard executable policy.
Bob intent: recorded above.
Cory GO: received 2026-09-17.

Next: implement against this contract, test, then verify before declaring 5B PASS.
