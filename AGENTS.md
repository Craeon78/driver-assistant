# Agent notes — Driver Assistant

This repository is **product code** for the tanker Driver Assistant iPad app.

## Orchestration lives elsewhere

Operating rules (PREBUILD / BUILD / GO / review loops / change reports) live in **`Craeon78/CozzaHQ`**, not here.

A cold agent that lands here first must:

1. Read this file.
2. Open `Craeon78/CozzaHQ` and follow `AGENTS.md` plus `docs/domain-routing.md`.
3. Treat this repo as authoritative for implementation, Intent-to-Build, and gate documents.
4. Not invent HQ process from this repo alone.

## What to look for in this repo

- Chunk Intent / gate docs: currently under `v3/` (e.g. `CHUNK5G_INTENT_TO_BUILD.md`, `CHUNK5G_REAL_SHIFT_GATE.md`).
- Current harness / UI: `v3/UI/` and `sources/` as applicable.
- Use the latest **merged** Intent on `main` unless a feature branch is already the authorised construction surface.

## Authority

Cory is the human principal. Substantial file changes follow CozzaHQ GO / build-system rules. Discussion is not write authority.
