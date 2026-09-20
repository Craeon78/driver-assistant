# Chunk 5F — iPad Field-Test Findings and V3 Interaction Resolution

**Status:** FIELD TEST FINDINGS — DESIGN INPUT  
**Date:** 20 September 2026  
**Scope:** Findings from hands-on iPad testing of the Chunk 5F adaptive-workspace UX harness. This is not a production specification and does not close 5F.

## Purpose

This document preserves the discoveries made while physically using the 5F harness so another developer/reviewer can continue the work without reconstructing the design reasoning from chat.

The central result is that the V3 adaptive-workspace concept is viable, but several targeted UX repairs and one broader interaction-model decision are required.

---

## 1. Core interaction principle: one truth/evidence plumbing, configurable interaction resolution

Driver Assistant must not have separate underlying logging systems for "basic" and "detailed" drivers.

The major operational anchors and automatic evidence plumbing remain the same. Driver settings determine how much intermediate detail the driver is invited or able to establish.

### Three layers

1. **Core anchors** — required/major facts needed for Driver Assistant to remain useful and truthful.
   Examples: shift boundaries, cargo-changing events, delivery/load confirmation, transfers, necessary reconciliation, ODO anchors, and work/rest facts required by the fatigue model.

2. **Automatic evidence** — captured observations/signals without requiring repetitive driver entry where technically and ethically appropriate.
   Examples: timestamps, GPS breadcrumbs, moving/stationary periods, location/site proximity and app interactions. These are evidence inputs; they do not become physical facts merely because DA captured them.

3. **Derived projections** — calculated views produced from authoritative committed events plus relevant evidence/context.
   Examples: current calculated cargo balance, projected cargo state, Run projections and other snapshots. These are useful outputs, not independent evidence or source truth, and must never be fed back as if they were authoritative events.

4. **Optional operational refinement** — additional driver-established points or classifications that increase resolution.
   Examples: waiting/demurrage, repositioning, prep, pack-up, paperwork, richer other-work classification, arrival/departure detail and operational notes.

A higher-detail driver may therefore have secondary layers available from existing controls rather than a primary screen covered in extra buttons.

### The two boundaries that must be designed explicitly

V3 needs a deliberate **minimum useful interaction floor** and **maximum practical interaction ceiling**.

**Minimum useful floor:** the fewest driver-entered/confirmed data points that still allow DA to perform its core job accurately enough to be genuinely useful. Anything removed below this line makes DA functionally weak, misleading, or unable to provide its intended assistance.

**Maximum practical ceiling:** the richest useful driver-confirmed resolution before extra prompts, buttons or classifications create interaction fatigue, distract from the physical job, encourage forgotten/late taps, or create false precision. Anything beyond this line costs more attention than the information is worth.

The production design lives between these boundaries. Driver settings choose the desired interaction resolution, but cannot disable core questions necessary for cargo truth, fatigue/work-rest integrity or other fundamental functions.

**Canonical principle:**

> Capture the strongest defensible evidence once. Preserve the same major anchors. Allow the driver to refine the operational record only to a useful, chosen resolution.

More detail must mean **more accurate/useful information**, not simply more taps.

---

## 2. Work/rest illustrates the resolution model

At low resolution a shift may be represented as:

`WORK → REST → WORK → END SHIFT`

The same shift at greater operational resolution may include:

`START SHIFT → DRIVE → SITE → REPOSITION → DELIVERY → WAITING → DELIVERY → DRIVE → REST → …`

The major shift hours do not change. Additional points refine what happened inside those hours.

However, a stationary GPS interval must not silently become REST. Stationary evidence may indicate an opportunity to ask the driver while the event is fresh.

Example:

> Stationary for 18 min. Record as REST?  
> YES / NO

A higher-detail configuration may expose additional classifications such as REST, WAITING/DEMURRAGE, OTHER WORK or another appropriate label.

This is especially important on time-constrained days: a potentially valid rest period should be captured/confirmed near the event rather than forcing the driver to retrofit the day from memory at shift end.

Exact fatigue/compliance semantics remain subject to the production rules engine and legal verification.

---

## 3. Multi-fill Site Visits need an inter-fill state/evidence gap

The 5F harness currently assumes:

`Fill 1 confirmed → Fill 2 immediately current`

That is too simple.

Real SeaLink Cleveland example:

