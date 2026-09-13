# V3 Chunk 1 — Silent Spine

Status: IN PROGRESS
Owner: Core
Authority: V3_REFACTOR_CONTRACT.md + resources/v3/V3_ROADMAP.md

## Goal
Establish the V3 ownership model, event spine, canonical IDs and minimal persistence so a fabricated shift can be saved and replayed, including forced crash/relaunch.

No real GPS, fatigue rules, Fuel UI or AppModel changes in this chunk.

## Gate
V3 boots, saves and replays a fabricated shift correctly, including forced crash/relaunch.

Close as PASS / PASS WITH RESIDUALS / FAIL before opening Chunk 2.

## Ownership (locked for this chunk)
- Core owns: lifecycle, persistence, event spine, canonical IDs, breadcrumbs/distance evidence interface (stub only), module infrastructure.
- Driver, Vehicle, Operations, Cargo etc. remain empty shells or absent until their chunks.
- V2 sources/ remain the behavioural and algorithmic reference. Do not edit them for V3 work.

## Slice contract (this chunk)
- Owning domain: Core
- Allowed dependencies: Foundation, nothing else yet
- Prohibited ownership: any Driver/Vehicle/Operations/Cargo truth, UI, GPS hardware, fatigue calculations
- Inputs: fabricated shift data only
- Outputs: saved event stream + successful replay to equivalent state
- Invariants to protect later: ODO as distance anchor, no silent consequential state changes, driver authority beats inference, corrections preserve provenance
- Acceptance: gate above
- Non-goals: real sensors, real UI, real fatigue, Fuel, multi-day querying

## Files introduced
- v3/Core/CanonicalID.swift
- v3/Core/Event.swift
- v3/Core/EventStore.swift
- v3/Core/ShiftFabricator.swift
- v3/Shared/Units.swift
- v3/Tests/SilentSpineGateTests.swift

## Next after gate
Chunk 2 — Distance truth engine (migrate proven V2 GPS filtering behind Core evidence interface).
