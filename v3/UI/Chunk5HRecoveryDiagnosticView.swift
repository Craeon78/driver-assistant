import SwiftUI

struct Chunk5HRecoveryDiagnosticView: View {
    @State private var result: Chunk5FPrototypeStore.RecoveryDiagnostic? = nil
    @State private var rawJSON: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("5H Recovery Diagnostic")
                    .font(.largeTitle)
                
                Text("READ ONLY — preserved evidence is not modified.")
                
                if result == nil {
                    Text("Reading preserved evidence...")
                }
                
                if let r = result {
                    Text("Live snapshot exists: \(r.liveSnapshotExists ? "PASS" : "FAIL")")
                    Text("Snapshot bytes: \(r.liveSnapshotBytes)")
                    Text("Valid JSON: \(r.jsonReadable ? "PASS" : "FAIL")")
                    Text("Snapshot decodes: \(r.snapshotDecodes ? "PASS" : "FAIL")")
                    Text("Snapshot validates: \(r.snapshotValidates ? "PASS" : "FAIL")")
                    Text("Driver ledger matches: \(r.driverStoreValidates ? "PASS" : "FAIL")")
                    
                    if let count = r.snapshotDriverEntryCount {
                        Text("Snapshot Driver entries: \(count)")
                    } else {
                        Text("Snapshot Driver entries: —")
                    }
                    
                    if let count = r.currentDriverEntryCount {
                        Text("Current Driver entries: \(count)")
                    } else {
                        Text("Current Driver entries: —")
                    }
                    
                    if let stage = r.failureStage {
                        Divider()
                        
                        Text("FAILURE STAGE")
                            .font(.headline)
                        
                        Text(stage)
                            .font(.title2)
                    }
                    
                    if let detail = r.failureDetail {
                        Text("DETAIL")
                            .font(.headline)
                        
                        Text(detail)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    if r.failureStage == nil {
                        Divider()
                        
                        Text("ALL RECOVERY CHECKS PASSED")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    Button(rawJSON == nil ? "Show Raw JSON" : "Hide Raw JSON") {
                        if rawJSON == nil {
                            rawJSON = Chunk5FPrototypeStore().recoveryRawJSON()
                        } else {
                            rawJSON = nil
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    if let rawJSON {
                        Text("RAW PRESERVED SNAPSHOT")
                            .font(.headline)
                        
                        Text("Selectable UTF-8 text from the exact persisted snapshot bytes.")
                            .font(.caption)
                        
                        Text(rawJSON)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
        .task {
            result = Chunk5FPrototypeStore().recoveryDiagnostic()
        }
    }
}