
import SwiftUI

  

//======================================

// MARK: - Simulation Screen (v0.2)

//======================================

//

// Purpose:

// - Load template "sandbox" for Truck 92 mass simulation.

// - Save templates and apply them to the live Load Plan.

// - Includes a separate fatigue simulator (Phase 1 testing aid).

//

// Important separation (TWO simulators in one screen):

// 1. LOAD MASS SIM (top panels):

//    - Driven by AppModel.draftTemplate

//    - Edits DO affect saved templates

//    - "Apply to Load Plan" writes to live AppModel.compartments

//

// 2. FATIGUE SIM (bottom panel):

//    - Driven by local SimulationModel (isolated)

//    - Changes do NOT affect real shift data

//    - Pure sandbox for testing fatigue rules

//

// Notes / constraints (pre-persistence):

// - Saved templates are currently in-memory (lost on relaunch) unless you later persist them.

// - This screen intentionally mixes two "simulators":

//   (1) Load mass sim (driven by AppModel.draftTemplate + recalcDraftSimulation())

//   (2) Fatigue sim (local SimulationModel, does NOT touch real shift data)

//

// Future:

// - After persistence, templates become durable + searchable + taggable.

// - Fatigue sim can move behind a Debug/Dev panel.

//

//======================================

  

struct SimulationView: View {

  

    @EnvironmentObject var model: AppModel

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 16) {

                // A) Template editor

                templateEditor

                // B) Results preview

                resultsPanel

                // C) Save + library

                templateLibrary

                // D) Fatigue simulation (Phase 1 testing aid)

                Phase1StartPlannerCard()

                FatigueSimulationView()

            }

            .padding()

        }

        .navigationTitle("Simulation")

    }

}

  

//======================================

// MARK: - Fatigue Simulation (local-only)

//======================================

//

// This is intentionally isolated from AppModel.

// It exists purely as a “what if I did…” sandbox for fatigue testing.

//

struct FatigueSimulationView: View {

    @StateObject private var sim = SimulationModel()

    @State private var sliderTime: Double = 0    // seconds from 0 → 25h

    @State private var simScheme: FatigueScheme = .standardHV

    private func dayAndClock(_ t: TimeInterval) -> String {

        let totalMin = Int(t / 60)

        let day = totalMin / (24*60) + 1

        let minsInDay = totalMin % (24*60)

        let h = minsInDay / 60

        let m = minsInDay % 60

        return "Day \(day) • \(String(format: "%02d:%02d", h, m))"

    }

    @State private var simStartDate: Date = {

        var cal = Calendar(identifier: .gregorian)

        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

        return cal.startOfDay(for: Date())

    }()

    // For flashing the countdown bar when a rule is breached (temporary UI)

    @State private var countdownFlashOn = false

    private let maxSimTime: TimeInterval = 365 * 24 * 3600

    private func nudge(_ delta: TimeInterval) {

        // Snap to whole minutes after every move to avoid float creep.

        let next = sliderTime + delta

        let clamped = min(max(next, 0), maxSimTime)

        sliderTime = (clamped / 60).rounded() * 60

    }

    var body: some View {

        VStack(spacing: 20) {

  

            timeControlsSection

            Divider()

            inputControlsSection

            Divider()

            driverSummarySection

            Divider()

            FatigueEnginePanel(

                scheme: $simScheme,

                segments: engineSegments,

                now: engineNow

            )

            Divider()

            //========================================

            // Fatigue bars (mirrors TodayView style)

            //========================================

            fatigueBars

            Divider()

            segmentsSection

  

        }

        .padding()

        .background(Color.gray.opacity(0.06))

        .cornerRadius(12)

        .onAppear {

            print("FatigueSimulationView appeared. simStartDate=\(simStartDate)")

        }

    }

    private var timeControlsSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Simulated time")

                .font(.headline)

            Slider(value: $sliderTime, in: 0...maxSimTime, step: 300)

            Text("Position: \(dayAndClock(sliderTime))")

                .font(.caption)

                .foregroundColor(.secondary)