`Minjerrabah delivery → reposition/crawl → stationary/wait → Seabreeze delivery`

The iPad is assumed to remain in the truck during physical delivery work. Requiring the driver to press NEXT immediately before leaving the cab creates a memory obligation and may produce worse timestamps.

### Direction

After Fill 1 confirmation:
- mark Fill 1 complete;
- expose Fill 2 as the **next expected fill/context**;
- do not claim physical pumping has begun;
- allow GPS/time evidence to record movement/stationary intervals;
- allow the subsequent fill to be recorded when the driver returns to the iPad;
- where useful, ask the driver to classify a meaningful unexplained stationary interval.

GPS establishes evidence, not REST, demurrage or pumping.

The detailed interaction setting may expose additional secondary controls, but normal multi-fill work must not depend on perfect pre-delivery button discipline.

---

## 4. Pre-shift

### Finding
START SHIFT is not prominent enough in the current harness.

### Change
Move START SHIFT from the Driver/Truck column into the centre/Today area and make it a large, obvious primary action.

The existing opening ODO/location checkpoint remains conceptually valid after Start Shift.

---

## 5. Active Run

### Passed
- Hold/drag reorder while stationary/crawl: **PASS**
- Moving-state restraint: **PASS**
- Removing reorder manipulation while moving while retaining information: **PASS**

### Finding: plan must progressively become actual execution

The test deliberately completed work out of original plan order. The displayed Run remained tied too strongly to the original list.

Rule:

> Today’s Run begins as a plan and progressively becomes a record of actual execution.

Confirmed work may settle above current/remaining work after confirmation/return to Active. GPS alone must not silently reorder the Run. Remaining work remains editable plan.

### Fixture limitation
The 5F dummy Run contains customer visits but no real ATOM/BP terminal/load stops. The standalone TERMINAL / LOAD button is harness scaffolding.

Production Run must support operational sequence items such as terminal/load stops as well as customer Site Visits.

---

## 6. Delivery workspace

### Passed
- Truck-as-input concept: **PASS**
- Direct numeric/type precision: **PASS**
- Confirm as projection-to-truth boundary: **PASS conceptually**

### Partial: contextual snap

Near the planned delivery "magic number", the compartment area visibly shook/oscillated and made dragging difficult.

Likely repair direction:
- invariant drag coordinate/frame geometry;
- fill redraws inside a fixed compartment frame;
- surrounding totals/difference/snap indicators use stable geometry;
- snap hysteresis/latching: capture threshold and release threshold are different;
- snap threshold/state logic must not itself trigger layout movement.

Drag does not need one-litre precision because direct typing is available.

Desired stack remains:

`DRAG → CONTEXT SNAP → PRECISION → CONFIRM`

Classification: **Delivery concept PASS / snap precision PARTIAL PASS**.

---

## 7. Load workspace

### Multimodal Load Draft: PASS

Field test confirmed that simulated scan, drag and direct numeric entry can all manipulate one proposed Load Draft.

There must not be separate "OCR load" and "manual load" workflows.

### Product editing required

Product type must be easy to change per compartment as part of the same draft.

Correct shorthand discovered during field test:
- **XLS** = diesel
- **ULP** = unleaded 91
- **P95** = premium unleaded 95
- **P98** = premium unleaded 98
- **DIE** = Direct Into Equipment; this is an operational/delivery designation, **not diesel**

The 5F fixture's use of DIE to mean diesel must not migrate into production.

Product selection for a **fresh/new compartment, an explicitly degassed/cleared compartment, or a draft compartment whose confirmed fuel state permits the change** can be simple.

A compartment must retain **two distinct product-related states** where applicable:

1. **liquid product state** — the product currently represented by litres in the compartment; and
2. **residual/vapour state** — the chemically relevant product family/history that can remain when liquid reaches zero.

Therefore **0 L does not mean blank or freely relabellable**. A previously used compartment can be liquid-empty while still carrying diesel residue or petrol-family vapour/residue. That residual state persists until an explicit valid state-changing event such as Degas clears it, in accordance with the Fuel/Cargo contract.

Changing the asserted product where confirmed liquid cargo or incompatible residual/vapour state already exists must use the appropriate physical workflow/reconciliation rather than silently relabelling the compartment. The UI may make product selection easy; it must not collapse the two product states or bypass Fuel compatibility/state rules.

