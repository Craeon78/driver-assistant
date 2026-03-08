
import SwiftUI

  

extension TodayView {

    //======================================

    // MARK: - Todayview+Timeline Section (Expandable Rows)

    //======================================

    //

    // Purpose:

    // - Show chronological list of activity segments

    // - Expandable rows reveal contextual data (odo, location, events, loads)

    //

    // Pre-persistence scope:

    // - Operates on in-memory segmentsToday + confirmedLoads + odoLocationRecords

    // - Lost on restart

    //

    // Post-persistence:

    // - Will query from SQLite

    // - May support editing (time corrections, notes)

    //

    // Design:

    // - Always shows Start Shift + End Shift markers as "slots"

    //   (data fills in once events exist)

    // - Collapsed: segment type + time range + location (if available)

    // - Expanded: odo/location details, events during segment, confirmed loads

    //

    //======================================

    var timelineSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Timeline")

                .font(.headline)

            // Segments (finished + current)

            let segs = model.timelineSegmentsIncludingCurrent

            // Shift markers anchored to ODO capture contexts (visible everywhere)

            let startRec = model.odoLocationRecords.last(where: { $0.context == .shiftStart })

            let endRec   = model.odoLocationRecords.last(where: { $0.context == .shiftEnd })

            // --- START SHIFT slot (always visible) ---

            ShiftMarkerRow(

                title: "START SHIFT",

                time: startRec?.timestamp,

                subtitle: startRec == nil

                ? "Pending (odo/location not captured yet)"

                : "Odo \(startRec!.odoText) • \(startRec!.suburb.trimmingCharacters(in: .whitespacesAndNewlines))",

                symbol: "play.circle.fill"

            )

            Divider()

            // --- Segment list ---

            if segs.isEmpty {

                Text("No activity recorded yet.")

                    .font(.caption)

                    .foregroundStyle(.secondary)

            } else {

                ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in

                    TimelineRow(segment: seg)

                        .environmentObject(model)

                    Divider()

                }

            }

            // --- END SHIFT slot (always visible) ---

            ShiftMarkerRow(

                title: "END SHIFT",

                time: endRec?.timestamp,

                subtitle: endRec == nil

                ? "Pending (odo/location not captured yet)"

                : "Odo \(endRec!.odoText) • \(endRec!.suburb.trimmingCharacters(in: .whitespacesAndNewlines))",

                symbol: "stop.circle.fill"

            )

        }

    }

}

  

// MARK: - Shift marker row (outside segments)

  

private struct ShiftMarkerRow: View {

    let title: String

    let time: Date?

    let subtitle: String?

    let symbol: String

    var body: some View {

        HStack(alignment: .top, spacing: 10) {

            Image(systemName: symbol)

                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {

                HStack {

                    Text(title)

                        .font(.subheadline)

                        .fontWeight(.bold)

                    Spacer()

                    if let time {

                        Text(time, style: .time)

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    } else {

                        Text("—")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                }

                if let subtitle, !subtitle.isEmpty {

                    Text(subtitle)

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                }

            }

        }

        .padding(.vertical, 4)

        .padding(.horizontal, 6)

        .background(Color.gray.opacity(0.08))

        .cornerRadius(8)

    }

}

  

private struct TimelineRow: View {

    @EnvironmentObject var model: AppModel

    let segment: ActivitySegment

    @State private var isExpanded: Bool = false

    private var endTime: Date { segment.end ?? Date() }

    private var isLive: Bool { segment.end == nil }

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            Button {

                isExpanded.toggle()

            } label: {

                HStack(alignment: .top) {

                    VStack(alignment: .leading, spacing: 2) {

                        Text(segment.type.displayName)

                            .font(.subheadline)

                        Text("\(segment.start, style: .time) → \(isLive ? "now" : endTime.formatted(date: .omitted, time: .shortened))")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                        if let rec = model.odoRecord(for: segment) {

                            let suburb = rec.suburb.trimmingCharacters(in: .whitespacesAndNewlines)

                            if !suburb.isEmpty {

                                Text(suburb)

                                    .font(.caption2)

                                    .foregroundStyle(.secondary)

                            }

                        }

                        let km = model.kmApprox(for: segment)

                        Text(String(format: "Segment distance (klm): %.1f", km))

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.right")

                        .font(.caption)

                        .foregroundStyle(.secondary)

                }

            }

            .buttonStyle(.plain)

            if isExpanded {

                expandedDetails

                    .padding(.top, 2)

            }

        }

        .padding(.vertical, 4)

    }

    @ViewBuilder

    private var expandedDetails: some View {

        let rec = model.odoRecord(for: segment)

        let segEvents = model.events(during: segment)

        let segLoads: [ConfirmedLoad] = model.confirmedLoadsDuring(segment)

        VStack(alignment: .leading, spacing: 6) {

            // Odo + location

            if let rec {

                HStack {

                    Text("Odo:")

                    Text(rec.odoText).bold()

                    Spacer()

                    Text(rec.timestamp, style: .time)

                        .foregroundStyle(.secondary)

                }

                .font(.caption)

                let suburb = rec.suburb.trimmingCharacters(in: .whitespacesAndNewlines)

                if !suburb.isEmpty {

                    Text("Location: \(suburb)")

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                }

            } else {

                // Odo + location (ONLY if we have a record)

                if let rec = model.odoRecord(for: segment) {

                    HStack {

                        Text("Odo:")

                        Text(rec.odoText).bold()

                        Spacer()

                        Text(rec.timestamp, style: .time)

                            .foregroundStyle(.secondary)

                    }

                    .font(.caption)

                    let suburb = rec.suburb.trimmingCharacters(in: .whitespacesAndNewlines)

                    if !suburb.isEmpty {

                        Text("Location: \(suburb)")

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                }

            }

            // Events inside segment

            if !segEvents.isEmpty {

                Text("Events:")

                    .font(.caption)

                    .bold()

                let visibleEvents = segEvents.filter { ev in

                    ![

                        .driveStart,

                        .load,

                        .unload

                    ].contains(ev.kind)

                }

                if !visibleEvents.isEmpty {

                    ForEach(visibleEvents, id: \.id) { ev in

                        let note = (ev.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                        let line = "• \(ev.kind.rawValue)" + (note.isEmpty ? "" : " — \(note)")

                        Text(line)

                            .font(.caption2)

                            .foregroundStyle(.secondary)

                    }

                }

            }

            // Confirmed loads inside segment

            // Confirmed loads inside segment

            if !segLoads.isEmpty {

                Text("Confirmed loads:")

                    .font(.caption)

                    .bold()

                ForEach(segLoads, id: \.id) { load in

                    // Find previous confirmed load in the *global* list (not just this segment)

                    let prevTotal: Int = {

                        guard let idx = model.confirmedLoads.firstIndex(where: { $0.id == load.id }) else { return 0 }

                        guard idx > 0 else { return 0 }

                        return model.confirmedLoads[idx - 1].totalLitres

                    }()

                    let delta = abs(load.totalLitres - prevTotal)

                    // Friendly verb based on mode (optional)

                    let verb = (load.mode.rawValue.uppercased().contains("UNLOAD")) ? "UNLOAD" : "LOAD"

                    Text("• \(verb) @ \(load.timestamp.formatted(date: .omitted, time: .shortened)) — \(delta)L / \(load.totalLitres)L")

                        .font(.caption2)

                        .foregroundStyle(.secondary)

                }

            }

            Text("Notes: (post-persistence)")

                .font(.caption2)

                .foregroundStyle(.secondary)

        }

        .padding(8)

        .background(Color.gray.opacity(0.08))

        .cornerRadius(8)

    }

}
