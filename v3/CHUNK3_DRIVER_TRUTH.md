# V3 Chunk 3 — Driver Truth

Status: OPEN
Owner: Driver
Authority: V3_REFACTOR_CONTRACT.md + resources/v3/V3_ROADMAP.md + V2 FatigueEngine / RestLogic / FatigueRules (behavioural reference only)

## Roadmap goal
Persistent Driver Work/Rest ledger; migrate/prove daily fatigue; add rolling/multi-day rules. A minimal Operations-style input may be borrowed early (work vs rest only) without building Operations wholesale.

## Roadmap gate
Real shifts plus relaunch and overnight-open-shift tests preserve fatigue truth.

## Locked invariants
- One persistent Driver Work/Rest ledger feeds one fatigue rule engine.
- Shift boundaries and midnight do **not** reset fatigue.
- Unresolved fatigue carries forward until corrected history or qualifying rest resolves it.
- Driver authority beats inference; no silent consequential state changes.
- Corrections preserve provenance (occurrence vs recorded time).
- Core distance/retention remain Core-owned; Driver does not reach around them.

## Sub-chunk plan (manageable, harness-testable)

| Sub | Name | Driver-sensible question | Gate style |
|-----|------|--------------------------|------------|
| **3a** | Work/Rest ledger spine | “After I kill the app, does it still know what I worked and rested?” | Fabricated shift + relaunch + overnight-open |
| **3b** | Daily fatigue from ledger | “Do today’s legal rest, spacing, and caps match what I actually did?” | Same-day scripted timeline + correction provenance |
| **3c** | Rolling windows | “Does yesterday still count in 24h / 7d / 14d?” | Multi-day fabricated ledger (time-accelerated OK) |
| **3d** | Field / real-shift gate | “Does a real day (and overnight open) still feel true?” | Real shift + relaunch + overnight-open; closes roadmap gate |

Detail contracts: `CHUNK3A_LEDGER_SPINE.md`, `CHUNK3B_DAILY_FATIGUE.md`, `CHUNK3C_ROLLING_WINDOWS.md`, `CHUNK3D_FIELD_GATE.md`.

## Explicitly deferred
- **BFM scheme** — out of critical path until pre-ship (tester does not hold BFM quals). Standard HV only for 3a–3d.
- Full Operations activity model / SITE two-tier buttons.
- Commodity-specific activity kinds (fuel load, cattle, etc.).
- AFM / bus-coach schemes.
- Journal UI, Policy overlays, coach-copy polish.

## Option D (compound testing)
Chunk 3 sub-gates close independently. When 3a+ exist, add a small compound runner that checks:
- Core distance/retention still sane;
- Driver ledger independent;
- no silent cross-domain writes.

Harnesses remain diagnostic assets; ContentView points at the active harness.

## V2 reference (do not edit for V3)
- `sources/FatigueEngine.swift` — pure evaluate over segments (24h/7d/14d, night rest, Standard HV).
- `sources/AppModel+RestLogic.swift` — Phase 1 today-only planning / limbo (not ledger truth).
- `sources/FatigueRules.swift` — today-only UI helpers.
- `sources/FatigueCountdownLogic.swift`, `FatigueRuleModels.swift` — supporting Phase 1 shapes.

Migrate behaviour into Driver-owned types; do not grow AppModel.

## Progress
See `CHUNK3_PROGRESS.md`.
