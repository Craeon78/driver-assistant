# Chunk 5B — Fuel Module / Cargo Handshake Contract

Status: REVIEWED CONTRACT — BUILD BASIS
Date: 2026-09-17

## Purpose

Chunk 5A already owns and proves the generic Cargo foundation. Chunk 5B does **not** create a second Fuel/Cargo architecture.

Chunk 5B builds **Fuel as the first production specialisation/client of the generic Cargo contract established in 5A**.

The generic Cargo layer remains unaware of fuel semantics. Fuel plugs into that socket and supplies the richer tanker-specific meaning required by Cory's driver configuration.

This contract consolidates the 5B fuel questionnaire and subsequent fuel deep dive. It deliberately excludes route optimisation, ETA, fatigue strategy and site-dwell prediction.

## 5A generic Cargo foundation — authoritative socket

The existing 5A Cargo layer remains authoritative for generic transported-cargo concepts and ledger behaviour. Existing generic types/contracts are to be reused rather than duplicated or shadowed.

The current Cargo contract includes generic cargo identity/descriptor semantics, type-erased `CargoKind`, generic unit naming and optional mass conversion, and Vehicle-owned compartment limits. The generic ledger must not interpret fuel-specific `kind` values.

The modular rule is:

**5A owns the socket. 5B plugs Fuel into that socket.**

A future non-fuel module must be able to satisfy the same Cargo contract without changes to Core, Driver, Vehicle or Operations.

## Modular handshake

For Cory's tanker-driver configuration:

Driver Assistant → generic Cargo contract → Fuel module.

Fuel must expose its transported-product truth through the existing Cargo vocabulary/ledger boundary rather than teaching Core/Driver/Vehicle/Operations about petrol or diesel.

Fuel may specialise/extend the generic contract with fuel-only metadata and projections, including:

- fuel product catalogue/identity;
- litres as the fuel quantity unit;
- density/SG used for derived mass;
- compartment liquid-product state;
- residue/vapour state;
- degas/switch-loading state transitions;
- fuel/DG/policy inputs;
- fuel-specific workflow and UI projections.

Those extensions must remain behind the Fuel module boundary.

## Ownership boundaries

- Generic Cargo (5A) owns the reusable cargo contract, generic quantity/ledger/transaction semantics and modular socket.
- Vehicle owns compartment identity, physical capacity, Safe Fill and geometry.
- Fuel (5B) owns fuel product identity and fuel-specific metadata/state: litres specialisation, density/SG, residue/vapour and fuel-specific transitions/projections.
- Mass consumes Fuel-provided quantity/density plus Vehicle geometry; Fuel does not own empirical axle-distribution rules.
- Operations records operational events through generic boundaries; it does not gain fuel-specific dependencies.
- Site supplies customer/site context and site policy facts.
- Policy interprets DG, slosh, placard, compatibility and site restrictions. Fuel must not invent regulatory policy.
- Run/TodayView may plan/propose cargo states but planning remains prospective until Confirm commits actual truth.
- Journal reconstructs actual history from committed events; corrections do not rewrite history.

## Supported fuel product catalogue

Initial fuel products:

- Diesel
- Ultimate Diesel
- ULP 91
- PULP 95
- S-PULP 98
- E10

Product catalogue data is Fuel configuration, not hard-coded Core/Cargo policy.

## Fuel truth projected through Cargo

### Litres

For Fuel, litres are the primary inventory quantity. Mass is derived, not independently edited inventory truth.

Derived product mass = observed litres × applicable density/SG.

A load uses one density/SG value per product for that load across compartments unless a later evidence-backed requirement explicitly establishes otherwise.

### Fuel compartment state

Fuel's compartment projection must distinguish at least:

1. liquid fuel product identity, if litres > 0;
2. liquid litres;
3. residual/vapour state;
4. whether an explicit degas has cleared the residual state.

Zero litres does NOT mean chemically blank/degassed.

Initial/new compartment state may be treated as effectively degassed only as an explicit initialisation condition; once product history exists, emptying liquid does not silently clear residue/vapour.

