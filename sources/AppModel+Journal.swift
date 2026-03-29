//======================================
// MARK: - AppModel+Journal
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+Journal.swift
//
// Purpose:
// - Prepares a unified timeline (“journal”) of the driver’s day for review, reconstruction, and export.
//
// Responsibilities:
// - Aggregate shift events into a continuous, ordered timeline.
// - Support NHVR work diary views (24-hour compliance window).
// - Provide data for map + timeline synchronisation (scrubbing / replay).
// - Enable reconstruction of a shift via user interaction (timeline focus + map context).
//
// Notes:
// - Pre-persistence planning layer; not yet implemented.
// - Journal sits above raw events and below UI (derived, not authoritative).
// - Will likely become the bridge between timeline, map, and export (PDF/CSV).
//
// Phase: Pre-persistence (planned)
//======================================

import SwiftUI

// Future planning
