# V3 Chunk 2 — Progress & Handover

Last updated: 2026-09-14 (Bob)

## Status
Structural + regression layer complete and pushed.
Final road-comparison gate remains open (requires real driving data).

## What exists under `v3/`
- CHUNK2_DISTANCE_TRUTH.md — contract
- Core/ODOAnchor.swift
- Core/DistanceEvidence.swift — protocol + DistanceInterval
- Core/GPSFilter.swift — ported V2 rules, CoreLocation-free for tests
- Core/DistanceEngine.swift — span + ODO close + factor learning
- Tests/DistanceRegressionFixtures.swift
- Tests/DistanceGateTests.swift
- DistancePlaygroundsRunner.swift

## Verified offline
- ODO interval integrity (exact delta, no misallocation)
- Jump rejection
- Near-zero delta does not invent distance
- Correction-factor machinery stays in bounds

## Exact stop line / impasse
I cannot close the official Chunk 2 gate without road data.
The gate is: “road comparison matches or beats V2 accuracy without the catalogued distance regressions.”

That needs at least one real drive with known ODO anchors and the GPS samples collected under the new engine.

## What you can do on iPad right now (optional)
```swift
print(DistancePlaygroundsRunner.runStructuralGate())
```
Expect `STRUCTURAL PASS`. That confirms the fixtures; it is not the road gate.

## After STRUCTURAL PASS
Chunk 2 stays open until a short real-world comparison is done. At that point we either:
- close Chunk 2 and open Chunk 3 (Driver truth), or
- fix any remaining distance regressions that surface on the road.

No further pure-code work is blocked; the next meaningful increment is device evidence.
