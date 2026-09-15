# V3 Chunk 3b — Daily Fatigue from Ledger

Status: OPEN (blocked on 3a)
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md + V2 Phase 1 RestLogic/FatigueRules (reference)

## Goal
Same-day fatigue metrics computed **only** from the persistent ledger — not from session-only AppModel memory.

## Driver-sensible question
“Do today’s legal rest, work-since-last-break, and simple caps match what I actually did?”

## Scope
- Legal rest = rest segments ≥ 15 minutes (stationary as required by ported rules).
- Short rest &lt; 15m does not count as legal rest (NHVR-style proxy: may still count toward work buckets if V2 did).
- Work since last legal rest.
- Today proxies: 7.5h / 10h thresholds, 12h cap, rest limbo (&lt;15m in progress).
- Corrections to ledger entries preserve provenance; metrics recompute.

## Out of scope
- Rolling 24h / 7d / 14d (Chunk 3c).
- BFM.
- Full Operations activity taxonomy.

## Gate
1. Scripted same-day timeline produces expected daily metrics.
2. Rest limbo: in-progress rest &lt;15m is provisional, not legal.
3. After ≥15m, rest becomes legal and resets work-since-last-legal-rest.
4. Correcting a rest duration updates metrics without silent history rewrite.

## Harness
Time-controlled fabricated day on the ledger; assert metric table; apply one correction; re-assert.
