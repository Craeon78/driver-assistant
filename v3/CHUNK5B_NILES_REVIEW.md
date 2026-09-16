# Chunk 5B — Niles Pre-Codex Review

Date: 2026-09-17
Reviewer: Niles
Status: NOT YET CLEARED FOR CODEX

## Scope checked

Reviewed Bob's first 5B implementation against:

- the existing 5A generic Cargo contract and ledger;
- the corrected 5B Fuel/Cargo handshake contract;
- the requirement that Fuel be a client/specialisation of Cargo rather than a second cargo architecture.

## What is structurally correct

1. Bob did not create a second Fuel inventory ledger. Fuel load/delivery/transfer/correction commands adapt to the existing `CargoTransaction` and `CargoLedger` spine.
2. `FuelProduct` adapts to namespaced generic `CargoKind`; generic Cargo does not interpret petrol/diesel kinds.
3. Residue/vapour is implemented as a Fuel-only projection layered over generic liquid Cargo truth.
4. Degas is a Fuel-specific state transition and does not pretend to be an unload-to-zero transaction.
5. Running-tank fuel is represented as a generic unload/customer delivery rather than unexplained consumption or an internal cargo transfer.
6. The 5B gate explicitly invokes the existing 5A gate, preserving the thin non-fuel cargo implementation as a regression tripwire.
7. No route, ETA, fatigue or axle-distribution logic was added to Fuel.

## Blockers found

### N1 — Fuel residue events can diverge from Cargo truth

A caller can append a generic Fuel load transaction without appending the corresponding `FuelStateEvent.productEntered`. Cargo would then correctly show liquid fuel aboard while Fuel could still report `.clear` residual state.

That violates the intended handshake: a confirmed Fuel load must commit its generic Cargo quantity truth and its Fuel-specific chemical-state consequence as one deliberate domain operation, or otherwise provide a replay rule that cannot silently omit the Fuel state transition.

**Required Bob fix:** provide a Fuel commit/service boundary that produces/commits the paired Cargo + Fuel state facts together, with validation before mutation.

### N2 — 5B gate is incomplete relative to the contract

The current TestFuel harness covers the core adapter, residue/degas, petrol vapour, derived mass, reload, running-tank delivery, transfer and correction cases, plus 5A regression. It does not yet explicitly cover:

- demand 20,000 → customer-confirmed 17,000 → actual as separate facts;
- incident/shandy versus correction;
- prevention of an invalid proposal without fabricating a physical event.

Some of those belong outside the Fuel inventory ledger, but the 5B contract requires proof that Fuel participates correctly at those boundaries. They must either receive explicit boundary types/tests or be reclassified into a later chunk with the 5B contract amended accordingly. Do not silently claim them passed.

### N3 — Density/SG identity assumption needs an explicit constraint

`FuelProduct.cargoKind` places `kilogramsPerLitre` inside `CargoKind`. `CargoKind` equality therefore treats the same fuel product with a different load density as a different cargo descriptor. The generic ledger will reject additive loading into an occupied compartment as `mixedCargo` if the density differs.

The current contract says density/SG is applicable load evidence rather than a universal product constant. Therefore this representation is safe only if 5B deliberately forbids mixing/reloading the same product with different density evidence into one live compartment, or the model is changed so product identity and load-specific mass evidence are separate.

**Required Bob fix:** do not guess. Encode the limitation explicitly for this build and leave cross-density blending unresolved unless the domain requirement is confirmed; add a gate proving the system fails visibly rather than silently relabelling or averaging.

## Niles decision

**RETURN TO BOB.**

The 5A/5B modular boundary is substantially better and no shadow Fuel ledger was created, but N1 is an architectural truth-integrity defect and N2/N3 prevent a clean pre-Codex clearance.

Jarvis should return these findings to Bob under the existing Cory GO. After Bob's correction, Niles must re-review before Cory checks Codex comments/review.
