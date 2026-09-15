# V3 Chunk 3a — Work/Rest Ledger Spine

Status: **PASS** (device gate 2026-09-15)
Owner: Driver
Authority: CHUNK3_DRIVER_TRUTH.md + Red Team 2026-09-15

## Goal
A persistent, append-oriented Work/Rest ledger that survives relaunch and overnight-open segments. No full NHVR maths in this sub-chunk.

## Gate result
All structural checks PASS on device: closed shift, relaunch open preserved, overnight single open entry spanning midnight, shift end preserves history, explicit close.

## Red Team non-negotiables (held)
1. Ledger-only feed
2. Continuous timeline — midnight/shift never wipe history
3. Binary kind — work | rest only

## Files
- Driver/WorkRestEntry.swift
- Driver/WorkRestLedger.swift
- Tests/LedgerSpineGateTests.swift
- LedgerPlaygroundsRunner.swift
