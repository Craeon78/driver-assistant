# Driver Assistant V3 Refactor Contract

## Authority

V3 is the architectural authority for this refactor. The v0.2.x code and older guides remain behavioural, algorithmic and UX reference material.

When sources conflict, prefer the V3 ownership model unless doing so would discard a documented safety, legal or field-tested invariant.

Central thesis:

> Fuel is the first customer of a transport platform, not the foundation of the app.

## Target ownership

- Core: lifecycle, persistence, event spine, GPS/location, breadcrumbs, distance evidence, mapping and module infrastructure.
- Driver: work/rest ledger, fatigue and driver profile/settings.
- Vehicle: physical vehicle/combination, dimensions, axle geometry/ratings, odometer, running fuel and mass behaviour.
- Operations: Drive, Stop, Load, Unload, Transfer, Wait, maintenance context and incident events.
- Sites/Runs: persistent sites, run templates/current run and What's Next.
- Cargo/Fuel: transported-fuel products, compartments, quantities, DG, SFL/slosh and cargo-mass contribution.
- Policy/Regulatory: interpretations and advisory rules over evidence owned elsewhere.
- Data Packs: reference/template data, not authoritative history.
- Journal: projections/reconstruction over stored truth.
- Numbers: analytics over other domains.
- Simulation: hypothetical state only; never historical truth.
- Command: query/control surface over mature domain contracts, not a parallel data model.
- Developer: diagnostics, fixtures and regression evidence; no business truth.

## Ownership test

For each datum or feature ask: **Who owns the truth?** Do not assign ownership based on which screen displays it.

A second Cargo module must be able to attach through the Cargo contract without requiring changes to Core, Driver, Vehicle or Operations. If it cannot, the boundary is not complete.

## Invariants to preserve

- Driver-entered ODO is authoritative distance anchor; GPS is evidence.
- ODO anchors reconcile intervals and must not assign an entire anchor delta to the segment containing the later reading.
- Driver, Vehicle and Operations are simultaneous truths.
- Corrections preserve provenance rather than silently rewriting history.
- Transactions are Fuel truth; balances and snapshots are derived.
- Vehicle fuel and transported Fuel cargo have different owners.
- Shift boundaries and midnight do not reset fatigue.
- Driver authority beats inference; no silent consequential state changes.
- Turning a module off does not delete historical data.
- Diagnostics observes but owns no business truth.

## Migration rule

Understand V2 behaviour -> identify V3 owner -> migrate/reimplement -> regression-test -> device/field-test where required -> retire legacy implementation only when proven.

Do not rebuild a giant AppModel. Do not create a protocol/factory/coordinator maze without a current caller. Prefer a small number of strong domains with obvious ownership and boring interfaces.

## Repository reconciliation

The branch must reconcile the complete available source corpus, not only the old snapshot/resource aggregates:

1. extract/reconcile each Swift source file;
2. extract/reconcile each Markdown and text resource;
3. update an existing file when it remains the correct canonical home;
4. add a new file when V3 ownership requires a new canonical home;
5. retain legacy material only when it remains useful as provenance/reference;
6. never let stale V2 wording silently become V3 architecture.

## Diff discipline

Semantic work and whitespace cleanup are separate passes.

The whitespace-only pass may remove editor/Obsidian-style blank-line noise, trailing whitespace and other non-semantic formatting, but must contain no architecture or behaviour changes. Reviewers may therefore discount that pass when assessing semantic changes.

Do not combine file relocation, public-type renaming and behaviour changes merely to make the repository look tidy.

## Completion

Compilation alone is insufficient. Required checks include architecture ownership, known regression cases, persistence/replay where applicable, and device/field gates for iPad lifecycle, GPS, sensors, touch and in-cab UX.

Every deliberately invoked review finding must be explicitly dispositioned before the refactor is called done.
