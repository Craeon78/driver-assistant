# V3 Chunk 3a — Work/Rest Ledger Spine

Status: STRUCTURAL READY (awaiting device gate)
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md + Red Team 2026-09-15

## Goal
A persistent, append-oriented Work/Rest ledger that survives relaunch and overnight-open segments. No full NHVR maths in this sub-chunk.

## Driver-sensible question
“After I kill the app mid-shift, does it still know what I worked and rested — including an open segment across midnight?”

## Red Team non-negotiables (gate-encoded)
1. **Ledger-only feed** — no parallel session array as fatigue authority.
2. **Continuous timeline** — midnight/shift never wipe or reset history.
3. **Binary kind** — work | rest only; Operations stays out.

## Scope
- `WorkRestEntry`: kind, start, optional end, stationaryRest, occurrence/recorded times, provenance.
- Open segment allowed (`end == nil`).
- `WorkRestLedger` + in-memory and file stores; `simulateRelaunch()` for crash proof.
- Fabricators: closed shift, open shift, overnight-open.

## Out of scope
- Fatigue limits, rolling windows, night-rest scoring, countdown UI.
- Operations activities beyond work vs rest.
- BFM.

## Gate
1. Fabricated closed shift saves and replays identically.
2. Fabricated open shift remains open after relaunch (file store).
3. Overnight-open: one work entry spans pre/post midnight; still open; not split or wiped.
4. Shift end does not delete prior ledger entries.
5. Explicit close of open entry works.

## Harness
```swift
print(LedgerPlaygroundsRunner.runGate())
```
Expect `GATE PASS`.

## Files
- Driver/WorkRestEntry.swift
- Driver/WorkRestLedger.swift
- Tests/LedgerSpineGateTests.swift
- LedgerPlaygroundsRunner.swift