Product entry establishes the corresponding residual family/state. Diesel residue and petrol-family vapour/residue remain meaningful after liquid reaches zero. Explicit Degas is the Fuel-specific state transition that clears residual/vapour state.

## Transactions — generic spine, Fuel meaning

5B must reuse the 5A generic cargo ledger/transaction spine wherever the existing contract supports the required semantic. It must not introduce a competing Fuel-owned ledger merely to rename generic cargo events.

Fuel supplies the domain meaning required for:

- Load — fuel enters transported cargo from an external source.
- Unload / Delivery — fuel leaves transported cargo to a customer/destination.
- Transfer — fuel moves between represented cargo locations without pretending it was newly loaded or disappeared.
- Degas — Fuel-specific explicit operational state transition clearing applicable residual/vapour state; it is not equivalent to unloading to zero.
- Correction — append-only provenance correcting a recorded fact without erasing the original record.

Where the existing generic transaction contract requires extension to express a legitimate Fuel semantic, extend the generic contract minimally and prove the extension remains cargo-generic where possible. Do not fork a parallel Fuel transaction architecture.

Multiple loads and reloads during one shift/run are supported. A later load must not overwrite earlier load/delivery history.

### Running tank

Vehicle running fuel is distinct from transported cargo state. However, where company accounting treats the truck running tank as a customer, product delivered from transported cargo into the running tank is represented through the generic cargo transaction boundary as an Unload/Delivery to a Fuel destination/customer type such as Vehicle / Running Tank.

This reduces transported fuel litres normally and preserves the commercial/accounting meaning of the delivery.

Do not misclassify such a delivery as an internal cargo transfer merely because source and destination are on the same vehicle.

## Plan → actual → Confirm

Planning may propose Fuel/Cargo projections without mutating authoritative actual cargo truth.

Required flow:

Plan → capture actual → reconcile → Confirm → append committed event(s) through the Cargo truth spine → project current state.

Original demand, proposed plan, chosen plan and confirmed actual are distinct facts. A changed customer quantity must not rewrite the original requested quantity.

Example test case: customer demand may begin at 20,000 L, driver/customer agreement may later confirm 17,000 L, and the actual load/delivery may differ again. All relevant stages remain reconstructable.

## Correction / incident / prevention semantics

These are not synonyms:

- Correct — the record is wrong; append a correction with provenance.
- Incident / shandy — the physical event itself was wrong or contamination/mixing actually occurred; preserve it as an incident, not as a tidy correction.
- Prevention — a proposed unsafe/invalid state is challenged before it becomes physical truth.

Consequential actions must be deliberate and easy to find. No silent correction of cargo history.

## Compatibility and policy

Fuel may represent compatible additive loading when the physical/product model permits it, but terminal, site, DG, placard, switch-loading and other restrictions belong to Policy/Site rather than being guessed by Fuel.

Switch-loading and degassing must be explicit Fuel state transitions where applicable. Configured site restrictions must not be inferred merely from GPS position.

Policy severity remains distinguishable as:

1. hard invariant;
2. verified regulatory intervention;
3. operational warning;
4. empirical advisory.

Unverified regulatory numbers or empirical Truck 92 behaviour must not become universal executable policy.

## Restricted-site behaviour

A site policy may require pre-printed paperwork, device-off, device-in-cab or similar operating constraints. Those constraints alter presentation/workflow availability, not Cargo/Fuel truth semantics.

## V2 behaviour explicitly retained

5B must preserve the useful V2 Fuel concepts rather than accidentally deleting them during refactor:

- residue/vapour awareness;
- Empty Load behaviour;
- placard-related projection inputs;
- degassing behaviour;
- running fuel distinguished from transported fuel;
- multiple/reload loads;
- relevant fuel widgets/projections, rebuilt against the 5A Cargo truth spine rather than copied as authority.

## Non-goals for 5B

5B does not own:

- a replacement generic Cargo contract or ledger;
- route optimisation or stop ordering;
- ETA/traffic prediction;
- fatigue strategy;
- customer/site dwell baselines;
- GPS breadcrumb logic;
- empirical axle mass-distribution formulae;
- terminal or site policy authoring;
- an all-purpose AppModel.

