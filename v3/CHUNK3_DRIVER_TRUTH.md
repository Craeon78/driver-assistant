# V3 Chunk 3 — Driver Truth

Status: **PASS — CLOSED 2026-09-16**
Owner: Driver
Authority: V3_REFACTOR_CONTRACT.md + resources/v3/V3_ROADMAP.md + V2 FatigueEngine / RestLogic / FatigueRules (behavioural reference only)

## Roadmap goal
Persistent Driver Work/Rest ledger; migrate/prove daily fatigue; add rolling/multi-day analytical views. A minimal Operations-style input may be borrowed early (work vs rest only) without building Operations wholesale.

## Roadmap gate
Real shifts plus relaunch and overnight-open-shift tests preserve fatigue truth.

**Gate result: PASS.**

Chunk 3 establishes Driver temporal truth. It does **not** claim complete NHVR statutory counting-period compliance. Regulatory interpretation discovered during the field/temporal review is now the separate **Chunk 3.5** dependency.

## Locked invariants
- One persistent Driver Work/Rest ledger feeds derived fatigue/regulatory views.
- Shift boundaries and midnight do **not** reset fatigue.
- Calendar day ≠ shift ≠ continuous episode ≠ rolling analytics ≠ statutory counting period.
- Unresolved fatigue carries forward until corrected history or qualifying rest resolves it.
- Driver authority beats inference; no silent consequential state changes.
- Corrections preserve provenance (occurrence vs recorded time).
- Core distance/retention remain Core-owned; Driver does not reach around them.

## Passed sub-chunks

| Sub | Name | Gate result |
|-----|------|-------------|
| **3a** | Work/Rest ledger spine | **PASS** — fabricated shift + relaunch + overnight-open |
| **3b** | Daily/calendar fatigue from ledger | **PASS** — same-day timeline, legal/short-rest semantics |
| **3c** | Rolling analytical windows | **PASS** — multi-day ledger; `now - 24h/7d/14d` remains useful analytics, not final statutory interpretation |
| **3d** | Field / temporal gate | **PASS** — real shift + relaunch + overnight-open plus explicit calendar/shift/episode/rolling temporal proof |

Detail contracts: `CHUNK3A_LEDGER_SPINE.md`, `CHUNK3B_DAILY_FATIGUE.md`, `CHUNK3C_ROLLING_WINDOWS.md`, `CHUNK3D_FIELD_GATE.md`.

## Temporal model locked by 3d
From one canonical ledger, Driver can derive:
- previous calendar day;
- current calendar day;
- driver-declared shift;
- current continuous episode;
- rolling analytical windows.

A cross-midnight rest can therefore simultaneously be one continuous episode and two calendar-day portions without contradiction.

## Deferred / moved forward
Moved to **Chunk 3.5 — NHVR regulatory interpretation + diary projections**:
- NHVR forward counting-period anchors and overlapping statutory windows;
- statutory 24h / 7d / 14d interpretation;
- driver-facing regulatory-window status;
- WWD/logbook and EWD-style projections from the canonical exact-time ledger;
- forgotten/late/missing input uncertainty and regulatory replay.

Still deferred unless separately promoted:
- **BFM scheme** — out of initial Standard Hours critical path (tester does not hold BFM quals).
- Full Operations activity model / SITE two-tier buttons.
- Commodity-specific activity kinds (fuel load, cattle, etc.).
- AFM / bus-coach schemes.
- Journal UI and coach-copy polish.

## Option D (compound testing)
Chunk 3 harnesses remain diagnostic assets. Compound tests should continue to ensure:
- Core distance/retention remains sane;
- Driver ledger remains independent;
- no silent cross-domain writes.

## V2 reference (do not edit for V3)
- `sources/FatigueEngine.swift` — behavioural reference only.
- `sources/AppModel+RestLogic.swift` — Phase 1 today-only planning / limbo.
- `sources/FatigueRules.swift` — today-only UI helpers.
- `sources/FatigueCountdownLogic.swift`, `FatigueRuleModels.swift` — supporting Phase 1 shapes.

Do not grow AppModel and do not create a second Work/Rest source of truth.

## Progress
Closure evidence and handover: `CHUNK3_PROGRESS.md`.
