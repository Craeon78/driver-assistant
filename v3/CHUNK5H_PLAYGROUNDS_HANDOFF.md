# Chunk 5H — Playgrounds handoff candidate

**State:** Candidate until PR review, merge and Niles verification against `main`. Do not treat this file as a completed iPad run.

## Device-side changes relative to a 5G master containing PR #39 and the compile fix

| Action | Repository path | Playgrounds action |
| --- | --- | --- |
| ADD | `v3/Tests/Chunk5HIntegrationPreflightTests.swift` | Add as a new Swift source. |
| ADD | `v3/Chunk5HPreflightPlaygroundsRunner.swift` | Add as a new Swift source. |
| REPLACE | `v3/Driver/WorkRestLedger.swift` | Replace existing canonical Driver ledger source. |
| REPLACE | `v3/Tests/Chunk5GRecoveryMigrationTests.swift` | Replace the executable legacy recovery regression with its 5H migration expectations. |
| REPLACE | `v3/UI/Chunk5FPrototypeStore.swift` | Replace live workflow store. |
| REPLACE | `v3/UI/Chunk5FAdaptiveWorkspaceView.swift` | Replace live workspace with canonical fatigue readout. |
| REPLACE | `v3/UI/Chunk5GEventLog.swift` | Replace Gate report data definition. |
| REPLACE | `v3/UI/Chunk5GGateReportView.swift` | Replace Gate report display. |
| DELETE | none | Do not delete 5G tests or sources. |
| UNCHANGED | Other V3 Cargo/Run/Vehicle/Policy sources | Retain the current `main` versions. |

If the Playgrounds master predates PR #39, this delta is insufficient: sync the current `main` V3 sources first, including the `CocoaError(.fileWriteUnknown)` compile fix. This manifest is relative to `main` at `bf23ef7`; check again if `main` moves before import.

**Before importing:** finish and archive any active 5G shift. An older mid-shift snapshot has no canonical Driver intervals; 5H must not silently invent past Work/Rest on upgrade. Begin the field gate from a fresh `READY TO START` state.
If an older active snapshot is already present, retain its original evidence and use the recovery-locked path; do not try to resume its Cargo or Run as a 5H shift.

## Temporary preflight ContentView

If local `ContentView.swift` still points to the 5G final-field runner, temporarily replace its content with the following complete view for the preflight only:

```swift
import SwiftUI

struct ContentView: View {
    @State private var result = "Running 5H preflight…"

    var body: some View {
        ScrollView {
            Text(result)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .task {
            result = Chunk5HPreflightPlaygroundsRunner.runGate()
        }
    }
}
```

Expected final line: `PREFLIGHT PASS — FIELD GATE STILL REQUIRED`. Preserve the full output if any check reads FAIL or Playgrounds reports a compile/runtime error. This fixture uses its own isolated UserDefaults suite; it must not write to the normal live Driver file or shift.

## Restore the live entry point before the real shift

Replace the temporary preflight `ContentView.swift` with this complete view, unless the actual 5G master has a different app entry convention that Niles identifies at handoff:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Chunk5FAdaptiveWorkspaceView()
    }
}
```

Launch and verify the top bar says `LIVE`, the opening screen says `READY TO START`, and the Driver fatigue readout does not say `Driver ledger unavailable`. A `FIXTURE` label means this is not the live field path. Do not run the test runner in place of the normal UI during work.

## Live-shift evidence to return

1. Run the real shift as it unfolds. Record planned versus actual Rest/Other Work, deliveries, Run edits and exceptions that genuinely occur. Do not force a zero delivery or exception.
2. After mixed committed activity, terminate/reopen the app when safe and check cargo, current Run and Rest/Work context before continuing. Report any missing or duplicated event.
3. At End Shift capture the Gate Report, including opening/closing ODO, events, canonical Driver ledger status, representation integrity, cargo checks, persistence/replay and `NOT ESTABLISHED` operational completeness. Record the actual work DA missed or misrepresented independently; do not edit DA history to match an external report.
4. Return screenshots or copied Gate output plus concise observations and any compiler/runtime failure. Niles adjudicates; preflight success and merge are not PASS.

Keep the normal live `ContentView.swift` after the preflight. The temporary runner view is only a diagnostic entry point.
