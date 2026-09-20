# Chunk 5F — Bob Build Report

**State:** BUILD CANDIDATE COMPLETE — AWAITING TARGET RUNTIME

## Built

- Five-state adaptive SwiftUI workspace: Pre-shift, Active/Driving, Site/Delivery, Load, Rest.
- Persistent instrument shell.
- Physical Run -> Site Visit -> Fill Item fixture.
- Stationary/crawl Run reorder with a deterministic simulated moving state that makes the Run view-only.
- Shared truck cargo interaction surface.
- Delivery draft manipulation with contextual EMPTY/planned-remainder snap, direct numeric precision, Undo and Confirm.
- Cargo confirmation backed by existing CargoLedger rather than a parallel UI truth store.
- Multi-fill SeaLink Cleveland flow.
- Single Load Draft manipulated by simulated scan, drag and direct numeric entry.
- Returned cargo preserved through ledger-derived confirmed state.
- Rest presentation with fatigue dominant and Run subdued.
- Deterministic gate tests and iPad touch checklist.

## Not built

All Intent non-goals remain out of scope, including real OCR, GRDB, production fatigue/DG/compliance logic, real GPS/routing, Journal redesign and the eventual V2 feature migration audit.

## Known prototype-only choices

- 5 km/h is the harness stationary/crawl threshold; it is not a production rule.
- 42 km/h is only the simulated moving value.
- Snap tolerances are reversible prototype tuning.
- Truck 92 and current compartment quantities are deterministic fixtures.
- Map and contact/detail surfaces are placeholders.
- No visual-polish claim is made.

## Build disposition

Repository-side 5F candidate is ready for Niles final audit and then iPad target-runtime testing. 5F itself remains open until Cory performs the touch gate and classifies UX PASS / PARTIAL PASS / UX FAIL.
