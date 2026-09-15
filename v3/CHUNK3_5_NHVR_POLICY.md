# V3 Chunk 3.5 — NHVR Regulatory Interpretation + Diary Projections

Status: **PASS — CLOSED 2026-09-16**
Owner: Policy/Regulatory
Consumes: Driver-owned `WorkRestEntry` ledger and temporal views
Authority: `V3_REFACTOR_CONTRACT.md` + `resources/v3/V3_ROADMAP.md` + current authoritative NHVR counting-time/work-rest guidance

## Purpose
Interpret passed Chunk 3 Driver truth under an explicit regulatory policy. Chunk 3.5 does not own or rewrite work/rest truth.

## Locked boundaries
- Driver owns exact occurrence timestamps and work/rest history.
- Policy derives anchors, counting periods, compliance state and diary projections.
- Rolling analytics remain useful but are not statutory counting periods.
- Calendar, shift, episode, rolling analytics and statutory counting periods remain distinct views.
- Historical correction/replay regenerates policy results deterministically.
- Missing/uncertain history must never silently improve compliance state.

## Standard Hours solo — first policy
Implementation foundation covers the Standard Hours solo table:
- 5.5h: max 5.25h work; minimum 15 continuous minutes rest.
- 8h: max 7.5h work; minimum 30m rest in blocks of >=15 continuous minutes.
- 11h: max 10h work; minimum 60m rest in blocks of >=15 continuous minutes.
- 24h: max 12h work; minimum 7 continuous hours stationary rest.
- 7d: max 72h work; minimum 24 continuous hours stationary rest.
- 14d: max 144h work; 2 night rest breaks AND 2 night rest breaks on consecutive days.

## Counting-period semantics
### Less than 24 hours
Generate forward candidate periods from the end of every rest break. Retain simultaneously applicable/overlapping periods; do not keep one mutable `currentWindow`.

### 24 hours or longer — Standard Hours
Count forward from the end of the longest major rest break required for the applicable period. If the required break has not been taken, count from the end of any rest break. A subsequent major rest inside an already-running 24h period does not erase that period; relevant overlapping periods remain evaluable.

## Base time zone
Policy evaluation and diary rendering use the driver's base time zone, not the device's transient location time zone.

## Diary projections
One canonical exact-timestamp ledger supports projections; projections never mutate canonical truth.

- `actualExact`: canonical occurrence timestamps.
- `ewdStyle`: completed-minute interpretation for planning/testing; this app must not claim to be an NHVR-approved EWD unless separately approved.
- `wwd`: written-work-diary representation/rounding rules.
- `localAreaRecord`: separate projection because local-area records are not assumed to use WWD/EWD rounding semantics.

## Driver UX contract
For each applicable rule the UI can show a concise current state and drill into all relevant windows. A tick means compliant **as of now**, not permission to continue working until the period end.

States support at least:
- compliant as of now;
- approaching constraint / action due;
- breach;
- uncertain history.

## Forgetfulness / corrections
Late or forgotten input is normal. Policy may identify uncertainty but must not invent favourable history. Driver confirmation/correction updates canonical Driver truth with provenance, then Policy replays all affected anchors/windows.

## Gate result
**PASS on Swift Playgrounds/iPad, 2026-09-16.** Foundation gate plus 3.5a Long-period Standard Hours, 3.5b Diary interpretation, 3.5c Recovery/replay and 3.5d Driver surface all passed. See `CHUNK3_5_CLOSEOUT.md`.

Given one canonical work/rest history, the implemented foundation can reconcile calendar/logbook representation, continuous episodes, driver-declared shift truth, rolling analytics and Standard Hours policy counting-period views without introducing a competing Driver truth source.

## Safety boundary
Chunk 3.5 PASS is an engineering gate, not NHVR approval/certification of Driver Assistant as an EWD. Revalidate Policy against then-current authoritative requirements before wider release.
