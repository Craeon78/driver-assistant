# V3 Chunk 2 — Progress

Last updated: 2026-09-14 (Bob)

## Status
Structural + regression layer complete. Road-comparison gate still open (requires real driving).

## What exists
- DistanceEvidence protocol and DistanceInterval
- ODOAnchor (authoritative)
- GPSFilter (ported V2 acceptance rules, testable without CoreLocation)
- DistanceEngine (span accumulation, ODO close, correction-factor learning)
- Regression fixtures for doubled-distance, jump rejection, ODO interval integrity
- Playgrounds-callable DistanceGateTests

## What is deliberately unfinished
- Real road validation (the final gate)
- Breadcrumb retention policy beyond stubs
- Integration with the EventStore from Chunk 1 (next small slice if needed)
- Any UI or Operations coupling

## Next device action (when you want it)
Run on iPad:
```swift
print(DistanceGateTests.runAll().isEmpty ? "STRUCTURAL PASS" : DistanceGateTests.runAll())
```
Then, when convenient, collect a short real drive with known ODO points so we can close the road-comparison gate.

## Impasse / stop line
I will not claim the road gate is passed. Everything above is offline-verifiable.
