# V3 Chunk 2b — Breadcrumb Thinning

Status: IN PROGRESS
Owner: Core
Authority: V2 Data Retention strategy + V3 privacy note + field experiment

## Goal
Decide, with human-in-the-loop evidence, how aggressively GPS breadcrumbs can be thinned before the resulting track becomes impractical for “where did I go / where did I stop”.

This policy will later feed Chunk 6 (Journal) and the long-term retention rules.

## Existing intent (do not invent new philosophy)
- ≤ 28 days: high detail (time + heading + speed transitions + key events). Always keep terminals/delivery/depots.
- 28 d – 12 m: collapse to named stops + arrival/departure + dwell. Discard continuous paths.
- > 12 m: stops only.
- Privacy: occupational only, progressively reduce detail, remove positional journey history after ~3 months while keeping justified derived records.

## Gate for 2b
Cory has exercised the interactive harness on real (or representative) data and recorded the practical thinning floor he is willing to accept.

## Files
- Core/Breadcrumb.swift
- Core/BreadcrumbThinner.swift
- ThinningHarnessView.swift (Playgrounds entry)
