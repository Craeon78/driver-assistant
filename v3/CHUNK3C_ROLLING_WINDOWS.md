# V3 Chunk 3c — Rolling Windows (Standard HV)

Status: OPEN (blocked on 3a; 3b recommended first)
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md + V2 FatigueEngine (Standard HV path only)

## Goal
Rolling 24h / 7d / 14d work and rest structure from the persistent ledger. **Standard HV only.** BFM deferred until pre-ship.

## Driver-sensible question
“Does yesterday still count? Does a long day still sit in the 7- and 14-day buckets after relaunch?”

## Scope
- Port/adapt FatigueEngine-style evaluation over ledger entries.
- Windows: work24, max continuous stationary rest24, work7d, work14d.
- 24h continuous stationary rest in 7d.
- Night rest labels in 14d (≥7h stationary overlapping 22:00–08:00; consecutive pair detection).
- Standard HV limits only (e.g. 12h/24h, 72h/7d, 144h/14d as in V2 Standard path).

## Out of scope
- BFM long/night work and 84h reset rules.
- AFM / bus-coach.
- Live UI polish.

## Gate
1. Multi-day fabricated ledger (time-accelerated OK) yields stable 24h/7d/14d totals.
2. Relaunch does not change rolling totals.
3. Midnight and shift end do **not** reset rolling fatigue.
4. Regression: V2-style “fatigue reset on boundary” cannot recur.

## Harness
Fabricate 3–14 days of work/rest; evaluate; persist; reload; assert same FatigueStatus fields for Standard HV.
