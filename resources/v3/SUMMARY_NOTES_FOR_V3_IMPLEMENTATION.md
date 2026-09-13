# DriverAssistant V3 — Restart Supplement

Status: architectural authority for the V3 refactor. Derived from the 18 August 2026 V3 field-test/restart supplement supplied by Cory. Preserve the supplied source document outside this condensed repository orientation when full provenance is required.

## Purpose

V3 uses a fresh modular spine while v0.2.95 remains runnable/reference material. This is not a blind rewrite.

Migration pattern:

> Understand V2 behaviour -> identify V3 owner -> migrate/reimplement -> regression-test -> device/field-test -> retire legacy implementation when proven.

The architecture must prefer explicit ownership, replaceable implementations behind stable contracts, configuration over hard-coded assumptions, unit/localisation abstractions, migrations for persisted data, module/feature flags and tests that protect behaviour without freezing accidental implementation details.

## Domain structure

Core; Driver; Vehicle; Operations; Sites/Runs; Cargo/Fuel; Policy/Regulatory; Data Packs; Journal; Numbers; Simulation; Command; Developer.

### Ownership

- Fuel may display axle estimates but Vehicle owns axle physics.
- Journal displays unloads but Operations/Cargo transaction truth is upstream.
- Numbers displays distance but does not own distance.
- Diagnostics can observe everything but owns no business truth.

## Event truth

Important events support distinct occurrence and recording times, provenance/inference state and correction/supersession relationships. Late input is normal. Corrections preserve provenance.

## Distance

Preserve proven V2 GPS measurement/filtering behind a canonical Core evidence interface. No downstream domain reaches around that interface for legacy/intermediate variables.

ODO remains the authoritative distance anchor. An ODO observation is a journey anchor, never the distance of the current activity segment. Preserve this with permanent regression tests.

## Driver/Fatigue

Use one persistent Driver Work/Rest ledger feeding one fatigue rule engine. Shift boundaries and midnight do not reset fatigue. Unresolved fatigue carries forward until corrected history or qualifying rest resolves it.

## Vehicle / Operations

Driver, Vehicle and Operations are simultaneous truths. Vehicle owns the physical combination and mass behaviour. Operations records Drive/Stop/Load/Unload/Transfer/Wait and vehicle-context events without becoming the Vehicle owner.

Vehicle fuel is not transported Fuel cargo.

## Cargo/Fuel

Transactions are truth; balances/snapshots are derived. Fuel supplies product/compartment/quantity/density/cargo-distribution information to generic Vehicle mass behaviour.

Fuel must conform to a Cargo boundary that permits a thin second Cargo module to attach without changes to Core, Driver, Vehicle or Operations.

## Sites/Runs/Data Packs

Sites persist independently of shifts/runs. Runs organise Sites/jobs. Data Packs are reference/template sources, not authoritative history. Avoid duplicating geographic truth by Cargo module.

## Journal / Numbers / Diagnostics

Journal is a projection/composition surface over upstream truth. Numbers consumes domains and owns little operational truth. Diagnostics is read-only observation, distinct from fixtures/tests and the regression catalogue.

## Privacy

DriverAssistant tracks work, not the person. Occupational breadcrumb collection is bounded by Start Shift/End Shift. Current intent: progressively reduce breadcrumb detail and remove positional journey history after three months while retaining justified derived operational records.

## Development principles

- Coach, not nanny.
- Driver authority beats inference.
- No silent consequential state changes.
- Observe more than you persist.
- Delete what is not required.
- Enter a fact once; reuse it.
- Missing information creates uncertainty, not invented certainty.
- Store canonical quantities with explicit units/semantics; convert at boundaries.
- Avoid both a new monolith and speculative abstraction mazes.

## Testing

Testing starts with the architecture. Preserve field-discovered regressions including doubled GPS distance, wrong V1/V2 consumer, ODO interval misallocation, silent movement-state changes, overlapping Vehicle repair/Driver rest, late incidents/unloads/loads, crash/relaunch, overnight open shift, cargo carryover, fatigue reset errors, malformed input, double taps and interrupted confirmation/save flows.

## Central thesis

> Fuel should be the first customer of a transport platform, not the foundation of the app.

> Core records evidence. Driver owns human work/rest truth. Vehicle owns the machine. Operations records what is happening. Cargo modules describe what is being carried. Policy interprets evidence. Journal reconstructs it. Numbers analyses it. Diagnostics observes it.

> Build a clean spine, transplant what V2 proved worthwhile, encode important field failures as tests, and progressively colour in each module.
