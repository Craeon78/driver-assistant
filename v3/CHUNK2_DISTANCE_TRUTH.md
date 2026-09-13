# V3 Chunk 2 — Distance Truth Engine

Status: IN PROGRESS
Owner: Core
Authority: V3_REFACTOR_CONTRACT.md + resources/v3/V3_ROADMAP.md + V2 GPS sources

## Goal
Migrate proven V2 GPS measurement/filtering into a canonical Core evidence interface. Establish breadcrumb lifecycle stubs, Distance/ODO engine, and field-derived regression fixtures.

## Central invariants (locked)
- Driver-entered ODO is the authoritative distance anchor.
- GPS is evidence only; it never overrides an ODO reading.
- An ODO observation is a journey anchor. It must never assign the entire anchor delta to the segment that happens to contain the later reading.
- Corrections preserve provenance.
- No silent consequential state changes.

## Gate
Road comparison matches or beats V2 accuracy without the catalogued distance regressions.

(This gate requires real driving data. Until then we close only the structural + regression-fixture layer.)

## Slice contract
- Owning domain: Core
- Allowed dependencies: Foundation, CoreLocation (for CLLocation only)
- Prohibited: Driver fatigue, Vehicle mass, Operations activities, Cargo, UI
- Inputs: CLLocation samples + driver ODO anchors
- Outputs: DistanceEvidence events + corrected span distances
- Non-goals: real-time UI, persistence of breadcrumbs beyond the event spine, multi-vehicle profiles

## Files
- Core/DistanceEvidence.swift
- Core/GPSFilter.swift
- Core/DistanceEngine.swift
- Core/ODOAnchor.swift
- Tests/DistanceRegressionFixtures.swift
- Tests/DistanceGateTests.swift

## Residuals expected
- Real road validation still required for final gate.
- Breadcrumb retention policy is stubbed only.
- Learning-rate maturity machine is carried forward from V2; may be refined later.
