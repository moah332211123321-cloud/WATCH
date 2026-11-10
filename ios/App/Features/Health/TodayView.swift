import SwiftData
import SwiftUI

/// S02: today's rings and the latest value of each metric.
struct TodayView: View {
    @Environment(DeviceController.self) private var device
    @Query(sort: \DaySummaryRecord.day, order: .reverse) private var summaries: [DaySummaryRecord]
    @Query(sort: \HealthSampleRecord.date, order: .reverse) private var samples: [HealthSampleRecord]
    @AppStorage("stepGoal") private var stepGoal = 8000
    @AppStorage("kcalGoal") private var kcalGoal = 400

    private var today: DaySummaryRecord? {
        summaries.first { Calendar.current.isDateInToday($0.day) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tok.Space.l) {
                    statusBanner
                    ringsCard
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Tok.Space.m) {
                        ForEach([Metric.heartRate, .bloodOxygen, .bloodPressure, .sleep, .stress, .temperature, .weight, .glucose]) { metric in
                            NavigationLink(value: metric) { metricCard(metric) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Tok.Space.l)
            }
            .background(Tok.bg)
            .navigationTitle(L("Today"))
            .navigationDestination(for: Metric.self) { MetricDetailView(metric: $0) }
            .refreshable { await device.sync() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "person.crop.circle") }
                        .accessibilityLabel(Text(L("Profile and settings")))
                }
            }
        }
    }

    @ViewBuilder private var statusBanner: some View {
        if !device.isConnected {
            UnsupportedNote(reason: L("No watch connected. Data shown is from the last sync."))
        } else if device.isSyncing {
            Label(L("Syncing with your watch…"), systemImage: "arrow.triangle.2.circlepath")
                .font(.footnote).foregroundStyle(Tok.textMuted)
        } else if let error = device.syncError {
            Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Tok.warning)
        }
    }

    private var ringsCard: some View {
        let steps = today?.steps ?? 0
        let kcal = today?.kilocalories ?? 0
        return HStack(spacing: Tok.Space.xl) {
            MetricRing(rings: [
                .init(progress: Double(steps) / Double(max(stepGoal, 1)), color: Tok.steps),
                .init(progress: Double(kcal) / Double(max(kcalGoal, 1)), color: Tok.energy),
            ])
            .frame(width: 120, height: 120)
            .accessibilityLabel(Text(L("Daily goals")))
            VStack(alignment: .leading, spacing: Tok.Space.s) {
                NavigationLink(value: Metric.steps) {
                    VStack(alignment: .leading) {
                        Text(L("Steps")).font(.subheadline).foregroundStyle(Tok.steps)
                        Text(verbatim: steps.formatted()).font(.title.bold()).foregroundStyle(Tok.text)
                    }
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading) {
                    Text(L("Active energy")).font(.subheadline).foregroundStyle(Tok.energy)
                    HStack(alignment: .firstTextBaseline, spacing: Tok.Space.xs) {
                        Text(verbatim: kcal.formatted()).font(.title.bold()).foregroundStyle(Tok.text)
                        Text(L("kcal")).font(.footnote).foregroundStyle(Tok.textMuted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Tok.Space.l)
        .background(Tok.surface, in: RoundedRectangle(cornerRadius: Tok.Radius.l, style: .continuous))
    }

    private func metricCard(_ metric: Metric) -> some View {
        Card(title: metric.title, systemImage: metric.icon, tint: metric.color) {
            if metric == .sleep, let today, today.lightSleepMinutes + today.deepSleepMinutes > 0 {
                let total = today.lightSleepMinutes + today.deepSleepMinutes
                MetricValue(value: "\(total / 60):" + String(format: "%02ld", total % 60), unit: L("h"))
            } else if let latest = samples.first(where: { $0.metric == metric }) {
                MetricValue(value: metric.format(latest.value, latest.value2), unit: metric.unit)
                Text(latest.date, style: .relative).font(.caption).foregroundStyle(Tok.textMuted)
            } else {
                Text(L("No data yet")).font(.subheadline).foregroundStyle(Tok.textMuted)
            }
        }
    }
}