### Product colour

Different products should be visually distinguishable in the truck graphic, but colour must not carry two meanings.

Separate:
- **product identity** — XLS/ULP/P95/P98/etc.;
- **state** — confirmed cargo vs proposed/draft cargo.

Product identity should never rely on colour alone; the short code remains visible.

Final palette/state treatment is not a 5F decision.

---

## 8. Load top-right panel: EIP first, paperwork behind a modal

Current inline PAPERWORK / SHOW DETAILS behaviour is not desirable. Expanding details beneath the truck changes the primary workspace geometry and disconnects the revealed information from the control that opened it.

### Revised hierarchy

Top row:
- **Left:** Terminal / Mini Map / location context
- **Centre:** Driver Load Plan — miniature representation used by the driver for the physical terminal/load-plan process
- **Right:** EIP / emergency-information area

The EIP deserves immediate screen presence because it relates directly to current cargo/emergency information.

At the bottom of the EIP panel:

**SHOW PAPERWORK**

This opens a large iPad modal/overlay containing the two structured paperwork likenesses. The Load workspace remains stationary underneath.

The likenesses are DA structured representations, not retained photos and not legal substitutes for physical documents.

Photo/OCR principle remains:

`PHOTO → OCR/EXTRACT → STRUCTURED DRAFT → DISCARD PHOTO`

The physical paperwork remains the reference the driver checks against.

Exact EIP/DG/document requirements must be verified before production wording/rules are implemented.

---

## 9. Rest workspace

**PASS for 5F.**

Current hierarchy is adequate for this gate:
- rest/fatigue state dominant;
- Run remains visible but subdued;
- recovery is foregrounded without hiding the driver's information.

Future interaction-resolution settings may expose secondary classification/detail without requiring redesign of the primary Rest workspace.

---

## 10. Persistent top row

In the 5F harness the persistent top instrument row is primarily a visual/state shell. Attention, ODO/location, compass, fatigue detail, next-destination interaction, menu and settings are not fully wired production controls.

Do not classify their lack of navigation as 5F UX failures. Assess their information hierarchy/state presentation in this gate.

---

## 11. Missing planning workspace

Field testing exposed a missing paper/design state: **Plan Run**.

The current pre-shift screen shows the result of planning but no workspace for constructing the operational day.

Plan Run should be designed separately rather than jammed into the 5F repair pass. It must accommodate terminal/load stops, Site Visits/fills, reloads, fixed/requested times, cargo requirements, travel/geography, fatigue constraints and driver judgement.

Planning remains optional and must not block unplanned work.

---

## 12. Recommended next pass

Do a targeted 5F UX repair, not an exhaustive production build:

1. centralise/enlarge START SHIFT;
2. stabilise delivery drag geometry and add snap hysteresis;
3. revise multi-fill progression so next fill is expected context rather than a falsely started operation;
4. allow confirmed execution to reconcile Run ordering;
5. replace Load PAPERWORK panel with EIP and SHOW PAPERWORK modal;
6. correct DIE/XLS fixture terminology;
7. preserve scan + drag + type as one Load Draft;
8. record product selection/visual differentiation as V3 requirements;
9. leave Rest substantially unchanged;
10. design Plan Run as its own subsequent paper/UX exercise;
11. explicitly design/test the minimum useful interaction floor and maximum practical interaction ceiling before production interaction settings are frozen.

---

## 13. Gate disposition

The iPad field test does **not** demonstrate production readiness.

It does demonstrate that the adaptive-workspace concept survives target-runtime touch testing well enough to continue.

Current disposition:

- **Target runtime:** PASS after iPad compile repairs
- **Adaptive workspace concept:** PASS WITH REFINEMENT
- **Run reorder:** PASS
- **Moving restraint:** PASS
- **Delivery interaction:** CONCEPT PASS / SNAP PRECISION PARTIAL
- **Load multimodality:** PASS
- **Rest workspace:** PASS
- **Multi-fill progression:** PARTIAL
- **Product editing/differentiation:** REQUIRED, NOT YET TESTED
- **Plan Run:** MISSING DESIGN STATE
- **Interaction-resolution floor/ceiling:** REQUIRED ARCHITECTURE/UX DECISION

Do not close 5F merely because the harness runs. Apply/review the targeted findings, then decide the formal gate closure.
