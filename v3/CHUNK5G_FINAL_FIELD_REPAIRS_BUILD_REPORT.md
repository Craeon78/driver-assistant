# Chunk 5G — Final Field Repairs Build Report

**Status:** BUILD candidate; Niles review required

**Baseline:** `main` at `cad9e56` (merged PR #38)

**Branch:** `chunk5g-final-field-repairs`

## Bounded intent

Close only the remaining field-harness gaps: explicit mixed Run planning, a deliberate guarded 0 L delivery outcome, and a reachable Site workspace in constrained landscape height. PR #37 recovery behavior and the PR #38 exception layer remain compatibility gates, not reopened scopes.

## Implemented contract

- Today's Run has explicit `siteVisit`, `terminalLoad`, `plannedRest`, and `plannedOtherWork` items. Rest/Other Work planning emits only `planChange`; actual Rest remains Start/End truth and planned Other Work uses the existing generic `workRest`/WORK anchor.
- Terminal, Rest, and Other Work items do not manufacture visits, fills, or cargo.
- Remaining items can be edited/reordered/removed; executed items are locked.
- Execution lock and satisfaction are distinct: the first completed fill establishes the durable Run-item → event lock, while a Site is satisfied only after every fill is complete. Partial Sites remain current/reopenable.
- Old snapshots without Run items normalize completed/partial Sites and retained Terminal rows into an explicit compatibility state without inventing operational events; selected indices are remapped when terminal rows are removed from the Site collection. A recovered legacy `Load` workspace returns to Active and requires the driver to reopen its retained Terminal item explicitly.
- 0 L is a separate confirmed outcome requiring an unchanged draft and a trimmed 1–120 character reason. It retains run/site/fill identity and planned litres, advances the run, creates no cargo/reconciliation, and cannot enter Correction.
- Positive Delivery retains its existing `> 0` movement gate.
- Delivery-outcome and Run-item knowledge participates in persistence fingerprints, validation, relaunch, and Gate representation. Legacy execution flags are Site-only and carry the exact pre-normalization completed-fill IDs. A recovered partial Site may combine that proven legacy set with later real Delivery outcomes only when the sets are disjoint and together exactly cover completed fills; final satisfaction points to the new final Delivery without inventing history for an old fill. Semantic-tamper fixtures recompute a valid fingerprint before asserting rejection. Snapshots without `runItems` retain the previous fingerprint and derive a compatible Run projection on install.
- Load, Terminal linkage, and variance recording form one commit boundary: a thrown variance path restores cargo, reconciliation, history, Run links, visit state, discrepancies, and workspace context.
- Only the Site workspace scrolls vertically, with hidden indicators and a bounded truck interaction region; confirmation controls remain reachable.

## Explicit non-goals

No 5H work, prediction, flow rate, learned duration, routing/maps, Journal redesign, waiting/demurrage taxonomy, general V3 redesign, or PR #37 recovery changes.

## Executable handoff

Run `Chunk5GFinalFieldRepairsPlaygroundsRunner.runGate()` with the V3 sources. It executes:

1. final-field repair acceptance fixtures;
2. PR #38 Field Test 02 exception regressions; and
3. PR #37 recovery/migration regressions.

Local Linux validation is limited to repository/static checks because Swift/Xcode is unavailable. iPad/Swift Playgrounds execution remains required before PASS.