These systems may consume generic Cargo/Fuel projections through explicit interfaces.

## Invariants

1. Fuel does not duplicate or bypass the 5A Cargo ledger/contract.
2. Core, Driver, Vehicle and Operations do not acquire petrol/diesel-specific knowledge to support Fuel.
3. No negative fuel quantity.
4. Confirmed litres cannot exceed Vehicle-defined compartment capacity/Safe Fill constraints without an explicit policy/error result; Fuel does not silently clamp the value.
5. A zero-litre fuel compartment retains its residual/vapour state until an explicit state-changing event clears it.
6. Derived mass never becomes an independent competing inventory truth.
7. Corrections append provenance; original committed events remain reconstructable.
8. Planning/proposed state cannot silently mutate actual cargo truth.
9. Every committed fuel quantity change is attributable through the Cargo truth spine.
10. No invented history and no silent balancing adjustment to make totals reconcile.
11. A thin non-fuel module must remain able to use the generic Cargo contract without importing Fuel.

## Implementation intent — Bob (corrected)

Build **Fuel as the first production client/specialisation of the generic Cargo contract established and proven in 5A**. Do not build a new `Fuel/Cargo` domain or a second ledger.

First inspect and reuse the existing `CargoContract`, `CargoQuantity`, `CargoTransaction` and `CargoLedger` types. Only extend those generic contracts where a required semantic is genuinely generic; otherwise keep the extension inside Fuel.

Introduce Fuel-owned types only for Fuel-specific concepts such as `FuelProduct`, `FuelResidualState` and a Fuel compartment projection/metadata layer. Fuel should adapt those concepts to/from the existing generic `CargoKind` / quantity / ledger boundary.

Build pure Fuel projection/reconciliation logic over authoritative Vehicle compartment definitions plus the generic Cargo ledger/events. UI integration follows the domain spine. Existing V2 fuel widgets may be re-expressed as projections but must not become sources of truth.

Before code is marked PASS, prove both sides of the handshake:

- the Fuel module can perform its tanker-specific work through the generic Cargo socket; and
- the existing thin non-fuel cargo implementation still works without importing or understanding Fuel.

Verification must also demonstrate the invariants below and show that Fuel has not absorbed Run Planning or Mass ownership.

## Acceptance cases

Minimum verification scenarios:

1. Existing 5A non-fuel Cargo harness still passes unchanged after Fuel is added.
2. Fuel registers/adapts its products through the generic Cargo identity/quantity boundary without Core/Vehicle/Operations interpreting fuel kinds.
3. Fresh/initial compartment → load diesel → unload to zero → diesel residual remains → Degas → residual clears.
4. Petrol-family load → unload to zero → vapour/residual remains.
5. Multiple compartments carrying the same product use the load's applicable product density/SG for derived mass.
6. Reload during the same run appends new truth and does not overwrite the first load.
7. 300 L XLS delivered from transported cargo to Vehicle / Running Tank reduces transported XLS by 300 L and is represented as a customer delivery through the generic Cargo transaction boundary, not unexplained consumption.
8. Requested 20,000 L → later customer-confirmed 17,000 L preserves both demand and confirmation; actual remains separately confirmable.
9. Incorrect recorded quantity is corrected append-only; the original record remains reconstructable.
10. Actual contamination/shandy is represented as an incident rather than disguised as a correction.
11. Proposed incompatible/invalid state can be prevented without creating a false physical event.
12. Route ETA, peak-hour traffic, site manoeuvring and dwell explanations do not enter the Fuel module.
13. A second thin non-fuel Cargo implementation can still satisfy the same 5A contract without Fuel dependencies or changes to Core/Driver/Vehicle/Operations.

## Gate

5A generic Cargo foundation: already established; remains authoritative.
Niles review: corrected 5B ownership/handshake boundary incorporated.
Costa review: policy/safety boundary retained; no unverified rule promoted to hard executable policy.
Bob intent: corrected above.
Cory GO: received 2026-09-17; remains valid for the corrected 5B scope.

Next: implement Fuel against the existing 5A Cargo contract, test both sides of the handshake, then verify before declaring 5B PASS.
