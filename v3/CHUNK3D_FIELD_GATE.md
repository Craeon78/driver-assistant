# V3 Chunk 3d — Field / Real-Shift Gate

Status: TEMPORAL MODEL UPDATED — structural gate available without overnight wait
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md + 2026-09-16 field temporal review

## Field finding
Rest 20:45 → 03:24 is **6:39 continuous** (episode) but calendar **current day** legal rest is **3:24** (from midnight). Both are correct. Do not patch one into the other.

## Temporal views (one ledger)
| View | Question |
|------|----------|
| Previous calendar day | Logbook yesterday 00:00–24:00 |
| Current calendar day | Logbook today 00:00–now |
| Current shift | Driver-declared shift start→end/now (may cross midnight) |
| Current episode | Uninterrupted open work or rest (crosses midnight) |
| Rolling / statutory | 24h / 7d / 14d compliance windows |

## Shift definition (locked)
- **Shift start / end** are explicit driver-declared boundaries (`ShiftBoundary`).
- They do **not** wipe the work/rest ledger.
- Shift end does **not** auto-close an open work/rest segment.
- Shift work/rest = ledger intervals overlapping [shiftStart, shiftEnd or now].
- If no shift is open, shift metrics are empty (`ShiftSnapshot.none`).

## Structural harness (no overnight wait)
```swift
print(TemporalModelPlaygroundsRunner.runGate())
```
Uses a fabricated 15→16 Sep rest spanning midnight.

## Live field harness
`FieldGateHarnessView` — still used for truck evidence; should surface calendar + episode + rolling (update when wiring UI).

## Roadmap gate
Real shifts + relaunch + overnight-open still required for full Chunk 3 PASS; temporal structural proof no longer requires waiting overnight twice.
