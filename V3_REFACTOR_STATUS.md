# Driver Assistant V3 Refactor Status

## Authority
V3 modularity is the architectural authority for this refactor.

When legacy v0.2.x structure conflicts with V3 domain ownership, V3 wins unless a documented safety, legal, or field-tested invariant requires preservation.

Fuel is the first Cargo customer, not the foundation of Driver Assistant.

## Execution discipline
1. Reconcile every available Swift, Markdown, and text resource against V3 ownership.
2. Material semantic changes are separate from formatting cleanup.
3. A whitespace-only pass must contain no architecture or behaviour changes.
4. Legacy code remains evidence until its corresponding V3 behaviour is implemented and validated.
5. Driver-entered odometer anchors remain authoritative; GPS is evidence.
6. Policy interprets event truth rather than owning it.
7. Cargo-specific nouns must not leak into generic infrastructure.

## Current material implementation
`sources/CargoUnits.swift` is no longer a placeholder. It now defines industry-neutral `QuantityValue`, `CargoUnit`, and `CargoModule` types so Fuel can map compartments/litres onto generic cargo concepts without making Fuel the platform vocabulary.

## Next implementation slices
- establish explicit V3 domain folders/contracts;
- extract generic operations and transaction truth;
- isolate Fuel-owned models, registries, rules, and UI;
- reduce AppModel domain ownership;
- reconcile persistence/event spine around generic truth;
- preserve and then complete the distance-engine cutover under the odometer-truth invariant;
- run a separate whitespace-only cleanup;
- architecture/maintenance review and completion gate.
