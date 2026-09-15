# V3 Chunk 2 — Progress & Handover

Last updated: 2026-09-15 (Niles — status alignment with field history)

## Status
**PASS WITH RESIDUALS**

Road-comparison gate met on real drive evidence (~88 km Gold Coast → Pinkenba, including a continuous 58 km leg). Structural fixtures and catalogued regression cases held. No doubled-distance, jump, or ODO-interval misallocation failures observed.

## Residuals
- Optional further terrain variety later if higher confidence is wanted.
- Breadcrumb lifecycle/retention is owned by Chunk 2b (PASS separately under Option D).
- Progress/docs previously lagged the field result; this file now matches history.

## What exists under `v3/`
- CHUNK2_DISTANCE_TRUTH.md — contract
- Core/ODOAnchor.swift
- Core/DistanceEvidence.swift — protocol + DistanceInterval
- Core/GPSFilter.swift — ported V2 rules, CoreLocation-free for tests
- Core/DistanceEngine.swift — span + ODO close + factor learning
- Tests/DistanceRegressionFixtures.swift
- Tests/DistanceGateTests.swift
- DistancePlaygroundsRunner.swift

## Verified
- ODO interval integrity (exact delta, no misallocation)
- Jump rejection
- Near-zero delta does not invent distance
- Correction-factor machinery stays in bounds
- STRUCTURAL PASS on device
- Road comparison: long leg 58.0 km ODO vs 58.12 km GPS; overall bias small; factor settled sensibly

## Option D note
Chunk 2 and Chunk 2b close separately. Cross-module compound checks are a Chunk 3+ obligation, not a reopen of this gate. Harnesses are retained diagnostic assets.

## Next
Chunk 3 — Driver truth (work/rest ledger + fatigue), with compound checks against Core distance/retention as modules compose.