            HStack(spacing: 8) {

                Button("-15m") { nudge(-15*60) }

                Button("-30m") { nudge(-30*60) }

                Button("-1h")  { nudge(-3600) }

                Button("+15m") { nudge(15*60) }

                Button("+30m") { nudge(30*60) }

                Button("+1h")  { nudge(3600) }

            }

            .buttonStyle(.bordered)

            HStack(spacing: 8) {

                Button("-5h")  { nudge(-5*3600) }

                Button("-7h")  { nudge(-7*3600) }

                Button("-12h") { nudge(-12*3600) }

                Button("+5h")  { nudge(5*3600) }

                Button("+7h")  { nudge(7*3600) }

                Button("+12h") { nudge(12*3600) }

            }

            .buttonStyle(.bordered)

            HStack(spacing: 8) {

                Button("◀︎ Day") { nudge(-24*3600) }

                Button("Snap 00:00") {

                    let day = floor(sliderTime / (24*3600))

                    sliderTime = day * 24*3600

                }

                Button("Day ▶︎") { nudge(24*3600) }

                Spacer()

                Text("Day \(Int(sliderTime / (24*3600)) + 1)")

                    .font(.caption2)

                    .foregroundStyle(.secondary)

            }

            .buttonStyle(.bordered)

        }

    }

    private var inputControlsSection: some View { 

        //========================================

        // Input controls

        //========================================

        HStack(spacing: 16) {

            Button("Add WORK to here") {

                sim.addWork(to: sliderTime)

            }

            .buttonStyle(.borderedProminent)

            Button("Add REST to here") {

                sim.addRest(to: sliderTime)

            }

            .buttonStyle(.bordered)

            Button("Reset") {

                sim.reset()

                sliderTime = 0

                simStartDate = {

                    var cal = Calendar(identifier: .gregorian)

                    cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

                    return cal.startOfDay(for: Date())

                }()

            }

            .buttonStyle(.bordered)

        }

    }    // add work/rest/reset

    private var driverSummarySection: some View { 

        VStack(alignment: .leading, spacing: 8) {

            Text("Driver Summary")

                .font(.headline)

            ForEach(driverSummaryGrowing, id: \.dayStart) { day in

                HStack {

                    VStack(alignment: .leading) {

                        Text(day.dayStart, style: .date)

                            .font(.subheadline)

                        if day.totalWork == 0 {

                            Text("OFF")

                                .foregroundColor(.secondary)

                        } else {

                            Text("Start: \(timeString(day.firstWorkStart))")

                            Text("Finish: \(timeString(day.lastWorkEnd))")

                            Text("Work: \(fmt(day.totalWork))")

                        }

                    }

                    Spacer()

                    if day.hasNightRest {

                        Text("🌙")

                    }

                }

                .padding(.vertical, 4)

                Divider()

            }

        }

        .padding()

        .background(Color(.systemGray6))

        .cornerRadius(8)

    }    // the 14-day list

    private var segmentsSection: some View { 

        //========================================

        // Timeline of simulated segments

        //========================================

        VStack(alignment: .leading, spacing: 6) {

            Text("Segments")

                .font(.headline)

            ForEach(sim.segments) { seg in

                HStack {

                    Text(seg.type == .work ? "WORK" : "REST")

                        .font(.caption)

                        .frame(width: 60, alignment: .leading)

                    Text("\(formatTimeHM(seg.start)) → \(formatTimeHM(seg.end))")

                        .font(.caption2)

                        .foregroundColor(.secondary)

                }

            }

            if sim.segments.isEmpty {

                Text("No segments yet. Use the buttons above to build a day.")

                    .font(.caption2)

                    .foregroundColor(.secondary)

                    .padding(.top, 4)

            }

        }

    }         // “Segments” list

    private func timeString(_ date: Date?) -> String {

        guard let date else { return "--:--" }

        let formatter = DateFormatter()

        formatter.dateFormat = "HH:mm"

        return formatter.string(from: date)

    }

    private func fmt(_ seconds: TimeInterval) -> String {

        let s = Int(seconds)

        let h = s / 3600

        let m = (s % 3600) / 60

        return "\(h)h \(m)m"

    }

    //========================================

    // MARK: - Fatigue bars (mirrors TodayView)

    //========================================

    private var fatigueBars: some View {

        let workToday = sim.workSecondsToday

        let legalRest = sim.legalRestToday

        let hasTakenLegalRest15 = legalRest >= FatigueConstants.legalBreak15

        // 12h bar maths

        let twelveHours: TimeInterval = FatigueConstants.nhvrDailyCap

        let elevenHours: TimeInterval = CountdownThresholds.cautionThresholdMinutes

        let ratio = min(workToday / twelveHours, 1.0)

        let colour: Color

        if workToday <= elevenHours { colour = .green }

        else if workToday <= twelveHours { colour = .orange }

        else { colour = .red }

        let remaining = max(twelveHours - workToday, 0)

        return VStack(alignment: .leading, spacing: 16) {

            Text("Fatigue (simulated)")

                .font(.headline)

            // 5h15 spacing rule (NHVR-style) — Simulation semantics match TodayView:

            // - Grey circle until the first ≥15m legal rest exists

            // - Green tick once at least one ≥15m legal rest exists (and not breached)

            // - Red when breached (worked ≥5h15 since last ≥15m legal rest)

            VStack(alignment: .leading, spacing: 6) {

                let w = sim.workSinceLastRest()

                let limit: TimeInterval = FatigueConstants.nhvrSpacingLimit

                let (symbolName, color, statusText): (String, Color, String) = {

                    if w < limit {

                        let remaining = formatTimeHM(limit - w)

                        if !hasTakenLegalRest15 {

                            return ("circle", .gray,

                                    "No ≥15m legal rest logged yet. First legal rest due in \(remaining).")

                        } else {

                            return ("checkmark.circle.fill", .green,

                                    "OK. Next legal rest due in \(remaining).")

                        }

                    } else {

                        let over = formatTimeHM(w - limit)

                        return ("xmark.octagon.fill", .red,

                                "Over by \(over). Take ≥15m legal rest ASAP.")

                    }

                }()

                HStack(alignment: .top, spacing: 8) {

                    Image(systemName: symbolName)

                        .foregroundColor(color)

                    VStack(alignment: .leading, spacing: 2) {

                        Text("5h15 spacing rule (NHVR)")

                            .font(.subheadline)

                        Text("Max 5h15 work between ≥15m legal rests.")

                            .font(.caption2)

                            .foregroundColor(.secondary)

                        Text(statusText)

                            .font(.caption2)

                            .foregroundColor(color)

                    }

                }

            }

            // 12h total work bar

            VStack(alignment: .leading, spacing: 4) {

                HStack {

                    Text("Work today (total)")

                        .font(.subheadline)

                    Spacer()

                    Text("\(formatTimeHM(workToday)) / 12h 00m")

                        .font(.caption)

                }

                ProgressView(value: ratio)

                    .tint(colour)

                HStack {

                    Text("Total work towards 12h daily cap.")

                    Spacer()

                    Text("Remaining: \(formatTimeHM(remaining))")

                }

                .font(.caption2)

                .foregroundColor(.secondary)

            }

            // Countdown to NEXT rule using shared logic

            nextRuleCountdownSection

            Text("Legal rest today (≥15m blocks): \(formatTimeHM(legalRest))")

                .font(.caption2)

                .foregroundColor(.secondary)

        }

    }

    //========================================

    // MARK: - Countdown bar (shared engine)

    //========================================

    private var nextRuleCountdownSection: some View {

        let workToday     = sim.workSecondsToday

        let legalRest     = sim.legalRestToday

        let workSinceRest = sim.workSinceLastRest()

        let next = determineNextRule(

            workSinceRest: workSinceRest,

            workToday: workToday,

            legalRest: legalRest

        )

        let severity = countdownSeverity(

            forRemaining: next.remaining,

            window: next.window

        )

        let ratio = max(0.0, min(next.remaining / max(next.limit, 1), 1.0))

        let barColor: Color = {

            switch severity {

            case .normal:   return .green

            case .caution:  return .yellow

            case .warning:  return .orange

            case .critical: return .red

            case .breached: return .red

            }

        }()

        let barOpacity: Double =

        (severity == .breached && countdownFlashOn) ? 0.3 : 1.0

        let remaining = next.remaining

        let remainingText = formatTimeHM(abs(remaining))

        let sign = remaining >= 0 ? "" : "-"

        let subtitleText: String

        let subtitleColor: Color

        switch severity {

        case .breached:

            let ruleName = next.title.replacingOccurrences(of: "Next rule: ", with: "")

            subtitleText = "\(ruleName) is now due / exceeded. Take legal rest as soon as practicable."

            subtitleColor = .red

        case .critical:

            subtitleText = "\(next.descriptionPrefix) in \(remainingText)."

            subtitleColor = .red

        default:

            subtitleText = "\(next.descriptionPrefix) in \(remainingText)."

            subtitleColor = .secondary

        }

        return VStack(alignment: .leading, spacing: 4) {

            HStack {

                Text(next.title)

                    .font(.subheadline)

                Spacer()

                Text("\(sign)\(remainingText) remaining")

                    .font(.caption)

            }

            ProgressView(value: ratio)

                .tint(barColor)

                .opacity(barOpacity)

                .onAppear { updateCountdownFlashing(for: severity) }

                .onChange(of: severity, initial: false) { _, newSeverity in

                    updateCountdownFlashing(for: newSeverity)

                }

            Text(subtitleText)

                .font(.caption2)

                .foregroundColor(subtitleColor)

                .fixedSize(horizontal: false, vertical: true)

        }

        .padding(.top, 8)

    }

    private func updateCountdownFlashing(for severity: CountdownSeverity) {

        if severity == .breached {

            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {

                countdownFlashOn = true

            }

        } else {

            countdownFlashOn = false

        }

    }

    //========================================

    // MARK: - Engine bridge (Sim time → real Dates)

    //========================================

    private var engineNow: Date {

        simStartDate.addingTimeInterval(sliderTime)

    }

    private var engineSegments: [WorkRestSegment] {

        sim.segments.map { s in

            WorkRestSegment(

                kind: (s.type == .work) ? .work : .rest,

                start: simStartDate.addingTimeInterval(s.start),

                end: simStartDate.addingTimeInterval(s.end),

                stationaryRest: (s.type == .rest) // sim currently assumes rest is stationary

            )

        }

    }

    private var driverSummary14: [DailyDriverSummary] {

        FatigueEngine.build14DaySummary(

            segments: engineSegments,

            now: engineNow,

            tz: TimeZone(identifier: "Australia/Brisbane") ?? .current

        )

    }

  var driverSummaryGrowing: [DailyDriverSummary] {

        let tz = TimeZone(identifier: "Australia/Brisbane") ?? .current

        var cal = Calendar(identifier: .gregorian)

        cal.timeZone = tz

        let endDay   = cal.startOfDay(for: engineNow)

        let startDay = cal.date(byAdding: .day, value: -13, to: endDay)!

        // If you want night-rest to match the engine's judgement,

        // we can reuse build14DaySummary as a "night rest oracle" for nearby days.

        let nightByDay = Dictionary(uniqueKeysWithValues: driverSummary14.map { ($0.dayStart, $0.hasNightRest) })

        func minDate(_ a: Date?, _ b: Date) -> Date { a.map { min($0, b) } ?? b }

        func maxDate(_ a: Date?, _ b: Date) -> Date { a.map { max($0, b) } ?? b }

        var out: [DailyDriverSummary] = []

        var day = startDay

        while day <= endDay {

            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!

            var total: TimeInterval = 0

            var first: Date? = nil

            var last: Date?  = nil

            for seg in engineSegments where seg.kind == .work {

                let segStart = seg.start

                let segEnd   = seg.end ?? engineNow   // ✅ unwrap optional end using "now"

                // overlap test with [day, nextDay)

                if segEnd <= day || segStart >= nextDay { continue }

                let s = max(segStart, day)

                let e = min(segEnd, nextDay)

                if e > s {

                    total += e.timeIntervalSince(s)

                    first = minDate(first, s)

                    last  = maxDate(last, e)

                }

            }

            out.append(

                DailyDriverSummary(

                    dayStart: day,

                    firstWorkStart: first,

                    lastWorkEnd: last,

                    totalWork: total,

                    hasNightRest: nightByDay[day] ?? false

                )

            )

            day = nextDay

        }

        return out

    }

}

  

