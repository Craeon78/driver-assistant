
import SwiftUI

  

//======================================

// MARK: - Location Status Overlay (Top-Left)

//======================================

//

// Purpose:

// - Show live GPS/location service status

// - Alert driver to permission issues, staleness, reduced accuracy

// - Provide manual "Recover" button when GPS wedges

//

// Display:

// - Status banner (dismissible, auto-hide after 6s)

// - Status pill (always visible):

//   - Colored dot (green/orange/red)

//   - Service state label

//   - "Updated Xs ago" counter

//   - "Recover" button (when stalled/error)

//

// States:

// - idle: grey (not started yet)

// - running: green (good GPS)

// - requestingPermission: orange (waiting for user)

// - reducedAccuracy: orange (precise location OFF)

// - pausedOrStalled: orange (no updates >20s)

// - denied: red (location permission denied)

// - restricted: red (MDM/parental controls)

// - error: red (CoreLocation failure)

//

// Notes:

// - Owned by ContentView (overlaid above TabView)

// - Observes LocationManager @Published state

// - Ticks every 1s to update "Xs ago" counter

//

//======================================

  

struct LocationStatusView: View {

  

    @EnvironmentObject var locationManager: LocationManager

    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {

        VStack(spacing: 8) {

            // Banner (only shows when manager wants it)

            if locationManager.showStatusBanner, let msg = locationManager.lastStatusMessage {

                HStack(spacing: 8) {

                    Image(systemName: "location.circle")

                    Text(msg)

                        .font(.caption)

                        .lineLimit(3)

                    Spacer()

                    Button("Dismiss") {

                        locationManager.showStatusBanner = false

                    }

                    .font(.caption)

                }

                .padding(10)

                .background(.thinMaterial)

                .cornerRadius(10)

            }

            // Status pill

            HStack(spacing: 8) {

                Circle()

                    .frame(width: 10, height: 10)

                    .foregroundStyle(dotColor(for: locationManager.serviceState))

                Text(label(for: locationManager.serviceState))

                    .font(.caption)

                    .foregroundStyle(.secondary)

                    .lineLimit(1)

                Spacer()

                // Age (compact, always visible when we have a timestamp)

                if let t = locationManager.lastUpdateAt {

                    Text("Updated \(Int(now.timeIntervalSince(t)))s ago")

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                        .monospacedDigit()

                }

                // Recover button

                if shouldShowRecover(for: locationManager.serviceState) {

                    Button("Recover") {

                        locationManager.recover(reason: "UI Recover")

                    }

                    .font(.caption)

                    .buttonStyle(.bordered)

                }

            }

            .padding(10)

            .background(.thinMaterial)

            .cornerRadius(10)

        }

        .onReceive(ticker) { now = $0 } // attach once, not inside conditional

    }

    private func shouldShowRecover(for state: LocationManager.ServiceState) -> Bool {

        switch state {

        case .pausedOrStalled:

            return true

        case .error:

            return true

        default:

            return false

        }

    }

    private func label(for state: LocationManager.ServiceState) -> String {

        switch state {

        case .idle: return "Location: idle"

        case .requestingPermission: return "Location: requesting permission"

        case .running: return "Location: running"

        case .pausedOrStalled: return "Location: stalled"

        case .denied: return "Location: denied"

        case .restricted: return "Location: restricted"

        case .reducedAccuracy: return "Location: reduced accuracy (Precise OFF)"

        case .error(let msg): return "Location: error (\(msg))"

        }

    }

    private func dotColor(for state: LocationManager.ServiceState) -> Color {

        switch state {

        case .running: return .green

        case .requestingPermission, .reducedAccuracy, .pausedOrStalled: return .orange

        case .denied, .restricted, .error: return .red

        case .idle: return .gray

        }

    }

}
