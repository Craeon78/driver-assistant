# V3 Chunk 3d — Field / Real-Shift Gate

Status: **PASS — CLOSED 2026-09-16**
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md + 2026-09-16 field temporal review

## Field finding
Rest 20:45 → 03:24 is **6:39 continuous** (episode) but calendar **current day** legal rest is **3:24** (from midnight), with **3:15** belonging to the previous calendar day. These are different correct temporal views. Do not patch one into another.

## Temporal views (one ledger)
| View | Question |
|------|----------|
| Previous calendar day | Logbook yesterday 00:00–24:00 |
| Current calendar day | Logbook today 00:00–now |
| Current shift | Driver-declared shift start→end/now (may cross midnight) |
| Current episode | Uninterrupted open work or rest (crosses midnight) |
| Rolling analytics | `now - 24h / 7d / 14d` analytical windows |
| Statutory counting periods | **Not Chunk 3** — NHVR anchored/overlapping interpretation belongs to Chunk 3.5 |

## Shift definition (locked)
- **Shift start / end** are explicit driver-declared boundaries (`ShiftBoundary`).
- They do **not** wipe the work/rest ledger.
- Shift end does **not** auto-close an open work/rest segment.
- Shift work/rest = ledger intervals overlapping [shiftStart, shiftEnd or now].
- If no shift is open, shift metrics are empty (`ShiftSnapshot.none`).

## Structural harness
```swift
print(TemporalModelPlaygroundsRunner.runGate())
```
Fabricated 15→16 Sep cross-midnight gate: **PASS**.

## Live field evidence
`FieldGateHarnessView` was exercised across the 2026-09-15→16 real shift. Evidence included:
- real work/rest transitions;
- legal-rest limbo behaviour;
- relaunch/persistence;
- overnight open rest across midnight;
- resumed work/rest next morning;
- ledger/history preservation;
- daily/calendar and rolling figures remaining coherent.

## Roadmap gate
Real shifts + relaunch + overnight-open preserve fatigue truth: **PASS**.

Chunk 3 is therefore closed. Regulatory interpretation identified during this gate is promoted to **Chunk 3.5**, rather than extending Chunk 3 after closure.
