# V3 Chunk 3c — Rolling Windows (Standard HV)

Status: STRUCTURAL READY (awaiting device gate)
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md + V2 FatigueEngine Standard path

## Goal
Rolling 24h / 7d / 14d from the persistent ledger. **Standard HV only.** BFM deferred.

## Gate
- work24 / work7d / work14d from ledger intervals
- max continuous stationary rest in 24h
- 24h continuous rest flag in 7d
- Cross-midnight work still counts (no calendar wipe)
- Remaining may be negative when over limit
- Empty ledger → zeros

## Harness
```swift
print(RollingFatiguePlaygroundsRunner.runGate())
```

## Files
- Driver/RollingFatigue.swift
- Tests/RollingFatigueGateTests.swift
- RollingFatiguePlaygroundsRunner.swift
