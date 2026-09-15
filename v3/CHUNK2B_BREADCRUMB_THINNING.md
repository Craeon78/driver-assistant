# V3 Chunk 2b — Breadcrumb Retention & Thinning

Status: **PASS** (segment-observation gate 2026-09-15)
Owner: Core
Authority: V2 Data Retention strategy + V3 privacy note + 2026-09-14/15 field experiments + lifecycle decisions below

## Goal
Establish a safe breadcrumb lifecycle that preserves accurate accepted GPS evidence while it is operationally useful, compresses repetitive geometry aggressively when its meaning is resolved, and never destructively thins evidence whose operational meaning remains unresolved.

This policy later feeds Operations/Sites classification and Chunk 6 Journal surfaces.

## Canonical lifecycle

> While a shift/segment/interval is open, retain the full accepted GPS stream needed for accurate measurement and interpretation.
> Closure does NOT automatically mean “thin now”. Closure triggers a retention decision.
> Only evidence whose semantic retention class is sufficiently resolved may undergo destructive thinning.
> Unresolved evidence remains dense until later evidence or driver reconciliation resolves it.

### Locked invariant

> Unresolved evidence is exempt from destructive thinning. Resolution should preferentially present preserved evidence itself when later UI/domain machinery exists, rather than asking the driver abstract questions that the evidence can help answer.

The app must not silently create consequential operational history from GPS inference. Later corrections preserve provenance, consistent with the V3 event-truth contract.

### Bracket, do not freeze the day
If uncertainty concerns only part of a journey/segment, preserve the smallest useful dense bracket plus enough surrounding context to interpret it. Resolved portions remain eligible for their normal retention treatment.

## Test vocabulary vs production vocabulary

Field gate used **test vocabulary**: DRIVE / OPERATIONAL / UNRESOLVED.

That vocabulary is **not** locked as production app language. Core must stay cargo-agnostic. Fuel, cattle, water, container, and other commodity modules sit on top of generic underlying motion/segment/retention concepts. Production Core names remain generic; commodity-specific meaning arrives with Operations / Cargo later.

Older draft labels (NORMAL / TRAFFIC / YARD CANDIDATE / UNRESOLVED) were superseded in the field harness by the test vocabulary above.

## Domain boundary
Core owns accepted breadcrumb evidence, retention execution, and the rule that unresolved evidence cannot be destructively compressed.

Core does NOT own:
- Driver Work/Rest truth;
- Operations segment/activity truth;
- Sites, gates, tanks or customer identity;
- Cargo/Fuel activity truth;
- Journal/reconciliation UI.

## Field evidence
- Thinning profiles measured on mixed highway/yard route (aggressive transit vs denser slow/traffic geometry).
- Segment Observation Gate: multi-hour real drive, thousands of dense points, human ground truth vs machine labels.
- Motion-state audit (MOVING / CRAWLING / STOPPED) supported segment character without promoting ordinary road stops into yard/operational truth by default.
- Unresolved class observed and later resolved when evidence allowed — correct behaviour.
- Segments that passed the decision threshold matched Cory truth for the gate question:
  > Can whole-segment context distinguish predominantly DRIVE from predominantly OPERATIONAL activity without ordinary road stops becoming yard truth?

## Gate result
**PASS** on the segment-observation gate (2026-09-15). Cory confirmed the three closure checks.

## Option D
Chunk 2 and Chunk 2b close **separately**. Cross-module compound tests are required when Chunk 3+ is built so modules remain independently gated but proven to compose. Harnesses are retained diagnostic assets; ContentView points at the active harness.

## Files
- Core/Breadcrumb.swift
- Core/BreadcrumbThinner.swift
- Core/BreadcrumbRetention.swift
- ThinningHarnessView.swift
- ClassificationHarnessView.swift (and related classifier test support)
- This document
