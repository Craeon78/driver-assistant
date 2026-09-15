# V3 Chunk 3b — Daily Fatigue from Ledger

Status: STRUCTURAL READY (awaiting device gate)
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md

## Goal
Same-day fatigue metrics computed **only** from the persistent ledger.

## Gate checks
- Work / legal rest (≥15m) / short rest
- Work since last legal rest
- Rest limbo (&lt;15m open rest)
- Remaining until 7.5h / 10h / 12h (may be negative)
- Empty ledger → zeros (ledger-only feed)

## Harness
```swift
print(DailyFatiguePlaygroundsRunner.runGate())
```

## Files
- Driver/DailyFatigue.swift
- Tests/DailyFatigueGateTests.swift
- DailyFatiguePlaygroundsRunner.swift