//======================================

// MARK: - Load template simulation panels

//======================================

  

private extension SimulationView {

    var templateEditor: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Draft template")

                .font(.headline)

            TextField("Template name", text: $model.draftTemplate.name)

                .textFieldStyle(.roundedBorder)

                .onChange(of: model.draftTemplate.name) { _, _ in

                    model.recalcDraftSimulation()

                }

            ForEach($model.draftTemplate.items) { $item in

                HStack(spacing: 12) {

                    // Product picker that writes into item.productShortName

                    Picker("", selection: $item.productShortName) {

                        Text("—").tag("")

                        ForEach(FuelProducts.all) { p in

                            Text(p.shortName).tag(p.shortName)

                        }

                    }

                    .pickerStyle(.menu)

                    .frame(width: 90, alignment: .leading)

                    .onChange(of: item.productShortName) { _, _ in

                        model.recalcDraftSimulation()

                    }

                    TextField("Litres", value: $item.litres, format: .number)

                        .textFieldStyle(.roundedBorder)

                        .keyboardType(.numberPad)

                        .frame(width: 90)

                        .onChange(of: item.litres) { _, _ in

                            model.recalcDraftSimulation()

                        }

                    // SG slider bound to the PRODUCT (same product moves together)

                    if let prod = FuelProducts.all.first(where: { $0.code == item.productShortName }) {

                        let sgBinding = Binding<Double>(

                            get: { model.sg(for: prod) },

                            set: { newValue in

                                model.setSg(newValue, for: prod)

                                model.recalcDraftSimulation()

                            }

                        )

                        HStack(spacing: 8) {

                            Text("SG").font(.caption)

                            Slider(value: sgBinding, in: prod.sgMin...prod.sgMax, step: 0.001)

                            Text(String(format: "%.3f", model.sg(for: prod)))

                                .font(.caption)

                                .foregroundStyle(.secondary)

                        }

                    }

                }

            }

        }

        .padding()

        .background(.thinMaterial)

        .cornerRadius(12)

    }

    var resultsPanel: some View {

        let r = model.draftSimulationResult

        return VStack(alignment: .leading, spacing: 8) {

            Text("Result")

                .font(.headline)

            Text("Total litres: \(r.totalLitres)")

            Text("Total mass: \(Int(r.totalMassKg)) kg")

            Divider()

            Text("Steer: \(Int(r.steerKg)) / \(Int(r.maxSteerKg)) kg")

            Text("Drive: \(Int(r.driveKg)) / \(Int(r.maxDriveKg)) kg")

            Text("GVM: \(Int(r.gvmKg)) / \(Int(r.maxGvmKg)) kg")

            if let warning = r.warning, !warning.isEmpty {

                Divider()

                Text(warning)

                    .font(.subheadline)

                    .foregroundStyle(.red)

            }

        }

        .padding()

        .background(.thinMaterial)

        .cornerRadius(12)

    }

    var templateLibrary: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("Saved templates")

                    .font(.headline)

                Spacer()

                Button("Save template") {

                    model.saveDraftAsNewTemplate()

                }

                .buttonStyle(.borderedProminent)

            }

            if model.savedTemplates.isEmpty {

                Text("No templates yet.")

                    .foregroundStyle(.secondary)

            } else {

                ForEach(model.savedTemplates) { t in

                    HStack {

                        VStack(alignment: .leading) {

                            Text(t.name).font(.headline)

                            Text("\(t.items.map { "\($0.compartmentName): \($0.productShortName) \($0.litres)L" }.joined(separator: "  •  "))")

                                .font(.caption)

                                .foregroundStyle(.secondary)

                                .lineLimit(2)

                        }

                        Spacer()

                        Button("Load") {

                            model.draftTemplate = t

                            model.recalcDraftSimulation()

                        }

                        .buttonStyle(.bordered)

                        Button("Apply to Load") {

                            model.applyTemplateToLoadPlan(t)

                        }

                        .buttonStyle(.borderedProminent)

                    }

                    .padding(.vertical, 6)

                }

            }

        }

        .padding()

        .background(.thinMaterial)

        .cornerRadius(12)

    }

}
