# Chunk 5F — Niles Re-audit

**State:** ALL CLEAR FOR NEXT BUILD STEP  
**Branch:** `chunk5f-adaptive-workspace`  
**Repair:** N5F-01

## Re-audit

Bob replaced the harness-owned confirmed-litre mutation path with the existing generic `CargoLedger` as the source of confirmed cargo state.

- Opening fixture quantities are established as ledger load transactions.
- Delivery drag/type remains draft-only.
- Delivery Confirm appends immutable `.unload` CargoTransactions to a candidate ledger and only adopts the candidate after validated append succeeds.
- Load scan/drag/type remains draft-only.
- Load Confirm appends `.load` CargoTransactions; returned cargo is preserved because confirmed state is projected from the ledger and the draft expresses additions over that state.
- Tests now assert that confirmed quantities do not change before Confirm and that Confirm appends CargoLedger transactions.

The repair did not alter existing Cargo, Operations, Driver or Fuel domain files.

## Important boundary note

5F deliberately does **not** route through the current `FuelDeliveryCoordinator`, because that coordinator requires `pumpFinishedAt` and therefore embodies the 5E interaction semantics that 5F is explicitly replacing. Using it would reintroduce a false physical pump-timing requirement. The generic CargoLedger is the correct existing truth owner for this harness while the future Fuel orchestration contract is redesigned separately if field testing validates the 5F interaction.

## Remaining harness work

N5F-01 is closed. Continue within the authorised Intent:
- add prototype Run reorder behaviour for stationary/crawl versus moving state without production GPS;
- prepare target-runtime/iPad handoff and touch checklist;
- do not widen domain scope.

**Disposition: ALL CLEAR FOR NEXT BUILD STEP.**
