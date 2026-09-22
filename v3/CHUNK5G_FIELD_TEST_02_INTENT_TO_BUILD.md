# Chunk 5G — Field Test 02 Bounded Intent-to-Build

**Status:** GO received; BUILD in progress

**Source package:** `v3/CHUNK5G_FIELD_TEST_02_FINDINGS_AND_REPAIR_PACKAGE.md`

**Build branch:** `chunk5g-field-test-02-exceptions`

**Baseline:** current `main` after merge of PR #37

**Separation rule:** PR #37 remains a distinct recovery repair. Its recovery validation is not reopened, changed, or counted as Field Test 02 evidence.

## Intent

Implement only the exception layer and explicit state transitions established by Field Test 02, on the existing Chunk 5G chronological event and cargo-ledger spine.

## Authorised build slices

1. Preserve a calculated transaction total, externally established actual total, signed variance, provenance, optional note, and supplied post-transaction physical state without turning variance into cargo.
2. Present **Physical Check** as the driver action; retain reconciliation as its accounting consequence, including both positive and negative observations.
3. Correct a committed Load or Delivery append-only by linking to the original event and appending a ledger reversal plus corrected replacement. Do not edit or delete the original.
4. Keep Transfer as a distinct physical compartment-to-compartment movement.
5. Provide repeatable Start Rest / End Rest transitions and distinct chronological events.
6. Provide explicit simulated-driving running/stopped state and an explicit stop action. Simulation remains test infrastructure.
7. Split Gate reporting into internal representation integrity, operational completeness, and evidence-based persistence status.
8. Add deterministic acceptance coverage for the canonical Field Test 02 fixtures.

## Bounded implementation surface

- `v3/UI/Chunk5GEventLog.swift`
- `v3/UI/Chunk5FPrototypeStore.swift`
- `v3/UI/Chunk5FAdaptiveWorkspaceView.swift`
- `v3/UI/Chunk5GGateReportView.swift`
- `v3/Tests/Chunk5FAdaptiveWorkspaceTests.swift`
- `v3/Tests/Chunk5GFieldTest02ExceptionTests.swift`

The ordinary cargo architecture remains unchanged. Review evidence proved one bounded ledger append defect for historical Load correction, so `v3/Cargo/CargoLedger.swift` gains an atomic reversal/replacement append that reuses the existing transaction and replay rules.

## Acceptance boundary

- 15,997 L calculated → 16,192 L actual → +195 L; post-state empty; both totals retained; no invented or negative cargo.
- Physical Check 0 → 100 L and 100 → 0 L, with explicit signed differences and reconciled projections.
- 19,604 L → 19,504 L correction; -100 L; original retained; correction append-only.
- Transfer remains semantically separate.
- Two complete Rest cycles in one active shift.
- Simulation visibly starts and explicitly stops.
- Internal integrity cannot claim operational completeness; persistence remains PASS / FAIL / NOT TESTED from evidence.

## Non-goals

No recovery changes from PR #37; no ordinary cargo redesign; no Journal, navigation, map, mass model, EWD, OCR, external-report import, or general delivery-screen redesign.

## Review and merge gate

BUILD must pass bounded static/executable checks available in the build environment, then Niles review and any Bob repair loop. A review-clear implementation may proceed to PR/external review. Merge-for-test remains a separate authorised transition and does not constitute field PASS.
