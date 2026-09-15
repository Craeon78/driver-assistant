# V3 Chunk 3a — Work/Rest Ledger Spine

Status: OPEN
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md

## Goal
A persistent, append-oriented Work/Rest ledger that survives relaunch and overnight-open segments. No full NHVR maths in this sub-chunk.

## Driver-sensible question
“After I kill the app mid-shift, does it still know what I worked and rested — including an open segment across midnight?”

## Scope
- Driver-owned work/rest entries: kind (work|rest), start, optional end, stationaryRest flag, occurrence vs recorded time, provenance.
- Open segment allowed (end == nil).
- Persist and reload via Core event/store patterns already proven in Chunk 1.
- Fabricators for closed and open shifts.

## Out of scope
- Fatigue limits, rolling windows, night-rest scoring.
- Operations activities beyond work vs rest.
- UI beyond a minimal Playgrounds harness.

## Gate
1. Fabricated closed shift saves and replays identically.
2. Fabricated open shift remains open after relaunch.
3. Overnight-open: segment that crosses midnight is still one open work (or rest) entry; fatigue history is not wiped by date change.
4. Shift end does not delete prior ledger entries.

## Harness
Playgrounds runner: fabricate → persist → simulate relaunch → assert ledger equality. Second path: open segment + advance clock past midnight → reload → still open, same id/start.

## Files (expected)
- Driver/WorkRestEntry.swift (or equivalent)
- Driver/WorkRestLedger.swift
- Tests/LedgerSpineGateTests.swift
- LedgerPlaygroundsRunner.swift (or shared Chunk 3 runner)
