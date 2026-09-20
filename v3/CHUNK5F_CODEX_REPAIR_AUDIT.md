# Chunk 5F — Niles Codex Repair Audit

**State:** ALL FOUR CODEX FINDINGS ACCEPTED AND REPAIRED  
**Branch:** `chunk5f-codex-repairs`

## C5F-01 — Run row opens editable Site while moving
**Codex:** P1  
**Niles:** VALID  
**Repair:** Run rows are disabled while moving; the store itself also rejects `openSite` while above the prototype stationary/crawl threshold. This is defence in depth rather than a UI-only gate.

## C5F-02 — Wrong product can count toward current fill
**Codex:** P1  
**Niles:** VALID  
**Repair:** Site/delivery draft manipulation accepts only compartments whose product matches the current Fill Item. Delivery movement totals only matching-product compartments. Confirm revalidates the draft and appends unload transactions only for the current fill product.

This protects delivery semantics; it is not merely a visual anti-shandy rule.

## C5F-03 — Increased delivery compartment can be silently ignored
**Codex:** P2  
**Niles:** VALID WITH RECONCILIATION BOUNDARY  
**Repair:** Delivery mode rejects a proposed compartment quantity above confirmed cargo. Confirm also rejects an invalid delivery draft as a whole.

This does **not** mean physical observations above calculated state are impossible. They belong to the explicit reconciliation/variance path established in 5E. 5F does not implement that exception UI; it must not disguise reconciliation as a Delivery.

## C5F-04 — Completed fill/site can reopen
**Codex:** P2  
**Niles:** VALID  
**Repair:** `openSite` now requires an incomplete Fill Item. Completed visits remain non-editable in the Run. `OPEN NEXT SITE` resolves the next incomplete physical Site Visit rather than hard-coding index zero.

## Regression coverage

Deterministic tests now cover:
- moving prevents Site workspace opening;
- wrong-product delivery manipulation is rejected;
- delivery increases are rejected to the future reconciliation path;
- completed SeaLink cannot reopen;
- next-site navigation skips completed visits.

## Scope check

No production Cargo/Operations/Driver/Fuel contract was modified. The repairs remain inside the authorised 5F harness boundary.

## Disposition

**ALL CLEAR TO OPEN REPAIR PR FOR EXTERNAL REVIEW.**

Do not merge until the repair PR's external/Codex review has been checked.
