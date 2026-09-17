# Chunk 5C — Niles Loop 1 Review

## Scope
Vehicle Mass Integration only.

## Review findings
- PASS: Vehicle consumes generic kilograms and does not interpret Fuel products or density.
- PASS: Fuel-to-Vehicle dependency is isolated in `FuelVehicleMassAdapter`.
- PASS: tare remains Vehicle evidence and is never mutated by cargo projection.
- PASS: gross mass is derived from applicable tare + current transported mass; no second ledger exists.
- PASS: axle distribution requires explicit longitudinal geometry and configuration-matched axle tare evidence.
- PASS: missing/ambiguous geometry returns an explicit unavailable reason rather than guessed axle splits.
- PASS: Truck 92 July evidence is a fixture, not architecture. The lazy-UP tare versus lazy-DOWN gross state is documented and the observed axle delta is not used to tune the generic model.
- PASS: supplier 16,083 kg versus weighbridge 16,040 kg is retained as independent mass reconciliation; rounded compartment masses remain 16,084 kg without rewriting source evidence.
- PASS: no 5D operational workflow, 5E journal/replay, routing, fatigue, or policy logic introduced.

## Proportional review note
The generic two-support reaction formula is intentionally narrow. It is available only when the caller supplies a coherent common datum and matching tare configuration. Truck 92 currently withholds that geometry because the July survey datum is not independently established and the lazy state changed between tare and gross measurements.

## Loop 1 disposition
ALL CLEAR for PR/Codex review. Runtime PASS is not claimed; Swift Playgrounds gate remains after merge under the canonical lifecycle.
