# V3 Chunk 2 — Field Gate Close-out

**Status:** PASS  
**Field validation date:** 15 September 2026  
**Next chunk:** Chunk 3 is READY but NOT COMMENCED.

## Gate decision

Chunk 2 / 2b passes its field gate. The Segment Observation Gate demonstrated that whole-segment context can meaningfully distinguish predominantly DRIVE from predominantly OPERATIONAL activity without ordinary road stops becoming operational/yard truth.

This closes the current Chunk 2 validation work. It does **not** authorise implementation of Chunk 3 in this change.

## Field evidence

A full working-shift run was used as the principal field validation rather than tuning against a small synthetic or short-drive sample.

At end-of-shift review:

- 14 completed segments were retrospectively labelled by Cory as human ground truth.
- Machine segment classifications agreed with Cory's segment-level labels across the reviewed set.
- The run contained sustained road driving, urban/traffic interruptions, crawling/manoeuvring, long stationary/operational periods, multiple operational sites, and transitions between them.
- Ordinary traffic stops and low-speed interruptions inside driving did not cause the surrounding driving segments to become OPERATIONAL.
- Operational periods were identified as OPERATIONAL from their whole-segment movement mix rather than from boundary proximity alone.
- Cory made one deliberate DRIVE correction/input during the earlier test while approaching a traffic light to observe behaviour; it was not required to repair a machine misclassification.
- A final observed blue/DRIVE trace south of the last pair of boundary flags was explained by a missed driver boundary/input at the second-last job. Treat this as driver-input/missed-boundary evidence, **not classifier failure**.

## What the test established

The useful abstraction is the segment, not the individual stop episode:

`driver boundary -> segment observations -> dominant movement/context -> DRIVE | OPERATIONAL | UNRESOLVED`

A boundary defines the observation interval/context change. It is not evidence that nearby movement is operational and must not retrospectively convert traffic into yard activity.

The classifier may use lower-level STOPPED / CRAWLING / MOVING observations as evidence, but those observations are not themselves the final operational truth.

## Residuals deliberately deferred

These are not Chunk 2 blockers:

1. Missed-boundary recovery/detection should later produce a candidate/unresolved item for the Driver Attention System rather than fabricate certainty.
2. SITE hierarchy, candidate pins, learned gates/points, geofences and inferred load/unload/rest points remain later work.
3. Site context and activity remain separate concepts: a truck may be DRIVE/site-transit inside a large site before becoming operational.
4. The successful classifier should not be threshold-tuned merely to optimise this one shift. Preserve this field result as baseline evidence and evaluate future changes by replay/regression.

## Regression principle

Preserve, where technically available, the raw observations/trace, machine output and Cory ground-truth labels from this validation as replay/regression evidence. Human correction/ground truth must remain distinguishable from original machine observations.

Future classifier changes should be compared against this baseline for at least:

- segment-level DRIVE/OPERATIONAL agreement;
- resistance to ordinary traffic-stop contamination;
- boundary-adjacent behaviour;
- ambiguous/missed-boundary handling;
- false confident classifications that should have remained UNRESOLVED.

## Definition of Done — satisfied

> The system can use driver-supplied boundaries to divide the trace into segments and meaningfully distinguish predominantly DRIVE from predominantly OPERATIONAL activity, without ordinary road stops or boundary proximity corrupting that distinction. Missed/ambiguous cases remain explicitly unresolved rather than being confidently misclassified.

**Result: PASS.**

## Handoff

Chunk 2 is closed. Do not continue modifying Chunk 2 simply because more tuning is possible; reopen only on contradictory field evidence or a demonstrated regression.

The next work session may orient to **V3 Chunk 3 — Driver truth** and its existing roadmap gate. Chunk 3 has not been started by this close-out.