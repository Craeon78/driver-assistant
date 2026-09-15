# V3 Chunk 3d — Field / Real-Shift Gate

Status: HARNESS READY (truck evidence pending)
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md (roadmap gate)

## Goal
Close the Chunk 3 roadmap gate with real evidence.

## Harness
`FieldGateHarnessView` — point ContentView at it (file ends with `typealias ContentView = FieldGateHarnessView`, or paste the same pattern as other gates).

Ledger is file-backed under Documents (`v3-field-gate-ledger.json`) so kill/relaunch keeps history.

## Checklist
1. Start Work → leg → End segment  
2. Start Rest — observe limbo then legal ≥15m  
3. Kill app mid-open (or Simulate relaunch) — open entry survives  
4. Daily + rolling cards still match what you did  
5. Shift end does not wipe ledger  
6. Optional: overnight-open across morning relaunch  

## Gate (roadmap)
Real shifts plus relaunch and overnight-open-shift tests preserve fatigue truth.

## Files
- FieldGateHarnessView.swift
- Depends on 3a–3c Driver types already in the playground
