# V3 Chunk 3.5 — Closeout

Status: **PASS — CLOSED 2026-09-16**
Owner: Policy/Regulatory

## Device evidence
Swift Playgrounds/iPad execution on 2026-09-16 returned PASS for the foundation harness and all final sub-gates:

- Foundation — overlapping rest anchors, uncertainty, 7h major-rest anchor, exact work boundary/one-minute breach, minimum rest, overlapping 24h anchors, canonical timestamp preservation and WWD conservatism: PASS.
- 3.5a — Long-period Standard Hours: PASS.
- 3.5b — Diary interpretation: PASS.
- 3.5c — Recovery / deterministic replay: PASS.
- 3.5d — Driver surface: PASS.

## Locked outcome
Chunk 3.5 adds a Policy/Regulatory interpretation layer over passed Chunk 3 Driver truth. It does not create a second fatigue ledger or mutate canonical occurrence timestamps.

The implemented Standard Hours foundation proves:
- forward rest-end anchored sub-24h counting windows with overlapping windows retained;
- long-period 24h/7d/14d policy fixtures and major/night-rest handling;
- exact canonical ledger projected separately as WWD, EWD-style and local-area views;
- explicit base-time-zone input;
- missing/uncertain history cannot silently produce a favourable compliance state;
- corrected history deterministically replays policy results;
- driver-surface headline state retains drill-down to underlying active windows.

## Regulatory verification at closeout
Authoritative NHVR material was rechecked on 2026-09-16. Standard Hours solo limits remain 5.5h/5.25h/15m; 8h/7.5h/30m; 11h/10h/60m; 24h/12h/7h stationary; 7d/72h/24h stationary; 14d/144h with 2 night rests and 2 night rests on consecutive days. NHVR counting guidance states sub-24h periods count forward from the end of any rest break; Standard Hours periods of 24h+ count forward from the end of the longest major rest required for the period, with fallback to any rest if that required rest has not been taken, and subsequent major rest does not erase an already-running period. Time is counted relative to the driver's base time zone. WWD counts 15-minute periods with work rounded up/rest down; EWD counts completed minutes and continuous rest under 15 minutes does not satisfy minimum-rest requirements.

## Safety boundary
PASS means the defined V3 Standard Hours policy architecture and device gates passed. It is **not** NHVR approval or certification of Driver Assistant as an Electronic Work Diary. Regulatory Policy must be revalidated against then-current authoritative requirements before wider release.

## Handover
Chunk 3.5 is locked. Chunk 4 — Vehicle + Operations — is unblocked. Future regulatory schemes (including BFM/AFM/ACH/exemptions) are Policy variants and must not push scheme-specific truth into Driver.
