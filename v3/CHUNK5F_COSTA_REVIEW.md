# Chunk 5F — Costa Prebuild Review

**State:** PREBUILD REVIEW  
**Scope:** Knowledge/source-of-truth and boundary review of the proposed Adaptive Workspace UX Harness  
**Input:** Niles prebuild review plus current V3 ownership contract.

## Review conclusion

**PROCEED. No competing canonical source is required for 5F.**

5F should remain a disposable/testable interaction layer over existing V3 domain ownership. The durable design knowledge belongs in the chunk contract/review/intent documents; the harness itself must not become a second canonical specification.

## Boundary findings

1. **Plan, projection, observation, draft and confirmed event must remain named distinctly.** Do not use “current cargo” for an unconfirmed finger/OCR proposal.
2. **OCR is transient input, not durable evidence.** Production intent is capture -> OCR/extract -> discard image. 5F should simulate the extracted result only; it should not add photo storage, document archives or image provenance infrastructure.
3. **Driver verification is whole-document verification.** Do not create a field-confidence bureaucracy. The UI should ask the driver to check the screen against the physical BOL and allow rescan/manual/drag correction.
4. **DA-generated paperwork likenesses are not official documents.** They may represent structured extracted/derived information and expand via Show Details, but must not be labelled or styled as approved legal substitutes.
5. **EIP/ERG/DG rules are not 5F truth.** Use neutral demo/document-status placeholders. No remembered operational rule should be promoted to policy without later jurisdictional verification.
6. **Receiving-vessel fill graphics are representational only.** Persist/confirm movement quantities, not invented customer tank levels.
7. **Rest-state presentation must not create a second fatigue calculation.** It may project deterministic demo values from fixtures. Production legal/advisory interpretation remains Policy/Regulatory over Driver evidence.
8. **Location/context must not manufacture events.** A future geofence may suggest context; 5F must not teach the UI that presence equals arrival, service or pumping.
9. **Preserve V2 knowledge intentionally.** The five paper sheets and 5F scope are not exhaustive. Later migration audit must explicitly classify V2 capabilities KEEP / ADAPT / REPLACE / RETIRE so useful features are not lost by omission.
10. **Do not duplicate CozzaHQ project truth.** CozzaHQ should continue to point to this repository; 5F detail belongs here.

## Durable knowledge recommendation

Create a single 5F intent/contract in this repository and keep review documents adjacent to it. Do not copy the full 5F design into CozzaHQ. Later field-test results should amend/close the chunk here.

## Costa disposition

Niles's constraints are structurally coherent. No knowledge-boundary blocker to Bob's Intent-to-Build.
