# V3 Chunk 2b — Breadcrumb Retention & Thinning

Status: IN PROGRESS — field thinning evidence obtained; semantic classification gate remains
Owner: Core
Authority: V2 Data Retention strategy + V3 privacy note + 2026-09-14 field experiments + lifecycle/retention decisions below

## Goal
Establish a safe breadcrumb lifecycle that preserves accurate accepted GPS evidence while it is operationally useful, compresses repetitive geometry aggressively when its meaning is resolved, and never destructively thins evidence whose operational meaning remains unresolved.

This policy will later feed Operations/Sites classification and Chunk 6 Journal/reconciliation surfaces.

## Canonical lifecycle — revised 2026-09-14

> While a shift/segment/interval is open, retain the full accepted GPS stream needed for accurate measurement and interpretation.
> Closure does NOT automatically mean “thin now”. Closure triggers a retention decision.
> Only evidence whose semantic retention class is sufficiently resolved may undergo destructive thinning.
> Unresolved evidence remains dense until later evidence or driver reconciliation resolves it.

This supersedes the earlier simpler “close -> thin” wording.

### Retention classes

1. **NORMAL** — ordinary transit geometry. Candidate policy: aggressive field-tested E profile (60 s / 100 m / 45°).
2. **TRAFFIC** — stop/start or low-speed road behaviour where more geometry is useful. Candidate policy: field-tested C profile (15 s / 25 m / 25°).
3. **YARD CANDIDATE** — destination-like / yard-like spatial evidence. Preserve dense evidence for future Site footprint/polygon interpretation. This is not confirmed Site truth in Chunk 2b.
4. **UNRESOLVED** — evidence conflicts with, or cannot safely be explained by, recorded operational history. Preserve the relevant dense bracket. Destructive thinning is prohibited until resolution.

### Locked invariant

> Unresolved evidence is exempt from destructive thinning. Resolution should preferentially present preserved evidence itself when later UI/domain machinery exists, rather than asking the driver abstract questions that the evidence can help answer.

The app must not silently create consequential operational history from GPS inference. Later corrections preserve provenance, consistent with the V3 event-truth contract.

### Bracket, do not freeze the day
If uncertainty concerns only part of a journey/segment, preserve the smallest useful dense bracket plus enough surrounding context to interpret it. Resolved portions remain eligible for their normal retention treatment. One suspicious stop must not force an entire working day to remain dense.

## Domain boundary
Core owns accepted breadcrumb evidence, retention classes, retention execution and the rule that unresolved evidence cannot be destructively compressed.

Core does NOT own:
- Driver Work/Rest truth;
- Operations segment/activity truth;
- Sites, gates, tanks or customer identity;
- Cargo/Fuel activity truth;
- Journal/reconciliation UI.

Later domains may provide evidence used to classify a spatial episode. Core then applies the retention disposition.

## Classification evidence — provisional, not all implemented in Chunk 2b
Candidate evidence includes:
- motion state / speed trend;
- position relative to an Operations segment boundary;
- dwell duration;
- compact versus linear spatial progression;
- manoeuvring / heading-change pattern;
- known Site/pin proximity when Sites exists;
- optional road-network relationship when road data exists;
- repeated historical destination evidence.

No single signal is canonical truth. In particular, “stopped for N minutes” and “off road” must not independently create a Site or operational event.

### Segment-boundary hypothesis to test
- Mid-segment low-movement episode -> strong TRAFFIC prior.
- Low-movement episode around segment start/end -> strong destination/YARD-CANDIDATE prior.
- Destination-like episode appearing mid-segment -> UNRESOLVED prior; may indicate a forgotten Load/Unload/Break/etc boundary.

Chunk 2b may simulate segment boundaries to test differentiation. Production Operations ownership arrives later.

## Existing time-based intent (still in force)
- ≤ 28 days: high detail appropriate to operational need; always preserve consequential events separately.
- 28 d – 12 m: collapse toward named stops + arrival/departure + dwell; discard unnecessary continuous paths.
- > 12 m: stops only.
- Privacy: occupational only, progressively reduce detail, remove positional journey history after ~3 months while keeping justified derived records.

Semantic retention happens inside these longer-term tiers. An unresolved item may temporarily delay destructive compression of its bounded evidence, but should itself be surfaced for resolution rather than becoming permanent accidental storage.

## Field evidence obtained
The MapKit thinning harness recorded a mixed real-world route with highway/transit and slow yard/crawl behaviour.

Representative dataset:
- dense accepted points: 1,921;
- accepted/rejected GPS: 1,921 / 16;
- dense distance: 39.16 km;
- stop transitions: 10.

Notable candidate policies:
- C: 15 s / 25 m / 25° -> 1,323 / 1,921 retained (68.9%); 39.12 km; -0.10%; stops 10 -> 10.
- E: 60 s / 100 m / 45° -> 377 / 1,921 retained (19.6%); 39.02 km; -0.34%; stops 10 -> 10.

This supports aggressive thinning for ordinary transit while spending GPS detail where it buys semantic information.

## Harnesses are retained development assets
The temporary Playgrounds harnesses are policy-training / diagnostic instruments, not disposable UI. Preserve them after gates pass. They may later inform a tiled Developer/Diagnostics surface showing multiple under-the-hood projections of the same field evidence.

The current MapKit interaction also prototypes a useful future reconciliation pattern: show preserved slow/destination evidence in spatial context so a stationary driver can identify meaningful features such as gate, tank or optional exit when Sites exists. Do not implement production Site/Journal UI in Chunk 2b.

## Remaining Chunk 2b test
Build a semantic classification/retention harness using accepted GPS plus simulated segment boundaries and available motion/spatial evidence.

The harness should distinguish provisionally among:
- NORMAL;
- TRAFFIC;
- YARD CANDIDATE;
- UNRESOLVED.

It should include at least:
1. ordinary transit;
2. short traffic-light stop;
3. prolonged stop/start traffic or queue;
4. genuine destination-like crawl/manoeuvre near a simulated segment boundary;
5. destination-like behaviour with an intentionally omitted boundary -> UNRESOLVED;
6. long roadside stop/break-like ambiguity -> UNRESOLVED unless evidence justifies otherwise.

A road/on-road/off-road signal may be simulated or added opportunistically, but Chunk 2b does not depend on live road-network data.

### Retention-routing assertions
- NORMAL -> E/aggressive thinning;
- TRAFFIC -> C/conservative thinning;
- YARD CANDIDATE -> dense preserved for future semantic/site representation;
- UNRESOLVED -> bounded dense evidence preserved unchanged;
- resolving UNRESOLVED later permits reclassification and only then the corresponding destructive-safe retention treatment.

## Gate for 2b
PASS when:
1. the field experiment establishes practical candidate thinning profiles;
2. the classifier demonstrates useful differentiation on representative/live evidence rather than perfection;
3. retention routing obeys the four-class contract;
4. unresolved evidence survives closure without destructive thinning and can later be reclassified safely;
5. no consequential Driver/Operations/Site truth is silently invented.

Pins, customer/site history and production road-network intelligence are explicitly NOT required for this gate. They are later confidence improvements.

## Files
- Core/Breadcrumb.swift
- Core/BreadcrumbThinner.swift
- Core/BreadcrumbRetention.swift
- ThinningHarnessView.swift (Playgrounds/diagnostic policy-training UI)
- This document
