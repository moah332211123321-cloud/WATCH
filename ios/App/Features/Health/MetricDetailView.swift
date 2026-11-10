import Charts
import SwiftData
import SwiftUI
import WatchCore

/// S03–S08: chart by day/week/month, measure now, manual entry, list with sources.
struct MetricDetailView: View {
    enum Range: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self { case .day: return L("Day"); case .week: return L("Week"); case .month: return L("Month") }
        }
        var start: Date {
            let cal = Calendar.current, now = Date()
            switch self {
            case .day: return cal.startOfDay(for: now)
            case .week: return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!
            case .month: return cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))!
            }
        }
    }

    let metric: Metric
    @Environment(DeviceController.self) private var device
    @Environment(\.modelContext) private var context
    @Query private var samples: [HealthSampleRecord]
    @Query(sort: \DaySummaryRecord.day) private var summaries: [DaySummaryRecord]
    @Query(sort: \SleepSegmentRecord.start) private var sleep: [SleepSegmentRecord]
    @State private var range: Range = .week
    @State private var measuring = false
    @State private var measureError: String?
    @State private var showAdd = false

    init(metric: Metric) {
        self.metric = metric
        let raw = metric.rawValue
        _samples = Query(filter: #Predicate<HealthSampleRecord> { $0.metricRaw == raw },
                         sort: \HealthSampleRecord.date, order: .reverse)
    }

    private var inRange: [HealthSampleRecord] { samples.filter { $0.date >= range.start } }

    var body: some View {
        List {
            Section {
                Picker(L("Range"), selection: $range) {
                    ForEach(Range.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                chart.frame(height: 220)
            }
            if let kind = metric.measureKind { measureSection(kind) }
            if metric == .stress || metric == .sleep {
                Section { UnsupportedNote(reason: L("Values come from your watch's own algorithm. Stage details are not confirmed yet.")) }
            }
            Section(L("History")) {
                if metric == .steps {
                    ForEach(summaries.reversed().filter { $0.day >= range.start }) { s in
                        row(date: s.day, value: s.steps.formatted(), source: .device, dateOnly: true)
                    }
                } else if metric == .sleep {
                    ForEach(sleep.reversed().filter { $0.start >= range.start }) { s in
                        row(date: s.start, value: "\(s.minutes)", source: .device)
                    }
                } else if inRange.isEmpty {
                    Text(L("No data yet")).foregroundStyle(Tok.textMuted)
                } else {
                    ForEach(inRange) { s in
                        row(date: s.date, value: metric.format(s.value, s.value2), source: s.source)
                    }
                    .onDelete { offsets in
                        for i in offsets where inRange[i].source == .manual { context.delete(inRange[i]) }
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle(metric.title)
        .toolbar {
            if metric.allowsManualEntry {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text(L("Add entry")))
            }
        }
        .sheet(isPresented: $showAdd) { ManualEntryView(metric: metric) }
    }

    @ViewBuilder private var chart: some View {
        if metric == .steps {
            Chart(summaries.filter { $0.day >= range.start }) {
                BarMark(x: .value(S("Date"), $0.day, unit: .day), y: .value(S("Steps"), $0.steps))
                    .foregroundStyle(metric.color)
            }
        } else if metric == .sleep {
            Chart(sleep.filter { $0.start >= range.start }) {
                BarMark(x: .value(S("Date"), $0.start, unit: .day), y: .value(S("Minutes"), $0.minutes))
                    .foregroundStyle(metric.color)
            }
        } else if metric == .bloodPressure {
            Chart(inRange) {
                RuleMark(x: .value(S("Date"), $0.date), yStart: .value(S("Diastolic"), $0.value2 ?? $0.value),
                         yEnd: .value(S("Systolic"), $0.value))
                    .foregroundStyle(metric.color).lineStyle(StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        } else {
            Chart(inRange) {
                LineMark(x: .value(S("Date"), $0.date), y: .value(S("Value"), $0.value))
                    .foregroundStyle(metric.color)
                PointMark(x: .value(S("Date"), $0.date), y: .value(S("Value"), $0.value))
                    .foregroundStyle(metric.color)
            }
        }
    }

    private func measureSection(_ kind: MeasureKind) -> some View {
        Section {
            if device.capabilities[metric.capability ?? .heartRate] == .unsupported {
                UnsupportedNote(reason: L("Your watch reports that it can't measure this."))
            } else {
                Button {
                    Task { await measure(kind) }
                } label: {
                    HStack {
                        Label(measuring ? L("Measuring… keep the watch on your wrist") : L("Measure now"),
                              systemImage: metric.icon)
                        Spacer()
                        if measuring { ProgressView() }
                    }
                }
                .disabled(!device.isConnected || measuring)
                if kind == .heartRate, let live = device.liveHeartRate {
                    MetricValue(value: "\(live)", unit: L("bpm"))
                }
                if let measureError {
                    Text(measureError).font(.footnote).foregroundStyle(Tok.danger)
                }
                if !device.isConnected {
                    Text(L("Connect your watch to measure.")).font(.footnote).foregroundStyle(Tok.textMuted)
                }
            }
        }
    }

    private func measure(_ kind: MeasureKind) async {
        measuring = true
        measureError = nil
        defer { measuring = false }
        do {
            let sample = try await device.measure(kind)
            var single = sample
            single.isLive = false // a measurement the user asked for is stored even if it came as a live value
            HealthRepository(context: context).store(.sample(single), deviceID: device.connectedID)
        } catch {
            measureError = describe(error)
        }
    }

    private func row(date: Date, value: String, source: SampleSource, dateOnly: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(date, format: dateOnly ? Date.FormatStyle.dateTime.day().month() : Date.FormatStyle.dateTime.day().month().hour().minute())
                Text(source.label).font(.caption).foregroundStyle(Tok.textMuted)
            }
            Spacer()
            Text(verbatim: value).font(.headline).foregroundStyle(Tok.text)
        }
    }
}

/// Manual entry: stored with source "manual", never shown as a watch measurement.
struct ManualEntryView: View {
    let metric: Metric
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var value = ""
    @State private var value2 = ""

    private var parsed: (Double, Double?)? {
        guard let v = Double(value.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
        if metric == .bloodPressure {
            guard let d = Double(value2), d > 0, d < v else { return nil }
            return (v, d)
        }
        return (v, nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(L("Time"), selection: $date, in: ...Date())
                TextField(metric == .bloodPressure ? L("Systolic") : metric.title, text: $value)
                    .keyboardType(.decimalPad)
                if metric == .bloodPressure {
                    TextField(L("Diastolic"), text: $value2).keyboardType(.numberPad)
                }
                Text(metric.unit).foregroundStyle(Tok.textMuted)
            }
            .navigationTitle(L("Add entry"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save")) {
                        if let p = parsed {
                            HealthRepository(context: context).addManual(metric, date: date, value: p.0, value2: p.1)
                            dismiss()
                        }
                    }
                    .disabled(parsed == nil)
                }
            }
        }
    }
}
