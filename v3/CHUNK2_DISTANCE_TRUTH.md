# V3 Chunk 2 — Distance Truth Engine

Status: **PASS WITH RESIDUALS** (road gate 2026-09-14)
Owner: Core
Authority: V3_REFACTOR_CONTRACT.md + resources/v3/V3_ROADMAP.md + V2 GPS sources

## Goal
Migrate proven V2 GPS measurement/filtering into a canonical Core evidence interface. Establish Distance/ODO engine and field-derived regression fixtures. Breadcrumb lifecycle detail is completed under Chunk 2b.

## Central invariants (locked)
- Driver-entered ODO is the authoritative distance anchor.
- GPS is evidence only; it never overrides an ODO reading.
- An ODO observation is a journey anchor. It must never assign the entire anchor delta to the segment that happens to contain the later reading.
- Corrections preserve provenance.
- No silent consequential state changes.

## Gate
Road comparison matches or beats V2 accuracy without the catalogued distance regressions.

**Result:** PASS WITH RESIDUALS. Real drive evidence satisfied the gate; optional further terrain variety remains a residual, not a blocker.

## Slice contract
- Owning domain: Core
- Allowed dependencies: Foundation, CoreLocation (for CLLocation only)
- Prohibited: Driver fatigue, Vehicle mass, Operations activities, Cargo, UI
- Inputs: CLLocation samples + driver ODO anchors
- Outputs: DistanceEvidence events + corrected span distances
- Non-goals: real-time UI, multi-vehicle profiles, commodity-specific vocabulary

## Files
- Core/DistanceEvidence.swift
- Core/GPSFilter.swift
- Core/DistanceEngine.swift
- Core/ODOAnchor.swift
- Tests/DistanceRegressionFixtures.swift
- Tests/DistanceGateTests.swift

## Residuals
- Optional more varied terrain / multi-day distance samples later.
- Breadcrumb retention policy and segment classification live in Chunk 2b.
