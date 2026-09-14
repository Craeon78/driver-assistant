# V3 Chunk 2b — Breadcrumb Thinning

Status: IN PROGRESS
Owner: Core
Authority: V2 Data Retention strategy + V3 privacy note + field experiment + clarifying lifecycle rule below

## Goal
Decide, with human-in-the-loop evidence, how aggressively GPS breadcrumbs can be thinned before the resulting track becomes impractical for “where did I go / where did I stop”.

This policy will later feed Chunk 6 (Journal) and the long-term retention rules.

## Canonical lifecycle (clarifying rule — locked 2026-09-14)

> While a shift/segment is open, retain the full accepted GPS stream needed for accurate measurement.
> Once the relevant interval closes, thin that breadcrumb trail according to the established policy and persist the thinned version for later Journal/logbook reconstruction.
> Authoritative ODO anchors and consequential events are preserved separately.

This rule was not previously explicit in V2 retention tiers or V3 documents. It is consistent with their spirit (measurement accuracy first, storage realism later, ODO/events as separate truth) and is now the binding Core contract for breadcrumbs.

### Implications
- Live / open interval: dense accepted stream stays available to the DistanceEngine and any in-shift diagnostics.
- On close (ODO anchor, shift end, or explicit segment close): run the ThinningPolicy, persist the thinned trail, discard or archive the dense stream according to retention tiers.
- ODO anchors, key events, and stop transitions remain first-class records outside the thinned geometry.
- Journal reconstruction uses the thinned trail + separate anchors/events; it never requires the original dense stream after the interval has closed.

## Existing time-based intent (still in force)
- ≤ 28 days: high detail (time + heading + speed transitions + key events). Always keep terminals/delivery/depots.
- 28 d – 12 m: collapse to named stops + arrival/departure + dwell. Discard continuous paths.
- > 12 m: stops only.
- Privacy: occupational only, progressively reduce detail, remove positional journey history after ~3 months while keeping justified derived records.

The lifecycle rule above sits *inside* these tiers: thinning happens at interval close; the tiers then decide how long the thinned result (and any residual detail) is kept.

## Gate for 2b
Cory has exercised the interactive harness on real (or representative) data and recorded the practical thinning floor he is willing to accept.

## Files
- Core/Breadcrumb.swift
- Core/BreadcrumbThinner.swift
- ThinningHarnessView.swift (Playgrounds entry)
- This document (lifecycle rule + policy experiment)
