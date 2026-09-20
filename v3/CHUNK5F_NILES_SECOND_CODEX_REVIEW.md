# Chunk 5F — Niles Second Codex Review

**State:** BOTH FINDINGS VALID — REPAIRED WITHOUT DISCUSSION BLOCKER

## C5F-05 — Wrong-product regression test was a no-op
**Codex:** P2  
**Niles:** VALID TEST DEFECT, not a newly discovered domain defect.

The production/harness guard added in the prior repair was real, but the regression test was weak: C2 contained 0 L and attempted to set it to 0 L, so the test could pass even without the guard.

**Bob repair:** the test now deliberately establishes 1,000 L ULP in C2 through the Load path, opens the DIE fill, attempts to reduce C2 to 500 L, and asserts that C2 remains at 1,000 L. This distinguishes actual wrong-product rejection from a no-op.

No design discussion required.

## C5F-06 — Next-site display can disagree with next-site action
**Codex:** P2  
**Niles:** VALID, and Cory's broader concern is correct.

The defect was larger than one stale card. “Next” appeared in the top instrument bar, NEXT SITE card, map context and navigation action, but those surfaces did not share one projection. Hard-coded SeaLink/Cleveland text could therefore disagree with the Run.

The customer names themselves are acceptable as deterministic 5F fixture/test data. They are **not** acceptable as hard-coded UI truth.

**Bob repair:** the store now exposes one `nextIncompleteVisit` projection derived from the Run. The top bar, NEXT SITE card, map context and OPEN NEXT SITE action all derive from that same source. Once SeaLink Cleveland is complete, all of those surfaces move to Hemmant together. When no incomplete visit remains, they show the run-complete/no-next-site state.

No production customer/site database is being introduced in 5F; SeaLink/Everstin remain fixture records in the prototype store only.

## Disposition

Both Codex findings were actionable and have been repaired immediately within the existing 5F scope.

**READY FOR CODEX RE-REVIEW. DO NOT MERGE YET.**
