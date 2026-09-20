# Chunk 5F — iPad Touch Gate

**State:** CANDIDATE READY FOR TARGET-RUNTIME TEST  
**Branch:** `chunk5f-adaptive-workspace`

This is a UX harness, not production V3.

## Run it

Use `Chunk5FAdaptiveWorkspaceHarnessView()` as the Swift Playgrounds root view after bringing the branch into the iPad project.

## Touch sequence

### A — Pre-shift
- Confirm the persistent top instrument bar reads clearly.
- Confirm Truck 92/readiness/run information is understandable without hunting.
- Tap **START SHIFT**.
- PASS if Active workspace replaces Pre-shift without feeling like a separate app.

### B — Active / Driving
- With prototype speed at 0, reorder TODAY'S RUN by hold/drag.
- Tap **SIMULATE DRIVING**. Speed becomes 42 km/h.
- Confirm Run remains readable but reorder is unavailable.
- Confirm site/load manipulation buttons are unavailable while moving.
- Tap **SIMULATE STOP** and confirm manipulation returns.
- PASS if driving is information-rich but interaction-poor without hiding useful information.

### C — Site / Delivery
- Open SeaLink Cleveland.
- Confirm it is one Site Visit with Minjerrabah and Seabreeze underneath.
- For Minjerrabah, drag C4 from 3,200 to EMPTY/0.
- Drag C5 from 7,200 toward 5,400 and feel whether the planned-remainder snap is useful rather than obstructive.
- Tap/type an exact number to test precision.
- Use **UNDO**, then repeat C4=0 and C5=5,400.
- Confirm the receiving visual reads as movement only, not a claimed customer tank level.
- Confirm **5,000 L DELIVERY**.
- PASS if Seabreeze becomes current without returning to Active.
- Do not judge final colours/polish.

### D — Load
- From Active, open **TERMINAL / LOAD**.
- Tap **SCAN BOL (SIMULATED)**.
- Confirm the same truck draft changes; there is no separate OCR mode.
- Alter one compartment by drag and one by typing.
- Use Undo and rescan if useful.
- Confirm the wording makes you compare the whole DA representation with the physical BOL conceptually.
- Tap **CONFIRM LOAD**.
- PASS if scan/drag/type feel like three manipulators of one proposed load state.

### E — Rest
- From Active tap **START REST**.
- Confirm fatigue/current rest is visually dominant.
- Confirm Today’s Run remains available but subdued.
- Confirm the screen does not pressure you with leave-now/lateness messaging.
- Tap **END REST**.
- PASS if recovery is foregrounded without paternalistically hiding the day.

## Report

For each state report:
- PASS / PARTIAL PASS / UX FAIL
- what your finger expected;
- what actually happened;
- anything too dense, too small or too slow;
- any moment the app appeared to invent a fact;
- anything from V2 you immediately missed.

Especially report:
- drag feel;
- EMPTY snap;
- 5,400 L planned-remainder snap;
- numeric precision entry;
- Run reorder;
- moving-state interaction suppression;
- Load density;
- Rest emphasis;
- state transitions.

A compile, screenshot or merge is not the 5F result. The target-runtime touch gate is.
